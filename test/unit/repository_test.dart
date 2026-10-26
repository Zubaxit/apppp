import 'package:bangladesh_newspaper_hub/data/feeds/feed_service.dart';
import 'package:bangladesh_newspaper_hub/data/models/article.dart';
import 'package:bangladesh_newspaper_hub/data/models/feed_query.dart';
import 'package:bangladesh_newspaper_hub/data/models/news_source.dart';
import 'package:bangladesh_newspaper_hub/data/models/source_health.dart';
import 'package:bangladesh_newspaper_hub/data/models/vocabulary_entry.dart';
import 'package:bangladesh_newspaper_hub/data/services/article_repository.dart';
import 'package:bangladesh_newspaper_hub/data/services/stores.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  late SourceRegistry registry;

  setUp(() {
    registry = SourceRegistry(
      sources: <NewsSource>[
        sampleSource(),
        sampleSource(
          id: 'daily_star',
          name: 'The Daily Star',
          nameBn: 'দ্য ডেইলি স্টার',
          website: 'https://www.thedailystar.net/',
          feedUrl: 'https://www.thedailystar.net/rss/all',
          language: SourceLanguage.en,
        ),
        sampleSource(
          id: 'no_feed',
          name: 'No Feed Daily',
          website: 'https://nofeed.example.com/',
          feedUrl: null,
        ),
      ],
      epapers: const <EpaperEdition>[],
      updatedAt: DateTime.utc(2026, 10, 24),
      about: '',
    );
  });

  test('refresh stores articles and records health per source', () async {
    final Article pa = sampleArticle(sourceId: 'prothomalo');
    final Article ds = sampleArticle(
      sourceId: 'daily_star',
      title: 'Bangladesh exports rise',
      language: SourceLanguage.en,
    );
    final FakeFeedGateway gateway = FakeFeedGateway(
      articlesBySource: <String, List<Article>>{
        'prothomalo': <Article>[pa],
        'daily_star': <Article>[ds],
      },
    );
    final AppStores stores = fakeStores();
    final ArticleRepository repository =
        ArticleRepository(registry: registry, stores: stores, feedService: gateway);

    final RefreshReport report = await repository.refresh(force: true);

    expect(report.sourcesAttempted, 2, reason: 'only sources with feeds are fetched');
    expect(report.sourcesSucceeded, 2);
    expect(report.sourcesFailed, 0);
    expect(report.newArticles, 2);
    expect(await stores.articles.count(), 2);
    expect((await repository.healthMap())['prothomalo']?.status, SourceHealthStatus.ok);
    expect(gateway.fetchedSources, isNot(contains('no_feed')));
    expect(await repository.lastRefreshAt(), isNotNull);
  });

  test('one failing feed does not stop the others', () async {
    final FakeFeedGateway gateway = FakeFeedGateway(
      articlesBySource: <String, List<Article>>{
        'prothomalo': <Article>[sampleArticle()],
        'daily_star': <Article>[
          sampleArticle(sourceId: 'daily_star', title: 'Exports rise'),
        ],
      },
      failing: <String>{'prothomalo'},
    );
    final AppStores stores = fakeStores();
    final ArticleRepository repository =
        ArticleRepository(registry: registry, stores: stores, feedService: gateway);

    final RefreshReport report = await repository.refresh(force: true);

    expect(report.sourcesSucceeded, 1);
    expect(report.sourcesFailed, 1);
    expect(report.failures['prothomalo'], 'HTTP 503');
    final Map<String, SourceHealth> health = await repository.healthMap();
    expect(health['prothomalo']?.status, SourceHealthStatus.failing);
    expect(health['daily_star']?.status, SourceHealthStatus.ok);
    final List<Article> stored = await repository.loadFeed(queryOf());
    expect(stored.map((Article a) => a.sourceId), <String>['daily_star']);
  });

  test('a gateway that throws is reported as a failing source', () async {
    final AppStores stores = fakeStores();
    final ArticleRepository repository =
        ArticleRepository(registry: registry, stores: stores, feedService: _ThrowingGateway());

    final RefreshReport report = await repository.refresh(force: true);
    expect(report.sourcesFailed, 2);
    expect(report.newArticles, 0);
    final List<SourceHealth> health = await stores.health.all();
    expect(health.every((SourceHealth h) => h.status == SourceHealthStatus.failing), isTrue);
  });

  test('second refresh within the minimum gap is skipped', () async {
    final FakeFeedGateway gateway = FakeFeedGateway(
      articlesBySource: <String, List<Article>>{
        'prothomalo': <Article>[sampleArticle()],
      },
    );
    final ArticleRepository repository =
        ArticleRepository(registry: registry, stores: fakeStores(), feedService: gateway);

    await repository.refresh(force: true);
    final int firstCount = gateway.calls;
    final RefreshReport second = await repository.refresh();

    expect(second.sourcesAttempted, 0);
    expect(gateway.calls, firstCount);
  });

  test('force refresh bypasses the minimum gap', () async {
    final FakeFeedGateway gateway = FakeFeedGateway();
    final ArticleRepository repository =
        ArticleRepository(registry: registry, stores: fakeStores(), feedService: gateway);

    await repository.refresh(force: true);
    final int first = gateway.calls;
    await repository.refresh(force: true);
    expect(gateway.calls, greaterThan(first));
  });

  test('a storage failure is reported instead of looking like a success', () async {
    final ArticleRepository repository = ArticleRepository(
      registry: registry,
      stores: fakeStores(articles: _BrokenArticleStore()),
      feedService: FakeFeedGateway(
        articlesBySource: <String, List<Article>>{
          'prothomalo': <Article>[sampleArticle()],
        },
      ),
    );

    final RefreshReport report = await repository.refresh(force: true);

    expect(report.storageError, contains('Local cache write failed'));
    expect(report.failures.values, contains(report.storageError));
    // The per-source fetch itself still happened and is not lost.
    expect(report.sourcesAttempted, greaterThan(0));
  });

  test('feed filters by source, topic, language and text', () async {
    final AppStores stores = fakeStores(
      seed: <Article>[
        sampleArticle(title: 'বাংলাদেশের রাজনীতি নিয়ে খবর', topic: ArticleTopic.politics),
        sampleArticle(
          sourceId: 'daily_star',
          title: 'Exports rise sharply',
          topic: ArticleTopic.economy,
          language: SourceLanguage.en,
        ),
        sampleArticle(title: 'খেলার খবর', topic: ArticleTopic.sports),
      ],
    );
    final ArticleRepository repository = ArticleRepository(
      registry: registry,
      stores: stores,
      feedService: FakeFeedGateway(),
    );

    expect((await repository.loadFeed(queryOf(sources: <String>{'daily_star'}))).length, 1);
    expect(
      (await repository.loadFeed(queryOf(topics: <ArticleTopic>{ArticleTopic.sports}))).single.title,
      'খেলার খবর',
    );
    expect(
      (await repository.loadFeed(queryOf(languages: <SourceLanguage>{SourceLanguage.en}))).single.title,
      'Exports rise sharply',
    );
    expect(
      (await repository.loadFeed(queryOf(text: 'Exports'))).single.sourceId,
      'daily_star',
    );
  });

  test('followed-only feed is empty without follows', () async {
    final AppStores stores = fakeStores(seed: <Article>[sampleArticle()]);
    final ArticleRepository repository = ArticleRepository(
      registry: registry,
      stores: stores,
      feedService: FakeFeedGateway(),
    );

    expect(
      await repository.loadFeed(queryOf(followedOnly: true)),
      isEmpty,
    );
    expect(
      await repository.loadFeed(
        queryOf(followedOnly: true),
        followedSourceIds: <String>{'prothomalo'},
      ),
      hasLength(1),
    );
  });

  test('live feed sorts publisher times and excludes undated records', () async {
    final DateTime now = DateTime.utc(2026, 10, 24, 12);
    final Article newer = sampleArticle(
      title: 'নতুন খবর',
      publishedAt: now.subtract(const Duration(minutes: 5)),
    );
    final Article older = sampleArticle(
      title: 'পুরোনো খবর',
      publishedAt: now.subtract(const Duration(hours: 5)),
    );
    final Article undated = Article.create(
      sourceId: 'prothomalo',
      title: 'তারিখহীন খবর',
      link: 'https://www.prothomalo.com/undated',
      fetchedAt: now,
    );
    final AppStores stores = fakeStores(seed: <Article>[older, newer, undated]);
    final ArticleRepository repository = ArticleRepository(
      registry: registry,
      stores: stores,
      feedService: FakeFeedGateway(),
      clock: () => now,
    );

    final List<Article> feed = await repository.loadFeed(queryOf());
    expect(feed.map((Article article) => article.title),
        <String>['নতুন খবর', 'পুরোনো খবর']);
    expect(feed, isNot(contains(undated)),
        reason: 'fetch time must not be presented as publication freshness');
  });

  test('bookmarks persist and survive the article leaving the feed', () async {
    final AppStores stores = fakeStores(seed: <Article>[sampleArticle()]);
    final ArticleRepository repository = ArticleRepository(
      registry: registry,
      stores: stores,
      feedService: FakeFeedGateway(),
    );
    final Article article = (await repository.loadFeed(queryOf())).single;

    await repository.saveArticle(article);
    expect(await repository.isSaved(article.id), isTrue);

    await stores.articles.clear();
    final List<SavedArticle> saved = await repository.savedArticles();
    expect(saved, hasLength(1));
    expect(saved.single.article.link, article.link);
    expect(saved.single.article.title, article.title);

    await repository.unsaveArticle(article.id);
    expect(await repository.isSaved(article.id), isFalse);
  });

  test('reading history is recorded and can be cleared', () async {
    final AppStores stores = fakeStores();
    final ArticleRepository repository =
        ArticleRepository(registry: registry, stores: stores, feedService: FakeFeedGateway());
    final Article article = sampleArticle();

    await repository.recordHistory(article);
    expect(await repository.history(), hasLength(1));
    await repository.clearHistory();
    expect(await repository.history(), isEmpty);
  });

  test('related coverage keeps separate publishers and excludes self', () async {
    final DateTime at = DateTime.utc(2026, 10, 24, 6);
    const String title = 'Bangladesh exports rise sharply this quarter';
    final Article a = Article.create(
      sourceId: 'prothomalo',
      title: title,
      link: 'https://www.prothomalo.com/a',
      publishedAt: at,
    );
    final Article b = Article.create(
      sourceId: 'daily_star',
      title: title,
      link: 'https://www.thedailystar.net/b',
      publishedAt: at,
    );
    final Article c = Article.create(
      sourceId: 'prothomalo',
      title: title,
      link: 'https://www.prothomalo.com/c',
      publishedAt: at,
    );
    final AppStores stores = fakeStores(seed: <Article>[a, b, c]);
    final ArticleRepository repository = ArticleRepository(
      registry: registry,
      stores: stores,
      feedService: FakeFeedGateway(),
      clock: () => at.add(const Duration(hours: 1)),
    );

    final List<Article> related = await repository.relatedCoverage(a);
    expect(related.map((Article x) => x.id), <String>[b.id]);
  });

  test('clearing the cache keeps bookmarks', () async {
    final AppStores stores = fakeStores(seed: <Article>[sampleArticle()]);
    final ArticleRepository repository =
        ArticleRepository(registry: registry, stores: stores, feedService: FakeFeedGateway());
    final Article article = (await repository.loadFeed(queryOf())).single;
    await repository.saveArticle(article);
    await repository.recordOpen(article);
    await repository.saveVocabulary(VocabularyEntry(
      word: 'policy',
      meaningBn: 'নীতি',
      savedAt: DateTime.utc(2026, 10, 26),
    ));

    await repository.clearCache();
    expect(await stores.articles.count(), 0);
    expect(await repository.savedArticles(), hasLength(1));
    expect(await repository.history(), hasLength(1));
    expect(await repository.vocabulary(), hasLength(1));
    expect((await repository.vocabulary()).single.meaningBn, 'নীতি');
    expect(await repository.lastRefreshAt(), isNull);
  });
}

class _ThrowingGateway implements FeedGateway {
  @override
  Future<FeedFetchOutcome> fetch(NewsSource source, {DateTime? now}) async {
    throw StateError('simulated crash inside the gateway');
  }
}

/// Simulates an unusable local cache (e.g. the schema/column mismatch that
/// emptied the shipped app) to prove the repository surfaces it.
class _BrokenArticleStore extends FakeArticleStore {
  @override
  Future<void> upsertAll(Iterable<Article> articles) async {
    throw StateError('table articles has no column named sourceId');
  }
}
