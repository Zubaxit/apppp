import 'dart:async';

import 'package:bangladesh_newspaper_hub/data/feeds/feed_service.dart';
import 'package:bangladesh_newspaper_hub/data/models/article.dart';
import 'package:bangladesh_newspaper_hub/data/models/feed_query.dart';
import 'package:bangladesh_newspaper_hub/data/models/news_source.dart';
import 'package:bangladesh_newspaper_hub/data/models/source_health.dart';
import 'package:bangladesh_newspaper_hub/data/services/stores.dart';
import 'package:bangladesh_newspaper_hub/services/machine_translation.dart';

/// In-memory implementations of every store, used by unit and widget tests so
/// no sqflite platform channel is required.
class FakeArticleStore implements ArticleStore {
  FakeArticleStore([Iterable<Article> seed = const <Article>[]]) {
    for (final Article article in seed) {
      _items[article.id] = article;
    }
  }

  final Map<String, Article> _items = <String, Article>{};

  @override
  Future<void> upsertAll(Iterable<Article> articles) async {
    for (final Article article in articles) {
      _items[article.id] = article;
    }
  }

  @override
  Future<List<Article>> latest({
    int limit = 200,
    Set<String> sourceIds = const <String>{},
    Set<ArticleTopic> topics = const <ArticleTopic>{},
    Set<SourceLanguage> languages = const <SourceLanguage>{},
    String text = '',
  }) async {
    final String needle = text.trim().toLowerCase();
    final List<Article> filtered = _items.values.where((Article a) {
      if (sourceIds.isNotEmpty && !sourceIds.contains(a.sourceId)) return false;
      if (topics.isNotEmpty && !topics.contains(a.topic)) return false;
      if (languages.isNotEmpty && !languages.contains(a.language)) return false;
      if (needle.isNotEmpty &&
          !a.title.toLowerCase().contains(needle) &&
          !(a.excerpt ?? '').toLowerCase().contains(needle)) {
        return false;
      }
      return true;
    }).toList()
      ..sort((Article a, Article b) => b.sortKey.compareTo(a.sortKey));
    return filtered.take(limit).toList();
  }

  @override
  Future<List<Article>> bySource(String sourceId, {int limit = 60}) async {
    final List<Article> items =
        _items.values.where((Article a) => a.sourceId == sourceId).toList()
          ..sort((Article a, Article b) => b.sortKey.compareTo(a.sortKey));
    return items.take(limit).toList();
  }

  @override
  Future<Article?> byId(String id) async => _items[id];

  @override
  Future<List<Article>> byClusterKey(String clusterKey, {int limit = 8}) async {
    return _items.values
        .where((Article a) => a.clusterKey == clusterKey)
        .take(limit)
        .toList();
  }

  @override
  Future<int> count() async => _items.length;

  @override
  Future<DateTime?> newestFetchAt() async {
    if (_items.isEmpty) return null;
    return _items.values
        .map((Article a) => a.fetchedAt)
        .reduce((DateTime a, DateTime b) => a.isAfter(b) ? a : b);
  }

  @override
  Future<void> prune({
    int keepPerSource = 80,
    int keepTotal = 2500,
    Duration maxAge = const Duration(days: 45),
  }) async {
    final DateTime cutoff = DateTime.now().toUtc().subtract(maxAge);
    _items.removeWhere((String id, Article a) => a.fetchedAt.isBefore(cutoff));
  }

  @override
  Future<void> clear() async => _items.clear();
}

class FakeSavedStore implements SavedStore {
  final Map<String, SavedArticle> _items = <String, SavedArticle>{};

  List<SavedArticle> get raw => _items.values.toList();

  @override
  Future<void> save(Article article) async {
    _items[article.id] = SavedArticle(article: article, savedAt: DateTime.now().toUtc());
  }

  @override
  Future<void> remove(String articleId) async => _items.remove(articleId);

  @override
  Future<List<SavedArticle>> all() async {
    final List<SavedArticle> items = _items.values.toList()
      ..sort((SavedArticle a, SavedArticle b) => b.savedAt.compareTo(a.savedAt));
    return items;
  }

  @override
  Future<bool> contains(String articleId) async => _items.containsKey(articleId);

  @override
  Future<void> clear() async => _items.clear();
}

class FakeHistoryStore implements HistoryStore {
  final Map<String, SavedArticle> _items = <String, SavedArticle>{};

  @override
  Future<void> record(Article article) async {
    _items[article.id] = SavedArticle(article: article, savedAt: DateTime.now().toUtc());
  }

  @override
  Future<List<SavedArticle>> recent({int limit = 60}) async {
    return _items.values.toList().take(limit).toList();
  }

  @override
  Future<void> clear() async => _items.clear();
}

class FakeHealthStore implements HealthStore {
  final Map<String, SourceHealth> _items = <String, SourceHealth>{};

  @override
  Future<List<SourceHealth>> all() async => _items.values.toList();

  @override
  Future<SourceHealth?> bySource(String sourceId) async => _items[sourceId];

  @override
  Future<void> upsert(SourceHealth health) async => _items[health.sourceId] = health;

  @override
  Future<void> clear() async => _items.clear();
}

class FakeFeedMetaStore implements FeedMetaStore {
  final Map<String, FeedMeta> _items = <String, FeedMeta>{};

  @override
  Future<FeedMeta?> get(String sourceId) async => _items[sourceId];

  @override
  Future<void> save(FeedMeta meta) async => _items[meta.sourceId] = meta;

