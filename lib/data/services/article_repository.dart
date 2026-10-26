import 'package:flutter/foundation.dart';

import '../../core/utils/article_freshness.dart';
import '../../core/utils/story_matcher.dart';

import '../feeds/feed_service.dart';
import '../models/article.dart';
import '../models/feed_query.dart';
import '../models/news_source.dart';
import '../models/source_health.dart';
import '../models/vocabulary_entry.dart';
import 'stores.dart';

/// Orchestrates feed fetching, caching and local persistence.
///
/// Policies implemented here:
///  * at most [concurrency] parallel requests;
///  * a per-source minimum gap between automatic fetches;
///  * cached content is served immediately and clearly marked as cached;
///  * a failing source never prevents other sources from updating.
class ArticleRepository {
  ArticleRepository({
    required this.registry,
    required this.stores,
    required this.feedService,
    DateTime Function()? clock,
  }) : _clock = clock ?? (() => DateTime.now().toUtc());

  final SourceRegistry registry;
  final AppStores stores;
  final FeedGateway feedService;
  final DateTime Function() _clock;

  static const String lastRefreshKey = 'last_refresh_at';
  static const String lastAttemptKey = 'last_attempt_at';
  static const Duration minimumSourceGap = Duration(minutes: 2);
  static const int concurrency = 4;

