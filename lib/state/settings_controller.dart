import 'package:flutter/material.dart';

import '../core/l10n/app_strings.dart';
import '../data/models/app_preferences.dart';
import '../data/models/article.dart';
import '../services/preferences_store.dart';

/// Owns every user preference and persists it on change.
class SettingsController extends ChangeNotifier {
  SettingsController({
    required AppPreferences initial,
    required PreferencesStore store,
  })  : _prefs = initial,
        _store = store;

  final PreferencesStore _store;
  AppPreferences _prefs;

  AppPreferences get prefs => _prefs;
  AppStrings get strings => AppStrings.forLanguage(_prefs.language);
  bool get useBengali => _prefs.isBengali;
  double get textScale => _prefs.textScale;

  ThemeMode get themeMode {
    switch (_prefs.theme) {
      case AppThemeChoice.light:
        return ThemeMode.light;
      case AppThemeChoice.dark:
        return ThemeMode.dark;
      case AppThemeChoice.system:
        return ThemeMode.system;
    }
  }

  bool isFollowing(String sourceId) => _prefs.followedSourceIds.contains(sourceId);
  Set<String> get followedSourceIds => _prefs.followedSourceIds;
  bool get historyEnabled => _prefs.historyEnabled;
  bool get breakingBannerEnabled => _prefs.breakingBannerEnabled;
  bool get reduceMotion => _prefs.motion == MotionChoice.reduced;
  int get refreshMinutes => _prefs.refreshMinutes;
  DefaultFeed get defaultFeed => _prefs.defaultFeed;

  Future<void> _update(AppPreferences next, {bool notify = true}) async {
    _prefs = next;
    if (notify) notifyListeners();
    try {
      await _store.write(next.encode());
    } catch (_) {
      // Persistence is best effort; the in-memory value stays authoritative for
      // this session so the UI never blocks on disk.
    }
  }

  Future<void> setLanguage(AppLanguage language) =>
      _update(_prefs.copyWith(language: language));

  Future<void> toggleLanguage() => setLanguage(
      _prefs.language == AppLanguage.bn ? AppLanguage.en : AppLanguage.bn);

  Future<void> setTheme(AppThemeChoice theme) => _update(_prefs.copyWith(theme: theme));

  Future<void> setTextScale(double scale) => _update(_prefs.copyWith(textScale: scale));

  Future<void> setDefaultFeed(DefaultFeed feed) =>
      _update(_prefs.copyWith(defaultFeed: feed));

  Future<void> setRefreshMinutes(int minutes) =>
      _update(_prefs.copyWith(refreshMinutes: minutes));

  Future<void> setHistoryEnabled(bool enabled) =>
      _update(_prefs.copyWith(historyEnabled: enabled));

  Future<void> setBreakingBannerEnabled(bool enabled) =>
      _update(_prefs.copyWith(breakingBannerEnabled: enabled));

  Future<void> setReduceMotion(bool reduce) => _update(
        _prefs.copyWith(motion: reduce ? MotionChoice.reduced : MotionChoice.system),
      );

  Future<void> toggleFollow(String sourceId) =>
      _update(_prefs.toggleFollow(sourceId));

  Future<void> togglePreferredTopic(ArticleTopic topic) =>
      _update(_prefs.toggleTopic(topic));

  bool isPreferredTopic(ArticleTopic topic) =>
      _prefs.preferredTopics.contains(topic);

  Future<void> rememberSearch(String query) => _update(_prefs.addSearch(query));

  Future<void> clearSearchHistory() => _update(_prefs.copyWith(searchHistory: const <String>[]));

  Future<void> completeOnboarding() =>
      _update(_prefs.copyWith(onboardingComplete: true));

  Future<void> applyExtractedPreferences(AppPreferences prefs) => _update(prefs);
}
