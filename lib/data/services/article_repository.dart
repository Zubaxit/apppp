import '../feeds/feed_service.dart';
import '../models/article.dart';
import '../models/feed_query.dart';
import '../models/news_source.dart';
import '../models/source_health.dart';
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
  static const Duration minimumSourceGap = Duration(minutes: 8);
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
    return stores.articles.latest(
      limit: query.limit,
      sourceIds: sources,
      topics: query.topics,
      languages: query.languages,
      text: query.text,
    );
  }

  Future<List<Article>> articlesForSource(String sourceId, {int limit = 40}) =>
      stores.articles.bySource(sourceId, limit: limit);

  Future<Article?> articleById(String id) => stores.articles.byId(id);

  Future<List<Article>> searchArticles(String text, {int limit = 40}) async {
    if (text.trim().isEmpty) return const <Article>[];
    return stores.articles.latest(limit: limit, text: text);
  }

  Future<Map<String, SourceHealth>> healthMap() async {
    final List<SourceHealth> health = await stores.health.all();
    return <String, SourceHealth>{
      for (final SourceHealth item in health) item.sourceId: item,
    };
  }

  /// Publications that covered the same story, excluding [article] itself.
  Future<List<Article>> relatedCoverage(Article article, {int limit = 6}) async {
    final String? key = article.clusterKey;
    if (key == null) return const <Article>[];
    final List<Article> same = await stores.articles.byClusterKey(key, limit: limit + 4);
    final Map<String, Article> byPublisher = <String, Article>{};
    for (final Article candidate in same) {
      if (candidate.id == article.id) continue;
      if (candidate.sourceId == article.sourceId) continue;
      byPublisher.putIfAbsent(candidate.sourceId, () => candidate);
    }
    return byPublisher.values.take(limit).toList();
  }

  /// Fetches every enabled source (or a subset) and stores the results.
  Future<RefreshReport> refresh({
    bool force = false,
    Set<String>? onlySourceIds,
    void Function(int done, int total)? onProgress,
  }) async {
    final DateTime startedAt = _clock();
    await stores.meta.set(lastAttemptKey, startedAt.toIso8601String());

    final List<NewsSource> candidates = registry.withFeeds
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

    if (fetched.isNotEmpty) {
      await stores.articles.upsertAll(fetched);
      await stores.articles.prune();
    }

    final int countAfter = await stores.articles.count();
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

  Future<void> clearCache() async {
    await stores.articles.clear();
    await stores.meta.set(lastRefreshKey, null);
  }

}
