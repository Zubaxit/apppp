import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SentenceRange {
  const SentenceRange(
      {required this.start, required this.end, required this.text});
  final int start;
  final int end;
  final String text;

  bool contains(int offset) => offset >= start && offset < end;
}

class SpokenDocument {
  const SpokenDocument({
    required this.text,
    required this.sentences,
    required this.paragraphStarts,
  });

  final String text;
  final List<SentenceRange> sentences;
  final List<int> paragraphStarts;

  factory SpokenDocument.fromParagraphs(List<String> paragraphs) {
    final List<String> clean = <String>[
      for (final String paragraph in paragraphs)
        if (paragraph.trim().isNotEmpty) paragraph.trim(),
    ];
    final List<int> starts = <int>[];
    final StringBuffer joined = StringBuffer();
    for (int i = 0; i < clean.length; i++) {
      if (i > 0) {
        joined.write('\n\n');
      }
      starts.add(joined.length);
      joined.write(clean[i]);
    }
    final String text = joined.toString();
    final List<SentenceRange> sentences = <SentenceRange>[];
    int cursor = 0;
    final RegExp boundary = RegExp(r'[.!?।]+(?:["”’\)]*)?(?=\s|$)');
    for (final RegExpMatch match in boundary.allMatches(text)) {
      int start = cursor;
      while (start < match.end && _space(text.codeUnitAt(start))) {
        start += 1;
      }
      if (start < match.end) {
        sentences.add(SentenceRange(
          start: start,
          end: match.end,
          text: text.substring(start, match.end),
        ));
      }
      cursor = match.end;
    }
    int start = cursor;
    while (start < text.length && _space(text.codeUnitAt(start))) {
      start += 1;
    }
    if (start < text.length) {
      sentences.add(SentenceRange(
          start: start, end: text.length, text: text.substring(start)));
    }
    return SpokenDocument(
      text: text,
      sentences: List<SentenceRange>.unmodifiable(sentences),
      paragraphStarts: List<int>.unmodifiable(starts),
    );
  }

  static bool _space(int code) =>
      code == 9 || code == 10 || code == 13 || code == 32;

  int sentenceAt(int offset) {
    for (int i = 0; i < sentences.length; i++) {
      if (sentences[i].contains(offset) ||
          (offset == text.length && i == sentences.length - 1)) {
        return i;
      }
    }
    return -1;
  }

  int paragraphForSentence(int sentence) {
    if (sentence < 0 || sentence >= sentences.length) {
      return -1;
    }
    final int offset = sentences[sentence].start;
    int result = 0;
    for (int i = 0; i < paragraphStarts.length; i++) {
      if (paragraphStarts[i] > offset) {
        break;
      }
      result = i;
    }
    return result;
  }
}

enum TtsPlaybackState { idle, loading, playing, paused, completed, error }

class TtsEvent {
  const TtsEvent(this.type, this.data);
  final String type;
  final Map<String, Object?> data;
}

abstract class ReaderTtsEngine {
  Stream<TtsEvent> get events;
  Future<Map<String, Object?>> state();
  Future<void> speak({
    required String articleId,
    required String text,
    required String language,
    required double rate,
    int startOffset = 0,
  });
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> seek(int offset);
  Future<void> setRate(double rate);
}

class PlatformReaderTtsEngine implements ReaderTtsEngine {
  PlatformReaderTtsEngine() {
    _channel.setMethodCallHandler((MethodCall call) async {
      if (call.method != 'ttsEvent') {
        return;
      }
      final Map<Object?, Object?> raw =
          call.arguments as Map<Object?, Object?>? ?? <Object?, Object?>{};
      _events.add(TtsEvent(
        '${raw['type'] ?? ''}',
        <String, Object?>{
          for (final MapEntry<Object?, Object?> item in raw.entries)
            '${item.key}': item.value
        },
      ));
    });
  }

  static const MethodChannel _channel = MethodChannel('amar_news/reader_tts');
  final StreamController<TtsEvent> _events =
      StreamController<TtsEvent>.broadcast();

  @override
  Stream<TtsEvent> get events => _events.stream;

  @override
  Future<Map<String, Object?>> state() async {
    final Map<Object?, Object?> raw =
        await _channel.invokeMethod<Map<Object?, Object?>>('state') ??
            <Object?, Object?>{};
    return <String, Object?>{
      for (final MapEntry<Object?, Object?> item in raw.entries)
        '${item.key}': item.value
    };
  }

  @override
  Future<void> speak(
          {required String articleId,
          required String text,
          required String language,
          required double rate,
          int startOffset = 0}) =>
      _channel.invokeMethod<void>('speak', <String, Object?>{
        'articleId': articleId,
        'text': text,
        'language': language,
        'rate': rate,
        'startOffset': startOffset,
      });
  @override
  Future<void> pause() => _channel.invokeMethod<void>('pause');
  @override
  Future<void> resume() => _channel.invokeMethod<void>('resume');
  @override
  Future<void> stop() => _channel.invokeMethod<void>('stop');
  @override
  Future<void> seek(int offset) =>
      _channel.invokeMethod<void>('seek', <String, Object?>{'offset': offset});
  @override
  Future<void> setRate(double rate) =>
      _channel.invokeMethod<void>('setRate', <String, Object?>{'rate': rate});
}

