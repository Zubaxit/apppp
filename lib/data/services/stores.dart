import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../core/utils/text_utils.dart';
import '../models/article.dart';
import '../models/feed_query.dart';
import '../models/news_source.dart';
import '../models/source_health.dart';
import '../models/vocabulary_entry.dart';

/// Cache/ETag bookkeeping per source.
class FeedMeta {
  const FeedMeta({
    required this.sourceId,
    this.etag,
    this.lastModified,
    this.lastFetchAt,
    this.lastSuccessAt,
    this.itemCount = 0,
    this.lastError,
  });

  final String sourceId;
  final String? etag;
  final String? lastModified;
  final DateTime? lastFetchAt;
  final DateTime? lastSuccessAt;
  final int itemCount;
  final String? lastError;
}

abstract class ArticleStore {
  Future<void> upsertAll(Iterable<Article> articles);
  Future<List<Article>> latest({
    int limit = 200,
    Set<String> sourceIds = const <String>{},
    Set<ArticleTopic> topics = const <ArticleTopic>{},
    Set<SourceLanguage> languages = const <SourceLanguage>{},
    String text = '',
  });
  Future<List<Article>> bySource(String sourceId, {int limit = 60});
  Future<Article?> byId(String id);
  Future<List<Article>> byClusterKey(String clusterKey, {int limit = 8});
  Future<int> count();
  Future<DateTime?> newestFetchAt();
  Future<void> prune({
    int keepPerSource = 250,
    int keepTotal = 5000,
    Duration maxAge = const Duration(days: 180),
  });
  Future<void> clear();
}

abstract class SavedStore {
  Future<void> save(Article article);
  Future<void> remove(String articleId);
  Future<List<SavedArticle>> all();
  Future<bool> contains(String articleId);
  Future<void> clear();
}

abstract class HistoryStore {
  Future<void> record(Article article);
  Future<List<SavedArticle>> recent({int limit = 60});
  Future<void> clear();
}

abstract class VocabularyStore {
  Future<void> save(VocabularyEntry entry);
  Future<List<VocabularyEntry>> all();
  Future<VocabularyEntry?> byWord(String normalizedWord);
  Future<void> remove(String normalizedWord);
}

abstract class HealthStore {
  Future<List<SourceHealth>> all();
  Future<SourceHealth?> bySource(String sourceId);
  Future<void> upsert(SourceHealth health);
  Future<void> clear();
}

abstract class FeedMetaStore {
  Future<FeedMeta?> get(String sourceId);
  Future<void> save(FeedMeta meta);
  Future<List<FeedMeta>> all();
}

abstract class MetaStore {
  Future<String?> get(String key);
  Future<void> set(String key, String? value);
}

class SqliteArticleStore implements ArticleStore {
  SqliteArticleStore(this._db);
  final Database _db;

  static const String _table = 'articles';

