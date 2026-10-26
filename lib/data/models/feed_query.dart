import 'article.dart';
import 'news_source.dart';

/// Immutable description of the feed the user is currently looking at.
class FeedQuery {
  const FeedQuery({
    this.sourceIds = const <String>{},
    this.topics = const <ArticleTopic>{},
    this.languages = const <SourceLanguage>{},
    this.followedOnly = false,
    this.text = '',
    this.limit = 120,
  });

  final Set<String> sourceIds;
  final Set<ArticleTopic> topics;
  final Set<SourceLanguage> languages;
  final bool followedOnly;
  final String text;
  final int limit;

  bool get isUnfiltered =>
      sourceIds.isEmpty &&
      topics.isEmpty &&
      languages.isEmpty &&
      text.trim().isEmpty;

  FeedQuery copyWith({
    Set<String>? sourceIds,
    Set<ArticleTopic>? topics,
    Set<SourceLanguage>? languages,
    bool? followedOnly,
    String? text,
    int? limit,
  }) {
    return FeedQuery(
      sourceIds: sourceIds ?? this.sourceIds,
      topics: topics ?? this.topics,
      languages: languages ?? this.languages,
      followedOnly: followedOnly ?? this.followedOnly,
      text: text ?? this.text,
      limit: limit ?? this.limit,
    );
  }

  FeedQuery toggleSource(String id) {
    final Set<String> next = Set<String>.of(sourceIds);
    if (!next.remove(id)) next.add(id);
    return copyWith(sourceIds: next);
  }

  FeedQuery toggleTopic(ArticleTopic topic) {
    final Set<ArticleTopic> next = Set<ArticleTopic>.of(topics);
    if (!next.remove(topic)) next.add(topic);
    return copyWith(topics: next);
  }

  FeedQuery toggleLanguage(SourceLanguage language) {
    final Set<SourceLanguage> next = Set<SourceLanguage>.of(languages);
    if (!next.remove(language)) next.add(language);
    return copyWith(languages: next);
  }

  @override
  bool operator ==(Object other) {
    if (other is! FeedQuery) return false;
    return other.followedOnly == followedOnly &&
        other.text == text &&
        other.limit == limit &&
        _setEquals(other.sourceIds, sourceIds) &&
        _setEquals(other.topics, topics) &&
        _setEquals(other.languages, languages);
  }

  @override
  int get hashCode => Object.hash(
        followedOnly,
        text,
        limit,
        Object.hashAllUnordered(sourceIds),
        Object.hashAllUnordered(topics),
        Object.hashAllUnordered(languages),
      );

  static bool _setEquals<T>(Set<T> a, Set<T> b) =>
      a.length == b.length && a.every(b.contains);
}

/// Summary produced by a refresh pass, used for the "source status" surface.
class RefreshReport {
  const RefreshReport({
    required this.startedAt,
    required this.finishedAt,
    required this.sourcesAttempted,
    required this.sourcesSucceeded,
    required this.sourcesFailed,
    required this.sourcesNotModified,
    required this.newArticles,
    this.failures = const <String, String>{},
    this.notes = const <String>[],
    this.storageError,
  });

  final DateTime startedAt;
  final DateTime finishedAt;
  final int sourcesAttempted;
  final int sourcesSucceeded;
  final int sourcesFailed;
  final int sourcesNotModified;
  final int newArticles;

  /// sourceId -> short error message
  final Map<String, String> failures;
  final List<String> notes;

  /// Set when fetched articles could not be written to the local cache. The
  /// UI shows this as a real failure instead of a successful refresh.
  final String? storageError;

  Duration get duration => finishedAt.difference(startedAt);

  bool get hadNetworkFailure => sourcesFailed > 0;

  static RefreshReport empty(DateTime at) => RefreshReport(
        startedAt: at,
        finishedAt: at,
        sourcesAttempted: 0,
        sourcesSucceeded: 0,
        sourcesFailed: 0,
        sourcesNotModified: 0,
        newArticles: 0,
      );
}
