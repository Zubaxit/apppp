import '../models/article.dart';
import '../models/news_source.dart';
import '../models/source_health.dart';
import '../services/stores.dart';
import 'feed_parser.dart';
import 'news_http_client.dart';

class FeedFetchOutcome {
  const FeedFetchOutcome({
    required this.sourceId,
    required this.health,
    this.articles = const <Article>[],
    this.notModified = false,
    this.warnings = const <String>[],
  });

  final String sourceId;
  final SourceHealth health;
  final List<Article> articles;
  final bool notModified;
  final List<String> warnings;

  bool get isSuccess => health.isOk;
}

/// Abstraction over feed fetching so repositories can be tested with fakes.
abstract class FeedGateway {
  Future<FeedFetchOutcome> fetch(NewsSource source, {DateTime? now});
}

/// Fetches one source's feed and records its health.
///
/// Sources are fetched independently: one publisher being down can never take
/// the unified feed with it.
class FeedService implements FeedGateway {
  FeedService({
    required NewsHttpClient httpClient,
    required FeedMetaStore metaStore,
    FeedParser parser = const FeedParser(),
  })  : _http = httpClient,
        _meta = metaStore,
        _parser = parser;

  final NewsHttpClient _http;
  final FeedMetaStore _meta;
  final FeedParser _parser;

  @override
  Future<FeedFetchOutcome> fetch(NewsSource source, {DateTime? now}) async {
    final DateTime startedAt = (now ?? DateTime.now()).toUtc();
    if (!source.hasFeed || source.feedUrl == null) {
      return FeedFetchOutcome(
        sourceId: source.id,
        health: SourceHealth(
          sourceId: source.id,
          status: SourceHealthStatus.disabled,
          lastCheckedAt: startedAt,
        ),
      );
    }

    final String feedUrl = source.feedUrl!;
    final FeedMeta? meta = await _meta.get(source.id);
    final HttpFetchResult result = await _http.get(
      feedUrl,
      etag: meta?.etag,
      lastModified: meta?.lastModified,
    );

    if (result.notModified) {
      final SourceHealth health = SourceHealth(
        sourceId: source.id,
        status: SourceHealthStatus.ok,
        lastCheckedAt: startedAt,
        lastSuccessAt: startedAt,
        lastError: null,
        httpStatus: 304,
        itemCount: meta?.itemCount ?? 0,
        latencyMs: result.latencyMs,
      );
      await _meta.save(
        FeedMeta(
          sourceId: source.id,
          etag: meta?.etag,
          lastModified: meta?.lastModified,
          lastFetchAt: startedAt,
          lastSuccessAt: startedAt,
          itemCount: meta?.itemCount ?? 0,
        ),
      );
      return FeedFetchOutcome(
        sourceId: source.id,
        health: health,
        notModified: true,
        warnings: const <String>['Not modified since last fetch'],
      );
    }

    if (!result.isSuccess) {
      final SourceHealth health = SourceHealth(
        sourceId: source.id,
        status: SourceHealthStatus.failing,
        lastCheckedAt: startedAt,
        lastSuccessAt: meta?.lastSuccessAt,
        lastError: result.error ?? 'Unknown error',
        httpStatus: result.statusCode,
        itemCount: meta?.itemCount ?? 0,
        latencyMs: result.latencyMs,
      );
      await _meta.save(
        FeedMeta(
          sourceId: source.id,
          etag: meta?.etag,
          lastModified: meta?.lastModified,
          lastFetchAt: startedAt,
          lastSuccessAt: meta?.lastSuccessAt,
          itemCount: meta?.itemCount ?? 0,
          lastError: health.lastError,
        ),
      );
      return FeedFetchOutcome(sourceId: source.id, health: health);
    }

    final FeedParseResult parsed;
    try {
      parsed = _parser.parse(
        result.body ?? '',
        source: source,
        fetchedAt: startedAt,
      );
    } catch (error) {
      final SourceHealth health = SourceHealth(
        sourceId: source.id,
        status: SourceHealthStatus.failing,
        lastCheckedAt: startedAt,
        lastSuccessAt: meta?.lastSuccessAt,
        lastError: 'Could not parse feed: $error',
        httpStatus: result.statusCode,
        latencyMs: result.latencyMs,
      );
      return FeedFetchOutcome(sourceId: source.id, health: health);
    }

    if (parsed.articles.isEmpty) {
      final SourceHealth health = SourceHealth(
        sourceId: source.id,
        status: SourceHealthStatus.failing,
        lastCheckedAt: startedAt,
        lastSuccessAt: meta?.lastSuccessAt,
        lastError: 'Feed returned no usable items',
        httpStatus: result.statusCode,
        itemCount: 0,
        latencyMs: result.latencyMs,
      );
      await _meta.save(
        FeedMeta(
          sourceId: source.id,
          etag: null,
          lastModified: null,
          lastFetchAt: startedAt,
          lastSuccessAt: meta?.lastSuccessAt,
          itemCount: 0,
          lastError: health.lastError,
        ),
      );
      return FeedFetchOutcome(
        sourceId: source.id,
        health: health,
        warnings: parsed.warnings,
      );
    }

    final List<Article> articles = <Article>[...parsed.articles];
    final List<String> warnings = <String>[...parsed.warnings];
    final Set<String> seenPages = <String>{feedUrl};
    final Map<String, Article> byId = <String, Article>{
      for (final Article article in articles) article.id: article,
    };
    String? continuation = parsed.nextPageUrl;
    var page = 1;
    while (continuation != null && page < 3) {
      final Uri base = Uri.parse(seenPages.last);
      final Uri? next = Uri.tryParse(continuation);
      final Uri resolved = next == null ? base : base.resolveUri(next);
      // Follow only an explicit same-host HTTPS continuation. Cross-host
      // pagination can be added per publisher after authorization is audited.
      if (resolved.scheme != 'https' ||
          resolved.host.toLowerCase() !=
              Uri.parse(feedUrl).host.toLowerCase() ||
          !seenPages.add(resolved.toString())) {
        warnings.add('Ignored unsafe or cross-host feed continuation');
        break;
      }
      final HttpFetchResult more =
          await _http.get(resolved.toString(), attempts: 1);
      if (!more.isSuccess) {
        warnings.add('A publisher continuation page was unavailable');
        break;
      }
      final FeedParseResult moreParsed = _parser.parse(
        more.body ?? '',
        source: source,
        fetchedAt: startedAt,
      );
      for (final Article article in moreParsed.articles) {
        byId.putIfAbsent(article.id, () => article);
      }
      warnings.addAll(moreParsed.warnings);
      continuation = moreParsed.nextPageUrl;
      page++;
    }
    articles
      ..clear()
      ..addAll(byId.values)
      ..sort((Article a, Article b) => b.sortKey.compareTo(a.sortKey));

    final SourceHealth health = SourceHealth(
      sourceId: source.id,
      status: SourceHealthStatus.ok,
      lastCheckedAt: startedAt,
      lastSuccessAt: startedAt,
      lastError: parsed.recovered ? 'Feed XML was malformed; recovered' : null,
      httpStatus: result.statusCode,
      itemCount: articles.length,
      latencyMs: result.latencyMs,
    );
    await _meta.save(
      FeedMeta(
        sourceId: source.id,
        etag: result.etag,
        lastModified: result.lastModified,
        lastFetchAt: startedAt,
        lastSuccessAt: startedAt,
        itemCount: articles.length,
      ),
    );
    return FeedFetchOutcome(
      sourceId: source.id,
      health: health,
      articles: articles,
      warnings: warnings,
    );
  }
}