  @override
  Future<void> upsertAll(Iterable<Article> articles) async {
    if (articles.isEmpty) return;
    final Batch batch = _db.batch();
    for (final Article article in articles) {
      batch.insert(
        _table,
        article.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<List<Article>> latest({
    int limit = 200,
    Set<String> sourceIds = const <String>{},
    Set<ArticleTopic> topics = const <ArticleTopic>{},
    Set<SourceLanguage> languages = const <SourceLanguage>{},
    String text = '',
  }) async {
    final List<String> clauses = <String>[];
    final List<Object?> args = <Object?>[];
    if (sourceIds.isNotEmpty) {
      clauses.add('source_id IN (${List<String>.filled(sourceIds.length, '?').join(',')})');
      args.addAll(sourceIds);
    }
    if (topics.isNotEmpty) {
      clauses.add('topic IN (${List<String>.filled(topics.length, '?').join(',')})');
      args.addAll(topics.map((ArticleTopic t) => t.name));
    }
    if (languages.isNotEmpty) {
      clauses.add('language IN (${List<String>.filled(languages.length, '?').join(',')})');
      args.addAll(languages.map((SourceLanguage l) => l.name));
    }
    final String normalizedText = TextUtils.searchNormalize(text);
    if (normalizedText.isNotEmpty) {
      clauses.add('(LOWER(title) LIKE ? OR LOWER(IFNULL(excerpt, \'\')) LIKE ?)');
      args
        ..add('%$normalizedText%')
        ..add('%$normalizedText%');
    }
    final List<Map<String, Object?>> rows = await _db.query(
      _table,
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'COALESCE(published_at, fetched_at) DESC, fetched_at DESC',
      limit: limit,
    );
    return rows.map(Article.fromRow).toList();
  }

  @override
  Future<List<Article>> bySource(String sourceId, {int limit = 60}) async {
    final List<Map<String, Object?>> rows = await _db.query(
      _table,
      where: 'source_id = ?',
      whereArgs: <Object?>[sourceId],
      orderBy: 'COALESCE(published_at, fetched_at) DESC',
      limit: limit,
    );
    return rows.map(Article.fromRow).toList();
  }

  @override
  Future<Article?> byId(String id) async {
    final List<Map<String, Object?>> rows = await _db.query(
      _table,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Article.fromRow(rows.first);
  }

  @override
  Future<List<Article>> byClusterKey(String clusterKey, {int limit = 8}) async {
    final List<Map<String, Object?>> rows = await _db.query(
      _table,
      where: 'cluster_key = ?',
      whereArgs: <Object?>[clusterKey],
      orderBy: 'COALESCE(published_at, fetched_at) DESC',
      limit: limit,
    );
    return rows.map(Article.fromRow).toList();
  }

  @override
  Future<int> count() async {
    final List<Map<String, Object?>> rows =
        await _db.rawQuery('SELECT COUNT(*) AS c FROM $_table');
    return (rows.first['c'] as int?) ?? 0;
  }

  @override
  Future<DateTime?> newestFetchAt() async {
    final List<Map<String, Object?>> rows =
        await _db.rawQuery('SELECT MAX(fetched_at) AS m FROM $_table');
    final int? millis = rows.first['m'] as int?;
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  }

  @override
  Future<void> prune({
    int keepPerSource = 250,
    int keepTotal = 5000,
    Duration maxAge = const Duration(days: 180),
  }) async {
    final int cutoff = DateTime.now()
        .toUtc()
        .subtract(maxAge)
        .millisecondsSinceEpoch;
    await _db.rawDelete(
      'DELETE FROM $_table WHERE fetched_at < ?',
      <Object?>[cutoff],
    );
    final List<Map<String, Object?>> sourceRows = await _db.rawQuery(
      'SELECT DISTINCT source_id FROM $_table',
    );
    for (final Map<String, Object?> row in sourceRows) {
      final Object? sourceId = row['source_id'];
      await _db.rawDelete(
        'DELETE FROM $_table WHERE source_id = ? AND id NOT IN ('
        '  SELECT id FROM $_table WHERE source_id = ? '
        '  ORDER BY COALESCE(published_at, fetched_at) DESC LIMIT ?'
        ')',
        <Object?>[sourceId, sourceId, keepPerSource],
      );
    }
    await _db.rawDelete(
      'DELETE FROM $_table WHERE id NOT IN ('
      '  SELECT id FROM $_table ORDER BY COALESCE(published_at, fetched_at) DESC LIMIT ?'
      ')',
      <Object?>[keepTotal],
    );
  }

  @override
  Future<void> clear() async => _db.delete(_table);
}

class SqliteSavedStore implements SavedStore {
  SqliteSavedStore(this._db);
  final Database _db;
  static const String _table = 'saved_articles';

  @override
  Future<void> save(Article article) async {
    await _db.insert(
      _table,
      <String, Object?>{
        'article_id': article.id,
        'saved_at': DateTime.now().toUtc().millisecondsSinceEpoch,
        'payload': json.encode(article.toMap()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> remove(String articleId) async {
    await _db.delete(_table, where: 'article_id = ?', whereArgs: <Object?>[articleId]);
  }

  @override
  Future<List<SavedArticle>> all() async {
    final List<Map<String, Object?>> rows = await _db.query(
      _table,
      orderBy: 'saved_at DESC',
    );
    return _decode(rows);
  }

  @override
  Future<bool> contains(String articleId) async {
    final List<Map<String, Object?>> rows = await _db.query(
      _table,
      columns: <String>['article_id'],
      where: 'article_id = ?',
      whereArgs: <Object?>[articleId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  @override
  Future<void> clear() async => _db.delete(_table);

  List<SavedArticle> _decode(List<Map<String, Object?>> rows) {
    final List<SavedArticle> output = <SavedArticle>[];
    for (final Map<String, Object?> row in rows) {
      try {
        final dynamic decoded = json.decode(row['payload']! as String);
        if (decoded is! Map<String, dynamic>) continue;
        output.add(SavedArticle(
          article: Article.fromMap(decoded),
          savedAt: DateTime.fromMillisecondsSinceEpoch(
            (row['saved_at'] as int?) ?? 0,
            isUtc: true,
          ),
        ));
      } catch (_) {
        // Corrupt snapshot: skip rather than break the whole list.
      }
    }
    return output;
  }
}

class SqliteHistoryStore implements HistoryStore {
  SqliteHistoryStore(this._db);
  final Database _db;
  static const String _table = 'reading_history';

  @override
  Future<void> record(Article article) async {
    await _db.insert(
      _table,
      <String, Object?>{
        'article_id': article.id,
        'opened_at': DateTime.now().toUtc().millisecondsSinceEpoch,
        'payload': json.encode(article.toMap()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _db.rawDelete(
      'DELETE FROM $_table WHERE article_id NOT IN ('
      '  SELECT article_id FROM $_table ORDER BY opened_at DESC LIMIT 200'
      ')',
    );
  }

  @override
  Future<List<SavedArticle>> recent({int limit = 60}) async {
    final List<Map<String, Object?>> rows = await _db.query(
      _table,
      orderBy: 'opened_at DESC',
      limit: limit,
    );
    final List<SavedArticle> output = <SavedArticle>[];
    for (final Map<String, Object?> row in rows) {
      try {
        final dynamic decoded = json.decode(row['payload']! as String);
        if (decoded is! Map<String, dynamic>) continue;
        output.add(SavedArticle(
          article: Article.fromMap(decoded),
          savedAt: DateTime.fromMillisecondsSinceEpoch(
            (row['opened_at'] as int?) ?? 0,
            isUtc: true,
          ),
        ));
      } catch (_) {
        // ignore corrupt entry
      }
    }
    return output;
  }

  @override
  Future<void> clear() async => _db.delete(_table);
}

class SqliteVocabularyStore implements VocabularyStore {
  SqliteVocabularyStore(this._db);
  final Database _db;
  static const String _table = 'saved_vocabulary';

  @override
  Future<void> save(VocabularyEntry entry) async {
    await _db.insert(
      _table,
      <String, Object?>{
        'word': entry.normalizedWord,
        'display_word': entry.word.trim(),
        'meaning_bn': entry.meaningBn.trim(),
        'definition_en': entry.definitionEn,
        'part_of_speech': entry.partOfSpeech,
        'article_title': entry.articleTitle,
        'article_url': entry.articleUrl,
        'source_name': entry.sourceName,
        'saved_at': entry.savedAt.toUtc().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<VocabularyEntry>> all() async {
    final List<Map<String, Object?>> rows = await _db.query(
      _table,
      orderBy: 'saved_at DESC',
    );
    return rows.map(_decode).toList(growable: false);
  }

  @override
  Future<VocabularyEntry?> byWord(String normalizedWord) async {
    final List<Map<String, Object?>> rows = await _db.query(
      _table,
      where: 'word = ?',
      whereArgs: <Object?>[VocabularyEntry.normalizeWord(normalizedWord)],
      limit: 1,
    );
    return rows.isEmpty ? null : _decode(rows.first);
  }

  @override
  Future<void> remove(String normalizedWord) => _db.delete(
        _table,
        where: 'word = ?',
        whereArgs: <Object?>[VocabularyEntry.normalizeWord(normalizedWord)],
      );

  VocabularyEntry _decode(Map<String, Object?> row) => VocabularyEntry(
        word: (row['display_word'] as String?) ?? (row['word']! as String),
        meaningBn: row['meaning_bn']! as String,
        definitionEn: row['definition_en'] as String?,
        partOfSpeech: row['part_of_speech'] as String?,
        articleTitle: row['article_title'] as String?,
        articleUrl: row['article_url'] as String?,
        sourceName: row['source_name'] as String?,
        savedAt: DateTime.fromMillisecondsSinceEpoch(
          (row['saved_at'] as int?) ?? 0,
          isUtc: true,
        ),
      );
}

class SqliteHealthStore implements HealthStore {
  SqliteHealthStore(this._db);
  final Database _db;
  static const String _table = 'source_health';

  @override
  Future<List<SourceHealth>> all() async {
    final List<Map<String, Object?>> rows = await _db.query(_table);
    return rows.map(SourceHealth.fromRow).toList();
  }

  @override
  Future<SourceHealth?> bySource(String sourceId) async {
    final List<Map<String, Object?>> rows = await _db.query(
      _table,
      where: 'source_id = ?',
      whereArgs: <Object?>[sourceId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return SourceHealth.fromRow(rows.first);
  }

  @override
  Future<void> upsert(SourceHealth health) async {
    await _db.insert(
      _table,
      health.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> clear() async => _db.delete(_table);
}

class SqliteFeedMetaStore implements FeedMetaStore {
  SqliteFeedMetaStore(this._db);
  final Database _db;
  static const String _table = 'feed_meta';

  @override
  Future<FeedMeta?> get(String sourceId) async {
    final List<Map<String, Object?>> rows = await _db.query(
      _table,
      where: 'source_id = ?',
      whereArgs: <Object?>[sourceId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final Map<String, Object?> row = rows.first;
    DateTime? date(Object? value) {
      final int? millis = value as int?;
      return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
    }

    return FeedMeta(
      sourceId: row['source_id']! as String,
      etag: row['etag'] as String?,
      lastModified: row['last_modified'] as String?,
      lastFetchAt: date(row['last_fetch_at']),
      lastSuccessAt: date(row['last_success_at']),
      itemCount: (row['item_count'] as int?) ?? 0,
      lastError: row['last_error'] as String?,
    );
  }

  @override
  Future<void> save(FeedMeta meta) async {
    await _db.insert(
      _table,
      <String, Object?>{
        'source_id': meta.sourceId,
        'etag': meta.etag,
        'last_modified': meta.lastModified,
        'last_fetch_at': meta.lastFetchAt?.millisecondsSinceEpoch,
        'last_success_at': meta.lastSuccessAt?.millisecondsSinceEpoch,
        'item_count': meta.itemCount,
        'last_error': meta.lastError,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<FeedMeta>> all() async {
    final List<Map<String, Object?>> rows = await _db.query(_table);
    final List<FeedMeta> output = <FeedMeta>[];
    for (final Map<String, Object?> row in rows) {
      output.add(FeedMeta(
        sourceId: row['source_id']! as String,
        etag: row['etag'] as String?,
        lastModified: row['last_modified'] as String?,
        lastFetchAt: row['last_fetch_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(row['last_fetch_at']! as int, isUtc: true),
        lastSuccessAt: row['last_success_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(row['last_success_at']! as int, isUtc: true),
        itemCount: (row['item_count'] as int?) ?? 0,
        lastError: row['last_error'] as String?,
      ));
    }
    return output;
  }
}

class SqliteMetaStore implements MetaStore {
  SqliteMetaStore(this._db);
  final Database _db;
  static const String _table = 'app_meta';

  @override
  Future<String?> get(String key) async {
    final List<Map<String, Object?>> rows = await _db.query(
      _table,
      where: 'key = ?',
      whereArgs: <Object?>[key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  @override
  Future<void> set(String key, String? value) async {
    if (value == null) {
      await _db.delete(_table, where: 'key = ?', whereArgs: <Object?>[key]);
      return;
    }
    await _db.insert(
      _table,
      <String, Object?>{'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

/// Aggregate of every persistent store the app uses.
class AppStores {
  const AppStores({
    required this.articles,
    required this.saved,
    required this.history,
    required this.vocabulary,
    required this.health,
    required this.feedMeta,
    required this.meta,
  });

  final ArticleStore articles;
  final SavedStore saved;
  final HistoryStore history;
  final VocabularyStore vocabulary;
  final HealthStore health;
  final FeedMetaStore feedMeta;
  final MetaStore meta;
}

/// Helper used by the repository when a filter set must reach SQL.
String describeQuery(FeedQuery query) =>
    'sources=${query.sourceIds.length} topics=${query.topics.length} '
    'langs=${query.languages.length} followed=${query.followedOnly}';
