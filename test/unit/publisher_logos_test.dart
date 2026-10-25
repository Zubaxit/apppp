import 'dart:convert';
import 'dart:io';

import 'package:bangladesh_newspaper_hub/services/publisher_logos.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Serves the real files from disk, so the test reads the same manifest the app
/// ships instead of a copy of it.
class DiskAssetBundle extends CachingAssetBundle {
  DiskAssetBundle(this.root);

  final String root;

  @override
  Future<ByteData> load(String key) async {
    final File file = File('$root/$key');
    if (!file.existsSync()) throw StateError('missing asset: $key');
    final Uint8List bytes = file.readAsBytesSync();
    return ByteData.view(bytes.buffer);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => PublisherLogos.debugSet(const <String, String>{}));

  group('the bundled publisher manifest', () {
    test('loads from the shipped asset and maps ids to real files', () async {
      await PublisherLogos.load(
        bundle: DiskAssetBundle(Directory.current.path),
        forceReload: true,
      );

      expect(PublisherLogos.isLoaded, isTrue);
      expect(PublisherLogos.count, greaterThan(0));
      for (final String id in PublisherLogos.bundledIds) {
        final String? path = PublisherLogos.assetFor(id);
        expect(path, isNotNull);
        expect(File(path!).existsSync(), isTrue, reason: '$id -> $path is missing');
        expect(path, startsWith('assets/publishers/'));
      }
    });

    test('every bundled id exists in the shipped registry', () async {
      final Map<String, dynamic> registry = jsonDecode(
        File('assets/data/sources.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final Set<String> known = <String>{
        for (final Object? source in registry['sources'] as List<dynamic>)
          (source! as Map<String, dynamic>)['id'] as String,
      };

      await PublisherLogos.load(
        bundle: DiskAssetBundle(Directory.current.path),
        forceReload: true,
      );
      expect(PublisherLogos.bundledIds.difference(known), isEmpty);
    });

    test('no two publishers share one file by accident, except the documented pair', () async {
      await PublisherLogos.load(
        bundle: DiskAssetBundle(Directory.current.path),
        forceReload: true,
      );
      final Map<String, List<String>> byFile = <String, List<String>>{};
      for (final String id in PublisherLogos.bundledIds) {
        byFile.putIfAbsent(PublisherLogos.assetFor(id)!, () => <String>[]).add(id);
      }
      final List<List<String>> shared = byFile.values
          .where((List<String> ids) => ids.length > 1)
          .toList(growable: false);
      // The only legitimate shared artwork is the BBC News brand mark, which
      // both BBC services actually use.
      expect(shared.length, lessThanOrEqualTo(1));
      if (shared.isNotEmpty) {
        expect(shared.single.toSet(), <String>{'bbc_bangla', 'bbc_world'});
      }
    });

    test('a missing manifest degrades to no bundled marks instead of throwing', () async {
      await PublisherLogos.load(
        bundle: DiskAssetBundle('/nonexistent'),
        forceReload: true,
      );
      expect(PublisherLogos.isLoaded, isTrue);
      expect(PublisherLogos.count, 0);
      expect(PublisherLogos.assetFor('prothomalo'), isNull);
    });

    test('a publisher with no bundled mark is absent, not mapped to someone else', () async {
      await PublisherLogos.load(
        bundle: DiskAssetBundle(Directory.current.path),
        forceReload: true,
      );
      for (final String id in <String>['daily_star', 'tbs', 'jagonews24', 'sarabangla', 'suprobhat']) {
        expect(PublisherLogos.assetFor(id), isNull,
            reason: '$id must not borrow another publisher\'s artwork');
      }
    });
  });
}
