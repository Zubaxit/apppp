import 'dart:convert';

import 'package:bangladesh_newspaper_hub/core/utils/reader_extract.dart';
import 'package:flutter_test/flutter_test.dart';

String payload({
  bool ok = true,
  List<Map<String, Object>>? blocks,
  String title = 'A headline',
  String? error,
}) {
  return jsonEncode(<String, Object?>{
    'ok': ok,
    if (error != null) 'error': error,
    'url': 'https://www.thedailystar.net/news/x',
    'title': title,
    'byline': 'Staff Correspondent',
    'published': '2026-10-25',
    'site': 'thedailystar.net',
    'blocks': blocks ??
        <Map<String, Object>>[
          <String, Object>{'text': 'First paragraph ' * 12, 'heading': false},
          <String, Object>{'text': 'Second paragraph ' * 12, 'heading': false},
        ],
  });
}

void main() {
  group('reading a page as an article', () {
    test('keeps the English text, the headline and the article metadata', () {
      final ReaderDocument? document = ReaderDocument.parse(payload());
      expect(document, isNotNull);
      expect(document!.title, 'A headline');
      expect(document.byline, 'Staff Correspondent');
      expect(document.published, '2026-10-25');
      expect(document.site, 'thedailystar.net');
      expect(document.blocks.length, 2);
      expect(document.paragraphs.length, 2);
      expect(document.paragraphs.first, startsWith('First paragraph'));
    });

    test('a page the extractor could not read is reported, not faked', () {
      expect(ReaderDocument.parse(payload(ok: false, error: 'no article container')), isNull);
    });

    test('too little text is not an article', () {
      final String thin = payload(blocks: <Map<String, Object>>[
        <String, Object>{'text': 'Short.', 'heading': false},
        <String, Object>{'text': 'Also short.', 'heading': false},
      ]);
      expect(ReaderDocument.parse(thin), isNull);
    });

    test('malformed or empty payloads are rejected instead of throwing', () {
      expect(ReaderDocument.parse(null), isNull);
      expect(ReaderDocument.parse(''), isNull);
      expect(ReaderDocument.parse('not json'), isNull);
      expect(ReaderDocument.parse('[1,2,3]'), isNull);
    });

    test('the double-encoded payload an Android bridge can return still parses', () {
      // evaluateJavascript hands back a JSON string, so the payload may arrive
      // quoted one extra time.
      final String wrapped = jsonEncode(payload());
      expect(ReaderDocument.parse(wrapped), isNotNull);
    });

    test('duplicate blocks collapse and empty ones are dropped', () {
      final String body = 'Some long sentence that is repeated. ' * 5;
      final String json = payload(blocks: <Map<String, Object>>[
        <String, Object>{'text': body, 'heading': false},
        <String, Object>{'text': body, 'heading': false},
        <String, Object>{'text': '   ', 'heading': false},
        <String, Object>{'text': 'Another paragraph ' * 12, 'heading': false},
      ]);
      final ReaderDocument? document = ReaderDocument.parse(json);
      expect(document!.blocks.length, 2);
    });

    test('sub-headings are kept as headings and excluded from the prose', () {
      final String json = payload(blocks: <Map<String, Object>>[
        <String, Object>{'text': 'Opening paragraph ' * 15, 'heading': false},
        <String, Object>{'text': 'A section title', 'heading': true},
        <String, Object>{'text': 'Closing paragraph ' * 15, 'heading': false},
      ]);
      final ReaderDocument document = ReaderDocument.parse(json)!;
      expect(document.blocks[1].heading, isTrue);
      expect(document.paragraphs.length, 2);
      expect(document.paragraphs, isNot(contains('A section title')));
    });

    test('whitespace is normalised so translation requests stay stable', () {
      final String json = payload(blocks: <Map<String, Object>>[
        <String, Object>{'text': 'Line one\n\n  line   two\t\t' * 8, 'heading': false},
        <String, Object>{'text': 'Second paragraph ' * 12, 'heading': false},
      ]);
      final ReaderDocument document = ReaderDocument.parse(json)!;
      expect(document.blocks.first.text, isNot(contains('\n')));
      expect(document.blocks.first.text, isNot(contains('  ')));
    });

    test('character count reflects the extracted prose', () {
      final ReaderDocument document = ReaderDocument.parse(payload())!;
      expect(document.characterCount, greaterThan(200));
    });
  });
}
