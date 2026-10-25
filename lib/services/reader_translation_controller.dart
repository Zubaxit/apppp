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
/// It is deliberately a [ChangeNotifier] rather than screen state: the reader
/// screen subscribes, so a paragraph that finishes translating repaints that
/// paragraph instead of rebuilding the whole article, and the request logic is
/// testable without a widget tree.
///
/// Responsibilities that matter for correctness:
///  * never send the same paragraph twice (identical paragraphs share one
///    request);
///  * never run more than [_concurrency] requests at once;
///  * stop cleanly when the screen goes away, without touching state after
///    dispose;
///  * keep per-paragraph errors so one failure does not poison the page.
class ReaderTranslationController extends ChangeNotifier {
  ReaderTranslationController({
    required MachineTranslator translator,
    required List<String> paragraphs,
  })  : _translator = translator,
        _paragraphs = List<String>.unmodifiable(paragraphs),
        _units = List<ParagraphTranslation>.filled(paragraphs.length, const ParagraphTranslation());

  static const int _concurrency = 2;

  final MachineTranslator _translator;
  final List<String> _paragraphs;
  List<ParagraphTranslation> _units;

  final Map<String, Future<String>> _inFlight = <String, Future<String>>{};
  bool _disposed = false;
  bool _visible = true;
  bool _started = false;
  int _cursor = 0;

  bool get showTranslations => _visible;
  bool get started => _started;
  bool get busy => _units.any((ParagraphTranslation u) => u.loading);
  bool get hasAnyTranslation => _units.any((ParagraphTranslation u) => u.done);
  bool get allFailed =>
      _units.isNotEmpty && _units.every((ParagraphTranslation u) => u.failed);
  String get attribution => _translator.attribution;
  bool get requiresNetwork => _translator.requiresNetwork;
  int get length => _units.length;

  ParagraphTranslation unitAt(int index) =>
      index >= 0 && index < _units.length ? _units[index] : const ParagraphTranslation();

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void setVisible(bool value) {
    if (_visible == value || _disposed) return;
    _visible = value;
    notifyListeners();
  }

  void toggleVisibility() => setVisible(!_visible);

  /// Translates every paragraph that has no translation yet. Calling it twice is
  /// harmless: only unfinished units are queued.
  Future<void> translateAll() async {
    if (_disposed) return;
    _started = true;
    final List<int> queue = <int>[
      for (int i = 0; i < _units.length; i++)
        if (!_units[i].done && !_units[i].loading) i,
    ];
    if (queue.isEmpty) {
      notifyListeners();
      return;
    }
    _cursor = 0;

    Future<void> worker() async {
      while (!_disposed) {
        final int index;
        if (_cursor >= queue.length) return;
        index = queue[_cursor++];
        await _translate(index);
      }
    }

    notifyListeners();
    await Future.wait<void>(<Future<void>>[
      for (int i = 0; i < _concurrency; i++) worker(),
    ]);
  }

  /// Retries one paragraph — the reader offers this per paragraph so a single
  /// rate-limited request does not force the whole page to reload.
  Future<void> retry(int index) async {
    if (_disposed) return;
    _setUnit(index, const ParagraphTranslation(loading: true));
    await _translate(index);
  }

  Future<void> _translate(int index) async {
    final String source = _paragraphs[index].trim();
    if (source.isEmpty) {
      _setUnit(index, const ParagraphTranslation(text: ''));
      return;
    }
    _setUnit(index, ParagraphTranslation(loading: true, text: _units[index].text));

    try {
      final Future<String> request =
          _inFlight[source] ??= _translator.translate(source);
      final String translated = await request;
      if (_disposed) return;
      _setUnit(index, ParagraphTranslation(text: translated));
    } on TranslationException catch (error) {
      if (_disposed) return;
      _setUnit(index, ParagraphTranslation(error: error.message));
    } catch (_) {
      if (_disposed) return;
      _setUnit(index, const ParagraphTranslation(
        error: 'This paragraph could not be translated.',
      ));
    } finally {
      // The dedupe entry is cleared on failure so a retry can request it again.
      if (_units[index].done) _inFlight.remove(source);
    }
  }

  void _setUnit(int index, ParagraphTranslation unit) {
    if (_disposed || index < 0 || index >= _units.length) return;
    final List<ParagraphTranslation> next = List<ParagraphTranslation>.of(_units);
    next[index] = unit;
    _units = next;
    notifyListeners();
  }
}
