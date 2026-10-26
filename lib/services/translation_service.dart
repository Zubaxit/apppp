import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

/// One looked-up word.
class WordMeaning {
  const WordMeaning({required this.word, required this.meaning});

  final String word;

  /// `null` when the glossary has no entry. The UI must say so rather than
  /// guess: showing an invented meaning would be worse than showing nothing.
  final String? meaning;

  bool get found => meaning != null;
}

/// Offline English → Bengali word lookup.
///
/// Deliberately modest and honest:
///  * it is a word glossary bundled in the app, not a translation engine;
///  * it needs no network, no account and no paid API;
///  * unknown words come back as "not found" instead of being approximated;
///  * the app is fully usable if the glossary asset is missing or unreadable.
class TranslationService {
  TranslationService({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  Map<String, String> _words = const <String, String>{};
  bool _loaded = false;

  static const String assetPath = 'assets/data/bn_glossary.json';

  bool get isLoaded => _loaded;
  bool get isAvailable => _words.isNotEmpty;
  int get size => _words.length;

  /// Loads the glossary once. A failure leaves [isAvailable] false and the UI
  /// shows an unavailable state instead of throwing.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final String raw = await _bundle.loadString(assetPath);
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final Object? words = decoded['words'];
        if (words is Map<String, dynamic>) {
          _words = <String, String>{
            for (final MapEntry<String, dynamic> entry in words.entries)
              entry.key.toLowerCase(): '${entry.value}',
          };
        }
      }
    } catch (_) {
      _words = const <String, String>{};
    }
  }

  /// Looks up a single word, tolerating case and a trailing plural `s`.
  WordMeaning lookup(String input) {
    final String word = normalise(input);
    if (word.isEmpty) return WordMeaning(word: input, meaning: null);
    final String? direct = _words[word];
    if (direct != null) return WordMeaning(word: word, meaning: direct);
    if (word.length > 3 && word.endsWith('ies')) {
      final String? plural = _words['${word.substring(0, word.length - 3)}y'];
      if (plural != null) return WordMeaning(word: word, meaning: plural);
    }
    if (word.length > 3 && word.endsWith('s') && !word.endsWith('ss')) {
      final String? plural = _words[word.substring(0, word.length - 1)];
      if (plural != null) return WordMeaning(word: word, meaning: plural);
    }
    return WordMeaning(word: word, meaning: null);
  }

  /// Word-by-word pass over a phrase. Latin words only: Bengali text, numbers and
  /// punctuation are skipped, and duplicates are removed so the sheet stays
  /// readable.
  List<WordMeaning> gloss(String text) {
    final List<WordMeaning> out = <WordMeaning>[];
    final Set<String> seen = <String>{};
    for (final String token in tokenise(text)) {
      final WordMeaning meaning = lookup(token);
      if (!meaning.found) continue;
      if (seen.add(meaning.word)) out.add(meaning);
    }
    return out;
  }

  /// English words contained in a piece of text, in reading order.
  static List<String> tokenise(String text) {
    final Iterable<Match> matches =
        RegExp(r"[A-Za-z][A-Za-z'\-]*").allMatches(text);
    return matches.map((Match m) => m.group(0)!).toList(growable: false);
  }

  static String normalise(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r"^[^a-z]+|[^a-z]+$"), '')
        .trim();
  }
}