/// App-wide owner of the one permitted TTS session. Reader screens attach to it
/// but never dispose it, allowing Android foreground playback to outlive routes.
class ReaderTtsController extends ChangeNotifier {
  ReaderTtsController({ReaderTtsEngine? engine})
      : _engine = engine ?? PlatformReaderTtsEngine() {
    _subscription = _engine.events.listen(_onEvent);
    unawaited(_restore());
  }

  static ReaderTtsController instance = ReaderTtsController();
  static const List<double> speeds = <double>[0.75, 1, 1.25, 1.5, 2];

  final ReaderTtsEngine _engine;
  late final StreamSubscription<TtsEvent> _subscription;
  SpokenDocument? _document;
  String? _articleId;
  TtsPlaybackState _state = TtsPlaybackState.idle;
  int _offset = 0;
  int _activeSentence = -1;
  double _speed = 1;
  String? _error;

  TtsPlaybackState get playbackState => _state;
  SpokenDocument? get document => _document;
  String? get articleId => _articleId;
  int get offset => _offset;
  int get activeSentence => _activeSentence;
  double get speed => _speed;
  String? get error => _error;
  bool get active =>
      _state == TtsPlaybackState.playing || _state == TtsPlaybackState.paused;
  double? get progress => _document == null || _document!.text.isEmpty
      ? null
      : (_offset / _document!.text.length).clamp(0, 1);

  bool isCurrent(String id) => _articleId == id;

  Future<void> _restore() async {
    Map<String, Object?> value;
    try {
      value = await _engine.state();
    } on MissingPluginException {
      return;
    }
    if (value.isEmpty) {
      return;
    }
    _articleId = value['articleId'] as String?;
    _offset = (value['offset'] as num?)?.toInt() ?? 0;
    _speed = (value['rate'] as num?)?.toDouble() ?? 1;
    _state = _parseState('${value['state'] ?? 'idle'}');
    notifyListeners();
  }

  Future<void> play(String id, List<String> paragraphs,
      {required String language}) async {
    final SpokenDocument next = SpokenDocument.fromParagraphs(paragraphs);
    if (next.text.isEmpty) {
      _articleId = id;
      _document = next;
      _offset = 0;
      _activeSentence = -1;
      _state = TtsPlaybackState.error;
      _error = 'This article does not contain readable text.';
      notifyListeners();
      return;
    }
    if (_articleId != id) {
      _offset = 0;
      _activeSentence = 0;
    }
    _articleId = id;
    _document = next;
    _state = TtsPlaybackState.loading;
    _error = null;
    notifyListeners();
    try {
      await _engine.speak(
        articleId: id,
        text: next.text,
        language: language,
        rate: _speed,
        startOffset: _offset,
      );
    } on PlatformException catch (error) {
      _state = TtsPlaybackState.error;
      _error = error.message ?? 'Text-to-speech could not start.';
      notifyListeners();
    } on Object {
      _state = TtsPlaybackState.error;
      _error = 'Text-to-speech could not start. Check the Android TTS engine.';
      notifyListeners();
    }
  }

  Future<void> pause() => _engine.pause();
  Future<void> resume() => _engine.resume();
  Future<void> stop() => _engine.stop();

  Future<void> setSpeed(double value) async {
    if (!speeds.contains(value)) {
      return;
    }
    _speed = value;
    notifyListeners();
    await _engine.setRate(value);
  }

  Future<void> skipSentences(int delta) async {
    final SpokenDocument? value = _document;
    if (value == null || value.sentences.isEmpty) {
      return;
    }
    final int current =
        _activeSentence < 0 ? value.sentenceAt(_offset) : _activeSentence;
    final int target = (current + delta).clamp(0, value.sentences.length - 1);
    _activeSentence = target;
    _offset = value.sentences[target].start;
    notifyListeners();
    await _engine.seek(_offset);
  }

  void attach(String id, List<String> paragraphs) {
    if (_articleId != id) {
      return;
    }
    _document = SpokenDocument.fromParagraphs(paragraphs);
    _activeSentence = _document!.sentenceAt(_offset);
    notifyListeners();
  }

  void _onEvent(TtsEvent event) {
    if (event.data['articleId'] != null) {
      _articleId = '${event.data['articleId']}';
    }
    if (event.data['offset'] is num) {
      _offset = (event.data['offset']! as num).toInt();
    }
    switch (event.type) {
      case 'playing':
      case 'progress':
        _state = TtsPlaybackState.playing;
      case 'paused':
        _state = TtsPlaybackState.paused;
      case 'completed':
        _state = TtsPlaybackState.completed;
      case 'stopped':
        _state = TtsPlaybackState.idle;
        _activeSentence = -1;
      case 'error':
      case 'voiceUnavailable':
        _state = TtsPlaybackState.error;
        _error = '${event.data['message'] ?? 'Text-to-speech failed.'}';
    }
    if (_document != null) {
      _activeSentence = _document!.sentenceAt(_offset);
    }
    notifyListeners();
  }

  static TtsPlaybackState _parseState(String value) => switch (value) {
        'playing' => TtsPlaybackState.playing,
        'paused' => TtsPlaybackState.paused,
        'completed' => TtsPlaybackState.completed,
        'error' => TtsPlaybackState.error,
        _ => TtsPlaybackState.idle,
      };

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
