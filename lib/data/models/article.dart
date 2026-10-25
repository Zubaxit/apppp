import 'dart:convert';

import '../../core/utils/ids.dart';
import '../../core/utils/text_utils.dart';
import 'news_source.dart';

/// Editorial topics used by the category rail and feed filters.
enum ArticleTopic {
  bangladesh,
  politics,
  economy,
  international,
  education,
  sports,
  entertainment,
  technology,
  health,
  lifestyle,

  /// Government and private recruitment: circulars, exam schedules, admit
  /// cards, results.
  jobs,

  /// Explanatory and educational writing: science, history, literature,
  /// knowledge pieces rather than institutional education news.
  learning,

  /// Official announcements, gazette notices, citizen services and deadlines.
  government,

  /// Local and international scholarships, grants and fellowships.
  scholarships,

  other,
}

extension ArticleTopicX on ArticleTopic {
  static ArticleTopic fromKey(String? key) {
    for (final ArticleTopic value in ArticleTopic.values) {
      if (value.name == key) return value;
    }
    return ArticleTopic.other;
  }
}

/// Normalized article as produced by a feed adapter.
///
/// This is a *discovery* record: headline, excerpt and link only, exactly what
/// the publisher chose to publish in its feed. Full article text is never
/// fetched or stored.
class Article {
  const Article({
    required this.id,
    required this.sourceId,
    required this.title,
    required this.link,
    this.excerpt,
    this.imageUrl,
    this.publishedAt,
    required this.fetchedAt,
    this.guid,
    this.author,
    this.topic = ArticleTopic.other,
    this.publisherCategory,
    this.language = SourceLanguage.bn,
    this.tags = const <String>[],
    this.breaking = false,
    this.clusterKey,
  });

  final String id;
  final String sourceId;
  final String title;
  final String link;
  final String? excerpt;
  final String? imageUrl;

  /// Null when the publisher did not supply a usable publication date.
  final DateTime? publishedAt;

  /// When the app retrieved this item. Never displayed as a publication date.
  final DateTime fetchedAt;

  final String? guid;
  final String? author;
  final ArticleTopic topic;
  final String? publisherCategory;
  final SourceLanguage language;
  final List<String> tags;

  /// True only when the publisher's own metadata says so.
  final bool breaking;
  final String? clusterKey;

  bool get hasPublishedAt => publishedAt != null;

  Duration? get age {
    final DateTime? at = publishedAt;
    if (at == null) return null;
    return DateTime.now().toUtc().difference(at.toUtc());
  }

  /// Sort key: real publication time when known, otherwise retrieval time.
  DateTime get sortKey => publishedAt ?? fetchedAt;

  Article copyWith({
    String? id,
    String? sourceId,
    String? title,
    String? link,
    String? excerpt,
    String? imageUrl,
    DateTime? publishedAt,
    DateTime? fetchedAt,
    String? guid,
    String? author,
    ArticleTopic? topic,
    String? publisherCategory,
    SourceLanguage? language,
    List<String>? tags,
    bool? breaking,
    String? clusterKey,
    bool clearPublishedAt = false,
  }) {
    return Article(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      title: title ?? this.title,
      link: link ?? this.link,
      excerpt: excerpt ?? this.excerpt,
      imageUrl: imageUrl ?? this.imageUrl,
      publishedAt: clearPublishedAt ? null : (publishedAt ?? this.publishedAt),
      fetchedAt: fetchedAt ?? this.fetchedAt,
      guid: guid ?? this.guid,
      author: author ?? this.author,
      topic: topic ?? this.topic,
      publisherCategory: publisherCategory ?? this.publisherCategory,
      language: language ?? this.language,
      tags: tags ?? this.tags,
      breaking: breaking ?? this.breaking,
      clusterKey: clusterKey ?? this.clusterKey,
    );
  }

