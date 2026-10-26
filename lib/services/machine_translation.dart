import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// A translation that could not be produced, with a reason the UI can show.
enum TranslationFailure { quotaExhausted, modelUnavailable, network, other }

class TranslationException implements Exception {
  const TranslationException(
    this.message, {
    this.retryable = true,
    this.failure = TranslationFailure.other,
  });

  final String message;
  final bool retryable;
  final TranslationFailure failure;

  bool get quotaExhausted =>
      failure == TranslationFailure.quotaExhausted ||
      message == 'The free translation allowance for today is used up.';

  @override
  String toString() => 'TranslationException: $message';
}

/// The contract the reading experience depends on.
///
/// The app talks to this interface, not to a provider, so the engine can be
/// replaced (or faked in tests) without touching a single screen.
abstract class MachineTranslator {
  /// Whether a translation needs a network connection. Read by the UI so the
  /// offline state can be stated instead of discovered through a failed request.
  bool get requiresNetwork;

  /// The provider's name, shown to the user. Machine output must be attributed
  /// and must never be presented as an official or human translation.
  String get attribution;

  /// Translates a short piece of text (a word, a phrase, a sentence).
  Future<String> translate(String text, {String from = 'en', String to = 'bn'});

  /// Translates several paragraphs. Implementations are expected to coalesce
  /// duplicates and to keep the order of [texts].
  Future<List<String>> translateAll(List<String> texts,
      {String from = 'en', String to = 'bn'});
}

/// Machine translation through MyMemory, the free translation memory service.
///
/// Why this one:
///  * no API key, so nothing secret can leak into the APK;
///  * no API charge at the anonymous allowance; there is no guarantee that the
///    public service, quota or terms stay available; larger commercial volumes
///    are offered separately by the provider;
///  * no dependency beyond `http`, which the app already ships;
///  * it accepts plain text, so no HTML or script is ever sent anywhere.
///
/// Its documented limits are real and are surfaced in the UI, not hidden:
///  * **internet is required** — there is no on-device model, so this is not
///    offered as an offline feature (the bundled glossary remains the offline
///    word lookup and is labelled as such);
///  * the anonymous tier has a small daily allowance and rejects a single
///    request above roughly 500 bytes of text, so text is split at sentence
///    boundaries and requests are throttled;
///  * output is statistical machine translation: it can be wrong, and it is
///    always labelled as machine output with the provider's name.
///
/// If the allowance or the service is unavailable the failure is reported as
/// such and the English original stays on screen untouched.
class MyMemoryTranslator implements MachineTranslator {
  MyMemoryTranslator({http.Client? client, Uri? endpoint})
      : _client = client ?? http.Client(),
        _endpoint =
            endpoint ?? Uri.parse('https://api.mymemory.translated.net/get');

  final http.Client _client;
  final Uri _endpoint;

  /// MyMemory documents a hard 500-*byte* `q` limit. Keeping a 420-character
  /// packing target leaves URL/service headroom for ordinary Latin text; the
  /// splitter also verifies UTF-8 bytes, so non-ASCII input never exceeds 480.
  static const int maxChunkCharacters = 420;
  static const int maxChunkBytes = 480;

  /// Requests are serialised with a small in-memory cache, because the free tier
  /// rewards fewer calls and duplicate paragraphs are common in feeds.
  static const int _cacheEntries = 200;

  final Map<String, String> _cache = <String, String>{};

  @override
  bool get requiresNetwork => true;

  @override
  String get attribution => 'MyMemory';

  @override
  Future<String> translate(String text,
      {String from = 'en', String to = 'bn'}) async {
    final String input = text.trim();
    if (input.isEmpty) return '';
    if (input.length <= maxChunkCharacters &&
        utf8.encode(input).length <= maxChunkBytes) {
      return _translateChunk(input, from: from, to: to);
    }
    final List<String> pieces = splitForTranslation(input, maxChunkCharacters);
    final List<String> translated = <String>[];
    for (final String piece in pieces) {
      translated.add(await _translateChunk(piece, from: from, to: to));
    }
    return translated.join(' ');
  }

  @override
  Future<List<String>> translateAll(
    List<String> texts, {
    String from = 'en',
    String to = 'bn',
  }) async {
    final List<String> out = List<String>.filled(texts.length, '');
    final Map<String, List<int>> byText = <String, List<int>>{};
    for (int i = 0; i < texts.length; i++) {
      final String key = texts[i].trim();
      if (key.isEmpty) continue;
      byText.putIfAbsent(key, () => <int>[]).add(i);
    }
    // Two at a time: enough to keep the reading screen filling in, gentle enough
    // for a free endpoint that rate-limits bursts.
    const int concurrency = 2;
    final List<MapEntry<String, List<int>>> entries =
        byText.entries.toList(growable: false);
    int cursor = 0;

    Future<void> worker() async {
      while (cursor < entries.length) {
        final MapEntry<String, List<int>> entry = entries[cursor++];
        final String result = await translate(entry.key, from: from, to: to);
        for (final int index in entry.value) {
          out[index] = result;
        }
      }
    }

    await Future.wait<void>(<Future<void>>[
      for (int i = 0; i < concurrency; i++) worker(),
    ]);
    return out;
  }

