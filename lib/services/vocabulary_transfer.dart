import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

import '../data/models/vocabulary_entry.dart';

class VocabularyTransferException implements Exception {
  const VocabularyTransferException(this.message);
  final String message;
  @override
  String toString() => message;
}

class VocabularyImportPreview {
  const VocabularyImportPreview({
    required this.entries,
    required this.conflicts,
  });
  final List<VocabularyEntry> entries;
  final int conflicts;
}

class VocabularyTransferCodec {
  const VocabularyTransferCodec._();
  static const int version = 1;

  static String encode(Iterable<VocabularyEntry> entries) =>
      const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'format': 'amar-news-vocabulary',
        'version': version,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'entries': <Map<String, Object?>>[
          for (final VocabularyEntry entry in entries)
            <String, Object?>{
              'word': entry.word,
              'meaningBn': entry.meaningBn,
              'definitionEn': entry.definitionEn,
              'partOfSpeech': entry.partOfSpeech,
              'articleTitle': entry.articleTitle,
              'articleUrl': entry.articleUrl,
              'sourceName': entry.sourceName,
              'savedAt': entry.savedAt.toUtc().toIso8601String(),
            },
        ],
      });

  static List<VocabularyEntry> decode(String source) {
    Object? decoded;
    try {
      decoded = jsonDecode(source);
    } catch (_) {
      throw const VocabularyTransferException(
        'This file is not valid vocabulary JSON.',
      );
    }
    if (decoded is! Map<String, dynamic> ||
        decoded['format'] != 'amar-news-vocabulary' ||
        decoded['version'] is! num ||
        (decoded['version'] as num).toInt() > version ||
        decoded['entries'] is! List<dynamic>) {
      throw const VocabularyTransferException(
        'This vocabulary file format is not supported.',
      );
    }
    final Map<String, VocabularyEntry> unique = <String, VocabularyEntry>{};
    for (final Object? raw in decoded['entries'] as List<dynamic>) {
      if (raw is! Map<String, dynamic>) {
        throw const VocabularyTransferException('A vocabulary entry is malformed.');
      }
      final String word = '${raw['word'] ?? ''}'.trim();
      final String meaning = '${raw['meaningBn'] ?? ''}'.trim();
      final String normalized = VocabularyEntry.normalizeWord(word);
      final DateTime? savedAt = DateTime.tryParse('${raw['savedAt'] ?? ''}');
      if (normalized.isEmpty || meaning.isEmpty || savedAt == null) {
        throw const VocabularyTransferException(
          'A vocabulary entry is missing a word, meaning, or date.',
        );
      }
      unique[normalized] = VocabularyEntry(
        word: word,
        meaningBn: meaning,
        definitionEn: _optional(raw['definitionEn']),
        partOfSpeech: _optional(raw['partOfSpeech']),
        articleTitle: _optional(raw['articleTitle']),
        articleUrl: _optional(raw['articleUrl']),
        sourceName: _optional(raw['sourceName']),
        savedAt: savedAt.toUtc(),
      );
    }
    return unique.values.toList(growable: false);
  }

  static String? _optional(Object? value) {
    final String text = '${value ?? ''}'.trim();
    return text.isEmpty ? null : text;
  }
}

class VocabularyFileTransfer {
  const VocabularyFileTransfer._();

  static Future<bool> export(List<VocabularyEntry> entries) async {
    final FileSaveLocation? location = await getSaveLocation(
      suggestedName: 'amar-news-vocabulary.json',
      acceptedTypeGroups: const <XTypeGroup>[
        XTypeGroup(label: 'JSON', extensions: <String>['json']),
      ],
    );
    if (location == null) return false;
    final Uint8List bytes = Uint8List.fromList(
      utf8.encode(VocabularyTransferCodec.encode(entries)),
    );
    await XFile.fromData(
      bytes,
      mimeType: 'application/json',
      name: 'amar-news-vocabulary.json',
    ).saveTo(location.path);
    return true;
  }

  static Future<List<VocabularyEntry>?> pickAndDecode() async {
    const XTypeGroup json = XTypeGroup(
      label: 'JSON',
      extensions: <String>['json'],
      mimeTypes: <String>['application/json'],
    );
    final XFile? file = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[json],
    );
    if (file == null) return null;
    return VocabularyTransferCodec.decode(await file.readAsString());
  }
}
