import 'dart:convert';

import 'package:html/parser.dart' as html_parser;

/// Text helpers shared by the feed pipeline and the UI layer.
class TextUtils {
  const TextUtils._();

  static final RegExp _tagRe = RegExp(r'<[^>]*>');
  static final RegExp _spaceRe = RegExp(r'\s+');
  static final RegExp _nonSearchRe = RegExp(r'[^a-z0-9\u0980-\u09FF]+');

  /// Removes HTML markup and decodes entities.
  ///
  /// Some publisher feeds send badly broken markup, so this is deliberately
  /// forgiving: fall back to a tag-stripping regex if the html parser fails.
  static String stripHtml(String? input) {
    if (input == null) return '';
    final String value = input.trim();
    if (value.isEmpty) return '';
    if (!value.contains('<') && !value.contains('&')) {
      return normalizeSpaces(value);
    }
    String decoded;
    try {
      decoded = html_parser.parseFragment(value).text ?? '';
    } catch (_) {
      decoded = value.replaceAll(_tagRe, ' ');
    }
    if (decoded.trim().isEmpty) {
      decoded = value.replaceAll(_tagRe, ' ');
    }
    return normalizeSpaces(decoded);
  }

  /// Decodes HTML/XML entities without touching markup.
  static String decodeEntities(String input) {
    if (!input.contains('&')) return input;
    try {
      return html_parser.parseFragment(input).text ?? input;
    } catch (_) {
      return input
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&quot;', '"')
          .replaceAll('&nbsp;', ' ')
          .replaceAll('&#39;', "'");
    }
  }

  static String normalizeSpaces(String input) =>
      input.replaceAll(_spaceRe, ' ').trim();

  static String? nullIfBlank(String? value) {
    if (value == null) return null;
    final String trimmed = normalizeSpaces(value);
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Shortens [input] to at most [maxLength] characters on a word boundary.
  static String truncate(String input, int maxLength) {
    final String clean = normalizeSpaces(input);
    if (clean.length <= maxLength) return clean;
    final String cut = clean.substring(0, maxLength);
    final int lastSpace = cut.lastIndexOf(' ');
    final String base =
        lastSpace > maxLength * 0.6 ? cut.substring(0, lastSpace) : cut;
    return '${base.trimRight()}…';
  }

  /// Case-folded, punctuation-free key used for search and de-duplication.
  static String searchNormalize(String input) {
    final String lowered = input.toLowerCase();
    final String asciiDigits = _asciiDigits(lowered);
    return asciiDigits.replaceAll(_nonSearchRe, ' ').trim();
  }

  static String compactKey(String input) =>
      searchNormalize(input).replaceAll(' ', '');

  static String _asciiDigits(String input) {
    const List<String> bn = <String>[
      '০',
      '১',
      '২',
      '৩',
      '৪',
      '৫',
      '৬',
      '৭',
      '৮',
      '৯'
    ];
    var out = input;
    for (var i = 0; i < bn.length; i++) {
      out = out.replaceAll(bn[i], '$i');
    }
    return out;
  }

  /// Very small edit distance used for fuzzy publication search.
  static int editDistance(String a, String b, {int cap = 4}) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    if ((a.length - b.length).abs() > cap) return cap + 1;
    List<int> previous = List<int>.generate(b.length + 1, (int i) => i);
    List<int> current = List<int>.filled(b.length + 1, 0);
    for (var i = 0; i < a.length; i++) {
      current[0] = i + 1;
      var rowMin = current[0];
      for (var j = 0; j < b.length; j++) {
        final int cost = a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1;
        final int insertion = current[j] + 1;
        final int deletion = previous[j + 1] + 1;
        final int substitution = previous[j] + cost;
        int best = insertion < deletion ? insertion : deletion;
        if (substitution < best) best = substitution;
        current[j + 1] = best;
        if (best < rowMin) rowMin = best;
      }
      if (rowMin > cap) return cap + 1;
      final List<int> swap = previous;
      previous = current;
      current = swap;
    }
    return previous[b.length];
  }

  static String prettyJson(Object value) =>
      const JsonEncoder.withIndent('  ').convert(value);
}
