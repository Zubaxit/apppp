import 'dart:convert';
import 'dart:typed_data';

import 'package:bangladesh_newspaper_hub/data/models/vocabulary_entry.dart';
import 'package:bangladesh_newspaper_hub/services/vocabulary_transfer.dart';
import 'package:flutter_test/flutter_test.dart';

class _Writer implements VocabularyDocumentWriter {
  _Writer({this.result = true, this.error});
  final bool result;
  final Object? error;
  String? contents;

  @override
  Future<bool> write({
    required String suggestedName,
    required String contents,
  }) async {
    if (error != null) throw error!;
    this.contents = contents;
    return result;
  }
}

String uniqueWord(int index) {
  int value = index;
  final StringBuffer suffix = StringBuffer();
  do {
    suffix.writeCharCode(97 + value % 26);
    value = value ~/ 26;
  } while (value > 0);
  return 'term${suffix.toString()}';
}

VocabularyEntry entry(String word, String meaning) => VocabularyEntry(
      word: word,
      meaningBn: meaning,
      definitionEn: 'definition',
      partOfSpeech: 'noun',
      articleTitle: 'Article',
      articleUrl: 'https://example.com/article',
      sourceName: 'Example',
      savedAt: DateTime.utc(2026, 10, 26),
    );

void main() {
  test('versioned vocabulary JSON round trips all metadata', () {
    final List<VocabularyEntry> decoded = VocabularyTransferCodec.decode(
      VocabularyTransferCodec.encode(<VocabularyEntry>[
        entry('Policy', 'নীতি'),
      ]),
    );
    expect(decoded, hasLength(1));
    expect(decoded.single.word, 'Policy');
    expect(decoded.single.meaningBn, 'নীতি');
    expect(decoded.single.partOfSpeech, 'noun');
    expect(decoded.single.articleUrl, 'https://example.com/article');
    expect(decoded.single.savedAt, DateTime.utc(2026, 10, 26));
  });

  test('strict UTF-8 preserves Bengali conjuncts, signs, punctuation and mixed text',
      () {
    const List<String> meanings = <String>[
      'প্রতিবন্ধকতা',
      'রাষ্ট্রের আইনসভা—সংসদ; যুক্তাক্ষর: ক্ষ, জ্ঞ, ত্র',
      'Legislature অর্থ আইনসভা। ১২৩টি ধারা',
    ];
    final String json = VocabularyTransferCodec.encode(<VocabularyEntry>[
      for (int i = 0; i < meanings.length; i++) entry(uniqueWord(i), meanings[i]),
    ]);
    final List<VocabularyEntry> decoded = VocabularyTransferCodec.decodeBytes(
      Uint8List.fromList(<int>[0xEF, 0xBB, 0xBF, ...utf8.encode(json)]),
    );
    expect(
      decoded.map((VocabularyEntry value) => value.meaningBn).toList(),
      meanings,
    );
  });

  test('large UTF-8 vocabulary round trips without character replacement', () {
    final List<VocabularyEntry> original = <VocabularyEntry>[
      for (int i = 0; i < 1500; i++)
        entry(uniqueWord(i), 'অর্থ $i — বাংলাদেশের যুক্তাক্ষর ও কার-ফলা'),
    ];
    final List<VocabularyEntry> decoded = VocabularyTransferCodec.decodeBytes(
      Uint8List.fromList(
        utf8.encode(VocabularyTransferCodec.encode(original)),
      ),
    );
    expect(decoded, hasLength(original.length));
    expect(decoded[1499].meaningBn, original[1499].meaningBn);
  });

  test('invalid UTF-8 and known Bengali mojibake are rejected', () {
    expect(
      () => VocabularyTransferCodec.decodeBytes(
        Uint8List.fromList(<int>[0x7B, 0xFF, 0x7D]),
      ),
      throwsA(isA<VocabularyTransferException>()),
    );
    final String damaged = VocabularyTransferCodec.encode(
      <VocabularyEntry>[entry('obstacle', 'à¦ªà§\x8dà¦°à¦¤à¦¿à¦¬à¦¨à§\x8dà¦§à¦\x95à¦¤à¦¾')],
    );
    expect(
      () => VocabularyTransferCodec.decode(damaged),
      throwsA(isA<VocabularyTransferException>()),
    );
  });

  test('case-insensitive duplicates are collapsed safely', () {
    final String payload = VocabularyTransferCodec.encode(<VocabularyEntry>[
      entry('Policy', 'নীতি'),
      entry('policy', 'নীতিমালা'),
    ]);
    final List<VocabularyEntry> decoded =
        VocabularyTransferCodec.decode(payload);
    expect(decoded, hasLength(1));
    expect(decoded.single.meaningBn, 'নীতিমালা');
  });

  test('export writes a portable document that imports as a round trip',
      () async {
    final _Writer writer = _Writer();
    expect(
      await VocabularyFileTransfer.export(
        <VocabularyEntry>[entry('Policy', 'নীতি')],
        writer: writer,
      ),
      isTrue,
    );
    final List<VocabularyEntry> restored =
        VocabularyTransferCodec.decode(writer.contents!);
    expect(restored.single.meaningBn, 'নীতি');
  });

  test('empty export is explicit valid JSON and remains importable', () async {
    final _Writer writer = _Writer();
    expect(
      await VocabularyFileTransfer.export(<VocabularyEntry>[], writer: writer),
      isTrue,
    );
    expect(VocabularyTransferCodec.decode(writer.contents!), isEmpty);
  });

  test('document-picker cancellation is not reported as success', () async {
    final _Writer writer = _Writer(result: false);
    expect(
      await VocabularyFileTransfer.export(
        <VocabularyEntry>[entry('Policy', 'নীতি')],
        writer: writer,
      ),
      isFalse,
    );
  });

  test('document write failures are surfaced without changing data', () async {
    final _Writer writer = _Writer(
      error: const VocabularyTransferException('storage full'),
    );
    await expectLater(
      VocabularyFileTransfer.export(
        <VocabularyEntry>[entry('Policy', 'নীতি')],
        writer: writer,
      ),
      throwsA(isA<VocabularyTransferException>()),
    );
  });

  test('malformed, unsupported and incomplete files are rejected', () {
    for (final String payload in <String>[
      'not json',
      '{"format":"other","version":1,"entries":[]}',
      '{"format":"amar-news-vocabulary","version":99,"entries":[]}',
      '{"format":"amar-news-vocabulary","version":1,"entries":[{"word":"x"}]}',
    ]) {
      expect(
        () => VocabularyTransferCodec.decode(payload),
        throwsA(isA<VocabularyTransferException>()),
      );
    }
  });
}
