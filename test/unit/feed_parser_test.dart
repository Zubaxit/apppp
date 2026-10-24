import 'package:bangladesh_newspaper_hub/data/feeds/feed_parser.dart';
import 'package:bangladesh_newspaper_hub/data/models/article.dart';
import 'package:bangladesh_newspaper_hub/data/models/news_source.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

const String _rssFixture = '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0"
      xmlns:media="http://search.yahoo.com/mrss/"
      xmlns:dc="http://purl.org/dc/elements/1.1/"
      xmlns:content="http://purl.org/rss/1.0/modules/content/">
  <channel>
    <title>Prothom Alo</title>
    <link>https://www.prothomalo.com/</link>
    <item>
      <title><![CDATA[বাংলাদেশে নতুন উদ্যোগ ঘোষণা]]></title>
      <link>https://www.prothomalo.com/bangladesh/story-1?utm_source=rss</link>
      <description><![CDATA[<p>সরকার নতুন একটি <b>উদ্যোগ</b> ঘোষণা করেছে।</p>]]></description>
      <pubDate>Thu, 01 Oct 2026 12:00:00 +0600</pubDate>
      <category>বাংলাদেশ</category>
      <media:content url="https://images.prothomalo.com/one.jpg" medium="image" />
      <guid isPermaLink="false">story-1</guid>
    </item>
    <item>
      <title>ব্রেকিং: বড় সিদ্ধান্ত আসছে</title>
      <link>https://www.prothomalo.com/bangladesh/story-2</link>
      <description>সংক্ষিপ্ত বিবরণ&nbsp;এবং আরও কিছু তথ্য যা দীর্ঘ হবে যাতে সারাংশ হিসেবে ব্যবহার করা যায়।</description>
      <pubDate>01 Oct 2026 09:30:00</pubDate>
      <category>ব্রেকিং</category>
    </item>
    <item>
      <title>তারিখ ছাড়া খবর</title>
      <link>https://www.prothomalo.com/bangladesh/story-3</link>
      <description>তারিখ নেই এমন একটি খবর।</description>
      <pubDate>not-a-date</pubDate>
    </item>
    <item>
      <title>অনিরাপদ লিংক</title>
      <link>javascript:alert(1)</link>
      <description>এই আইটেম বাদ যাবে।</description>
    </item>
    <item>
      <title>ডুপ্লিকেট খবর</title>
      <link>https://www.prothomalo.com/bangladesh/story-3?fbclid=abc</link>
      <description>একই লিংকের দ্বিতীয় কপি।</description>
    </item>
  </channel>
</rss>
''';

const String _atomFixture = '''
<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Daily Star</title>
  <entry>
    <title>Bangladesh exports rise</title>
    <link rel="alternate" href="https://www.thedailystar.net/business/news/exports-rise-123"/>
    <updated>2026-10-01T08:30:00Z</updated>
    <summary>Exports rose by 12 percent year on year, officials said.</summary>
    <category term="business"/>
  </entry>
  <entry>
    <title>No link entry</title>
    <updated>2026-10-01T08:30:00Z</updated>
  </entry>
</feed>
''';

const String _malformedFixture = '''
<rss><channel>
  <item>
    <title>A & B <b>headline</b></title>
    <link>https://www.dhakapost.com/news/a-b</link>
    <description>broken & unescaped markup</description>
    <pubDate>Thu, 01 Oct 2026 10:00:00 GMT</pubDate>
  </item>
