import 'dart:async';

import '../core/utils/ids.dart';
import '../core/utils/text_utils.dart';
import '../data/models/article.dart';
import '../data/services/article_repository.dart';

/// On-demand archive query. Providers may honor more filters in future without
/// changing the search UI or inserting anything into the live feed.
class ArchiveSearchQuery {
  const ArchiveSearchQuery({
    required this.text,
    this.sourceIds = const <String>{},
    this.from,
    this.to,
    this.limit = 60,
  });

  final String text;
  final Set<String> sourceIds;
  final DateTime? from;
  final DateTime? to;
  final int limit;

  String get cacheKey => <String>[
        TextUtils.searchNormalize(text),
        (sourceIds.toList()..sort()).join(','),
        from?.toUtc().toIso8601String() ?? '',
        to?.toUtc().toIso8601String() ?? '',
        '$limit',
      ].join('|');
}

class ArchiveProviderResult {
  const ArchiveProviderResult({
    this.articles = const <Article>[],
    this.warning,
  });

  final List<Article> articles;
  final String? warning;
}

/// Extensible boundary for official publisher archives/documented APIs.
/// Providers return only metadata they actually received and never mutate the
/// repository's live feed.
abstract class ArchiveSearchProvider {
  String get id;
  String get label;
  Future<ArchiveProviderResult> search(ArchiveSearchQuery query);
}

/// Searches retained RSS/API records already obtained lawfully by normal feed
/// refresh. It can recover a story that has aged out of the 12-hour/7-day live
/// view without making another publisher request.
class CachedArticleArchiveProvider implements ArchiveSearchProvider {
  const CachedArticleArchiveProvider(this.repository);

  final ArticleRepository repository;

  @override
  String get id => 'retained-cache';

  @override
  String get label => 'Retained publisher feed cache';

  @override
  Future<ArchiveProviderResult> search(ArchiveSearchQuery query) async {
    final List<String> terms = TextUtils.searchNormalize(query.text)
        .split(' ')
        .where((String value) => value.length >= 2)
        .toList(growable: false);
    if (terms.isEmpty) return const ArchiveProviderResult();
    final List<Article> cached = await repository.searchArchiveCandidates();
    final List<({Article article, int score})> ranked =
        <({Article article, int score})>[];
    for (final Article article in cached) {
      if (query.sourceIds.isNotEmpty &&
          !query.sourceIds.contains(article.sourceId)) {
        continue;
      }
      final DateTime? published = article.publishedAt?.toUtc();
      if (query.from != null &&
          (published == null || published.isBefore(query.from!.toUtc()))) {
        continue;
      }
      if (query.to != null &&
          (published == null || published.isAfter(query.to!.toUtc()))) {
        continue;
      }
      final String title = TextUtils.searchNormalize(article.title);
      final String excerpt = TextUtils.searchNormalize(article.excerpt ?? '');
      var score = 0;
      for (final String term in terms) {
        if (title.contains(term)) score += 4;
        if (excerpt.contains(term)) score += 1;
      }
      // Require every meaningful term somewhere. This supports partial titles
      // without turning a one-word overlap into a misleading archive result.
      final bool allPresent = terms.every(
        (String term) => title.contains(term) || excerpt.contains(term),
      );
      if (allPresent && score > 0) ranked.add((article: article, score: score));
    }
    ranked.sort((a, b) {
      final int relevance = b.score.compareTo(a.score);
      if (relevance != 0) return relevance;
      return b.article.sortKey.compareTo(a.article.sortKey);
    });
    return ArchiveProviderResult(
      articles: ranked
          .take(query.limit)
          .map((value) => value.article)
          .toList(growable: false),
      warning: 'Results cover retained publisher feed records only.',
    );
  }
}

class ArchiveSearchResponse {
  const ArchiveSearchResponse({
    required this.articles,
    required this.providers,
    this.warnings = const <String>[],
  });

  final List<Article> articles;
  final List<String> providers;
  final List<String> warnings;
}

/// Aggregates permitted providers with timeout, dedupe and a short query cache.
/// There is deliberately no method that writes these articles to ArticleStore.
class ArchiveSearchService {
  ArchiveSearchService({required List<ArchiveSearchProvider> providers})
      : _providers = List<ArchiveSearchProvider>.unmodifiable(providers);

  static const Duration providerTimeout = Duration(seconds: 12);
  static const Duration cacheLifetime = Duration(minutes: 10);

  final List<ArchiveSearchProvider> _providers;
  final Map<String, ({DateTime at, ArchiveSearchResponse value})> _cache =
      <String, ({DateTime at, ArchiveSearchResponse value})>{};

  Future<ArchiveSearchResponse> search(ArchiveSearchQuery query) async {
    final String key = query.cacheKey;
    final cached = _cache[key];
    final DateTime now = DateTime.now().toUtc();
    if (cached != null && now.difference(cached.at) < cacheLifetime) {
      return cached.value;
    }

    final List<Article> combined = <Article>[];
    final List<String> warnings = <String>[];
    final List<String> searched = <String>[];
    for (final ArchiveSearchProvider provider in _providers) {
      searched.add(provider.label);
      try {
        final ArchiveProviderResult result =
            await provider.search(query).timeout(providerTimeout);
        combined.addAll(result.articles);
        if (result.warning != null) warnings.add(result.warning!);
      } on TimeoutException {
        warnings.add('${provider.label} timed out.');
      } catch (_) {
        warnings.add('${provider.label} is unavailable.');
      }
    }

    final Map<String, Article> byUrl = <String, Article>{};
    for (final Article article in combined) {
      final String canonical = Ids.canonicalUrl(article.link);
      // Provider order is relevance order; first provider/result wins while
      // canonical URL dedupe prevents the same record being presented twice.
      byUrl.putIfAbsent(canonical, () => article);
    }
    final List<Article> articles = byUrl.values.toList(growable: false);
    final ArchiveSearchResponse response = ArchiveSearchResponse(
      articles: articles.take(query.limit).toList(growable: false),
      providers: searched,
      warnings: warnings.toSet().toList(growable: false),
    );
    if (_cache.length >= 20) _cache.remove(_cache.keys.first);
    _cache[key] = (at: now, value: response);
    return response;
  }
}
