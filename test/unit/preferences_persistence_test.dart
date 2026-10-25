import 'package:bangladesh_newspaper_hub/data/models/app_preferences.dart';
import 'package:bangladesh_newspaper_hub/services/preferences_store.dart';
import 'package:bangladesh_newspaper_hub/state/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('theme and language persistence', () {
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

    test('language, motion, text scale and followed sources all persist', () async {
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

    test('News Shield global policy and site exceptions survive restart', () async {
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
  Future<void> write(String value) async => throw StateError('disk unavailable');
}
