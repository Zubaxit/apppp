import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'stores.dart';

/// SQLite schema and lifecycle for the local cache.
///
/// The database stores only metadata the publishers already expose in their
/// feeds: headline, link, excerpt, thumbnail URL, timestamps and the user's own
/// bookmarks/history. No article bodies are stored.
class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static const int schemaVersion = 2;
  static const String fileName = 'bangladesh_newspaper_hub.db';

  static Future<AppDatabase> open({String? path, DatabaseFactory? factory}) async {
    final DatabaseFactory dbFactory = factory ?? databaseFactory;
    final String resolvedPath = path ??
        p.join(await dbFactory.getDatabasesPath(), fileName);
    final Database database = await dbFactory.openDatabase(
      resolvedPath,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (Database db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (Database db, int version) async {
          await _createSchema(db);
        },
        onUpgrade: (Database db, int oldVersion, int newVersion) async {
          if (oldVersion < 2) await _createVocabularyTable(db);
        },
      ),
    );
    return AppDatabase._(database);
  }

  /// Used by tests with an in-memory database.
  static Future<AppDatabase> openInMemory({DatabaseFactory? factory}) async {
    final DatabaseFactory dbFactory = factory ?? databaseFactory;
    final Database database = await dbFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onCreate: (Database db, int version) async => _createSchema(db),
      ),
    );
    return AppDatabase._(database);
  }

  static Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE articles (
        id TEXT PRIMARY KEY,
        source_id TEXT NOT NULL,
        title TEXT NOT NULL,
        link TEXT NOT NULL,
        excerpt TEXT,
        image_url TEXT,
        published_at INTEGER,
        fetched_at INTEGER NOT NULL,
        guid TEXT,
        author TEXT,
        topic TEXT,
        publisher_category TEXT,
        language TEXT,
        tags TEXT,
        breaking INTEGER NOT NULL DEFAULT 0,
        cluster_key TEXT
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_articles_published ON articles (published_at DESC)');
    await db.execute(
        'CREATE INDEX idx_articles_fetched ON articles (fetched_at DESC)');
    await db.execute('CREATE INDEX idx_articles_source ON articles (source_id)');
    await db.execute('CREATE INDEX idx_articles_cluster ON articles (cluster_key)');

    await db.execute('''
      CREATE TABLE saved_articles (
        article_id TEXT PRIMARY KEY,
        saved_at INTEGER NOT NULL,
        payload TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE reading_history (
        article_id TEXT PRIMARY KEY,
        opened_at INTEGER NOT NULL,
        payload TEXT NOT NULL
      )
    ''');

    await _createVocabularyTable(db);

    await db.execute('''
      CREATE TABLE source_health (
        source_id TEXT PRIMARY KEY,
        status TEXT NOT NULL,
        last_checked_at INTEGER,
        last_success_at INTEGER,
        last_error TEXT,
        http_status INTEGER,
        item_count INTEGER,
        latency_ms INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE feed_meta (
        source_id TEXT PRIMARY KEY,
        etag TEXT,
        last_modified TEXT,
        last_fetch_at INTEGER,
        last_success_at INTEGER,
        item_count INTEGER,
        last_error TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE app_meta (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
  }

  static Future<void> _createVocabularyTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS saved_vocabulary (
        word TEXT PRIMARY KEY,
        display_word TEXT NOT NULL,
        meaning_bn TEXT NOT NULL,
        definition_en TEXT,
        part_of_speech TEXT,
        article_title TEXT,
        article_url TEXT,
        source_name TEXT,
        saved_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_vocabulary_saved_at '
      'ON saved_vocabulary (saved_at DESC)',
    );
  }

  AppStores get stores => AppStores(
        articles: SqliteArticleStore(db),
        saved: SqliteSavedStore(db),
        history: SqliteHistoryStore(db),
        vocabulary: SqliteVocabularyStore(db),
        health: SqliteHealthStore(db),
        feedMeta: SqliteFeedMetaStore(db),
        meta: SqliteMetaStore(db),
      );

  Future<void> close() => db.close();
}