</channel></rss>
''';

void main() {
  const FeedParser parser = FeedParser();
  final NewsSource bnSource = sampleSource();
  final NewsSource enSource = sampleSource(
    id: 'daily_star',
    name: 'The Daily Star',
    nameBn: 'দ্য ডেইলি স্টার',
    website: 'https://www.thedailystar.net/',
    language: SourceLanguage.en,
  );
  final DateTime fetchedAt = DateTime.utc(2026, 10, 2, 6);

  group('RSS 2.0 parsing', () {
    late FeedParseResult result;

    setUpAll(() {
      result = parser.parse(_rssFixture, source: bnSource, fetchedAt: fetchedAt);
    });

    test('detects RSS 2.0', () {
      expect(result.format, FeedFormatDetected.rss2);
      expect(result.recovered, isFalse);
    });

    test('keeps only usable items and drops unsafe links', () {
      expect(result.articles.length, 3);
      expect(result.articles.any((Article a) => a.title.contains('অনিরাপদ')), isFalse);
      expect(result.warnings.join(' '), contains('unsafe link'));
    });

    test('normalizes headline and excerpt without HTML', () {
      final Article first = result.articles.first;
      expect(first.title, 'বাংলাদেশে নতুন উদ্যোগ ঘোষণা');
      expect(first.excerpt, contains('উদ্যোগ'));
      expect(first.excerpt, isNot(contains('<p>')));
      expect(first.excerpt, isNot(contains('<b>')));
    });

    test('strips tracking parameters from the canonical link', () {
      expect(result.articles.first.link, isNot(contains('utm_source')));
      expect(result.articles.first.link, startsWith('https://'));
    });

    test('converts +0600 publication times to UTC', () {
      expect(result.articles.first.publishedAt, DateTime.utc(2026, 10, 1, 6));
    });

    test('assumes the configured offset when a feed omits the timezone', () {
      final Article second = result.articles[1];
      expect(second.publishedAt, DateTime.utc(2026, 10, 1, 3, 30));
    });

    test('leaves publication date null instead of inventing one', () {
      final Article undated =
          result.articles.firstWhere((Article a) => a.title.contains('তারিখ ছাড়া'));
      expect(undated.publishedAt, isNull);
      expect(undated.sortKey, undated.fetchedAt);
    });

    test('marks publisher-labelled breaking news and strips the prefix', () {
      final Article breaking =
          result.articles.firstWhere((Article a) => a.title.contains('বড় সিদ্ধান্ত'));
      expect(breaking.breaking, isTrue);
      expect(breaking.title.startsWith('ব্রেকিং'), isFalse);
    });

    test('extracts the media:content thumbnail', () {
      expect(result.articles.first.imageUrl, 'https://images.prothomalo.com/one.jpg');
    });

    test('classifies the topic from publisher category', () {
      expect(result.articles.first.topic, ArticleTopic.bangladesh);
    });

    test('produces stable ids for identical input', () {
      final FeedParseResult again =
          parser.parse(_rssFixture, source: bnSource, fetchedAt: fetchedAt);
      expect(
        again.articles.map((Article a) => a.id).toList(),
        result.articles.map((Article a) => a.id).toList(),
      );
    });

    test('deduplicates items that resolve to the same URL', () {
      final Set<String> ids = result.articles.map((Article a) => a.id).toSet();
      expect(ids.length, result.articles.length);
    });
  });

  group('Atom parsing', () {
    late FeedParseResult result;

    setUpAll(() {
      result = parser.parse(_atomFixture, source: enSource, fetchedAt: fetchedAt);
    });

    test('detects Atom', () {
      expect(result.format, FeedFormatDetected.atom);
    });

    test('reads the alternate link, summary and timestamp', () {
      expect(result.articles, hasLength(1));
      final Article entry = result.articles.single;
      expect(entry.link, 'https://www.thedailystar.net/business/news/exports-rise-123');
      expect(entry.excerpt, contains('Exports rose'));
      expect(entry.publishedAt, DateTime.utc(2026, 10, 1, 8, 30));
      expect(entry.language, SourceLanguage.en);
    });

    test('skips entries without a usable link', () {
      expect(result.articles.any((Article a) => a.title == 'No link entry'), isFalse);
    });
  });

  group('malformed feeds', () {
    test('recovers items from invalid XML instead of throwing', () {
      final FeedParseResult result =
          parser.parse(_malformedFixture, source: bnSource, fetchedAt: fetchedAt);
      expect(result.recovered, isTrue);
      expect(result.articles, hasLength(1));
      expect(result.articles.single.title, contains('A & B'));
      expect(result.articles.single.link, 'https://www.dhakapost.com/news/a-b');
      expect(result.articles.single.publishedAt, DateTime.utc(2026, 10, 1, 10));
    });

    test('returns an empty result for an HTML error page', () {
      final FeedParseResult result = parser.parse(
        '<!DOCTYPE html><html><body><h1>503 Service Unavailable</h1></body></html>',
        source: bnSource,
        fetchedAt: fetchedAt,
      );
      expect(result.articles, isEmpty);
      expect(result.isEmpty, isTrue);
    });

    test('never throws on empty input', () {
      expect(
        () => parser.parse('', source: bnSource, fetchedAt: fetchedAt),
        returnsNormally,
      );
    });

    test('ignores future-dated items beyond a day', () {
      final FeedParseResult result = parser.parse(
        '<rss><channel><item><title>ভবিষ্যতের খবর</title>'
        '<link>https://www.prothomalo.com/future</link>'
        '<pubDate>Fri, 01 Oct 2038 12:00:00 +0600</pubDate></item></channel></rss>',
        source: bnSource,
        fetchedAt: fetchedAt,
      );
      expect(result.articles.single.publishedAt, isNull);
    });
  });

  test('decodeFeedBody tolerates broken UTF-8', () {
    final String decoded = decodeFeedBody(<int>[0xE0, 0xA6, 0xAC, 0xFF], 'text/xml');
    expect(decoded, isNotEmpty);
  });
}
