import 'package:bangladesh_newspaper_hub/core/utils/bengali_text.dart';
import 'package:bangladesh_newspaper_hub/core/utils/ids.dart';
import 'package:bangladesh_newspaper_hub/core/utils/text_utils.dart';
import 'package:bangladesh_newspaper_hub/core/utils/url_safety.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TextUtils', () {
    test('strips markup and decodes entities', () {
      expect(
        TextUtils.stripHtml('<p>বাংলাদেশ &amp; বিশ্ব</p>'),
        'বাংলাদেশ & বিশ্ব',
      );
      expect(TextUtils.stripHtml('  Hello <br/> world  '), 'Hello world');
      expect(TextUtils.stripHtml(null), '');
    });

    test('normalizes whitespace', () {
      expect(TextUtils.normalizeSpaces('  a\n\t b  '), 'a b');
    });

    test('search normalization removes punctuation and folds case', () {
      expect(TextUtils.searchNormalize('The Daily Star — News!'), 'the daily star news');
      expect(TextUtils.searchNormalize('প্রথম আলো, ২০২৬'), 'প্রথম আলো 2026');
    });

    test('truncates on a word boundary with an ellipsis', () {
      final String result = TextUtils.truncate('one two three four five', 12);
      expect(result.length, lessThanOrEqualTo(13));
      expect(result, endsWith('…'));
    });

    test('edit distance is capped', () {
      expect(TextUtils.editDistance('kaler', 'kalar'), 1);
      expect(TextUtils.editDistance('abc', 'abcdefghij', cap: 3), greaterThan(3));
    });
  });

  group('BengaliText', () {
    test('converts digits both ways', () {
      expect(BengaliText.toBengaliDigits(2026), '২০২৬');
      expect(BengaliText.fromBengaliDigits('২০২৬'), '2026');
      expect(BengaliText.toBengaliDigits('টি ৫'), 'টি ৫');
    });

    test('detects Bengali script', () {
      expect(BengaliText.containsBengali('প্রথম আলো'), isTrue);
      expect(BengaliText.containsBengali('Prothom Alo'), isFalse);
    });

    test('formats relative time in both languages', () {
      final DateTime now = DateTime.utc(2026, 10, 24, 12);
      final DateTime twoHoursAgo = now.subtract(const Duration(hours: 2));
      expect(BengaliText.relative(twoHoursAgo, bengali: true, now: now), '২ ঘণ্টা আগে');
      expect(BengaliText.relative(twoHoursAgo, bengali: false, now: now), '2 hours ago');
      expect(
        BengaliText.relative(now.subtract(const Duration(seconds: 20)), bengali: true, now: now),
        'এইমাত্র',
      );
      expect(BengaliText.relative(null, bengali: true, now: now), isNull);
    });

    test('formats absolute dates in Bangladesh time', () {
      final DateTime utc = DateTime.utc(2026, 10, 23, 22, 30);
      expect(BengaliText.absolute(utc, bengali: true), '২৪ অক্টোবর ২০২৬');
      expect(BengaliText.absolute(utc, bengali: false), '24 October 2026');
      expect(BengaliText.dateTime(utc, bengali: false), '24 October, 4:30 AM');
    });

    test('transliterates Bengali names to Latin for search', () {
      expect(BengaliText.transliterateToLatin('প্রথম আলো'), 'prthm alo');
      expect(BengaliText.transliterateToLatin('ঢাকা'), 'dhaka');
    });
  });

  group('UrlSafety', () {
    test('accepts https and upgrades http', () {
      expect(UrlSafety.sanitize('https://www.prothomalo.com/a'), 'https://www.prothomalo.com/a');
      expect(UrlSafety.sanitize('http://example.com/a'), 'https://example.com/a');
    });

    test('rejects dangerous schemes and hosts', () {
      expect(UrlSafety.sanitize('javascript:alert(1)'), isNull);
      expect(UrlSafety.sanitize('data:text/html;base64,AAAA'), isNull);
      expect(UrlSafety.sanitize('file:///etc/passwd'), isNull);
      expect(UrlSafety.sanitize('intent://scan/#Intent;end'), isNull);
      expect(UrlSafety.sanitize('https://localhost:8080/x'), isNull);
      expect(UrlSafety.sanitize('https://user:pass@example.com/'), isNull);
      expect(UrlSafety.sanitize('https://example.com/download.exe'), isNull);
      expect(UrlSafety.sanitize('not a url'), isNull);
      expect(UrlSafety.sanitize(null), isNull);
    });

    test('never leaves an empty fragment behind', () {
      expect(UrlSafety.sanitize('https://www.prothomalo.com/a#'), 'https://www.prothomalo.com/a');
      expect(UrlSafety.sanitize('https://www.prothomalo.com/a?x=1#top'),
          'https://www.prothomalo.com/a?x=1');
    });

    test('removes campaign parameters but keeps functional ones', () {
      expect(
        UrlSafety.stripTracking('https://www.prothomalo.com/a?utm_source=rss&id=7'),
        'https://www.prothomalo.com/a?id=7',
      );
      expect(
        UrlSafety.stripTracking('https://www.prothomalo.com/a?utm_source=rss'),
        'https://www.prothomalo.com/a',
      );
      expect(
        UrlSafety.stripTracking('https://www.prothomalo.com/a'),
        'https://www.prothomalo.com/a',
      );
    });

    test('strips fragments', () {
      expect(
        UrlSafety.sanitize('https://www.thedailystar.net/a#section'),
        'https://www.thedailystar.net/a',
      );
    });

    test('compares publisher hosts', () {
      expect(
        UrlSafety.sameHost('https://www.prothomalo.com/a', 'https://prothomalo.com/b'),
        isTrue,
      );
      expect(
        UrlSafety.sameHost('https://prothomalo.com/a', 'https://dhakapost.com/b'),
        isFalse,
      );
    });
  });

  group('Ids', () {
    test('canonical URL drops tracking, fragments and trailing slashes', () {
      expect(
        Ids.canonicalUrl('https://www.ProthomAlo.com/news/story/?utm_source=rss&fbclid=x#top'),
        'https://prothomalo.com/news/story',
      );
      expect(
        Ids.canonicalUrl('https://example.com/a?b=2&a=1'),
        'https://example.com/a?a=1&b=2',
      );
    });

    test('article ids ignore tracking parameters but change per source', () {
      final String a = Ids.articleId(
        sourceId: 'prothomalo',
        link: 'https://www.prothomalo.com/news/1?utm_source=rss',
        title: 'শিরোনাম',
      );
      final String b = Ids.articleId(
        sourceId: 'prothomalo',
        link: 'https://www.prothomalo.com/news/1',
        title: 'শিরোনাম',
      );
      final String c = Ids.articleId(
        sourceId: 'daily_star',
        link: 'https://www.prothomalo.com/news/1',
        title: 'শিরোনাম',
      );
      expect(a, b);
      expect(a, isNot(c));
      expect(a.length, 16);
    });

    test('story cluster keys group the same headline on the same day', () {
      final DateTime day = DateTime.utc(2026, 10, 24, 6);
      final String? keyA = Ids.storyClusterKey(
        'Bangladesh exports rise sharply this quarter',
        day,
      );
      final String? keyB = Ids.storyClusterKey(
        'Bangladesh exports rise sharply this quarter',
        day.add(const Duration(hours: 4)),
      );
      final String? keyC = Ids.storyClusterKey(
        'Bangladesh exports rise sharply this quarter',
        day.add(const Duration(days: 2)),
      );
      expect(keyA, isNotNull);
      expect(keyA, keyB);
      expect(keyA, isNot(keyC));
    });

    test('story cluster keys are null for very short headlines', () {
      expect(Ids.storyClusterKey('খেলা', DateTime.utc(2026, 10, 24)), isNull);
    });
  });
}
