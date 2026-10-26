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
