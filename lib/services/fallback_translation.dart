import 'dart:async';

import 'package:google_mlkit_translation/google_mlkit_translation.dart';

import 'machine_translation.dart';

abstract class OnDeviceTranslationEngine {
  Future<bool> modelsReady({String from = 'en', String to = 'bn'});
  Future<void> prepare({String from = 'en', String to = 'bn'});
  Future<String> translate(String text, {String from = 'en', String to = 'bn'});
  Future<void> close();
}

class MlKitOnDeviceTranslationEngine implements OnDeviceTranslationEngine {
  final OnDeviceTranslatorModelManager _models =
      OnDeviceTranslatorModelManager();
  OnDeviceTranslator? _translator;

  static TranslateLanguage _language(String code) => switch (code) {
        'en' => TranslateLanguage.english,
        'bn' => TranslateLanguage.bengali,
        _ => throw TranslationException(
            'On-device translation does not support language “$code”.',
            retryable: false,
            failure: TranslationFailure.modelUnavailable,
          ),
      };

  @override
  Future<bool> modelsReady({String from = 'en', String to = 'bn'}) async {
    final TranslateLanguage source = _language(from);
    final TranslateLanguage target = _language(to);
    return await _models.isModelDownloaded(source.bcpCode) &&
        await _models.isModelDownloaded(target.bcpCode);
  }

  @override
  Future<void> prepare({String from = 'en', String to = 'bn'}) async {
    final TranslateLanguage source = _language(from);
    final TranslateLanguage target = _language(to);
    try {
      if (!await _models.isModelDownloaded(source.bcpCode)) {
        final bool downloaded =
            await _models.downloadModel(source.bcpCode, isWifiRequired: false);
        if (!downloaded) {
          throw StateError('English model download failed');
        }
      }
      if (!await _models.isModelDownloaded(target.bcpCode)) {
        final bool downloaded =
            await _models.downloadModel(target.bcpCode, isWifiRequired: false);
        if (!downloaded) {
          throw StateError('Bengali model download failed');
        }
      }
    } catch (_) {
      throw const TranslationException(
        'Offline English and Bengali models are not installed. Connect to the internet and prepare offline translation in Settings.',
        failure: TranslationFailure.modelUnavailable,
      );
    }
  }

  @override
  Future<String> translate(String text, {String from = 'en', String to = 'bn'}) async {
    if (!await modelsReady(from: from, to: to)) {
      await prepare(from: from, to: to);
    }
    _translator ??= OnDeviceTranslator(
      sourceLanguage: _language(from),
      targetLanguage: _language(to),
    );
    try {
      return (await _translator!.translateText(text)).trim();
    } catch (_) {
      throw const TranslationException(
        'On-device translation could not translate this text.',
      );
    }
  }

  @override
  Future<void> close() async {
    await _translator?.close();
    _translator = null;
  }
}

/// Keeps MyMemory primary and enters the on-device path only for an explicitly
/// identified quota failure. Network, authentication and malformed-response
/// failures are deliberately not reclassified as quota exhaustion.
class FallbackMachineTranslator implements MachineTranslator {
  FallbackMachineTranslator({
    required MachineTranslator primary,
    required OnDeviceTranslationEngine fallback,
  })  : _primary = primary,
        _fallback = fallback;

  final MachineTranslator _primary;
  final OnDeviceTranslationEngine _fallback;
  final Map<String, String> _cache = <String, String>{};
  final Map<String, Future<String>> _inFlight = <String, Future<String>>{};
  bool _usingFallback = false;

  bool get usingFallback => _usingFallback;

  @override
  bool get requiresNetwork => !_usingFallback && _primary.requiresNetwork;

  @override
  String get attribution =>
      _usingFallback ? 'Google ML Kit · on-device' : _primary.attribution;

  @override
  Future<String> translate(String text, {String from = 'en', String to = 'bn'}) {
    final String source = text.trim();
    if (source.isEmpty) {
      return Future<String>.value('');
    }
    final String key = '$from|$to|$source';
    final String? cached = _cache[key];
    if (cached != null) {
      return Future<String>.value(cached);
    }
    return _inFlight.putIfAbsent(key, () async {
      try {
        String translated;
        if (_usingFallback) {
          translated = await _fallback.translate(source, from: from, to: to);
        } else {
          try {
            translated = await _primary.translate(source, from: from, to: to);
          } on TranslationException catch (error) {
            if (!error.quotaExhausted) {
              rethrow;
            }
            _usingFallback = true;
            translated = await _fallback.translate(source, from: from, to: to);
          }
        }
        if (_cache.length >= 300) {
          _cache.remove(_cache.keys.first);
        }
        _cache[key] = translated;
        return translated;
      } finally {
        unawaited(_inFlight.remove(key));
      }
    });
  }

  @override
  Future<List<String>> translateAll(List<String> texts, {String from = 'en', String to = 'bn'}) async {
    final List<String> output = <String>[];
    for (final String text in texts) {
      output.add(await translate(text, from: from, to: to));
    }
    return output;
  }

  Future<void> prepareOffline() => _fallback.prepare();
}
