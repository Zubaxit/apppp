import 'dart:async';

import 'package:bangladesh_newspaper_hub/services/reader_tts.dart';
import 'package:flutter_test/flutter_test.dart';

class _TtsEngine implements ReaderTtsEngine {
  final StreamController<TtsEvent> stream =
      StreamController<TtsEvent>.broadcast();
  int speaks = 0;
  String? article;
  int start = 0;
  @override
  Stream<TtsEvent> get events => stream.stream;
  @override
  Future<Map<String, Object?>> state() async => <String, Object?>{};
  @override
  Future<void> speak(
      {required String articleId,
      required String text,
      required String language,
      required double rate,
      int startOffset = 0}) async {
    speaks++;
    article = articleId;
    start = startOffset;
    stream.add(TtsEvent('playing',
        <String, Object?>{'articleId': articleId, 'offset': startOffset}));
  }

  @override
  Future<void> pause() async => stream.add(TtsEvent(
      'paused', <String, Object?>{'articleId': article, 'offset': start}));
  @override
  Future<void> resume() async => stream.add(TtsEvent(
      'playing', <String, Object?>{'articleId': article, 'offset': start}));
  @override
  Future<void> seek(int offset) async {
    start = offset;
    stream.add(TtsEvent(
        'progress', <String, Object?>{'articleId': article, 'offset': offset}));
  }

  @override
  Future<void> setRate(double rate) async {}
  @override
  Future<void> stop() async => stream.add(TtsEvent(
      'stopped', <String, Object?>{'articleId': article, 'offset': 0}));
}

class _FailingTtsEngine extends _TtsEngine {
  @override
  Future<void> speak({
    required String articleId,
    required String text,
    required String language,
    required double rate,
    int startOffset = 0,
  }) async {
    throw StateError('engine initialization failed');
  }
}

void main() {
  test('segments Bengali and English while preserving UTF-16 offsets', () {
    final SpokenDocument value = SpokenDocument.fromParagraphs(<String>[
      'প্রথম বাক্য। দ্বিতীয় বাক্য!',
      'English sentence? Final line.',
    ]);
    expect(value.text,
        'প্রথম বাক্য। দ্বিতীয় বাক্য!\n\nEnglish sentence? Final line.');
    expect(value.sentences.map((SentenceRange item) => item.text), <String>[
      'প্রথম বাক্য।',
      'দ্বিতীয় বাক্য!',
      'English sentence?',
      'Final line.',
    ]);
    expect(value.sentenceAt(value.text.indexOf('English')), 2);
    expect(value.paragraphForSentence(2), 1);
  });

  test('active sentence follows native range offsets', () async {
    final _TtsEngine engine = _TtsEngine();
    final ReaderTtsController controller = ReaderTtsController(engine: engine);
    await controller.play('one', <String>['One sentence. Two sentence.'],
        language: 'en-US');
    await Future<void>.delayed(Duration.zero);
    engine.stream.add(const TtsEvent(
        'progress', <String, Object?>{'articleId': 'one', 'offset': 15}));
    await Future<void>.delayed(Duration.zero);
    expect(controller.activeSentence, 1);
    controller.dispose();
  });

  test('pause preserves position, resume and completion update state',
      () async {
    final _TtsEngine engine = _TtsEngine();
    final ReaderTtsController controller = ReaderTtsController(engine: engine);
    await controller.play('one', <String>['One sentence. Two sentence.'],
        language: 'en-US');
    await Future<void>.delayed(Duration.zero);
    await controller.skipSentences(1);
    final int pausedOffset = controller.offset;
    await controller.pause();
    await Future<void>.delayed(Duration.zero);
    expect(controller.playbackState, TtsPlaybackState.paused);
    expect(controller.offset, pausedOffset);
    await controller.resume();
    await Future<void>.delayed(Duration.zero);
    expect(controller.playbackState, TtsPlaybackState.playing);
    engine.stream.add(TtsEvent('completed', <String, Object?>{
      'articleId': 'one',
      'offset': controller.document!.text.length,
    }));
    await Future<void>.delayed(Duration.zero);
    expect(controller.playbackState, TtsPlaybackState.completed);
    controller.dispose();
  });

  test('starting another article replaces the session', () async {
    final _TtsEngine engine = _TtsEngine();
    final ReaderTtsController controller = ReaderTtsController(engine: engine);
    await controller.play('one', <String>['First article.'], language: 'en-US');
    await controller.play('two', <String>['Second article.'],
        language: 'en-US');
    expect(engine.speaks, 2);
    expect(controller.articleId, 'two');
    expect(controller.offset, 0);
    controller.dispose();
  });

  test('empty cleaned article never enters a false playing state', () async {
    final _TtsEngine engine = _TtsEngine();
    final ReaderTtsController controller = ReaderTtsController(engine: engine);
    await controller.play('empty', <String>['  ', '\n'], language: 'en-US');
    expect(engine.speaks, 0);
    expect(controller.playbackState, TtsPlaybackState.error);
    expect(controller.error, contains('readable text'));
    controller.dispose();
  });

  test('engine initialization failure becomes an actionable error state',
      () async {
    final ReaderTtsController controller =
        ReaderTtsController(engine: _FailingTtsEngine());
    await controller.play('one', <String>['Readable text.'], language: 'en-US');
    expect(controller.playbackState, TtsPlaybackState.error);
    expect(controller.error, contains('Android TTS engine'));
    controller.dispose();
  });

  test('unavailable voice data never leaves playback loading', () async {
    final _TtsEngine engine = _TtsEngine();
    final ReaderTtsController controller = ReaderTtsController(engine: engine);
    await controller.play('one', <String>['Readable text.'], language: 'en-US');
    engine.stream.add(const TtsEvent('error', <String, Object?>{
      'articleId': 'one',
      'offset': 0,
      'reasonCode': 'voiceUnavailable',
      'message': 'Install English voice data.',
    }));
    await Future<void>.delayed(Duration.zero);
    expect(controller.playbackState, TtsPlaybackState.error);
    expect(controller.error, contains('Install English'));
    controller.dispose();
  });

  test('error state exposes platform message', () async {
    final _TtsEngine engine = _TtsEngine();
    final ReaderTtsController controller = ReaderTtsController(engine: engine);
    await controller.play('one', <String>['Text.'], language: 'en-US');
    engine.stream.add(const TtsEvent('error', <String, Object?>{
      'articleId': 'one',
      'offset': 0,
      'message': 'voice unavailable',
    }));
    await Future<void>.delayed(Duration.zero);
    expect(controller.playbackState, TtsPlaybackState.error);
    expect(controller.error, 'voice unavailable');
    controller.dispose();
  });
}