  Future<DateTime?> lastRefreshAt() async {
    final String? raw = await stores.meta.get(lastRefreshKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }

  Future<DateTime?> lastAttemptAt() async {
    final String? raw = await stores.meta.get(lastAttemptKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }

  Future<int> articleCount() => stores.articles.count();

  Future<List<Article>> loadFeed(
    FeedQuery query, {
    Set<String> followedSourceIds = const <String>{},
  }) async {
    final Set<String> sources = <String>{...query.sourceIds};
    if (query.followedOnly) {
      if (followedSourceIds.isEmpty) return const <Article>[];
      if (sources.isEmpty) {
        sources.addAll(followedSourceIds);
      } else {
        sources.retainAll(followedSourceIds);
        if (sources.isEmpty) return const <Article>[];
      }
    }
    // Read beyond the visible limit because stale and undated cache rows are
    // deliberately retained for Archive Search but may never re-enter live UI.
    // SQLite already sorts newest first. Decoding all 5,000 retained rows on
    // every filter or Home rebuild caused visible main-isolate stalls; a bounded
    // overscan is enough to discard stale rows while preserving pagination.
    final int scanLimit = query.limit * 4 < 400
        ? 400
        : query.limit * 4 > 1200
            ? 1200
            : query.limit * 4;
    final List<Article> cached = await stores.articles.latest(
      limit: scanLimit,
      sourceIds: sources,
      topics: query.topics,
      languages: query.languages,
      text: query.text,
    );
    return ArticleFreshness.eligible(
      cached,
      now: _clock(),
      limit: query.limit,
    );
  }

  Future<List<Article>> articlesForSource(String sourceId, {int limit = 40}) async {
    final List<Article> cached =
        await stores.articles.bySource(sourceId, limit: 250);
    return ArticleFreshness.eligible(cached, now: _clock(), limit: limit);
  }

  Future<Article?> articleById(String id) => stores.articles.byId(id);

  Future<List<Article>> searchArticles(String text, {int limit = 40}) async {
    if (text.trim().isEmpty) return const <Article>[];
    final List<Article> cached =
        await stores.articles.latest(limit: 5000, text: text);
    return ArticleFreshness.eligible(cached, now: _clock(), limit: limit);
  }

  /// Retained cache search used only by Archive Search. It intentionally does
  /// not apply the live-feed freshness policy and never writes into the feed.
  Future<List<Article>> searchArchiveCandidates({int limit = 5000}) =>
      stores.articles.latest(limit: limit);

  Future<Map<String, SourceHealth>> healthMap() async {
    final List<SourceHealth> health = await stores.health.all();
    return <String, SourceHealth>{
      for (final SourceHealth item in health) item.sourceId: item,
    };
  }

  /// A query-independent live pool for Source Comparison. Building the index
  /// from the visible 80-row feed used to lose reports hidden by pagination,
  /// language, topic, following, or source filters.
  Future<List<Article>> comparisonCandidates({int limit = 5000}) async {
    final List<Article> cached = await stores.articles.latest(limit: limit);
    return ArticleFreshness.eligible(cached, now: _clock());
  }

  /// Publications that conservatively match [article], excluding the current
  /// report and duplicate publishers. Unlike the live index this scans retained
  /// cache too, so Article Detail opened from Archive can merge older matches.
  Future<List<Article>> relatedCoverage(Article article, {int limit = 6}) async {
    final List<Article> cached = await stores.articles.latest(limit: 5000);
    final Map<String, Article> byPublisher = <String, Article>{};
    for (final Article candidate in cached) {
      if (candidate.id == article.id ||
          candidate.sourceId == article.sourceId ||
          !StoryMatcher.matches(article, candidate)) {
        continue;
      }
      byPublisher.putIfAbsent(candidate.sourceId, () => candidate);
      if (byPublisher.length >= limit) break;
    }
    return byPublisher.values.toList(growable: false);
  }

  /// Fetches every enabled source (or a subset) and stores the results.
  Future<RefreshReport> refresh({
    bool force = false,
    Set<String>? onlySourceIds,
    void Function(int done, int total)? onProgress,
  }) async {
    final DateTime startedAt = _clock();
    await stores.meta.set(lastAttemptKey, startedAt.toIso8601String());

    final List<NewsSource> candidates = registry.feedSources
        .where((NewsSource s) => onlySourceIds == null || onlySourceIds.contains(s.id))
        .toList();
    final Map<String, FeedMeta> metaBySource = <String, FeedMeta>{
      for (final FeedMeta meta in await stores.feedMeta.all()) meta.sourceId: meta,
    };

    final List<NewsSource> due = <NewsSource>[];
    for (final NewsSource source in candidates) {
      final DateTime? last = metaBySource[source.id]?.lastFetchAt;
      if (!force && last != null && startedAt.difference(last) < minimumSourceGap) {
        continue;
      }
      due.add(source);
    }

    final int countBefore = await stores.articles.count();
    final List<FeedFetchOutcome> outcomes = <FeedFetchOutcome>[];
    var completed = 0;
    for (var i = 0; i < due.length; i += concurrency) {
      final List<NewsSource> chunk = due.sublist(
        i,
        (i + concurrency) > due.length ? due.length : i + concurrency,
      );
      final List<FeedFetchOutcome> chunkOutcomes = await Future.wait(
        chunk.map((NewsSource source) => _fetchSafely(source, startedAt)),
      );
      outcomes.addAll(chunkOutcomes);
      completed += chunk.length;
      onProgress?.call(completed, due.length);
    }

    final List<Article> fetched = <Article>[];
    final Map<String, String> failures = <String, String>{};
    var succeeded = 0;
    var failed = 0;
    var notModified = 0;
    final List<String> notes = <String>[];
    for (final FeedFetchOutcome outcome in outcomes) {
      await stores.health.upsert(outcome.health);
      // Pacing is the repository's job: record the attempt regardless of which
      // FeedGateway implementation performed it, keeping the cached
      // validators (ETag / Last-Modified) that the gateway wrote.
      await _recordAttempt(outcome, startedAt);
      if (outcome.notModified) {
        notModified++;
        succeeded++;
        continue;
      }
      if (outcome.health.isOk) {
        succeeded++;
        fetched.addAll(outcome.articles);
        if (outcome.health.lastError != null) {
          notes.add('${outcome.sourceId}: ${outcome.health.lastError}');
        }
      } else {
        failed++;
        failures[outcome.sourceId] = outcome.health.lastError ?? 'Unknown error';
      }
    }

    String? storageError;
    if (fetched.isNotEmpty) {
      try {
        await stores.articles.upsertAll(fetched);
        await stores.articles.prune();
      } catch (error) {
        // A storage failure must never look like a successful refresh, and it
        // must never discard the per-source diagnostics we just collected.
        storageError = 'Local cache write failed: $error';
        if (kDebugMode) debugPrint(storageError);
        for (final FeedFetchOutcome outcome in outcomes) {
          if (outcome.health.isOk) {
            failures[outcome.sourceId] = storageError;
          }
        }
      }
    }

    final int countAfter = storageError == null
        ? await stores.articles.count()
        : countBefore;
    final DateTime finishedAt = _clock();
    if (outcomes.any((FeedFetchOutcome o) => o.health.isOk)) {
      await stores.meta.set(lastRefreshKey, finishedAt.toIso8601String());
    }

    return RefreshReport(
      startedAt: startedAt,
      finishedAt: finishedAt,
      sourcesAttempted: outcomes.length,
      sourcesSucceeded: succeeded,
      sourcesFailed: failed,
      sourcesNotModified: notModified,
      newArticles: countAfter > countBefore ? countAfter - countBefore : 0,
      failures: failures,
      notes: notes,
      storageError: storageError,
    );
  }

  Future<void> _recordAttempt(FeedFetchOutcome outcome, DateTime startedAt) async {
    final FeedMeta? previous = await stores.feedMeta.get(outcome.sourceId);
    await stores.feedMeta.save(
      FeedMeta(
        sourceId: outcome.sourceId,
        etag: previous?.etag,
        lastModified: previous?.lastModified,
        lastFetchAt: startedAt,
        lastSuccessAt:
            outcome.health.isOk ? startedAt : previous?.lastSuccessAt,
        itemCount: outcome.notModified
            ? (previous?.itemCount ?? 0)
            : outcome.articles.length,
        lastError: outcome.health.lastError,
      ),
    );
  }

  Future<FeedFetchOutcome> _fetchSafely(NewsSource source, DateTime startedAt) async {
    try {
      return await feedService.fetch(source, now: startedAt);
    } catch (error) {
      await stores.health.upsert(SourceHealth(
        sourceId: source.id,
        status: SourceHealthStatus.failing,
        lastCheckedAt: startedAt,
        lastError: 'Unexpected error: ${error.runtimeType}',
      ));
      return FeedFetchOutcome(
        sourceId: source.id,
        health: SourceHealth(
          sourceId: source.id,
          status: SourceHealthStatus.failing,
          lastCheckedAt: startedAt,
          lastError: 'Unexpected error while reading the feed',
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Saved articles & history
  // ---------------------------------------------------------------------------

  Future<List<SavedArticle>> savedArticles() => stores.saved.all();

  Future<bool> isSaved(String id) => stores.saved.contains(id);

  Future<void> saveArticle(Article article) => stores.saved.save(article);

  Future<void> unsaveArticle(String id) => stores.saved.remove(id);

  Future<void> recordHistory(Article article) async {
    if (article.id.isEmpty) return;
    await stores.history.record(article);
  }

  Future<List<SavedArticle>> history({int limit = 60}) =>
      stores.history.recent(limit: limit);

  Future<void> clearHistory() => stores.history.clear();

  Future<List<VocabularyEntry>> vocabulary() => stores.vocabulary.all();

  Future<VocabularyEntry?> vocabularyByWord(String word) =>
      stores.vocabulary.byWord(word);

  Future<void> saveVocabulary(VocabularyEntry entry) =>
      stores.vocabulary.save(entry);

  Future<void> saveVocabularyAtomic(Iterable<VocabularyEntry> entries) =>
      stores.vocabulary.saveAllAtomic(entries);

  Future<void> removeVocabulary(String word) => stores.vocabulary.remove(word);

  Future<void> clearCache() async {
    await stores.articles.clear();
    await stores.meta.set(lastRefreshKey, null);
  }

}
