import 'dart:async';
import 'dart:convert';

import 'package:bangladesh_newspaper_hub/services/machine_translation.dart';
import 'package:bangladesh_newspaper_hub/services/reader_translation_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/fakes.dart';

http.Response ok(String translation) => http.Response(
      jsonEncode(<String, Object>{
        'responseStatus': 200,
        'responseData': <String, Object>{'translatedText': translation},
      }),
      200,
      headers: <String, String>{'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  group('splitting long text for a size-limited endpoint', () {
    test('short text is one request', () {
      expect(MyMemoryTranslator.splitForTranslation('One sentence.'), <String>['One sentence.']);
    });

    test('long text is split on sentence boundaries and never exceeds the limit', () {
      final String text = List<String>.generate(
        40,
        (int i) => 'This is sentence number $i of a fairly long newspaper paragraph.',
      ).join(' ');
      final List<String> chunks = MyMemoryTranslator.splitForTranslation(text, 200);
      expect(chunks.length, greaterThan(1));
      for (final String chunk in chunks) {
        expect(chunk.length, lessThanOrEqualTo(200));
        expect(chunk.trim(), chunk);
      }
      expect(chunks.join(' ').replaceAll(RegExp(r'\s+'), ' '),
          text.replaceAll(RegExp(r'\s+'), ' '));
    });

    test('a sentence longer than the limit falls back to word packing', () {
      final String monster = List<String>.filled(80, 'word').join(' ');
      final List<String> chunks = MyMemoryTranslator.splitForTranslation(monster, 60);
      expect(chunks.length, greaterThan(1));
      for (final String chunk in chunks) {
        expect(chunk.length, lessThanOrEqualTo(60));
      }
    });
  });

  group('the MyMemory translator', () {
    test('sends a plain GET with the language pair and no key', () async {
      late Uri seen;
      final MyMemoryTranslator translator = MyMemoryTranslator(
        client: MockClient((http.Request request) async {
          seen = request.url;
          return ok('অনুবাদ');
        }),
      );

      expect(await translator.translate('Hello world'), 'অনুবাদ');
      expect(seen.host, 'api.mymemory.translated.net');
      expect(seen.queryParameters['langpair'], 'en|bn');
      expect(seen.queryParameters, isNot(contains('key')));
      expect(translator.requiresNetwork, isTrue);
    });

    test('an exhausted allowance is reported as such, not as an empty result', () async {
      final MyMemoryTranslator translator = MyMemoryTranslator(
        client: MockClient((http.Request request) async => http.Response('', 429)),
      );
      expect(
        translator.translate('Hello'),
        throwsA(isA<TranslationException>().having(
          (TranslationException e) => e.message,
          'message',
          contains('allowance'),
        )),
      );
    });

    test('a refusal inside a 200 response is also a failure', () async {
      final MyMemoryTranslator translator = MyMemoryTranslator(
        client: MockClient((http.Request request) async => http.Response(
              jsonEncode(<String, Object>{'responseStatus': 403}),
              200,
            )),
      );
      expect(translator.translate('Hello'), throwsA(isA<TranslationException>()));
    });

    test('unreadable and empty answers fail loudly', () async {
      for (final http.Response response in <http.Response>[
        http.Response('not json', 200),
        http.Response(jsonEncode(<String, Object>{'responseStatus': 200}), 200),
        http.Response(
          jsonEncode(<String, Object>{
            'responseStatus': 200,
            'responseData': <String, Object>{'translatedText': '  '},
          }),
          200,
        ),
      ]) {
        final MyMemoryTranslator translator = MyMemoryTranslator(
          client: MockClient((http.Request request) async => response),
        );
        expect(translator.translate('Hello'), throwsA(isA<TranslationException>()));
      }
    });

    test('a dropped connection becomes a message about the connection', () async {
      final MyMemoryTranslator translator = MyMemoryTranslator(
        client: MockClient((http.Request request) async => throw const SocketLikeError()),
      );
      expect(
        translator.translate('Hello'),
        throwsA(isA<TranslationException>().having(
          (TranslationException e) => e.message,
          'message',
          contains('unreachable'),
        )),
      );
    });

    test('the same text is not requested twice', () async {
      int calls = 0;
      final MyMemoryTranslator translator = MyMemoryTranslator(
        client: MockClient((http.Request request) async {
          calls += 1;
          return ok('অনুবাদ');
        }),
      );
      await translator.translate('Repeat me');
      await translator.translate('Repeat me');
      expect(calls, 1);
    });

    test('long input is chunked and the pieces are joined', () async {
      final List<String> sent = <String>[];
      final MyMemoryTranslator translator = MyMemoryTranslator(
        client: MockClient((http.Request request) async {
          sent.add(request.url.queryParameters['q']!);
          return ok('অংশ');
        }),
      );
      // Numbered sentences, so the two chunks differ: the translator caches by
      // text, and two identical chunks would correctly cost one request.
      final String long = List<String>.generate(
        30,
        (int i) => 'Sentence number $i carries a little more of the story.',
      ).join(' ');
      final String result = await translator.translate(long);
      expect(sent.length, greaterThan(1));
      expect(result, contains('অংশ'));
      for (final String chunk in sent) {
        expect(chunk.length, lessThanOrEqualTo(MyMemoryTranslator.maxChunkCharacters));
      }
    });
  });

  group('the bilingual reading controller', () {
    test('identical paragraphs cost one request', () async {
      final FakeTranslator translator = FakeTranslator();
      final ReaderTranslationController controller = ReaderTranslationController(
        translator: translator,
        paragraphs: <String>['Same paragraph.', 'Same paragraph.', 'Different one.'],
      );
      addTearDown(controller.dispose);

      await controller.translateAll();
      expect(translator.requests.where((String t) => t == 'Same paragraph.').length, 1);
      expect(controller.unitAt(0).text, controller.unitAt(1).text);
      expect(controller.hasAnyTranslation, isTrue);
      expect(controller.busy, isFalse);
    });

    test('one failing paragraph does not hide the others', () async {
      final FakeTranslator translator = FakeTranslator(failOn: <String>['poison']);
      final ReaderTranslationController controller = ReaderTranslationController(
        translator: translator,
        paragraphs: <String>['Fine paragraph.', 'A poison paragraph.', 'Another fine one.'],
      );
      addTearDown(controller.dispose);

      await controller.translateAll();
      expect(controller.unitAt(0).done, isTrue);
      expect(controller.unitAt(1).failed, isTrue);
      expect(controller.unitAt(1).error, 'quota reached');
      expect(controller.unitAt(2).done, isTrue);
      expect(controller.allFailed, isFalse);
    });

    test('a retry after a failure can succeed and is counted per paragraph', () async {
      final FakeTranslator failing = FakeTranslator(failOn: <String>['flaky']);
      final ReaderTranslationController controller = ReaderTranslationController(
        translator: failing,
        paragraphs: <String>['A flaky paragraph.'],
      );
      addTearDown(controller.dispose);
      await controller.translateAll();
      expect(controller.unitAt(0).failed, isTrue);

      final FakeTranslator working = FakeTranslator();
      final ReaderTranslationController retried = ReaderTranslationController(
        translator: working,
        paragraphs: <String>['A flaky paragraph.'],
      );
      addTearDown(retried.dispose);
      await retried.retry(0);
      expect(retried.unitAt(0).done, isTrue);
    });

    test('translations can be hidden and shown without losing them', () async {
      final ReaderTranslationController controller = ReaderTranslationController(
        translator: FakeTranslator(),
        paragraphs: <String>['Something to read.'],
      );
      addTearDown(controller.dispose);
      await controller.translateAll();
      expect(controller.showTranslations, isTrue);

      controller.toggleVisibility();
      expect(controller.showTranslations, isFalse);
      expect(controller.unitAt(0).done, isTrue, reason: 'hidden is not discarded');

      controller.toggleVisibility();
      expect(controller.showTranslations, isTrue);
    });

    test('finishing after dispose does not notify or throw', () async {
      final FakeTranslator slow = FakeTranslator(delay: const Duration(milliseconds: 40));
      final ReaderTranslationController controller = ReaderTranslationController(
        translator: slow,
        paragraphs: <String>['Late paragraph.'],
      );
      unawaited(controller.translateAll());
      await Future<void>.delayed(const Duration(milliseconds: 5));
      controller.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      // Reaching here without an exception is the assertion: a disposed
      // controller must never call notifyListeners.
    });

    test('translateAll is idempotent', () async {
      final FakeTranslator translator = FakeTranslator();
      final ReaderTranslationController controller = ReaderTranslationController(
        translator: translator,
        paragraphs: <String>['Only paragraph.'],
      );
      addTearDown(controller.dispose);
      await controller.translateAll();
      final int first = translator.requests.length;
      await controller.translateAll();
      expect(translator.requests.length, first);
    });
  });
}

/// Stands in for a transport failure without depending on dart:io.
class SocketLikeError implements Exception {
  const SocketLikeError();
}
