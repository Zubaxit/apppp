import '../data/models/vocabulary_entry.dart';

class VocabularyMatch {
  const VocabularyMatch({
    required this.start,
    required this.end,
    required this.entry,
  });

  final int start;
  final int end;
  final VocabularyEntry entry;
}

/// Whole-word vocabulary matching with a small, defensible English inflection
/// set. It never stems arbitrary article text and never performs substring
/// matching (so `president` cannot match `presidential`).
class VocabularyMatcher {
  VocabularyMatcher(Iterable<VocabularyEntry> entries) {
    for (final VocabularyEntry entry in entries) {
      final String base = entry.normalizedWord;
      if (base.isEmpty) {
        continue;
      }
      _exact[base] = entry;
      for (final String form in formsFor(base)) {
        _forms.putIfAbsent(form, () => entry);
      }
    }
  }

  final Map<String, VocabularyEntry> _exact = <String, VocabularyEntry>{};
  final Map<String, VocabularyEntry> _forms = <String, VocabularyEntry>{};

  List<VocabularyMatch> find(String text) {
    if (_exact.isEmpty || text.isEmpty) {
      return const <VocabularyMatch>[];
    }
    final List<VocabularyMatch> matches = <VocabularyMatch>[];
    for (final RegExpMatch token
        in RegExp(r"[A-Za-z]+(?:['’][A-Za-z]+)?").allMatches(text)) {
      final String normalized = token.group(0)!.toLowerCase();
      final VocabularyEntry? entry = _exact[normalized] ?? _forms[normalized];
      if (entry == null) {
        continue;
      }
      matches.add(
          VocabularyMatch(start: token.start, end: token.end, entry: entry));
    }
    return matches;
  }

  static Set<String> formsFor(String value) {
    final String word = VocabularyEntry.normalizeWord(value);
    if (word.length < 4) {
      return <String>{word};
    }
    final Set<String> forms = <String>{word};
    if (word.endsWith('e')) {
      forms
        ..add('${word}d')
        ..add('${word.substring(0, word.length - 1)}ing');
    } else {
      forms
        ..add('${word}ed')
        ..add('${word}ing');
    }
    if (word.endsWith('y') &&
        word.length > 4 &&
        !'aeiou'.contains(word[word.length - 2])) {
      forms.add('${word.substring(0, word.length - 1)}ies');
    } else if (word.endsWith('s') ||
        word.endsWith('x') ||
        word.endsWith('z') ||
        word.endsWith('ch') ||
        word.endsWith('sh')) {
      forms.add('${word}es');
    } else {
      forms.add('${word}s');
    }
    return forms;
  }
}
