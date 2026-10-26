import 'dart:convert';

import 'package:bangladesh_newspaper_hub/services/translation_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// A bundle that serves one fixed JSON payload, standing in for the shipped
/// glossary asset without touching the file system.
class _StringBundle extends CachingAssetBundle {
  _StringBundle(this.payload);

  final String payload;

  @override
  Future<ByteData> load(String key) async {
    if (key != TranslationService.assetPath) {
      throw StateError('unexpected asset $key');
    }
    return ByteData.sublistView(utf8.encoder.convert(payload));
  }
}

class _FailingBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => throw StateError('asset missing');
}

const String _payload = '{"version":1,"words":{'
    '"news":"সংবাদ","report":"প্রতিবেদন","poem":"কবিতা","story":"গল্প",'
    '"poetry":"কবিতা","language":"ভাষা"}}';

void main() {
  group('TranslationService', () {
    test('loads a glossary and reports availability and size', () async {
      final TranslationService service =
          TranslationService(bundle: _StringBundle(_payload));
      expect(service.isAvailable, isFalse);
      await service.load();
      expect(service.isLoaded, isTrue);
      expect(service.isAvailable, isTrue);
      expect(service.size, 6);
    });

    test('a missing asset leaves the feature unavailable instead of throwing',
        () async {
      final TranslationService service =
          TranslationService(bundle: _FailingBundle());
      await service.load();
      expect(service.isAvailable, isFalse);
      expect(service.gloss('news report'), isEmpty);
    });

    test('lookup is case-insensitive and strips punctuation', () async {
      final TranslationService service =
          TranslationService(bundle: _StringBundle(_payload));
      await service.load();
      expect(service.lookup('News').meaning, 'সংবাদ');
      expect(service.lookup('"report",').meaning, 'প্রতিবেদন');
      expect(service.lookup('  POEM  ').meaning, 'কবিতা');
    });

    test('unknown words are reported as not found, never approximated',
        () async {
      final TranslationService service =
          TranslationService(bundle: _StringBundle(_payload));
      await service.load();
      final WordMeaning result = service.lookup('quixotic');
      expect(result.found, isFalse);
      expect(result.meaning, isNull);
    });

    test('a trailing plural falls back to the singular entry', () async {
      final TranslationService service =
          TranslationService(bundle: _StringBundle(_payload));
      await service.load();
      expect(service.lookup('reports').meaning, 'প্রতিবেদন');
      // Words that merely end in s are not mangled.
      expect(service.lookup('news').meaning, 'সংবাদ');
    });

    test('gloss keeps reading order, drops duplicates and skips Bengali',
        () async {
      final TranslationService service =
          TranslationService(bundle: _StringBundle(_payload));
      await service.load();
      final List<WordMeaning> gloss = service.gloss(
        'সংবাদ প্রতিবেদন: the news report, then poetry and poem again — news.',
      );
      expect(
        gloss.map((WordMeaning w) => w.word).toList(),
        <String>['news', 'report', 'poetry', 'poem'],
      );
      expect(gloss.first.meaning, 'সংবাদ');
    });

    test('tokenise finds Latin words only', () {
      expect(
        TranslationService.tokenise('A poem — কবিতা, 2025, and a report.'),
        <String>['A', 'poem', 'and', 'a', 'report'],
      );
    });
  });
}
