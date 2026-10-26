import 'package:bangladesh_newspaper_hub/services/fallback_translation.dart';
import 'package:bangladesh_newspaper_hub/services/machine_translation.dart';
import 'package:flutter_test/flutter_test.dart';

class _Primary implements MachineTranslator {
  _Primary({this.error});
  final TranslationException? error;
  int calls = 0;
  @override
  String get attribution => 'Primary';
  @override
  bool get requiresNetwork => true;
  @override
  Future<String> translate(String text,
      {String from = 'en', String to = 'bn'}) async {
    calls++;
    if (error != null) {
      throw error!;
    }
    return 'primary';
  }

  @override
  Future<List<String>> translateAll(List<String> texts,
          {String from = 'en', String to = 'bn'}) =>
      Future.wait(
          texts.map((String text) => translate(text, from: from, to: to)));
}

class _Device implements OnDeviceTranslationEngine {
  _Device({this.ready = true, this.failPrepare = false});
  bool ready;
  final bool failPrepare;
  int calls = 0;
  int prepares = 0;
  @override
  Future<bool> modelsReady({String from = 'en', String to = 'bn'}) async =>
      ready;
  @override
  Future<void> prepare({String from = 'en', String to = 'bn'}) async {
    prepares++;
    if (failPrepare) {
      throw const TranslationException(
        'models unavailable',
        failure: TranslationFailure.modelUnavailable,
      );
    }
    ready = true;
  }

  @override
  Future<String> translate(String text,
      {String from = 'en', String to = 'bn'}) async {
    calls++;
    if (!ready) {
      await prepare(from: from, to: to);
    }
    return 'বাংলা:$text';
  }

  @override
  Future<void> close() async {}
}

void main() {
  test('successful primary translation remains primary', () async {
    final _Primary primary = _Primary();
    final _Device device = _Device();
    final FallbackMachineTranslator translator = FallbackMachineTranslator(
      primary: primary,
      fallback: device,
    );
    expect(await translator.translate('hello'), 'primary');
    expect(primary.calls, 1);
    expect(device.calls, 0);
  });

  test('recognized quota exhaustion automatically uses ML Kit path', () async {
    final _Primary primary = _Primary(
      error: const TranslationException(
        'The free translation allowance for today is used up.',
        failure: TranslationFailure.quotaExhausted,
      ),
    );
    final _Device device = _Device();
    final FallbackMachineTranslator translator = FallbackMachineTranslator(
      primary: primary,
      fallback: device,
    );
    expect(await translator.translate('hello'), 'বাংলা:hello');
    expect(translator.usingFallback, isTrue);
    expect(device.calls, 1);
  });

  test('unrelated network failure does not trigger fallback', () async {
    final _Device device = _Device();
    final FallbackMachineTranslator translator = FallbackMachineTranslator(
      primary: _Primary(
        error: const TranslationException(
          'offline',
          failure: TranslationFailure.network,
        ),
      ),
      fallback: device,
    );
    await expectLater(
        translator.translate('hello'), throwsA(isA<TranslationException>()));
    expect(device.calls, 0);
  });

  test('model download failure stays actionable', () async {
    final FallbackMachineTranslator translator = FallbackMachineTranslator(
      primary: _Primary(
        error: const TranslationException(
          'The free translation allowance for today is used up.',
          failure: TranslationFailure.quotaExhausted,
        ),
      ),
      fallback: _Device(ready: false, failPrepare: true),
    );
    await expectLater(
      translator.translate('hello'),
      throwsA(predicate<Object>((Object error) =>
          error is TranslationException &&
          error.failure == TranslationFailure.modelUnavailable)),
    );
  });

  test('cache and in-flight coalescing avoid duplicate requests', () async {
    final _Primary primary = _Primary();
    final FallbackMachineTranslator translator = FallbackMachineTranslator(
      primary: primary,
      fallback: _Device(),
    );
    final List<String> values = await Future.wait(<Future<String>>[
      translator.translate('same'),
      translator.translate('same'),
    ]);
    expect(values, <String>['primary', 'primary']);
    expect(await translator.translate('same'), 'primary');
    expect(primary.calls, 1);
  });
}
