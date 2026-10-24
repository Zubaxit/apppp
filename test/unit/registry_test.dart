import 'dart:convert';
import 'dart:io';

import 'package:bangladesh_newspaper_hub/data/models/news_source.dart';
import 'package:bangladesh_newspaper_hub/core/utils/url_safety.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('shipped registry (assets/data/sources.json)', () {
    late Map<String, dynamic> raw;
    late SourceRegistry registry;

    setUpAll(() {
      final String contents = File('assets/data/sources.json').readAsStringSync();
      raw = json.decode(contents) as Map<String, dynamic>;
      registry = SourceRegistry.fromJsonString(contents);
    });

    test('parses every entry', () {
      expect(registry.sources.length, greaterThan(40));
      expect(registry.sources.length, raw['sources'].length);
    });

    test('ids are unique', () {
      final Set<String> ids = registry.sources.map((NewsSource s) => s.id).toSet();
      expect(ids.length, registry.sources.length);
    });

    test('every publication has a safe https website', () {
      for (final NewsSource source in registry.sources) {
        final String? safe = UrlSafety.sanitize(source.website);
        expect(safe, isNotNull, reason: '${source.id} has an unusable website');
        expect(safe, startsWith('https://'), reason: '${source.id} is not https');
      }
    });

    test('every feed and e-paper URL is safe or absent', () {
      for (final NewsSource source in registry.sources) {
        if (source.feedUrl != null) {
          expect(UrlSafety.sanitize(source.feedUrl), isNotNull, reason: source.id);
        }
        if (source.epaperUrl != null) {
          expect(UrlSafety.sanitize(source.epaperUrl), isNotNull, reason: source.id);
        }
      }
      for (final EpaperEdition edition in registry.epapers) {
        expect(UrlSafety.sanitize(edition.url), isNotNull, reason: edition.id);
        expect(registry.byId(edition.sourceId), isNotNull,
            reason: '${edition.id} points at an unknown source');
      }
    });

    test('feed URLs never claim "official" without documentation', () {
      for (final NewsSource source in registry.sources) {
        if (source.feedClaim == FeedClaim.officialDocumented) {
          expect(source.feedUrl, isNotNull, reason: source.id);
        }
        expect(source.feedUrl ?? '', isNot(contains('localhost')));
      }
    });

    test('regional sources carry a real division and district', () {
      for (final NewsSource source in registry.byCategory(SourceCategory.regional)) {
        expect(source.division, isNotNull, reason: source.id);
        expect(source.district, isNotNull, reason: source.id);
        expect(
          <String>[
            'Barishal',
            'Chattogram',
            'Dhaka',
            'Khulna',
            'Mymensingh',
            'Rajshahi',
            'Rangpur',
            'Sylhet',
          ],
          contains(source.division),
          reason: '${source.id} uses a non-standard division name',
        );
      }
    });

    test('broadcast entries are never tagged as newspapers', () {
      for (final NewsSource source in registry.sources) {
        if (source.categories.contains(SourceCategory.broadcast)) {
          expect(
            <PublicationType>[
              PublicationType.newsAgency,
              PublicationType.broadcaster,
            ],
            contains(source.type),
            reason: '${source.id} should be an agency or broadcaster',
          );
        }
      }
    });

    test('the brief\'s headline publications are present', () {
      final Set<String> ids = registry.sources.map((NewsSource s) => s.id).toSet();
      for (final String id in <String>[
        'prothomalo',
        'bd_pratidin',
        'kaler_kantho',
        'jugantor',
        'ittefaq',
        'samakal',
        'janakantha',
        'inqilab',
        'amar_sangbad',
        'ajker_patrika',
        'desh_rupantor',
        'naya_diganta',
        'manabzamin',
        'kalbela',
        'daily_star',
        'dhaka_tribune',
        'tbs',
        'financial_express',
        'daily_sun',
        'new_age',
        'daily_observer',
        'bangladesh_post',
        'bdnews24',
        'banglanews24',
        'jagonews24',
        'bangla_tribune',
        'dhaka_post',
        'risingbd',
        'barta24',
        'newsbangla24',
        'bonik_barta',
      ]) {
        expect(ids, contains(id), reason: 'missing required publication $id');
      }
    });

    test('categories and languages resolve', () {
      expect(registry.byCategory(SourceCategory.english), isNotEmpty);
      expect(registry.byCategory(SourceCategory.online), isNotEmpty);
      expect(registry.byCategory(SourceCategory.business), isNotEmpty);
      expect(registry.byCategory(SourceCategory.regional), isNotEmpty);
      expect(registry.byLanguage(SourceLanguage.en), isNotEmpty);
      expect(registry.withFeeds.length, greaterThan(20));
      expect(registry.epapers, isNotEmpty);
    });

    test('divisions are derived from data, not hard-coded', () {
      final List<String> divisions = registry.divisionsWithSources;
      expect(divisions, contains('Chattogram'));
      expect(divisions, contains('Sylhet'));
      for (final String division in divisions) {
        expect(registry.districtsIn(division), isNotEmpty);
      }
    });

    test('round-trips through toMap', () {
      final NewsSource original = registry.sources.first;
      final NewsSource copy = NewsSource.fromMap(original.toMap());
      expect(copy.id, original.id);
      expect(copy.name, original.name);
      expect(copy.nameBn, original.nameBn);
      expect(copy.categories, original.categories);
      expect(copy.feedClaim, original.feedClaim);
      expect(copy.language, original.language);
    });
  });

  group('registry key mapping (snake_case JSON)', () {
    test('underscored values resolve to the right enum members', () {
      final NewsSource parsed = NewsSource.fromMap(<String, dynamic>{
        'id': 'x',
        'name': 'Example Daily',
        'nameBn': 'উদাহরণ',
        'website': 'https://example.com/',
        'feedUrl': 'https://example.com/rss',
        'feedFormat': 'rss',
        'feedClaim': 'verified_working',
        'lastVerifiedAt': '2026-10-24',
        'language': 'bn',
        'type': 'daily_newspaper',
        'categories': <String>['national', 'regional'],
        'status': 'needs_review',
      });
      expect(parsed.type, PublicationType.dailyNewspaper);
      expect(parsed.status, SourceStatus.needsReview);
      expect(parsed.feedClaim, FeedClaim.verifiedWorking);
      expect(parsed.feedFormat, FeedFormat.rss);
      expect(parsed.categories, contains(SourceCategory.regional));
      expect(parsed.lastVerifiedAt, '2026-10-24');
    });

    test('camelCase keys keep working and unknown values stay safe', () {
      final NewsSource parsed = NewsSource.fromMap(<String, dynamic>{
        'id': 'y',
        'name': 'Example Two',
        'website': 'https://example.org/',
        'language': 'en',
        'type': 'onlinePortal',
        'feedClaim': 'officialDocumented',
        'status': 'active',
      });
      expect(parsed.type, PublicationType.onlinePortal);
      expect(parsed.status, SourceStatus.active);
      expect(parsed.feedClaim, FeedClaim.officialDocumented);
      expect(parsed.feedFormat, isNull);
      expect(parsed.lastVerifiedAt, isNull);

      final NewsSource broken = NewsSource.fromMap(<String, dynamic>{
        'id': 'z',
        'name': 'Example Three',
        'website': 'https://example.net/',
        'language': 'bn',
        'type': 'not_a_type',
        'feedClaim': 'nonsense',
      });
      expect(broken.type, PublicationType.unknown);
      expect(broken.feedClaim, FeedClaim.none);
      expect(broken.status, SourceStatus.active);
    });

    test('no shipped entry silently degrades to an unknown type', () {
      final String contents = File('assets/data/sources.json').readAsStringSync();
      final SourceRegistry registry = SourceRegistry.fromJsonString(contents);
      final List<NewsSource> unknown = registry.sources
          .where((NewsSource s) => s.type == PublicationType.unknown)
          .toList();
      expect(unknown, isEmpty, reason: 'unmapped types: ${unknown.map((NewsSource s) => s.id)}');
      for (final NewsSource source in registry.sources) {
        expect(source.categories, isNotEmpty, reason: '${source.id} lost its categories');
      }
    });

    test('verification claims are explicit and dated', () {
      final String contents = File('assets/data/sources.json').readAsStringSync();
      final SourceRegistry registry = SourceRegistry.fromJsonString(contents);
      for (final NewsSource source in registry.sources) {
        if (source.feedClaim == FeedClaim.verifiedWorking) {
          expect(source.lastVerifiedAt, isNotNull, reason: '${source.id} claims a verified feed');
          expect(source.feedUrl, isNotNull, reason: '${source.id} claims a verified feed');
          expect(source.hasVerifiedFeed, isTrue);
        }
        if (source.hasFeed) {
          expect(source.feedUrl, startsWith('https://'), reason: source.id);
        }
      }
    });
  });

  group('search behaviour', () {
    final SourceRegistry registry = testRegistry();

    test('matches an English query against a Bengali publication', () {
      final List<NewsSource> results = registry.search('daily star');
      expect(results.first.id, 'daily_star');
    });

    test('matches a Bengali query against the Bengali name', () {
      final List<NewsSource> results = registry.search('প্রথম আলো');
      expect(results.first.id, 'prothomalo');
    });

    test('matches a Bengali query against a Latin-named publication', () {
      final List<NewsSource> results = registry.search('বণিক বার্তা');
      expect(results, isNotEmpty);
      expect(results.first.id, 'bonik_barta');
    });

    test('is case and punctuation insensitive', () {
      expect(registry.search('THE DAILY STAR!').first.id, 'daily_star');
    });

    test('tolerates a small typo', () {
      final List<NewsSource> results = registry.search('daly star');
      expect(results.map((NewsSource s) => s.id), contains('daily_star'));
    });

    test('returns nothing for an empty query', () {
      expect(registry.search('   '), isEmpty);
    });

    test('filters by language, category and feeds', () {
      expect(
        registry.filter(language: SourceLanguage.en).every(
              (NewsSource s) => s.language == SourceLanguage.en,
            ),
        isTrue,
      );
      expect(
        registry.filter(onlyWithFeeds: true).every((NewsSource s) => s.hasFeed),
        isTrue,
      );
      expect(
        registry
            .filter(category: SourceCategory.business)
            .every((NewsSource s) => s.categories.contains(SourceCategory.business)),
        isTrue,
      );
    });
  });

  group('NewsSource presentation helpers', () {
    final NewsSource source = testRegistry().byId('prothomalo')!;

    test('localized names switch with the UI language', () {
      expect(source.localizedName(bengali: true), 'প্রথম আলো');
      expect(source.localizedName(bengali: false), 'Prothom Alo');
      expect(source.secondaryName(bengali: true), 'Prothom Alo');
    });

    test('monogram never exceeds two characters', () {
      expect(source.monogram.length, lessThanOrEqualTo(2));
    });

    test('search keys include transliterations', () {
      expect(source.searchKeys, contains('prothom alo'));
      expect(source.searchKeys, contains('প্রথম আলো'));
    });
  });
}
