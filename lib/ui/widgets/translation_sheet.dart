import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/extensions.dart';
import '../../services/translation_service.dart';
import '../../theme/materials.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';

/// Opens the offline word-meaning sheet for some text.
///
/// The sheet never claims to translate a page: it looks up English words in a
/// bundled glossary and says plainly when a word is not there.
Future<void> showTranslationSheet(
  BuildContext context, {
  required String text,
  TranslationService? service,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) =>
        TranslationSheet(text: text, service: service),
  );
}

class TranslationSheet extends StatefulWidget {
  const TranslationSheet({
    super.key,
    required this.text,
    this.service,
  });

  final String text;
  final TranslationService? service;

  @override
  State<TranslationSheet> createState() => _TranslationSheetState();
}

class _TranslationSheetState extends State<TranslationSheet> {
  late final TranslationService _service =
      widget.service ?? TranslationService();
  final TextEditingController _query = TextEditingController();
  bool _ready = false;
  List<WordMeaning> _gloss = const <WordMeaning>[];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    await _service.load();
    if (!mounted) return;
    setState(() {
      _ready = true;
      _gloss = _service.gloss(widget.text);
    });
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final WordMeaning? result =
        _query.text.trim().isEmpty ? null : _service.lookup(_query.text);
    final double keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        child: GlassPanel(
          radius: Tokens.radiusXl,
          borderRadius: BorderRadius.circular(Tokens.radiusXl),
          blur: Tokens.blurStrong,
          elevation: 1.2,
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 3,
                        height: 16,
                        decoration: BoxDecoration(
                          color: context.colors.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          context.strings.translateTitle,
                          style: context.texts.titleSmall?.copyWith(
                            fontFamily: Tokens.serif,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.close_rounded, size: 18),
                        visualDensity: VisualDensity.compact,
                        tooltip: context.strings.done,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.strings.translateOfflineNote,
                    style: context.texts.labelSmall?.copyWith(
                      fontSize: 10.8,
                      height: 1.5,
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (!_ready)
                    Row(
                      children: <Widget>[
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 1.6),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          context.strings.translateLoading,
                          style: context.texts.labelSmall,
                        ),
                      ],
                    )
                  else if (!_service.isAvailable)
                    _Notice(
                      icon: Icons.cloud_off_rounded,
                      text: context.strings.translateUnavailable,
                    )
                  else ...<Widget>[
                    TextField(
                      controller: _query,
                      textInputAction: TextInputAction.search,
                      textCapitalization: TextCapitalization.none,
                      onChanged: (_) => setState(() {}),
                      style: context.texts.bodyMedium,
                      decoration: InputDecoration(
                        hintText: context.strings.translateSelectionHint,
                        isDense: true,
                        filled: true,
                        fillColor: context.isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.white.withValues(alpha: 0.55),
                        prefixIcon:
                            const Icon(Icons.translate_rounded, size: 16),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 38,
                          minHeight: 36,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(Tokens.radiusMd),
                          borderSide: BorderSide(
                            color: context.isDark
                                ? Tokens.nightHairline
                                : Tokens.hairline,
                            width: 0.9,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(Tokens.radiusMd),
                          borderSide: BorderSide(
                            color: context.isDark
                                ? Tokens.nightHairline
                                : Tokens.hairline,
                            width: 0.9,
                          ),
                        ),
                      ),
                    ),
                    if (result != null) ...<Widget>[
                      const SizedBox(height: 12),
                      _MeaningCard(result: result),
                    ],
                    if (result == null && _gloss.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 16),
                      Text(
                        context.strings.translateWordByWord,
                        style: context.texts.labelSmall?.copyWith(
                          fontSize: 10.5,
                          letterSpacing: 0.8,
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: <Widget>[
                          for (final WordMeaning entry in _gloss.take(24))
                            GlassChip(
                              label: '${entry.word} · ${entry.meaning}',
                              dense: true,
                              onTap: () => setState(() {
                                _query.text = entry.word;
                                _query.selection = TextSelection(
                                  baseOffset: 0,
                                  extentOffset: entry.word.length,
                                );
                              }),
                            ),
                        ],
                      ),
                    ],
                    if (result == null && _gloss.isEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      _Notice(
                        icon: Icons.translate_rounded,
                        text: context.strings.translateUnavailable,
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MeaningCard extends StatelessWidget {
  const _MeaningCard({required this.result});

  final WordMeaning result;

  @override
  Widget build(BuildContext context) {
    final Motion motion = Motion.of(context);
    return AnimatedSize(
      duration: motion.standard,
      curve: Tokens.easeStandard,
      alignment: Alignment.topLeft,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Tokens.radiusMd),
          color: context.colors.primary.withValues(alpha: 0.055),
          border: Border.all(
            color: context.colors.primary.withValues(alpha: 0.2),
            width: 0.9,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              result.word,
              style: context.texts.labelSmall?.copyWith(
                fontSize: 11,
                letterSpacing: 0.4,
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              result.meaning ?? context.strings.translateNoMatch,
              style: context.texts.titleMedium?.copyWith(
                fontFamily: Tokens.serif,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: result.found
                    ? context.colors.onSurface
                    : context.colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 15, color: context.colors.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: context.texts.labelSmall?.copyWith(
              fontSize: 11.5,
              height: 1.4,
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
