import 'package:bangladesh_newspaper_hub/data/models/app_preferences.dart';
import 'package:bangladesh_newspaper_hub/services/preferences_store.dart';
import 'package:bangladesh_newspaper_hub/state/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('theme and language persistence', () {
    test('fresh install is English and explicit saved languages are preserved',
        () {
      expect(AppPreferences.decode(null).language, AppLanguage.en);
      expect(
        AppPreferences.decode(
          const AppPreferences(language: AppLanguage.bn).encode(),
        ).language,
        AppLanguage.bn,
      );
      expect(
        AppPreferences.decode(
          const AppPreferences(language: AppLanguage.en).encode(),
        ).language,
        AppLanguage.en,
      );
    });

    test('a theme change is written through the store and re-read on restart',
        () async {
      final InMemoryPreferencesStore store = InMemoryPreferencesStore();
      final SettingsController controller =
          SettingsController(initial: const AppPreferences(), store: store);

      await controller.setTheme(AppThemeChoice.dark);
      expect(controller.themeMode, ThemeMode.dark);

      final String? written = await store.read();
      expect(written, isNotNull);

      // A fresh controller — the app after a restart — sees the same choice.
      final SettingsController restarted = SettingsController(
        initial: AppPreferences.decode(written),
        store: store,
      );
      expect(restarted.prefs.theme, AppThemeChoice.dark);
      expect(restarted.themeMode, ThemeMode.dark);

      controller.dispose();
      restarted.dispose();
    });

    test('font choice persists independently from the theme', () async {
      final InMemoryPreferencesStore store = InMemoryPreferencesStore();
      final SettingsController controller =
          SettingsController(initial: const AppPreferences(), store: store);

      expect(controller.font, AppFontChoice.system);
      await controller.setTheme(AppThemeChoice.dark);
      await controller.setFont(AppFontChoice.notoSerif);

      final AppPreferences restarted =
          AppPreferences.decode(await store.read());
      expect(restarted.theme, AppThemeChoice.dark);
      expect(restarted.font, AppFontChoice.notoSerif);
      controller.dispose();
    });

    test('language, motion, text scale and followed sources all persist',
        () async {
      final InMemoryPreferencesStore store = InMemoryPreferencesStore();
      final SettingsController controller =
          SettingsController(initial: const AppPreferences(), store: store);

      await controller.setLanguage(AppLanguage.en);
      await controller.setReduceMotion(true);
      await controller.setTextScale(1.2);
      await controller.toggleFollow('prothom_alo');

      final AppPreferences restarted =
          AppPreferences.decode(await store.read());
      expect(restarted.language, AppLanguage.en);
      expect(restarted.motion, MotionChoice.reduced);
      expect(restarted.textScale, closeTo(1.2, 0.001));
      expect(restarted.followedSourceIds, contains('prothom_alo'));

      controller.dispose();
    });

    test('onboarding copy is localized exactly in Bengali and English', () {
      expect(
        SettingsController(
          initial: const AppPreferences(language: AppLanguage.bn),
          store: InMemoryPreferencesStore(),
        ).strings.firstLaunchWelcomeTitle,
        'আমার নিউজে স্বাগতম!',
      );
      expect(
        SettingsController(
          initial: const AppPreferences(language: AppLanguage.en),
          store: InMemoryPreferencesStore(),
        ).strings.performanceTipTitle,
        'Want a smoother experience?',
      );
    });

    test('performance tip completion persists independently', () async {
      final InMemoryPreferencesStore store = InMemoryPreferencesStore();
      final SettingsController controller = SettingsController(
        initial: const AppPreferences(),
        store: store,
      );
      await controller.completePerformanceTip();
      expect(controller.performanceTipComplete, isTrue);
      expect(
        AppPreferences.decode(await store.read()).performanceTipComplete,
        isTrue,
      );
      controller.dispose();
    });

    test('WebView tour claim is persisted and cannot be claimed twice',
        () async {
      final InMemoryPreferencesStore store = InMemoryPreferencesStore();
      final SettingsController controller = SettingsController(
        initial: const AppPreferences(),
        store: store,
      );
      expect(controller.beginWebViewTour(), isTrue);
      expect(controller.beginWebViewTour(), isFalse);
      expect(controller.webViewTourComplete, isFalse);
      await controller.completeWebViewTour();
      expect(controller.beginWebViewTour(), isFalse);
      expect(
        AppPreferences.decode(await store.read()).webViewTourComplete,
        isTrue,
      );
      controller.dispose();
    });

    test('reading integrations and Ultra-Light mode persist independently',
        () async {
      final InMemoryPreferencesStore store = InMemoryPreferencesStore();
      final SettingsController controller = SettingsController(
        initial: const AppPreferences(),
        store: store,
      );
      await controller.setVocabularyIntegrationEnabled(false);
      await controller.setTtsIntegrationEnabled(false);
      await controller.setTranslationIntegrationEnabled(false);
      await controller.setUltraLightMode(true);

      final AppPreferences restarted =
          AppPreferences.decode(await store.read());
      expect(restarted.vocabularyIntegrationEnabled, isFalse);
      expect(restarted.ttsIntegrationEnabled, isFalse);
      expect(restarted.translationIntegrationEnabled, isFalse);
      expect(restarted.ultraLightMode, isTrue);
      controller.dispose();
    });

    test('News Shield global policy and site exceptions survive restart',
        () async {
      final InMemoryPreferencesStore store = InMemoryPreferencesStore();
      final SettingsController controller =
          SettingsController(initial: const AppPreferences(), store: store);

      expect(controller.newsShieldEnabled, isTrue);
      await controller.setShieldException('example.com', except: true);
      expect(controller.shieldEnabledFor('example.com'), isFalse);
      expect(controller.shieldEnabledFor('publisher.com'), isTrue);

      final SettingsController restarted = SettingsController(
        initial: AppPreferences.decode(await store.read()),
        store: store,
      );
      expect(restarted.newsShieldExceptions, contains('example.com'));
      await restarted.setNewsShieldEnabled(false);
      expect(restarted.shieldEnabledFor('publisher.com'), isFalse);

      controller.dispose();
      restarted.dispose();
    });

    test('an unreadable store never loses the in-session preference', () async {
      final SettingsController controller = SettingsController(
        initial: const AppPreferences(),
        store: _FailingStore(),
      );
      await controller.setTheme(AppThemeChoice.light);
      expect(controller.prefs.theme, AppThemeChoice.light);
      controller.dispose();
    });
  });
}

class _FailingStore implements PreferencesStore {
  @override
  Future<String?> read() async => throw StateError('disk unavailable');

  @override
  Future<void> write(String value) async =>
      throw StateError('disk unavailable');
}
