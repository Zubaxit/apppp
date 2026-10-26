import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/extensions.dart';
import '../../core/utils/language_detect.dart';
import '../../core/utils/reader_extract.dart';
import '../../services/machine_translation.dart';
import '../../services/reader_translation_controller.dart';
import '../../services/reader_tts.dart';
import '../../services/vocabulary_matcher.dart';
import '../../state/saved_controller.dart';
import '../../theme/materials.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../widgets/actions.dart';
import '../widgets/common.dart';
import '../widgets/vocabulary.dart';

/// The bilingual reading surface.
///
/// One column, one measure: the publisher's English paragraph, then its Bengali
/// translation directly beneath it, in a quieter ink and an indent that reads as
/// a gloss rather than a second article. The English is never replaced, never
/// collapsed and never edited — the translation is additive.
///
/// Everything the screen knows comes from the page the user is already looking
/// at ([ReaderDocument]) plus paragraph translations from [MachineTranslator].
/// Nothing here fetches the article again, so reading costs no extra request and
/// the publisher sees exactly the page load the browser already made.
class ReaderModeScreen extends StatefulWidget {
  const ReaderModeScreen({
    super.key,
    required this.document,
    required this.translator,
    this.onOpenOriginal,
    this.startTranslated = false,
  });

  final ReaderDocument document;
  final MachineTranslator translator;
  final VoidCallback? onOpenOriginal;

  /// Test/migration hook. Production always uses the default (`false`): every
  /// reader session opens on the untouched article and needs an explicit tap.
  final bool startTranslated;

  @override
  State<ReaderModeScreen> createState() => _ReaderModeScreenState();
}

class _ReaderModeScreenState extends State<ReaderModeScreen> {
  late final ReaderTranslationController _controller = ReaderTranslationController(
    translator: widget.translator,
    paragraphs: widget.document.paragraphs,
  );
  final ReaderTtsController _tts = ReaderTtsController.instance;
  final ScrollController _scroll = ScrollController();
  late final List<GlobalKey> _paragraphKeys = <GlobalKey>[
    for (final String _ in widget.document.paragraphs) GlobalKey(),
  ];
  late final String _articleId = widget.document.url ?? widget.document.title;
  int _lastAutoSentence = -1;

  @override
  void initState() {
    super.initState();
    _tts.attach(_articleId, widget.document.paragraphs);
    _tts.addListener(_onTtsChanged);
    if (widget.startTranslated) unawaited(_controller.translateAll());
  }

