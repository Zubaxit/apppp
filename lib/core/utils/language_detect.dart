/// Which language a block of text is written in, as far as the app needs to
/// know it: is this Bengali, or is it something else that could usefully be
/// translated into Bengali?
///
/// The app deliberately does *not* guess from the publisher or the URL. A
/// Bengali paper publishes English pieces, and an English paper publishes
/// Bengali ones, so the decision is made from the text the reader is looking at.
enum TextLanguage {
  /// Overwhelmingly Bengali script — nothing to translate.
  bengali,

  /// Bengali is present but a large share of the text is in another script.
  /// Mixed pages are offered translation, but never started automatically.
  mixed,

  /// Bengali script is absent (or negligible) and there is enough text to be
  /// sure of it.
  nonBengali,

  /// Not enough text to decide. Treated as "do not offer translation", because
  /// offering a Bengali → Bengali translation is worse than offering nothing.
  unknown,
}

/// Script-based language detection for the reader.
///
/// Counting characters in the Bengali block (U+0980–U+09FF) against Latin
/// letters is deterministic, needs no model, costs one pass over the text and
/// cannot send anything anywhere. It is not a general-purpose language
/// identifier: it answers exactly one question, "is this already Bengali?".
class LanguageDetect {
  const LanguageDetect._();

  /// Below this many letters the answer is [TextLanguage.unknown]: a headline
  /// such as "Dhaka" or "নির্বাচন" is not evidence for a whole article.
  static const int minimumLetters = 60;

  /// Share of Bengali characters at or above which the text is Bengali.
  static const double bengaliShare = 0.55;

  /// Share of Bengali characters under which the text is treated as entirely
  /// non-Bengali.
  static const double mixedFloor = 0.05;

  static bool _isBengali(int rune) =>
      rune >= 0x0980 && rune <= 0x09FF;

  static bool _isLatin(int rune) =>
      (rune >= 0x41 && rune <= 0x5A) || (rune >= 0x61 && rune <= 0x7A);

  /// Classifies [text] by counting letters.
  static TextLanguage detect(String? text) {
    if (text == null || text.isEmpty) return TextLanguage.unknown;
    var bengali = 0;
    var latin = 0;
    for (final int rune in text.runes) {
      if (_isBengali(rune)) {
        bengali += 1;
      } else if (_isLatin(rune)) {
        latin += 1;
      }
    }
    final int letters = bengali + latin;
    if (letters < minimumLetters) return TextLanguage.unknown;
    final double share = bengali / letters;
    if (share >= bengaliShare) return TextLanguage.bengali;
    if (share < mixedFloor) return TextLanguage.nonBengali;
    return TextLanguage.mixed;
  }

  /// Convenience for the reader: the article body is the evidence, not the
  /// headline. Falls back to the headline when the body is unusable.
  static TextLanguage ofArticle({String? body, String? title}) {
    final TextLanguage fromBody = detect(body);
    if (fromBody != TextLanguage.unknown) return fromBody;
    return detect(title);
  }

  /// True when offering Bengali translation makes sense.
  ///
  /// [TextLanguage.unknown] is deliberately excluded: with too little text the
  /// conservative answer is to stay silent rather than to mislabel an article.
  static bool offersTranslation(TextLanguage language) =>
      language == TextLanguage.nonBengali || language == TextLanguage.mixed;

  /// The source language to send to the translation service.
  static String translationSource(TextLanguage language) =>
      language == TextLanguage.bengali ? 'bn' : 'en';
}
