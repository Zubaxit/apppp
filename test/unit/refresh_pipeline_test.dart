import 'dart:convert';
import 'dart:io';

import 'package:bangladesh_newspaper_hub/data/feeds/feed_service.dart';
import 'package:bangladesh_newspaper_hub/data/feeds/news_http_client.dart';
import 'package:bangladesh_newspaper_hub/data/models/article.dart';
import 'package:bangladesh_newspaper_hub/data/models/feed_query.dart';
import 'package:bangladesh_newspaper_hub/data/models/news_source.dart';
import 'package:bangladesh_newspaper_hub/data/services/article_repository.dart';
import 'package:bangladesh_newspaper_hub/data/services/stores.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/fakes.dart';

/// End-to-end check of the path that produced the empty app.
///
/// The previous defect lived in the seam between the network response and the
/// database row, where a unit test with a permissive fake cannot see it. This
/// suite wires the real [NewsHttpClient] (MockClient transport), the real
/// [FeedService] and parser, the real [ArticleRepository], and an
/// [ArticleStore] that rejects any key the real SQLite schema does not declare —
/// exactly like SQLite does. If the mapping regresses, this fails the same way
/// the phone did.
class SchemaStrictArticleStore extends FakeArticleStore {
  SchemaStrictArticleStore(this.columns, [Iterable<Article> seed = const <Article>[]])
      : super(seed);

  final Set<String> columns;
  final List<Map<String, Object?>> inserted = <Map<String, Object?>>[];

  @override
  Future<void> upsertAll(Iterable<Article> articles) async {
    for (final Article article in articles) {
      final Map<String, Object?> row = article.toRow();
      for (final String key in row.keys) {
        if (!columns.contains(key)) {
          // The exact failure SQLite raised on device.
          throw StateError('table articles has no column named $key');
        }
      }
      inserted.add(row);
    }
    return super.upsertAll(articles);
  }
}

/// Parsed lazily inside a test: reading the file and asserting at the top of
/// `main` would run outside the test zone and fail the whole suite.
Set<String> articleColumns() {
  final String schema = File('lib/data/services/app_database.dart').readAsStringSync();
  final RegExp create = RegExp(r"CREATE TABLE articles \((.*?)\)\s*'", dotAll: true);
  final RegExpMatch? match = create.firstMatch(schema);
  expect(match, isNotNull, reason: 'articles DDL not found');
  final Set<String> columns = <String>{};
  for (final String line in match!.group(1)!.split('\n')) {
    final String trimmed = line.trim().replaceAll(RegExp(r',$'), '');
    if (trimmed.isEmpty || trimmed.startsWith('--')) continue;
    final String first = trimmed.split(RegExp(r'\s+')).first;
    if (<String>{'PRIMARY', 'FOREIGN', 'UNIQUE', 'CONSTRAINT', 'CHECK'}.contains(first)) {
      continue;
    }
    columns.add(first);
  }
  return columns;
}

/// A Prothom Alo shape response: no charset on the content type, media:content
/// thumbnails, CDATA titles, a +0600 pubDate and a tracking parameter.
String prothomAloFeed() => '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:media="http://search.yahoo.com/mrss/">
  <channel>
    <title>Prothom Alo</title>
    <link>https://www.prothomalo.com/</link>
    <item>
      <title><![CDATA[নির্বাচন কমিশনের নতুন তফসিল ঘোষণা]]></title>
      <link>https://www.prothomalo.com/bangladesh/politics/abc123?utm_source=rss</link>
      <description><![CDATA[<p>আগামী নির্বাচনের <b>তফসিল</b> ঘোষণা করা হয়েছে।</p>]]></description>
      <pubDate>Sat, 25 Oct 2026 09:15:00 +0600</pubDate>
      <category>রাজনীতি</category>
      <media:content url="https://images.prothomalo.com/thumb/abc123.jpg" medium="image"/>
    </item>
    <item>
      <title><![CDATA[ঢাকায় নতুন মেট্রো স্টেশন চালু]]></title>
      <link>https://www.prothomalo.com/bangladesh/city/def456</link>
      <description>রাজধানীতে নতুন একটি মেট্রো স্টেশন চালু হয়েছে।</description>
      <pubDate>Sat, 25 Oct 2026 08:05:00 +0600</pubDate>
      <category>বাংলাদেশ</category>
    </item>
    <item>
      <title><![CDATA[বিশ্বকাপ ক্রিকেটে বাংলাদেশের জয়]]></title>
      <link>https://www.prothomalo.com/sports/cricket/ghi789</link>
      <description>রোমাঞ্চকর ম্যাচে জয় পেয়েছে বাংলাদেশ।</description>
      <pubDate>Sat, 25 Oct 2026 07:30:00 +0600</pubDate>
      <category>খেলা</category>
    </item>
  </channel>