  Future<String> _translateChunk(String text,
      {required String from, required String to}) async {
    final String key = '${from}_${to}_${text.toLowerCase()}';
    final String? cached = _cache[key];
    if (cached != null) return cached;

    final Uri url = _endpoint.replace(queryParameters: <String, String>{
      'q': text,
      'langpair': '$from|$to',
    });

    http.Response response;
    try {
      response = await _client.get(url, headers: <String, String>{
        'Accept': 'application/json'
      }).timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const TranslationException(
        'The translation service did not answer in time.',
      );
    } catch (error) {
      throw const TranslationException(
        'The translation service is unreachable. Check the connection.',
        failure: TranslationFailure.network,
      );
    }

    if (response.statusCode != 200) {
      final bool quota =
          response.statusCode == 429 || response.statusCode == 403;
      throw TranslationException(
        quota
            ? 'The free translation allowance for today is used up.'
            : 'The translation service answered ${response.statusCode}.',
        retryable: response.statusCode >= 500,
        failure: quota
            ? TranslationFailure.quotaExhausted
            : TranslationFailure.other,
      );
    }

    final Object? decoded = _decode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const TranslationException(
          'The translation service sent an unreadable answer.');
    }
    final Object? status = decoded['responseStatus'];
    if (status is num && status >= 400) {
      final bool quota = status == 403 || status == 429;
      throw TranslationException(
        quota
            ? 'The free translation allowance for today is used up.'
            : 'The translation service refused this text (${status.toInt()}).',
        retryable: false,
        failure: quota
            ? TranslationFailure.quotaExhausted
            : TranslationFailure.other,
      );
    }
    final Object? data = decoded['responseData'];
    if (data is! Map<String, dynamic>) {
      throw const TranslationException(
          'The translation service sent no translation.');
    }
    final String translated = '${data['translatedText'] ?? ''}'.trim();
    if (translated.isEmpty) {
      throw const TranslationException(
          'The translation service sent an empty translation.');
    }

    if (_cache.length >= _cacheEntries) _cache.remove(_cache.keys.first);
    _cache[key] = translated;
    return translated;
  }

  static Object? _decode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  /// Splits text at sentence, then word, boundaries so no request exceeds
  /// [limit]. Exposed because the split is behaviour worth testing on its own.
  static List<String> splitForTranslation(
    String text, [
    int limit = maxChunkCharacters,
  ]) {
    final String source = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (_fits(source, limit)) return <String>[source];

    final List<String> chunks = <String>[];
    String current = '';

    void addWord(String word) {
      if (word.isEmpty) return;
      final String candidate = current.isEmpty ? word : '$current $word';
      if (_fits(candidate, limit)) {
        current = candidate;
        return;
      }
      if (current.isNotEmpty) {
        chunks.add(current);
        current = '';
      }
      // One token can itself exceed 480 bytes (for example a long URL). Pack
      // runes, never UTF-16 code units, so a surrogate pair is not split.
      String runeChunk = '';
      for (final int rune in word.runes) {
        final String next = '$runeChunk${String.fromCharCode(rune)}';
        if (!_fits(next, limit) && runeChunk.isNotEmpty) {
          chunks.add(runeChunk);
          runeChunk = String.fromCharCode(rune);
        } else {
          runeChunk = next;
        }
      }
      current = runeChunk;
    }

    final List<String> sentences = source
        .split(RegExp(r'(?<=[.!?।])\s+'))
        .where((String value) => value.isNotEmpty)
        .toList(growable: false);
    for (final String sentence in sentences) {
      final String candidate =
          current.isEmpty ? sentence : '$current $sentence';
      if (_fits(candidate, limit)) {
        current = candidate;
        continue;
      }
      if (current.isNotEmpty) {
        chunks.add(current);
        current = '';
      }
      if (_fits(sentence, limit)) {
        current = sentence;
      } else {
        for (final String word in sentence.split(' ')) {
          addWord(word);
        }
      }
    }
    if (current.isNotEmpty) chunks.add(current);
    return chunks;
  }

  static bool _fits(String value, int characterLimit) =>
      value.length <= characterLimit &&
      utf8.encode(value).length <= maxChunkBytes;
}
