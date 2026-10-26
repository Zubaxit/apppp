import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/extensions.dart';
import '../../data/models/vocabulary_entry.dart';
import '../../services/machine_translation.dart';
import '../../state/saved_controller.dart';
import '../../theme/materials.dart';
import '../../theme/tokens.dart';
import 'common.dart';

Future<void> showVocabularyEditor(
  BuildContext context, {
  required String word,
  required MachineTranslator translator,
  String? articleTitle,
  String? articleUrl,
  String? sourceName,
}) async {
  final SavedController saved = context.read<SavedController>();
  final String normalized = VocabularyEntry.normalizeWord(word);
  if (normalized.isEmpty) {
    return;
  }
  final VocabularyEntry? existing = saved.vocabularyFor(normalized);
  final TextEditingController meaning =
      TextEditingController(text: existing?.meaningBn ?? '');
  final TextEditingController definition =
      TextEditingController(text: existing?.definitionEn ?? '');
  final TextEditingController part =
      TextEditingController(text: existing?.partOfSpeech ?? '');
  bool suggesting = false;
  String? suggestionError;

  await showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) => AlertDialog(
        title: Text(existing == null ? 'Save vocabulary' : 'Edit vocabulary'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(word, style: context.texts.titleLarge),
              const SizedBox(height: 12),
              TextField(
                controller: meaning,
                autofocus: existing == null,
                decoration: const InputDecoration(
                  labelText: 'Confirmed Bengali meaning',
                  hintText: 'বাংলা অর্থ লিখুন',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: definition,
                decoration: const InputDecoration(labelText: 'English definition · optional'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: part,
                decoration: const InputDecoration(labelText: 'Part of speech · optional'),
              ),
              const SizedBox(height: 10),
              Text(
                'Machine suggestions are unverified. Edit the meaning for this article context before saving.',
                style: context.texts.labelSmall,
              ),
              if (suggestionError != null) ...<Widget>[
                const SizedBox(height: 6),
                Text(suggestionError!, style: context.texts.labelSmall?.copyWith(color: context.colors.error)),
              ],
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: suggesting
                    ? null
                    : () async {
                        setState(() {
                          suggesting = true;
                          suggestionError = null;
                        });
                        try {
                          final String value = await translator.translate(normalized);
                          meaning.text = value;
                        } on TranslationException catch (error) {
                          suggestionError = error.message;
                        } catch (_) {
                          suggestionError = 'A suggestion is unavailable. You can still enter a meaning.';
                        }
                        setState(() => suggesting = false);
                      },
                icon: suggesting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      )
                    : const Icon(Icons.translate_rounded),
                label: const Text('Suggest meaning'),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.strings.cancel),
          ),
          FilledButton(
            onPressed: () async {
              if (meaning.text.trim().isEmpty) {
                return;
              }
              await saved.saveVocabulary(VocabularyEntry(
                word: existing?.word ?? word.trim(),
                meaningBn: meaning.text.trim(),
                definitionEn: definition.text.trim().isEmpty ? null : definition.text.trim(),
                partOfSpeech: part.text.trim().isEmpty ? null : part.text.trim(),
                articleTitle: existing?.articleTitle ?? articleTitle,
                articleUrl: existing?.articleUrl ?? articleUrl,
                sourceName: existing?.sourceName ?? sourceName,
                savedAt: existing?.savedAt ?? DateTime.now().toUtc(),
              ));
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  meaning.dispose();
  definition.dispose();
  part.dispose();
}

void showVocabularyMeaning(BuildContext context, VocabularyEntry entry) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(Tokens.gutter, 0, Tokens.gutter, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(entry.word, style: context.texts.titleLarge),
          const SizedBox(height: 8),
          Text(entry.meaningBn, style: context.texts.bodyLarge),
          if (entry.definitionEn != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(entry.definitionEn!, style: context.texts.bodySmall),
          ],
        ],
      ),
    ),
  );
}

class VocabularyList extends StatefulWidget {
  const VocabularyList({super.key, required this.translator});
  final MachineTranslator translator;

  @override
  State<VocabularyList> createState() => _VocabularyListState();
}

class _VocabularyListState extends State<VocabularyList> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final SavedController saved = context.watch<SavedController>();
    final List<VocabularyEntry> entries = saved.vocabulary.where((VocabularyEntry entry) {
      final String query = _query.trim().toLowerCase();
      return query.isEmpty ||
          entry.word.toLowerCase().contains(query) ||
          entry.meaningBn.contains(query);
    }).toList(growable: false);
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(Tokens.gutter, 12, Tokens.gutter, 4),
          child: TextField(
            onChanged: (String value) => setState(() => _query = value),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Search vocabulary',
            ),
          ),
        ),
        Expanded(
          child: entries.isEmpty
              ? const EmptyState(
                  icon: Icons.spellcheck_rounded,
                  title: 'No saved vocabulary',
                  body: 'Select an English word in Reading Mode to save a confirmed Bengali meaning.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(Tokens.gutter, 8, Tokens.gutter, 130),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (BuildContext context, int index) {
                    final VocabularyEntry entry = entries[index];
                    return GlassPanel(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(entry.word, style: context.texts.titleMedium),
                                const SizedBox(height: 3),
                                Text(entry.meaningBn, style: context.texts.bodyMedium),
                                if (entry.partOfSpeech != null)
                                  Text(entry.partOfSpeech!, style: context.texts.labelSmall),
                                if (entry.sourceName != null || entry.articleTitle != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 5),
                                    child: Text(
                                      <String>[
                                        if (entry.sourceName != null) entry.sourceName!,
                                        if (entry.articleTitle != null) entry.articleTitle!,
                                      ].join(' · '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.texts.labelSmall,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Edit',
                            onPressed: () => showVocabularyEditor(
                              context,
                              word: entry.word,
                              translator: widget.translator,
                            ),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: context.strings.clear,
                            onPressed: () => saved.removeVocabulary(entry.word),
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