</rss>
''';

/// A BBC Bangla shape Atom/RSS body with GMT dates and CDATA descriptions.
String bbcBanglaFeed() => '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>BBC Bangla</title>
    <item>
      <title>বাংলাদেশে অর্থনৈতিক প্রবৃদ্ধির পূর্বাভাস</title>
      <link>https://www.bbc.com/bengali/articles/c1234567</link>
      <description><![CDATA[বিশ্বব্যাংকের নতুন প্রতিবেদনে প্রবৃদ্ধির পূর্বাভাস দেওয়া হয়েছে।]]></description>
      <pubDate>Sat, 25 Oct 2026 03:00:00 GMT</pubDate>
    </item>
    <item>
      <title>জলবায়ু সম্মেলনে নতুন চুক্তি</title>
      <link>https://www.bbc.com/bengali/articles/c7654321</link>
      <description>জলবায়ু পরিবর্তন নিয়ে নতুন চুক্তি হয়েছে।</description>
      <pubDate>Fri, 24 Oct 2026 18:45:00 GMT</pubDate>
    </item>
    <item>
      <title>প্রবাসী বাংলাদেশিদের জন্য নতুন ভিসা নীতি</title>
      <link>https://www.bbc.com/bengali/articles/c9999999</link>
      <description>ইউরোপে নতুন ভিসা নীতি ঘোষণা।</description>
      <pubDate>Fri, 24 Oct 2026 12:00:00 GMT</pubDate>
    </item>
  </channel>
</rss>
''';

