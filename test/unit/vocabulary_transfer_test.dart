import 'package:bangladesh_newspaper_hub/data/models/vocabulary_entry.dart';
import 'package:bangladesh_newspaper_hub/services/vocabulary_transfer.dart';
import 'package:flutter_test/flutter_test.dart';

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
