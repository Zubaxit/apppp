import 'dart:async';

import 'package:flutter/foundation.dart';

import 'machine_translation.dart';

/// Translation state of one paragraph.
class ParagraphTranslation {
  const ParagraphTranslation({this.text, this.error, this.loading = false});

  final String? text;
  final String? error;
  final bool loading;

  bool get done => text != null;
  bool get failed => error != null;
}

/// Drives the bilingual reading surface.
///
/// [enabled] is the one authoritative ON/OFF state. Turning it off immediately
/// hides translations, clears loading indicators and invalidates the current
/// async generation. HTTP already sent cannot be unsent by `package:http`, but
/// its eventual result is ignored and can never turn the UI back on.
class ReaderTranslationController extends ChangeNotifier {
  ReaderTranslationController({
    required MachineTranslator translator,
    required List<String> paragraphs,
  })  : _translator = translator,
        _paragraphs = List<String>.unmodifiable(paragraphs),
        _units = List<ParagraphTranslation>.filled(
          paragraphs.length,
          const ParagraphTranslation(),
        );

  static const int _concurrency = 2;

  final MachineTranslator _translator;
  final List<String> _paragraphs;
  List<ParagraphTranslation> _units;

  final Map<String, Future<String>> _inFlight = <String, Future<String>>{};

  bool _disposed = false;
  bool _enabled = false;
  bool _started = false;
  int _generation = 0;
  int _cursor = 0;

  bool get enabled => _enabled;
  bool get showTranslations => _enabled;
  bool get started => _started;
  bool get busy => _enabled && _units.any((ParagraphTranslation u) => u.loading);
  bool get hasAnyTranslation => _units.any((ParagraphTranslation u) => u.done);
  bool get hasAnyFailure => _units.any((ParagraphTranslation u) => u.failed);
  bool get allFailed =>
      _units.isNotEmpty && _units.every((ParagraphTranslation u) => u.failed);
  bool get complete => _units.isNotEmpty &&
      _units.every((ParagraphTranslation u) => u.done || u.failed);
  String get attribution => _translator.attribution;
  bool get requiresNetwork => _translator.requiresNetwork;
  int get length => _units.length;

  ParagraphTranslation unitAt(int index) =>
      index >= 0 && index < _units.length
          ? _units[index]
          : const ParagraphTranslation();

  @override
  void dispose() {
    _disposed = true;
    _generation += 1;
    super.dispose();
  }

  /// Changes the complete translation feature state.
  ///
  /// Enabling starts any unfinished paragraph. Disabling performs a logical
  /// cancellation: pending responses from the old generation are ignored.
  Future<void> setEnabled(bool value) async {
    if (_disposed || _enabled == value) return;
    _enabled = value;
    _generation += 1;
    if (!value) {
      _units = <ParagraphTranslation>[
        for (final ParagraphTranslation unit in _units)
          ParagraphTranslation(text: unit.text, error: unit.error),
      ];
      notifyListeners();
      return;
    }
    _started = true;
    notifyListeners();
    await _translateUnfinished(_generation);
  }

  Future<void> toggle() => setEnabled(!_enabled);

  /// Compatibility entry point used by the screen's start/retry actions.
  Future<void> translateAll() async {
    if (_disposed) return;
    if (!_enabled) {
      await setEnabled(true);
      return;
    }
    _started = true;
    await _translateUnfinished(_generation);
  }

  Future<void> _translateUnfinished(int generation) async {
    final List<int> queue = <int>[
      for (int i = 0; i < _units.length; i++)
        if (!_units[i].done && !_units[i].loading) i,
    ];
    if (queue.isEmpty) {
      if (!_disposed) notifyListeners();
      return;
    }
    _cursor = 0;

    Future<void> worker() async {
      while (!_disposed && _enabled && generation == _generation) {
        if (_cursor >= queue.length) return;
        final int index = queue[_cursor++];
        await _translate(index, generation);
      }
    }

    await Future.wait<void>(<Future<void>>[
      for (int i = 0; i < _concurrency; i++) worker(),
    ]);
  }

  /// Retries one paragraph only while translation is ON.
  Future<void> retry(int index) async {
    if (_disposed || !_enabled) return;
    _setUnit(index, const ParagraphTranslation(loading: true));
    await _translate(index, _generation);
  }

  Future<void> _translate(int index, int generation) async {
    if (!_current(generation)) return;
    final String source = _paragraphs[index].trim();
    if (source.isEmpty) {
      _setUnit(index, const ParagraphTranslation(text: ''));
      return;
    }
    _setUnit(
      index,
      ParagraphTranslation(loading: true, text: _units[index].text),
    );

    try {
      final Future<String> request =
          _inFlight[source] ??= _translator.translate(source);
      final String translated = await request;
      if (!_current(generation)) return;
      _setUnit(index, ParagraphTranslation(text: translated));
    } on TranslationException catch (error) {
      if (!_current(generation)) return;
      _setUnit(index, ParagraphTranslation(error: error.message));
    } catch (_) {
      if (!_current(generation)) return;
      _setUnit(
        index,
        const ParagraphTranslation(
          error: 'This paragraph could not be translated.',
        ),
      );
    } finally {
      if (!_disposed && !_units[index].done) {
        _inFlight.remove(source)?.ignore();
      }
    }
  }

  bool _current(int generation) =>
      !_disposed && _enabled && generation == _generation;

  void _setUnit(int index, ParagraphTranslation unit) {
    if (_disposed || index < 0 || index >= _units.length) return;
    final List<ParagraphTranslation> next =
        List<ParagraphTranslation>.of(_units);
    next[index] = unit;
    _units = next;
    notifyListeners();
  }
}
