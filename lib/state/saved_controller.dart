import 'package:flutter/foundation.dart';

import '../data/models/article.dart';
import '../data/models/vocabulary_entry.dart';
import '../data/services/article_repository.dart';
import 'settings_controller.dart';

/// Bookmarks and reading history.
///
/// Bookmarks keep a snapshot of the article so they survive the publisher
/// dropping the item from its feed.
class SavedController extends ChangeNotifier {
  SavedController({required this.repository, required this.settings});

  final ArticleRepository repository;
  final SettingsController settings;

  List<SavedArticle> _saved = const <SavedArticle>[];
  List<SavedArticle> _history = const <SavedArticle>[];
  List<VocabularyEntry> _vocabulary = const <VocabularyEntry>[];
  Set<String> _ids = <String>{};
  int _vocabularyRevision = 0;
  bool _loading = true;

  List<SavedArticle> get saved => _saved;
  List<SavedArticle> get history => _history;
  List<VocabularyEntry> get vocabulary => _vocabulary;
  int get vocabularyRevision => _vocabularyRevision;
  bool get isLoading => _loading;
  int get count => _saved.length;

  VocabularyEntry? vocabularyFor(String word) {
    final String normalized = VocabularyEntry.normalizeWord(word);
    for (final VocabularyEntry entry in _vocabulary) {
      if (entry.normalizedWord == normalized) return entry;
    }
    return null;
  }

  bool isSaved(String articleId) => _ids.contains(articleId);

  Future<void> load() async {
    try {
      _saved = await repository.savedArticles();
      _ids = _saved.map((SavedArticle s) => s.article.id).toSet();
      if (settings.historyEnabled) {
        _history = await repository.history();
      } else {
        _history = const <SavedArticle>[];
      }
      _vocabulary = await repository.vocabulary();
      _vocabularyRevision += 1;
    } catch (error) {
      if (kDebugMode) debugPrint('Saved load failed: $error');
      _saved = const <SavedArticle>[];
      _ids = <String>{};
    }
    _loading = false;
    notifyListeners();
  }

  Future<bool> toggle(Article article) async {
    final bool currentlySaved = _ids.contains(article.id);
    if (currentlySaved) {
      await repository.unsaveArticle(article.id);
      _ids.remove(article.id);
      _saved = _saved.where((SavedArticle s) => s.article.id != article.id).toList();
    } else {
      await repository.saveArticle(article);
      _ids.add(article.id);
      _saved = <SavedArticle>[
        SavedArticle(article: article, savedAt: DateTime.now().toUtc()),
        ..._saved,
      ];
    }
    notifyListeners();
    return !currentlySaved;
  }

  Future<void> remove(String articleId) async {
    await repository.unsaveArticle(articleId);
    _ids.remove(articleId);
    _saved = _saved.where((SavedArticle s) => s.article.id != articleId).toList();
    notifyListeners();
  }

  Future<void> recordHistory(Article article) async {
    if (!settings.historyEnabled) return;
    try {
      await repository.recordHistory(article);
      _history = <SavedArticle>[
        SavedArticle(article: article, savedAt: DateTime.now().toUtc()),
        ..._history.where((SavedArticle s) => s.article.id != article.id),
      ].take(60).toList();
      notifyListeners();
    } catch (error) {
      if (kDebugMode) debugPrint('History write failed: $error');
    }
  }

  Future<void> saveVocabulary(VocabularyEntry entry) async {
    if (entry.normalizedWord.isEmpty || entry.meaningBn.trim().isEmpty) return;
    await repository.saveVocabulary(entry);
    _vocabulary = <VocabularyEntry>[
      entry,
      ..._vocabulary.where(
        (VocabularyEntry item) =>
            item.normalizedWord != entry.normalizedWord,
      ),
    ];
    _vocabularyRevision += 1;
    notifyListeners();
  }

  Future<int> importVocabulary(
    Iterable<VocabularyEntry> imported, {
    required bool replaceConflicts,
  }) async {
    final Map<String, VocabularyEntry> local = <String, VocabularyEntry>{
      for (final VocabularyEntry entry in _vocabulary)
        entry.normalizedWord: entry,
    };
    final List<VocabularyEntry> writes = <VocabularyEntry>[];
    for (final VocabularyEntry entry in imported) {
      if (!replaceConflicts && local.containsKey(entry.normalizedWord)) {
        continue;
      }
      writes.add(entry);
      local[entry.normalizedWord] = entry;
    }
    if (writes.isEmpty) return 0;
    await repository.saveVocabularyAtomic(writes);
    _vocabulary = local.values.toList()
      ..sort((VocabularyEntry a, VocabularyEntry b) =>
          b.savedAt.compareTo(a.savedAt));
    _vocabularyRevision += 1;
    notifyListeners();
    return writes.length;
  }

  Future<void> removeVocabulary(String word) async {
    final String normalized = VocabularyEntry.normalizeWord(word);
    await repository.removeVocabulary(normalized);
    _vocabulary = _vocabulary
        .where((VocabularyEntry item) => item.normalizedWord != normalized)
        .toList(growable: false);
    _vocabularyRevision += 1;
    notifyListeners();
  }

  Future<void> clearHistory() async {
    await repository.clearHistory();
    _history = const <SavedArticle>[];
    notifyListeners();
  }

  Future<void> refreshHistory() async {
    _history = settings.historyEnabled ? await repository.history() : const <SavedArticle>[];
    notifyListeners();
  }
}