void main() {
  // Computed per test, never during collection.
  Set<String> columns() => articleColumns();

  NewsSource source(String id, String name, String feed, SourceLanguage language) {
    return NewsSource(
      id: id,
      name: name,
      website: 'https://$id.example/',
      feedUrl: feed,
      language: language,
      type: PublicationType.dailyNewspaper,
      categories: const <SourceCategory>[SourceCategory.national],
      curated: true,
      curationOrder: 1,
    );
  }

  test('a live-shaped refresh persists articles through the real schema', () async {
    final SourceRegistry registry = SourceRegistry(
      sources: <NewsSource>[
        source('prothomalo', 'Prothom Alo', 'https://www.prothomalo.com/stories.rss', SourceLanguage.bn),
        source('bbc_bangla', 'BBC Bangla', 'https://feeds.bbci.co.uk/bengali/rss.xml', SourceLanguage.bn),
      ],
      epapers: const <EpaperEdition>[],
      updatedAt: DateTime.utc(2026, 10, 25),
      about: 'pipeline test',
    );

    final SchemaStrictArticleStore articles = SchemaStrictArticleStore(columns());
    final AppStores stores = fakeStores(articles: articles);
    final DateTime clock = DateTime.utc(2026, 10, 25, 10);
    final NewsHttpClient httpClient = NewsHttpClient(
      client: MockClient((http.Request request) async {
        final String body = request.url.host.contains('prothomalo')
            ? prothomAloFeed()
            : bbcBanglaFeed();
        return http.Response.bytes(
          utf8.encode(body),
          200,
          // Deliberately no charset: the shape that used to mojibake Bengali.
          headers: <String, String>{'content-type': 'application/rss+xml'},
        );
      }),
      minHostInterval: Duration.zero,
    );

    final ArticleRepository repository = ArticleRepository(
      registry: registry,
      stores: stores,
      feedService: FeedService(httpClient: httpClient, metaStore: stores.feedMeta),
      clock: () => clock,
    );

    final RefreshReport report = await repository.refresh(force: true);

    expect(report.storageError, isNull);
    expect(report.sourcesSucceeded, 2);
    expect(report.sourcesFailed, 0);
    expect(report.newArticles, 6);

    // The rows that reached "SQLite" are complete, Bengali and correctly dated.
    expect(articles.inserted, hasLength(6));
    final List<Article> feed = await repository.loadFeed(const FeedQuery());
    expect(feed, hasLength(6));
    expect(feed.first.title, 'নির্বাচন কমিশনের নতুন তফসিল ঘোষণা');
    expect(feed.first.link, 'https://www.prothomalo.com/bangladesh/politics/abc123');
    expect(feed.first.sourceId, 'prothomalo');
    expect(feed.first.imageUrl, 'https://images.prothomalo.com/thumb/abc123.jpg');
    expect(feed.first.topic, ArticleTopic.politics);
    // Publication order, newest first, with the +0600 date converted to UTC.
    expect(feed.first.publishedAt, DateTime.utc(2026, 10, 25, 3, 15));
    expect(feed.map((Article a) => a.title), everyElement(isNot(contains('à¦'))));

    // Category browsing reaches the same rows.
    final List<Article> sports =
        await repository.loadFeed(const FeedQuery(topics: <ArticleTopic>{ArticleTopic.sports}));
    expect(sports, hasLength(1));
    expect(sports.single.title, contains('ক্রিকেট'));
  });

  test('one failing publisher never blocks the others', () async {
    final SourceRegistry registry = SourceRegistry(
      sources: <NewsSource>[
        source('prothomalo', 'Prothom Alo', 'https://www.prothomalo.com/stories.rss', SourceLanguage.bn),
        source('jugantor', 'Jugantor', 'https://www.jugantor.com/rss', SourceLanguage.bn),
        source('bbc_bangla', 'BBC Bangla', 'https://feeds.bbci.co.uk/bengali/rss.xml', SourceLanguage.bn),
      ],
      epapers: const <EpaperEdition>[],
      updatedAt: DateTime.utc(2026, 10, 25),
      about: 'pipeline test',
    );
    final SchemaStrictArticleStore articles = SchemaStrictArticleStore(columns());
    final AppStores stores = fakeStores(articles: articles);
    final NewsHttpClient httpClient = NewsHttpClient(
      client: MockClient((http.Request request) async {
        if (request.url.host.contains('jugantor')) {
          // The live answer for most of these publishers: bot protection.
          return http.Response('Forbidden', 403);
        }
        final String body = request.url.host.contains('prothomalo')
            ? prothomAloFeed()
            : bbcBanglaFeed();
        return http.Response.bytes(utf8.encode(body), 200,
            headers: <String, String>{'content-type': 'text/xml'});
      }),
      minHostInterval: Duration.zero,
    );
    final ArticleRepository repository = ArticleRepository(
      registry: registry,
      stores: stores,
      feedService: FeedService(httpClient: httpClient, metaStore: stores.feedMeta),
      clock: () => DateTime.utc(2026, 10, 25, 10),
    );

    final RefreshReport report = await repository.refresh(force: true);

    expect(report.sourcesSucceeded, 2);
    expect(report.sourcesFailed, 1);
    expect(report.failures['jugantor'], contains('403'));
    expect(await repository.articleCount(), 6);
    final List<Article> feed = await repository.loadFeed(const FeedQuery());
    expect(feed, hasLength(6));
    expect(feed.map((Article a) => a.sourceId).toSet(), <String>{'prothomalo', 'bbc_bangla'});
  });

  test('a second refresh inside the minimum gap does not re-fetch', () async {
    final SourceRegistry registry = SourceRegistry(
      sources: <NewsSource>[
        source('prothomalo', 'Prothom Alo', 'https://www.prothomalo.com/stories.rss', SourceLanguage.bn),
      ],
      epapers: const <EpaperEdition>[],
      updatedAt: DateTime.utc(2026, 10, 25),
      about: 'pipeline test',
    );
    var calls = 0;
    final AppStores stores = fakeStores(articles: SchemaStrictArticleStore(columns()));
    final NewsHttpClient httpClient = NewsHttpClient(
      client: MockClient((http.Request request) async {
        calls += 1;
        return http.Response.bytes(utf8.encode(prothomAloFeed()), 200);
      }),
      minHostInterval: Duration.zero,
    );
    DateTime now = DateTime.utc(2026, 10, 25, 10);
    final ArticleRepository repository = ArticleRepository(
      registry: registry,
      stores: stores,
      feedService: FeedService(httpClient: httpClient, metaStore: stores.feedMeta),
      clock: () => now,
    );

    await repository.refresh(force: true);
    expect(calls, 1);
    now = now.add(const Duration(minutes: 3));
    final RefreshReport second = await repository.refresh();
    expect(calls, 1, reason: 'the per-source floor must hold on device');
    expect(second.sourcesAttempted, 0);
    // A forced refresh is the user asking, so it does go out again.
    await repository.refresh(force: true);
    expect(calls, 2);
  });

  test('a broken store is reported instead of silently emptying the feed', () async {
    final SourceRegistry registry = SourceRegistry(
      sources: <NewsSource>[
        source('prothomalo', 'Prothom Alo', 'https://www.prothomalo.com/stories.rss', SourceLanguage.bn),
      ],
      epapers: const <EpaperEdition>[],
      updatedAt: DateTime.utc(2026, 10, 25),
      about: 'pipeline test',
    );
    final AppStores stores = fakeStores(
      articles: SchemaStrictArticleStore(<String>{'id', 'source_id'}),
    );
    final NewsHttpClient httpClient = NewsHttpClient(
      client: MockClient((http.Request request) async =>
          http.Response.bytes(utf8.encode(prothomAloFeed()), 200)),
      minHostInterval: Duration.zero,
    );
    final ArticleRepository repository = ArticleRepository(
      registry: registry,
      stores: stores,
      feedService: FeedService(httpClient: httpClient, metaStore: stores.feedMeta),
      clock: () => DateTime.utc(2026, 10, 25, 10),
    );

    final RefreshReport report = await repository.refresh(force: true);
    // The refresh must not report success it did not have: the storage error is
    // named, the source is marked failed, and nothing pretends to be cached.
    expect(report.storageError, isNotNull);
    expect(report.storageError, contains('no column named'));
    expect(report.failures['prothomalo'], contains('Local cache write failed'));
    expect(await stores.articles.count(), 0);
  });
}
