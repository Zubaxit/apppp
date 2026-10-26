/// A reader-confirmed English vocabulary item stored only on this device.
class VocabularyEntry {
  const VocabularyEntry({
    required this.word,
    required this.meaningBn,
    required this.savedAt,
    this.definitionEn,
    this.partOfSpeech,
    this.articleTitle,
    this.articleUrl,
    this.sourceName,
  });

  final String word;
  final String meaningBn;
  final String? definitionEn;
  final String? partOfSpeech;
  final String? articleTitle;
  final String? articleUrl;
  final String? sourceName;
  final DateTime savedAt;

  String get normalizedWord => normalizeWord(word);

  VocabularyEntry copyWith({
    String? word,
    String? meaningBn,
    String? definitionEn,
    String? partOfSpeech,
    String? articleTitle,
    String? articleUrl,
    String? sourceName,
    DateTime? savedAt,
  }) {
    return VocabularyEntry(
      word: word ?? this.word,
      meaningBn: meaningBn ?? this.meaningBn,
      definitionEn: definitionEn ?? this.definitionEn,
      partOfSpeech: partOfSpeech ?? this.partOfSpeech,
      articleTitle: articleTitle ?? this.articleTitle,
      articleUrl: articleUrl ?? this.articleUrl,
      sourceName: sourceName ?? this.sourceName,
      savedAt: savedAt ?? this.savedAt,
    );
  }

  static String normalizeWord(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r"^[^a-z]+|[^a-z]+$"), '');
}