  void _onTtsChanged() {
    if (!mounted) return;
    setState(() {});
    if (!_tts.isCurrent(_articleId) ||
        _tts.playbackState != TtsPlaybackState.playing ||
        _tts.activeSentence == _lastAutoSentence) return;
    _lastAutoSentence = _tts.activeSentence;
    final int paragraph = _tts.document?.paragraphForSentence(_tts.activeSentence) ?? -1;
    if (paragraph < 0 || paragraph >= _paragraphKeys.length) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? target = _paragraphKeys[paragraph].currentContext;
      if (mounted && target != null) {
        Scrollable.ensureVisible(
          target,
          duration: Motion.of(context).standard,
          alignment: 0.28,
          curve: Motion.of(context).curve,
        );
      }
    });
  }

  @override
  void dispose() {
    _tts.removeListener(_onTtsChanged);
    _scroll.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _openOriginal() {
    final VoidCallback? open = widget.onOpenOriginal;
    if (open != null) {
      open();
      return;
    }
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final ReaderDocument document = widget.document;
    final TextLanguage language = LanguageDetect.ofArticle(
      body: document.paragraphs.join(' '),
      title: document.title,
    );
    final bool canTranslate = LanguageDetect.offersTranslation(language);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AuroraBackdrop(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              _ReaderHeader(
                title: document.title,
                site: document.site,
                onBack: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: ListenableBuilder(
                  listenable: _controller,
                  builder: (BuildContext context, Widget? child) => _Article(
                    document: document,
                    controller: _controller,
                    tts: _tts,
                    articleId: _articleId,
                    scrollController: _scroll,
                    paragraphKeys: _paragraphKeys,
                    translator: widget.translator,
                    onRetry: (int index) => unawaited(_controller.retry(index)),
                    onOpenOriginal: _openOriginal,
                  ),
                ),
              ),
              _ListenBar(
                controller: _tts,
                currentArticle: _articleId,
                onPlay: () => unawaited(_tts.play(
                  _articleId,
                  document.paragraphs,
                  language: language == TextLanguage.bengali ? 'bn-BD' : 'en-US',
                )),
              ),
              if (canTranslate)
                ListenableBuilder(
                  listenable: _controller,
                  builder: (BuildContext context, Widget? child) =>
                      _TranslationBar(
                    controller: _controller,
                    onToggle: () => unawaited(_controller.toggle()),
                    onStart: () => unawaited(_controller.setEnabled(true)),
                    onRetry: () => unawaited(_controller.translateAll()),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReaderHeader extends StatelessWidget {
  const _ReaderHeader({required this.title, required this.site, required this.onBack});

  final String title;
  final String? site;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Tokens.gutter - 6, 6, Tokens.gutter, 4),
      child: Row(
        children: <Widget>[
          GlassIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: context.strings.back,
            onTap: onBack,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  context.strings.readerMode,
                  style: context.texts.labelSmall?.copyWith(
                    fontSize: 10,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800,
                    color: context.colors.primary,
                  ),
                ),
                Text(
                  site ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.labelSmall?.copyWith(fontSize: 10.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Article extends StatelessWidget {
  const _Article({
    required this.document,
    required this.controller,
    required this.tts,
    required this.articleId,
    required this.scrollController,
    required this.paragraphKeys,
    required this.translator,
    required this.onRetry,
    required this.onOpenOriginal,
  });

  final ReaderDocument document;
  final ReaderTranslationController controller;
  final ReaderTtsController tts;
  final String articleId;
  final ScrollController scrollController;
  final List<GlobalKey> paragraphKeys;
  final MachineTranslator translator;
  final ValueChanged<int> onRetry;
  final VoidCallback onOpenOriginal;

  @override
  Widget build(BuildContext context) {
    int proseIndex = -1;
    final SavedController saved = context.watch<SavedController>();
    final VocabularyMatcher vocabulary = VocabularyMatcher(saved.vocabulary);

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(Tokens.gutter, 8, Tokens.gutter, 140),
      // Blocks are cheap text rows; the extra cache extent keeps a fast fling
      // from showing gaps, and nothing off-screen holds an animation.
      cacheExtent: 480,
      itemCount: document.blocks.length + 1,
      itemBuilder: (BuildContext context, int index) {
        if (index == 0) return _ArticleHead(document: document);

        final ReaderBlock block = document.blocks[index - 1];
        if (block.isImage) {
          return Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 18),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Tokens.radiusSm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: RemoteImage(url: block.imageUrl!, decodeWidth: 720),
                  ),
                  if (block.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        block.text,
                        style: context.texts.labelSmall?.copyWith(
                          fontSize: 10.5,
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }
        if (block.heading) {
          return Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 6),
            child: Text(
              block.text,
              style: context.texts.titleMedium?.copyWith(
                fontFamily: Tokens.serif,
                fontSize: 18,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }

        proseIndex += 1;
        final int paragraph = proseIndex;
        final ParagraphTranslation unit = controller.unitAt(paragraph);
        // A page that has not started translating shows nothing under the
        // paragraph: a pending spinner there would spin forever.
        final bool show = controller.enabled && controller.started;

        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _ReaderParagraph(
                key: paragraphKeys[paragraph],
                text: block.text,
                matches: vocabulary.find(block.text),
                activeSentence: tts.isCurrent(articleId) &&
                        tts.document != null &&
                        tts.activeSentence >= 0 &&
                        paragraph < tts.document!.paragraphStarts.length
                    ? _localSentence(
                        tts.document!,
                        tts.activeSentence,
                        paragraph,
                      )
                    : null,
                translator: translator,
                document: document,
              ),
              if (show)
                Padding(
                  padding: const EdgeInsets.only(top: 10, left: 14),
                  child: _Translation(unit: unit, onRetry: () => onRetry(paragraph)),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ReaderParagraph extends StatefulWidget {
  const _ReaderParagraph({
    super.key,
    required this.text,
    required this.matches,
    required this.activeSentence,
    required this.translator,
    required this.document,
  });

  final String text;
  final List<VocabularyMatch> matches;
  final SentenceRange? activeSentence;
  final MachineTranslator translator;
  final ReaderDocument document;

  @override
  State<_ReaderParagraph> createState() => _ReaderParagraphState();
}

class _ReaderParagraphState extends State<_ReaderParagraph> {
  final List<TapGestureRecognizer> _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final TapGestureRecognizer recognizer in _recognizers) recognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final TapGestureRecognizer recognizer in _recognizers) recognizer.dispose();
    _recognizers.clear();
    final Set<int> boundary = <int>{0, widget.text.length};
    final SentenceRange? active = widget.activeSentence;
    if (active != null) boundary.addAll(<int>[active.start, active.end]);
    for (final VocabularyMatch match in widget.matches) {
      boundary.addAll(<int>[match.start, match.end]);
    }
    final List<int> points = boundary.where((int value) => value >= 0 && value <= widget.text.length).toList()..sort();
    final List<InlineSpan> spans = <InlineSpan>[];
    for (int i = 0; i + 1 < points.length; i++) {
      final int start = points[i];
      final int end = points[i + 1];
      if (start == end) continue;
      VocabularyMatch? vocabulary;
      for (final VocabularyMatch candidate in widget.matches) {
        if (start >= candidate.start && end <= candidate.end) {
          vocabulary = candidate;
          break;
        }
      }
      final bool speaking = active != null && start >= active.start && end <= active.end;
      TapGestureRecognizer? recognizer;
      if (vocabulary != null) {
        final VocabularyMatch selected = vocabulary;
        recognizer = TapGestureRecognizer()
          ..onTap = () => showVocabularyMeaning(context, selected.entry);
        _recognizers.add(recognizer);
      }
      spans.add(TextSpan(
        text: widget.text.substring(start, end),
        recognizer: recognizer,
        style: TextStyle(
          backgroundColor: speaking
              ? context.colors.primary.withValues(alpha: 0.16)
              : vocabulary == null
                  ? null
                  : context.colors.tertiary.withValues(alpha: 0.13),
          decoration: vocabulary == null ? null : TextDecoration.underline,
          decorationColor: vocabulary == null ? null : context.colors.primary,
          decorationThickness: vocabulary == null ? null : 1.5,
        ),
      ));
    }

    return SelectableText.rich(
      TextSpan(children: spans),
      style: context.texts.bodyMedium?.copyWith(
        fontFamily: Tokens.serif,
        fontSize: 16.4,
        height: 1.72,
        letterSpacing: 0.1,
        color: context.colors.onSurface,
      ),
      contextMenuBuilder: (BuildContext menuContext, EditableTextState state) {
        final TextSelection selection = state.textEditingValue.selection;
        final String selected = selection.isValid
            ? selection.textInside(state.textEditingValue.text).trim()
            : '';
        final List<ContextMenuButtonItem> items =
            List<ContextMenuButtonItem>.of(state.contextMenuButtonItems);
        if (RegExp(r"^[A-Za-z]+(?:['’][A-Za-z]+)?$").hasMatch(selected)) {
          items.add(ContextMenuButtonItem(
            label: 'Save word',
            onPressed: () {
              state.hideToolbar();
              showVocabularyEditor(
                context,
                word: selected,
                translator: widget.translator,
                articleTitle: widget.document.title,
                articleUrl: widget.document.url,
                sourceName: widget.document.site,
              );
            },
          ));
        }
        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: state.contextMenuAnchors,
          buttonItems: items,
        );
      },
    );
  }
}

class _ListenBar extends StatelessWidget {
  const _ListenBar({
    required this.controller,
    required this.currentArticle,
    required this.onPlay,
  });

  final ReaderTtsController controller;
  final String currentArticle;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final bool current = controller.isCurrent(currentArticle);
    final TtsPlaybackState state =
        current ? controller.playbackState : TtsPlaybackState.idle;
    final int sentence = current ? controller.activeSentence : -1;
    final int total = current ? controller.document?.sentences.length ?? 0 : 0;
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Tokens.gutter, 4, Tokens.gutter, 5),
        child: GlassPanel(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          radius: Tokens.radiusPill,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (current && controller.progress != null)
                LinearProgressIndicator(
                  value: controller.progress,
                  minHeight: 2,
                  backgroundColor: context.colors.outlineVariant,
                ),
              Row(
                children: <Widget>[
                  IconButton(
                    tooltip: 'Stop',
                    onPressed: current && state != TtsPlaybackState.idle
                        ? () => unawaited(controller.stop())
                        : null,
                    icon: const Icon(Icons.stop_rounded),
                  ),
                  IconButton(
                    tooltip: 'Back about 10 seconds',
                    onPressed: current && controller.active
                        ? () => unawaited(controller.skipSentences(-1))
                        : null,
                    icon: const Icon(Icons.replay_10_rounded),
                  ),
                  IconButton.filled(
                    tooltip: state == TtsPlaybackState.playing ? 'Pause' : 'Listen',
                    onPressed: () {
                      if (state == TtsPlaybackState.playing) {
                        unawaited(controller.pause());
                      } else if (state == TtsPlaybackState.paused) {
                        unawaited(controller.resume());
                      } else {
                        onPlay();
                      }
                    },
                    icon: Icon(state == TtsPlaybackState.playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded),
                  ),
                  IconButton(
                    tooltip: 'Forward about 10 seconds',
                    onPressed: current && controller.active
                        ? () => unawaited(controller.skipSentences(1))
                        : null,
                    icon: const Icon(Icons.forward_10_rounded),
                  ),
                  Expanded(
                    child: Text(
                      state == TtsPlaybackState.error
                          ? controller.error ?? 'Playback error'
                          : sentence >= 0 && total > 0
                              ? 'Sentence ${sentence + 1} of $total'
                              : 'Listen',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.labelSmall,
                    ),
                  ),
                  PopupMenuButton<double>(
                    tooltip: 'Playback speed',
                    initialValue: controller.speed,
                    onSelected: (double value) =>
                        unawaited(controller.setSpeed(value)),
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<double>>[
                      for (final double speed in ReaderTtsController.speeds)
                        PopupMenuItem<double>(
                          value: speed,
                          child: Text('${speed}x'),
                        ),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text('${controller.speed}x'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

SentenceRange? _localSentence(
  SpokenDocument document,
  int sentenceIndex,
  int paragraph,
) {
  if (sentenceIndex < 0 || sentenceIndex >= document.sentences.length) return null;
  final SentenceRange sentence = document.sentences[sentenceIndex];
  final int paragraphStart = document.paragraphStarts[paragraph];
  final int paragraphEnd = paragraph + 1 < document.paragraphStarts.length
      ? document.paragraphStarts[paragraph + 1] - 2
      : document.text.length;
  if (sentence.end <= paragraphStart || sentence.start >= paragraphEnd) return null;
  return SentenceRange(
    start: (sentence.start - paragraphStart).clamp(0, paragraphEnd - paragraphStart),
    end: (sentence.end - paragraphStart).clamp(0, paragraphEnd - paragraphStart),
    text: sentence.text,
  );
}

/// One translation block: the Bengali, or its honest state (working / failed).
class _Translation extends StatelessWidget {
  const _Translation({required this.unit, required this.onRetry});

  final ParagraphTranslation unit;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final Color muted = context.colors.onSurfaceVariant;
    if (unit.failed) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.translate_rounded, size: 13, color: context.colors.error),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  unit.error ?? context.strings.translationUnavailable,
                  style: context.texts.labelSmall?.copyWith(
                    fontSize: 11,
                    height: 1.5,
                    color: context.colors.error,
                  ),
                ),
                const SizedBox(height: 4),
                JellySurface(
                  onTap: onRetry,
                  scale: 0.94,
                  child: Text(
                    context.strings.retry,
                    style: context.texts.labelSmall?.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: context.colors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (unit.done && (unit.text ?? '').isNotEmpty) {
      return Container(
        padding: const EdgeInsets.only(left: 12),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: context.colors.primary.withValues(alpha: 0.35),
              width: 2,
            ),
          ),
        ),
        child: SelectableText(
          unit.text!,
          style: context.texts.bodyMedium?.copyWith(
            fontSize: 15.4,
            height: 1.85,
            color: muted,
          ),
        ),
      );
    }

    return Row(
      children: <Widget>[
        SizedBox(
          width: 11,
          height: 11,
          child: CircularProgressIndicator(
            strokeWidth: 1.4,
            color: context.colors.primary.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          context.strings.translating,
          style: context.texts.labelSmall?.copyWith(fontSize: 10.5, color: muted),
        ),
      ],
    );
  }
}

class _ArticleHead extends StatelessWidget {
  const _ArticleHead({required this.document});

  final ReaderDocument document;

  @override
  Widget build(BuildContext context) {
    final List<String> meta = <String>[
      if ((document.byline ?? '').isNotEmpty) document.byline!,
      if ((document.published ?? '').isNotEmpty) document.published!,
      if ((document.site ?? '').isNotEmpty) document.site!,
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            document.title,
            style: context.texts.headlineSmall?.copyWith(
              fontFamily: Tokens.serif,
              fontSize: 25,
              height: 1.32,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          if (meta.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              meta.join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.texts.labelSmall?.copyWith(
                fontSize: 10.5,
                height: 1.5,
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 14),
          const SoftRule(),
        ],
      ),
    );
  }
}

/// The bottom strip: the translation switch, the provider, and the way back to
/// the real page. It is chrome, so it is frosted; it is not a second toolbar.
class _TranslationBar extends StatelessWidget {
  const _TranslationBar({
    required this.controller,
    required this.onToggle,
    required this.onStart,
    required this.onRetry,
  });

  final ReaderTranslationController controller;
  final VoidCallback onToggle;
  final VoidCallback onStart;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final bool enabled = controller.enabled;
    final bool failed = enabled && controller.complete &&
        !controller.hasAnyTranslation && controller.allFailed;
    final String state = enabled
        ? '${context.strings.hideTranslation} · ${controller.attribution}'
        : context.strings.showTranslation;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: GlassBar(
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          child: Row(
            children: <Widget>[
              Icon(
                enabled ? Icons.translate_rounded : Icons.translate_outlined,
                size: 17,
                color: enabled
                    ? context.colors.primary
                    : context.colors.onSurfaceVariant,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  failed
                      ? context.strings.translationUnavailable
                      : controller.busy
                          ? context.strings.translating
                          : state,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.labelSmall?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: failed ? context.colors.error : null,
                  ),
                ),
              ),
              if (controller.busy) ...<Widget>[
                SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: context.colors.primary,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              if (failed)
                JellyButton(
                  label: context.strings.retry,
                  compact: true,
                  onPressed: onRetry,
                )
              else if (!controller.started)
                JellyButton(
                  key: const ValueKey<String>('translation-start'),
                  label: context.strings.showTranslation,
                  icon: Icons.translate_rounded,
                  compact: true,
                  onPressed: onStart,
                )
              else
                Semantics(
                  label: context.strings.translationLabel,
                  value: enabled ? 'ON' : 'OFF',
                  toggled: enabled,
                  child: JellySwitch(
                    key: const ValueKey<String>('translation-switch'),
                    value: enabled,
                    onChanged: (_) => onToggle(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact sheet that answers "what does this say?" for a selection.
///
/// The selected text is preserved at the top, exactly as the user selected it,
/// and can be copied even when the translation fails — which is the honest
/// fallback for a page that cannot be read by the app.
Future<void> showSelectionTranslation(
  BuildContext context, {
  required String selection,
  required MachineTranslator translator,
  required Future<String?> Function(String word) glossary,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) => SelectionTranslationSheet(
      selection: selection,
      translator: translator,
      glossary: glossary,
    ),
  );
}

class SelectionTranslationSheet extends StatefulWidget {
  const SelectionTranslationSheet({
    super.key,
    required this.selection,
    required this.translator,
    required this.glossary,
  });

  final String selection;
  final MachineTranslator translator;

  /// Offline fallback: the bundled glossary's meaning for a single word.
  final Future<String?> Function(String word) glossary;

  @override
  State<SelectionTranslationSheet> createState() => _SelectionTranslationSheetState();
}

class _SelectionTranslationSheetState extends State<SelectionTranslationSheet> {
  String? _translation;
  String? _error;
  String? _offlineMeaning;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  Future<void> _run() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final String value = await widget.translator.translate(widget.selection);
      if (!mounted) return;
      setState(() {
        _translation = value;
        _loading = false;
      });
    } on TranslationException catch (error) {
      final String? meaning = await widget.glossary(widget.selection);
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _offlineMeaning = meaning;
        _loading = false;
      });
    } catch (_) {
      final String? meaning = await widget.glossary(widget.selection);
      if (!mounted) return;
      setState(() {
        _error = widget.selection.trim().contains(' ')
            ? 'This text could not be translated right now.'
            : null;
        _offlineMeaning = meaning;
        _loading = false;
      });
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.selection));
    if (!mounted) return;
    context.showSnack(context.strings.textCopied);
  }

  @override
  Widget build(BuildContext context) {
    final String selection = widget.selection;
    return Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
      ),
      child: GlassPanel(
        radius: Tokens.radiusLg,
        tone: GlassTone.sheet,
        blur: Tokens.blurStrong,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.translate_rounded, size: 15, color: context.colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.strings.bengaliMeaning,
                    style: context.texts.titleSmall?.copyWith(fontSize: 14),
                  ),
                ),
                JellySurface(
                  onTap: _copy,
                  scale: 0.9,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.copy_rounded,
                      size: 15,
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 96),
              child: SingleChildScrollView(
                child: SelectableText(
                  selection,
                  style: context.texts.bodySmall?.copyWith(
                    fontSize: 12.5,
                    height: 1.55,
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const SoftRule(),
            const SizedBox(height: 12),
            if (_loading)
              Row(
                children: <Widget>[
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: context.colors.primary,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Text(
                    context.strings.translating,
                    style: context.texts.labelSmall?.copyWith(fontSize: 11),
                  ),
                ],
              )
            else if (_translation != null)
              SelectableText(
                _translation!,
                style: context.texts.bodyMedium?.copyWith(
                  fontSize: 16,
                  height: 1.75,
                ),
              )
            else ...<Widget>[
              if (_offlineMeaning != null)
                Text(
                  _offlineMeaning!,
                  style: context.texts.bodyMedium?.copyWith(
                    fontSize: 15,
                    height: 1.7,
                  ),
                ),
              if (_offlineMeaning == null)
                Text(
                  _error ?? context.strings.translationUnavailable,
                  style: context.texts.labelSmall?.copyWith(
                    fontSize: 11.5,
                    height: 1.5,
                    color: context.colors.error,
                  ),
                ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  JellyButton(
                    label: context.strings.retry,
                    compact: true,
                    onPressed: _run,
                  ),
                  const SizedBox(width: 8),
                  TextButton(onPressed: _copy, child: Text(context.strings.copyText)),
                ],
              ),
            ],
            const SizedBox(height: 6),
            Text(
              '${context.strings.machineTranslationNotice} · ${widget.translator.attribution}',
              style: context.texts.labelSmall?.copyWith(
                fontSize: 9.5,
                height: 1.4,
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