  static Article create({
    required String sourceId,
    required String title,
    required String link,
    String? excerpt,
    String? imageUrl,
    DateTime? publishedAt,
    DateTime? fetchedAt,
    String? guid,
    String? author,
    ArticleTopic topic = ArticleTopic.other,
    String? publisherCategory,
    SourceLanguage language = SourceLanguage.bn,
    List<String> tags = const <String>[],
    bool breaking = false,
  }) {
    // Rows store epoch milliseconds, so an article is normalised to that
    // precision at creation: an in-memory article then equals its persisted
    // form, and a round trip cannot fail on sub-millisecond digits.
    DateTime toMillis(DateTime value) => DateTime.fromMillisecondsSinceEpoch(
          value.toUtc().millisecondsSinceEpoch,
          isUtc: true,
        );
    final DateTime fetched = toMillis(fetchedAt ?? DateTime.now());
    final String cleanTitle = TextUtils.normalizeSpaces(title);
    return Article(
      id: Ids.articleId(sourceId: sourceId, link: link, title: cleanTitle),
      sourceId: sourceId,
      title: cleanTitle,
      link: link,
      excerpt: TextUtils.nullIfBlank(excerpt),
      imageUrl: TextUtils.nullIfBlank(imageUrl),
      publishedAt: publishedAt == null ? null : toMillis(publishedAt),
      fetchedAt: fetched,
      guid: TextUtils.nullIfBlank(guid),
      author: TextUtils.nullIfBlank(author),
      topic: topic,
      publisherCategory: TextUtils.nullIfBlank(publisherCategory),
      language: language,
      tags: tags,
      breaking: breaking,
      clusterKey: Ids.storyClusterKey(cleanTitle, publishedAt),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'sourceId': sourceId,
        'title': title,
        'link': link,
        'excerpt': excerpt,
        'imageUrl': imageUrl,
        'publishedAt': publishedAt?.millisecondsSinceEpoch,
        'fetchedAt': fetchedAt.millisecondsSinceEpoch,
        'guid': guid,
        'author': author,
        'topic': topic.name,
        'publisherCategory': publisherCategory,
        'language': language.name,
        'tags': tags,
        'breaking': breaking ? 1 : 0,
        'clusterKey': clusterKey,
      };

  Map<String, dynamic> toJson() => toMap();

  /// SQLite row mapping.
  ///
  /// Deliberately separate from [toMap]: the JSON payload keeps camelCase keys
  /// for the saved/history blobs, while the `articles` table uses snake_case
  /// columns. Conflating the two meant every insert failed with
  /// "no column named sourceId", which aborted the whole refresh.
  Map<String, Object?> toRow() => <String, Object?>{
        'id': id,
        'source_id': sourceId,
        'title': title,
        'link': link,
        'excerpt': excerpt,
        'image_url': imageUrl,
        'published_at': publishedAt?.millisecondsSinceEpoch,
        'fetched_at': fetchedAt.millisecondsSinceEpoch,
        'guid': guid,
        'author': author,
        'topic': topic.name,
        'publisher_category': publisherCategory,
        'language': language.name,
        'tags': jsonEncode(tags),
        'breaking': breaking ? 1 : 0,
        'cluster_key': clusterKey,
      };

  /// A malformed tag blob must never hide an article, so a bad payload reads
  /// as "no tags" rather than throwing out of the row mapper.
  static List<String> _tagsFromJson(String payload) {
    try {
      final Object? parsed = jsonDecode(payload);
      if (parsed is List) return parsed.map((Object? e) => '$e').toList();
    } catch (_) {
      return const <String>[];
    }
    return const <String>[];
  }

  static Article fromRow(Map<String, Object?> row) {
    int? asInt(Object? value) =>
        value is int ? value : int.tryParse('${value ?? ''}');
    DateTime? asDate(Object? value) {
      final int? millis = asInt(value);
      return millis == null || millis == 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
    }

    final Object? decodedTags = row['tags'];
    final List<String> tags = decodedTags is String && decodedTags.isNotEmpty
        ? _tagsFromJson(decodedTags)
        : const <String>[];

    return Article(
      id: row['id']! as String,
      sourceId: (row['source_id'] ?? '') as String,
      title: (row['title'] ?? '') as String,
      link: (row['link'] ?? '') as String,
      excerpt: row['excerpt'] as String?,
      imageUrl: row['image_url'] as String?,
      publishedAt: asDate(row['published_at']),
      fetchedAt: asDate(row['fetched_at']) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      guid: row['guid'] as String?,
      author: row['author'] as String?,
      topic: ArticleTopicX.fromKey(row['topic'] as String?),
      publisherCategory: row['publisher_category'] as String?,
      language: SourceLanguageX.fromKey(row['language'] as String?),
      tags: tags,
      breaking: row['breaking'] == 1 || row['breaking'] == true,
      clusterKey: row['cluster_key'] as String?,
    );
  }

  static Article fromMap(Map<String, dynamic> map) {
    final int? published = map['publishedAt'] as int?;
    final int fetched = (map['fetchedAt'] as int?) ?? 0;
    return Article(
      id: map['id'] as String,
      sourceId: map['sourceId'] as String,
      title: map['title'] as String,
      link: map['link'] as String,
      excerpt: map['excerpt'] as String?,
      imageUrl: map['imageUrl'] as String?,
      publishedAt:
          published == null ? null : DateTime.fromMillisecondsSinceEpoch(published, isUtc: true),
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(fetched, isUtc: true),
      guid: map['guid'] as String?,
      author: map['author'] as String?,
      topic: ArticleTopicX.fromKey(map['topic'] as String?),
      publisherCategory: map['publisherCategory'] as String?,
      language: SourceLanguageX.fromKey(map['language'] as String?),
      tags: (map['tags'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic e) => '$e')
          .toList(),
      breaking: map['breaking'] == 1 || map['breaking'] == true,
      clusterKey: map['clusterKey'] as String?,
    );
  }

  @override
  bool operator ==(Object other) => other is Article && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Article($sourceId, $title)';
}

/// The user's saved snapshot. Keeping a copy of the article means a bookmark
/// survives the publisher dropping the item from its feed.
class SavedArticle {
  const SavedArticle({required this.article, required this.savedAt});

  final Article article;
  final DateTime savedAt;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'article': article.toMap(),
        'savedAt': savedAt.toUtc().millisecondsSinceEpoch,
      };

  static SavedArticle fromMap(Map<String, dynamic> map) => SavedArticle(
        article: Article.fromMap(map['article'] as Map<String, dynamic>),
        savedAt: DateTime.fromMillisecondsSinceEpoch(
          (map['savedAt'] as int?) ?? 0,
          isUtc: true,
        ),
      );
}

/// A story that several publishers covered, shown as related links.
class StoryCluster {
  const StoryCluster({required this.key, required this.articles});

  final String key;
  final List<Article> articles;

  int get publisherCount => articles.map((Article a) => a.sourceId).toSet().length;
}
