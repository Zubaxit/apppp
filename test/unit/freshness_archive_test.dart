import 'package:bangladesh_newspaper_hub/core/utils/article_freshness.dart';
import 'package:bangladesh_newspaper_hub/data/models/article.dart';
import 'package:bangladesh_newspaper_hub/services/archive_search.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  group('ArticleFreshness', () {
    final DateTime now = DateTime.utc(2026, 10, 25, 12);

    test('uses 12-hour standard and seven-day extended windows', () {
      final Article recent = sampleArticle(
        title: 'recent',
        publishedAt: now.subtract(const Duration(hours: 12)),
      );
      final Article stale = sampleArticle(
        title: 'stale',
        publishedAt: now.subtract(const Duration(hours: 12, seconds: 1)),
      );
      final Article oldJob = sampleArticle(
        title: 'job',
        topic: ArticleTopic.jobs,
        publishedAt: now.subtract(const Duration(days: 6, hours: 23)),
      );
      final Article expiredJob = sampleArticle(
        title: 'old job',
        topic: ArticleTopic.jobs,
        publishedAt: now.subtract(const Duration(days: 7, seconds: 1)),
      );

      expect(
        ArticleFreshness.eligible(
          <Article>[recent, stale, oldJob, expiredJob],
          now: now,
        ),
        <Article>[recent, oldJob],
      );
    });

    test('keeps editorials for seven days and safely dates undated discoveries',
        () {
      final Article current = sampleArticle(
        title: 'Editorial current',
        topic: ArticleTopic.editorial,
        publishedAt: now.subtract(const Duration(days: 6, hours: 23)),
      );
      final Article expired = sampleArticle(
        title: 'Editorial expired',
        topic: ArticleTopic.editorial,
        publishedAt: now.subtract(const Duration(days: 7, seconds: 1)),
      );
      final Article seed = sampleArticle(title: 'Undated editorial');
      final Article undated = Article(
        id: seed.id,
        sourceId: seed.sourceId,
        title: seed.title,
        link: seed.link,
        publishedAt: null,
        fetchedAt: now.subtract(const Duration(hours: 2)),
        topic: ArticleTopic.editorial,
        language: seed.language,
      );

      expect(
        ArticleFreshness.eligible(
          <Article>[current, expired, undated],
          now: now,
        ),
        <Article>[current, undated],
      );
    });

    test('conservatively excludes missing and implausible future times', () {
      final Article base = sampleArticle();
      final Article unknown = Article(
        id: base.id,
        sourceId: base.sourceId,
        title: base.title,
        link: base.link,
        excerpt: base.excerpt,
        publishedAt: null,
        fetchedAt: now,
        topic: base.topic,
        language: base.language,
      );
      final Article future = sampleArticle(
        title: 'future',
        publishedAt: now.add(const Duration(minutes: 11)),
      );
      final Article tolerated = sampleArticle(
        title: 'clock skew',
        publishedAt: now.add(const Duration(minutes: 9)),
      );
      expect(
        ArticleFreshness.eligible(
          <Article>[unknown, future, tolerated],
          now: now,
        ),
        <Article>[tolerated],
      );
    });
  });

  group('ArchiveSearchService', () {
    test('keeps provider relevance order, canonical-dedupes and caches',
        () async {
      final Article first = sampleArticle(
        title: 'বাংলাদেশ বাজেট',
        link: 'https://example.com/story?utm_source=test',
      );
      final Article duplicate = sampleArticle(
        sourceId: 'daily_star',
        title: 'Bangladesh budget',
        link: 'https://example.com/story',
      );
      final Article second = sampleArticle(
        title: 'বাজেট বিশ্লেষণ',
        link: 'https://example.com/analysis',
      );
      final _Provider provider = _Provider(<Article>[first, duplicate, second]);
      final ArchiveSearchService service =
          ArchiveSearchService(providers: <ArchiveSearchProvider>[provider]);
      const ArchiveSearchQuery query = ArchiveSearchQuery(text: 'budget');

      final ArchiveSearchResponse one = await service.search(query);
      final ArchiveSearchResponse two = await service.search(query);

      expect(one.articles, <Article>[first, second]);
      expect(two.articles, one.articles);
      expect(provider.calls, 1);
    });

    test('isolates provider errors and reports limitations', () async {
      final ArchiveSearchService service = ArchiveSearchService(
        providers: <ArchiveSearchProvider>[
          _ThrowingProvider(),
          _Provider(<Article>[sampleArticle()]),
        ],
      );
      final ArchiveSearchResponse result =
          await service.search(const ArchiveSearchQuery(text: 'news'));
      expect(result.articles, hasLength(1));
      expect(result.warnings, contains('Broken archive is unavailable.'));
    });
  });
}

class _Provider implements ArchiveSearchProvider {
  _Provider(this.articles);
  final List<Article> articles;
  int calls = 0;

  @override
  String get id => 'fake';
  @override
  String get label => 'Fake archive';

  @override
  Future<ArchiveProviderResult> search(ArchiveSearchQuery query) async {
    calls++;
    return ArchiveProviderResult(articles: articles);
  }
}

class _ThrowingProvider implements ArchiveSearchProvider {
  @override
  String get id => 'broken';
  @override
  String get label => 'Broken archive';
  @override
  Future<ArchiveProviderResult> search(ArchiveSearchQuery query) {
    throw StateError('offline');
  }
}
