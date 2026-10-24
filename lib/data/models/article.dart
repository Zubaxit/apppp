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
    final DateTime fetched = (fetchedAt ?? DateTime.now()).toUtc();
    final String cleanTitle = TextUtils.normalizeSpaces(title);
    return Article(
      id: Ids.articleId(sourceId: sourceId, link: link, title: cleanTitle),
      sourceId: sourceId,
      title: cleanTitle,
      link: link,
      excerpt: TextUtils.nullIfBlank(excerpt),
      imageUrl: TextUtils.nullIfBlank(imageUrl),
      publishedAt: publishedAt?.toUtc(),
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
