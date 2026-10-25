import '../../data/models/article.dart';

/// One central live-feed retention policy.
///
/// The cache is allowed to retain older records for bookmarks and Archive
/// Search, but every live-feed/category/search read passes through this policy.
/// Unknown publication timestamps are excluded from live surfaces: `fetchedAt`
/// is retrieval evidence, not publication evidence, and must never make an
/// undated article appear new.
class ArticleFreshness {
  const ArticleFreshness._();

  static const Duration standard = Duration(hours: 12);
  static const Duration extended = Duration(days: 7);
  static const Duration futureTolerance = Duration(minutes: 10);

  static const Set<ArticleTopic> extendedTopics = <ArticleTopic>{
    ArticleTopic.education,
    ArticleTopic.jobs,
    ArticleTopic.learning,
    ArticleTopic.government,
    ArticleTopic.scholarships,
  };

  static Duration retentionFor(ArticleTopic topic) =>
      extendedTopics.contains(topic) ? extended : standard;

  static bool isEligible(Article article, {DateTime? now}) {
    final DateTime? published = article.publishedAt?.toUtc();
    if (published == null) return false;
    final DateTime clock = (now ?? DateTime.now()).toUtc();
    final Duration age = clock.difference(published);
    if (age < -futureTolerance) return false;
    return age <= retentionFor(article.topic);
  }

  static List<Article> eligible(
    Iterable<Article> articles, {
    DateTime? now,
    int? limit,
  }) {
    final List<Article> result = <Article>[
      for (final Article article in articles)
        if (isEligible(article, now: now)) article,
    ];
    return limit == null ? result : result.take(limit).toList(growable: false);
  }
}