  @override
  Future<List<FeedMeta>> all() async => _items.values.toList();
}

class FakeMetaStore implements MetaStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> get(String key) async => values[key];

  @override
  Future<void> set(String key, String? value) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}

/// Gateway that returns canned outcomes, optionally failing or delaying.
class FakeFeedGateway implements FeedGateway {
  FakeFeedGateway({
    Map<String, List<Article>>? articlesBySource,
    Set<String>? failing,
    this.delay = Duration.zero,
  })  : _articles = articlesBySource ?? <String, List<Article>>{},
        _failing = failing ?? <String>{};

  final Map<String, List<Article>> _articles;
  final Set<String> _failing;
  final Duration delay;
  int calls = 0;
  final List<String> fetchedSources = <String>[];

  @override
  Future<FeedFetchOutcome> fetch(NewsSource source, {DateTime? now}) async {
    calls++;
    fetchedSources.add(source.id);
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    final DateTime at = now ?? DateTime.now().toUtc();
    if (_failing.contains(source.id)) {
      return FeedFetchOutcome(
        sourceId: source.id,
        health: SourceHealth(
          sourceId: source.id,
          status: SourceHealthStatus.failing,
          lastCheckedAt: at,
          lastError: 'HTTP 503',
          httpStatus: 503,
        ),
      );
    }
    final List<Article> items = _articles[source.id] ?? const <Article>[];
    return FeedFetchOutcome(
      sourceId: source.id,
      health: SourceHealth(
        sourceId: source.id,
        status: SourceHealthStatus.ok,
        lastCheckedAt: at,
        lastSuccessAt: at,
        httpStatus: 200,
        itemCount: items.length,
      ),
      articles: items,
    );
  }
}

AppStores fakeStores({
  Iterable<Article> seed = const <Article>[],
  FakeArticleStore? articles,
}) {
  return AppStores(
    articles: articles ?? FakeArticleStore(seed),
    saved: FakeSavedStore(),
    history: FakeHistoryStore(),
    health: FakeHealthStore(),
    feedMeta: FakeFeedMetaStore(),
    meta: FakeMetaStore(),
  );
}

NewsSource sampleSource({
  String id = 'prothomalo',
  String name = 'Prothom Alo',
  String? nameBn = 'প্রথম আলো',
  String website = 'https://www.prothomalo.com/',
  String? feedUrl = 'https://www.prothomalo.com/feed',
  SourceLanguage language = SourceLanguage.bn,
  List<SourceCategory> categories = const <SourceCategory>[SourceCategory.national],
  PublicationType type = PublicationType.dailyNewspaper,
  String? epaperUrl,
  String? logoUrl,
  bool featured = false,
  bool curated = false,
  String? division,
  String? district,
}) {
  return NewsSource(
    id: id,
    name: name,
    nameBn: nameBn,
    website: website,
    feedUrl: feedUrl,
    language: language,
    categories: categories,
    type: type,
    epaperUrl: epaperUrl,
    logoUrl: logoUrl,
    featured: featured,
    curated: curated,
    division: division,
    district: district,
  );
}

Article sampleArticle({
  String sourceId = 'prothomalo',
  String title = 'বাংলাদেশে নতুন উদ্যোগ ঘোষণা',
  String? link,
  String? excerpt = 'সরকার নতুন একটি উদ্যোগ ঘোষণা করেছে বলে জানা গেছে।',
  DateTime? publishedAt,
  ArticleTopic topic = ArticleTopic.bangladesh,
  SourceLanguage language = SourceLanguage.bn,
  bool breaking = false,
  String? imageUrl,
}) {
  return Article.create(
    sourceId: sourceId,
    title: title,
    link: link ?? 'https://www.prothomalo.com/bangladesh/$sourceId-${title.hashCode}',
    excerpt: excerpt,
    publishedAt: publishedAt ?? DateTime.now().toUtc().subtract(const Duration(minutes: 20)),
    topic: topic,
    language: language,
    breaking: breaking,
    imageUrl: imageUrl,
  );
}

FeedQuery queryOf({
  Set<String> sources = const <String>{},
  Set<ArticleTopic> topics = const <ArticleTopic>{},
  Set<SourceLanguage> languages = const <SourceLanguage>{},
  bool followedOnly = false,
  String text = '',
  int limit = 80,
}) {
  return FeedQuery(
    sourceIds: sources,
    topics: topics,
    languages: languages,
    followedOnly: followedOnly,
    text: text,
    limit: limit,
  );
}

/// A translator with no network. Records what it was asked for, and can fail
/// paragraphs containing a given substring so per-paragraph errors are testable.
class FakeTranslator implements MachineTranslator {
  FakeTranslator({this.failOn = const <String>[], this.delay = Duration.zero});

  final List<String> failOn;
  final Duration delay;
  final List<String> requests = <String>[];

  @override
  bool get requiresNetwork => true;

  @override
  String get attribution => 'Fake';

  @override
  Future<String> translate(String text, {String from = 'en', String to = 'bn'}) async {
    requests.add(text);
    if (delay != Duration.zero) await Future<void>.delayed(delay);
    for (final String needle in failOn) {
      if (text.contains(needle)) {
        throw const TranslationException('quota reached');
      }
    }
    return 'বাংলা: ${text.length}';
  }

  @override
  Future<List<String>> translateAll(
    List<String> texts, {
    String from = 'en',
    String to = 'bn',
  }) async {
    return <String>[
      for (final String text in texts) await translate(text, from: from, to: to),
    ];
  }
}
