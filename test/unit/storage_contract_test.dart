import 'dart:io';

import 'package:bangladesh_newspaper_hub/data/models/article.dart';
import 'package:bangladesh_newspaper_hub/data/models/news_source.dart';
import 'package:bangladesh_newspaper_hub/data/models/source_health.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression suite for the defect that emptied the shipped app.
///
/// `Article.toMap()` emits camelCase keys for the JSON payloads (saved items,
/// reading history) while the SQLite table uses snake_case columns. The SQLite
/// store reused `toMap()`, so every insert failed with
/// "table articles has no column named sourceId", which aborted the whole
/// refresh and left every screen empty.
///
/// These tests compare the row mappers against the real DDL, without needing a
/// SQLite plugin, so the mismatch can never come back silently.
void main() {
  final String schema =
      File('lib/data/services/app_database.dart').readAsStringSync();

  /// Column names declared in `CREATE TABLE <name> ( ... )`.
  Set<String> columnsOf(String table) {
    final RegExp create = RegExp(
      'CREATE TABLE $table \\((.*?)\\)\\s*\'',
      dotAll: true,
    );
    final RegExpMatch? match = create.firstMatch(schema);
    expect(match, isNotNull, reason: 'no CREATE TABLE for $table');
    final Set<String> columns = <String>{};
    for (final String line in match!.group(1)!.split('\n')) {
      final String trimmed = line.trim().replaceAll(RegExp(r',$'), '');
      if (trimmed.isEmpty || trimmed.startsWith('--')) continue;
      final String first = trimmed.split(RegExp(r'\s+')).first;
      if (<String>{'PRIMARY', 'FOREIGN', 'UNIQUE', 'CONSTRAINT', 'CHECK'}
          .contains(first)) {
        continue;
      }
      columns.add(first);
    }
    return columns;
  }

  group('SQLite schema contract', () {
    test('articles table matches Article.toRow exactly', () {
      final Set<String> table = columnsOf('articles');
      final Set<String> mapped = Article.create(
        sourceId: 'prothomalo',
        title: 'শিরোনাম',
        link: 'https://www.prothomalo.com/a',
      ).toRow().keys.toSet();
      expect(table.difference(mapped), isEmpty,
          reason: 'columns the app never writes: ${table.difference(mapped)}');
      expect(mapped.difference(table), isEmpty,
          reason:
              'keys with no column (the original bug): ${mapped.difference(table)}');
    });

    test('source_health table matches SourceHealth.toRow exactly', () {
      final Set<String> table = columnsOf('source_health');
      final Set<String> mapped = const SourceHealth(
        sourceId: 'prothomalo',
        status: SourceHealthStatus.ok,
      ).toRow().keys.toSet();
      expect(mapped.difference(table), isEmpty);
      expect(table.difference(mapped), isEmpty);
    });

    test('row mappers never emit camelCase column names', () {
      final Iterable<String> keys = Article.create(
        sourceId: 'x',
        title: 't',
        link: 'https://example.com/a',
      ).toRow().keys;
      for (final String key in keys) {
        expect(key, key.toLowerCase(), reason: '$key is not a column name');
      }
    });
  });

  group('Article row round trip', () {
    final Article original = Article.create(
      sourceId: 'prothomalo',
      title: 'সড়কে বন্দুক হাতে তরুণের মহড়া',
      link: 'https://www.prothomalo.com/video/bangladesh/1jf9hf946z',
      excerpt: 'খাগড়াছড়িতে অবরোধের মধ্যে ভিডিওটি ছড়িয়ে পড়েছে।',
      imageUrl: 'https://media.prothomalo.com/thumb.jpg',
      publishedAt: DateTime.utc(2026, 10, 24, 14, 8, 41),
      topic: ArticleTopic.bangladesh,
      publisherCategory: 'বাংলাদেশ',
      language: SourceLanguage.bn,
      tags: const <String>['খাগড়াছড়ি', 'অপরাধ'],
      breaking: true,
      guid: '18339f1e-f251',
    );

    test('preserves every field through toRow/fromRow', () {
      final Article restored = Article.fromRow(original.toRow());
      expect(restored.id, original.id);
      expect(restored.sourceId, original.sourceId);
      expect(restored.title, original.title);
      expect(restored.link, original.link);
      expect(restored.excerpt, original.excerpt);
      expect(restored.imageUrl, original.imageUrl);
      expect(restored.publishedAt, original.publishedAt);
      expect(restored.fetchedAt, original.fetchedAt);
      expect(restored.topic, original.topic);
      expect(restored.publisherCategory, original.publisherCategory);
      expect(restored.language, original.language);
      expect(restored.tags, original.tags);
      expect(restored.breaking, isTrue);
      expect(restored.guid, original.guid);
    });

    test('keeps Bengali text byte-for-byte', () {
      final Article restored = Article.fromRow(original.toRow());
      expect(restored.title.codeUnits, original.title.codeUnits);
    });

    test('survives a missing optional date and a corrupt tag blob', () {
      final Article undated = Article.create(
        sourceId: 'tbs',
        title: 'Exports rise',
        link: 'https://www.tbsnews.net/a',
      );
      final Map<String, Object?> row = undated.toRow();
      row['tags'] = 'not json';
      final Article restored = Article.fromRow(row);
      expect(restored.publishedAt, isNull);
      expect(restored.tags, isEmpty);
      expect(restored.title, 'Exports rise');
    });

    test('JSON payload mapping still works for saved items', () {
      final Article restored = Article.fromMap(original.toMap());
      expect(restored.title, original.title);
      expect(restored.publishedAt, original.publishedAt);
      expect(restored.tags, original.tags);
    });
  });
}
