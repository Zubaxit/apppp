import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:provider/provider.dart';

import '../../core/extensions.dart';
import '../../data/models/app_preferences.dart';
import '../../services/fallback_translation.dart';
import '../../services/machine_translation.dart';
import '../../state/feed_controller.dart';
import '../../state/saved_controller.dart';
import '../../state/settings_controller.dart';
import '../../theme/materials.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../helpers/app_nav.dart';
import 'about_screen.dart';

Future<void> _prepareOfflineTranslation(BuildContext context) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final bool bengali = context.isBengali;
  messenger.showSnackBar(SnackBar(
    content: Text(bengali
        ? 'অফলাইন অনুবাদ প্রস্তুত করা হচ্ছে…'
        : 'Preparing offline translation…'),
  ));
  final MlKitOnDeviceTranslationEngine engine =
      MlKitOnDeviceTranslationEngine();
  try {
    await engine.prepare();
    messenger.showSnackBar(SnackBar(
      content: Text(bengali
          ? 'ইংরেজি ও বাংলা অফলাইন অনুবাদ প্রস্তুত।'
          : 'Offline English and Bengali translation is ready.'),
    ));
  } on TranslationException catch (_) {
    messenger.showSnackBar(SnackBar(
      content: Text(bengali
          ? 'অনুবাদের ভাষা ফাইল ডাউনলোড করা যায়নি। সংযোগ দেখে আবার চেষ্টা করুন।'
          : 'Translation files could not be downloaded. Check your connection and try again.'),
    ));
  } finally {
    await engine.close();
  }
}

/// Settings, composed as a short stack of glass panels.
///
/// Every control animates: the switches are springy glass toggles, the
/// selectors slide a capsule rather than swapping a border, and the rows respond
/// to touch. Section titles are upper-case so the page scans as three clear
/// groups instead of a long list.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.ultraLightKey});

  final Key? ultraLightKey;

  static const String appVersion = '1.2.0 (3)';

  @override
  Widget build(BuildContext context) {
    final SettingsController settings = context.watch<SettingsController>();
    final FeedController feed = context.watch<FeedController>();
    final SavedController saved = context.watch<SavedController>();
    final bool bengali = context.isBengali;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AuroraBackdrop(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: <Widget>[
            SliverAppBar(
              pinned: true,
              toolbarHeight: 62,
              automaticallyImplyLeading: false,
              backgroundColor: context.theme.scaffoldBackgroundColor,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              titleSpacing: Tokens.gutter,
              title: Text(
                context.strings.settingsTitle,
                style: context.texts.titleLarge?.copyWith(
                  fontFamily: Tokens.serif,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _SectionTitle(settings.strings.appearance),
                  _Panel(
                    children: <Widget>[
                      _Row(
                        label: context.strings.theme,
                        child: _Choice<AppThemeChoice>(
                          values: AppThemeChoice.values,
                          selected: settings.prefs.theme,
                          labelOf: (AppThemeChoice value) => switch (value) {
                            AppThemeChoice.system =>
                              context.strings.themeSystem,
                            AppThemeChoice.light => context.strings.themeLight,
                            AppThemeChoice.dark => context.strings.themeDark,
                          },
                          onSelected: settings.setTheme,
                        ),
                      ),
                      const _PanelDivider(),
                      _Row(
                        label: context.strings.appLanguage,
                        child: _Choice<AppLanguage>(
                          values: AppLanguage.values,
                          selected: settings.prefs.language,
                          labelOf: (AppLanguage value) =>
                              value == AppLanguage.bn
                                  ? context.strings.bengali
                                  : 'English',
                          onSelected: settings.setLanguage,
                        ),
                      ),
                      const _PanelDivider(),
                      _FontRow(settings: settings, bengali: bengali),
                      const _PanelDivider(),
                      _TextScaleRow(settings: settings, bengali: bengali),
                      const _PanelDivider(),
                      _ToggleRow(
                        title: context.strings.reduceMotion,
                        subtitle: bengali
                            ? 'সিস্টেম সেটিংসকেও সম্মান করা হয়'
                            : 'System settings are respected too',
                        value: settings.reduceMotion,
                        onChanged: settings.setReduceMotion,
                      ),
                      const _PanelDivider(),
                      _ToggleRow(
                        key: ultraLightKey,
                        title: bengali
                            ? 'আল্ট্রা-লাইট পারফরম্যান্স'
                            : 'Ultra-Light performance',
                        subtitle: bengali
                            ? 'ব্লার, ভারী ছায়া ও সাজসজ্জার অ্যানিমেশন কমায়'
                            : 'Reduces blur, heavy shadows and decorative animation',
                        value: settings.ultraLightMode,
                        onChanged: settings.setUltraLightMode,
                      ),
                      const _PanelDivider(),
                      _ToggleRow(
                        title: context.strings.breakingBannerToggle,
                        subtitle: context.strings.breakingBannerBody,
                        value: settings.breakingBannerEnabled,
                        onChanged: settings.setBreakingBannerEnabled,
                      ),
                    ],
                  ),
                  _SectionTitle(settings.strings.feedPreferences),
                  _Panel(
                    children: <Widget>[
                      _Row(
                        label: context.strings.defaultFeed,
                        child: _Choice<DefaultFeed>(
                          values: DefaultFeed.values,
                          selected: settings.defaultFeed,
                          labelOf: (DefaultFeed value) {
                            final bool narrow =
                                MediaQuery.sizeOf(context).width < 380;
                            if (value == DefaultFeed.latest) {
                              return narrow
                                  ? (bengali ? 'সর্বশেষ' : 'Latest')
                                  : context.strings.latestFeed;
                            }
                            return narrow
                                ? (bengali ? 'অনুসরণ' : 'Following')
                                : context.strings.followingFeed;
                          },
                          onSelected: (DefaultFeed value) async {
                            await settings.setDefaultFeed(value);
                            if (context.mounted) {
                              await context
                                  .read<FeedController>()
                                  .onSettingsChanged();
                            }
                          },
                        ),
                      ),
                      const _PanelDivider(),
                      _Row(
                        label: context.strings.autoRefresh,
                        child: _Choice<int>(
                          values: AppPreferences.refreshOptions,
                          selected: settings.refreshMinutes,
                          labelOf: (int minutes) => bengali
                              ? '${_bnNumber(minutes)} মি.'
                              : '${minutes}m',
                          onSelected: (int value) async {
                            await settings.setRefreshMinutes(value);
                            if (context.mounted) {
                              await context
                                  .read<FeedController>()
                                  .onSettingsChanged();
                            }
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          bengali
                              ? 'অ্যাপে ফিরে এলে কতক্ষণ পর নতুন খবর খোঁজা হবে তা বেছে নিন।'
                              : 'Choose how soon the app checks for new stories when you return.',
                          style: context.texts.labelSmall?.copyWith(
                            fontSize: 10,
                            height: 1.55,
                          ),
                        ),
                      ),
                    ],
                  ),
                  _SectionTitle(
                    bengali ? 'পড়ার সহায়তা' : 'Reading tools',
                  ),
                  _Panel(
                    children: <Widget>[
                      _ToggleRow(
                        title:
                            bengali ? 'শব্দ সংরক্ষণ' : 'Word Save & Vocabulary',
                        subtitle: bengali
                            ? 'ওয়েবপৃষ্ঠা ও রিডিং মোডে শব্দ সংরক্ষণ করুন'
                            : 'Save words from webpages and Reading Mode',
                        value: settings.vocabularyIntegrationEnabled,
                        onChanged: settings.setVocabularyIntegrationEnabled,
                      ),
                      const _PanelDivider(),
                      _ToggleRow(
                        title: bengali ? 'শুনুন' : 'Text to speech',
                        subtitle: bengali
                            ? 'নির্বাচিত লেখা ও নিবন্ধ শুনুন'
                            : 'Read selected text and articles aloud',
                        value: settings.ttsIntegrationEnabled,
                        onChanged: settings.setTtsIntegrationEnabled,
                      ),
                      const _PanelDivider(),
                      _ToggleRow(
                        title: bengali ? 'অনুবাদ' : 'Translation',
                        subtitle: bengali
                            ? 'নির্বাচিত লেখা ও রিডিং মোডে অনুবাদ দেখুন'
                            : 'Translate selections and Reading Mode text',
                        value: settings.translationIntegrationEnabled,
                        onChanged: settings.setTranslationIntegrationEnabled,
                      ),
                    ],
                  ),
                  _SectionTitle(settings.strings.dataAndStorage),
                  _Panel(
                    children: <Widget>[
                      _ToggleRow(
                        title: context.strings.newsShield,
                        subtitle: context.strings.newsShieldBody,
                        value: settings.newsShieldEnabled,
                        onChanged: settings.setNewsShieldEnabled,
                      ),
                      const _PanelDivider(),
                      _ToggleRow(
                        title: context.strings.historyToggle,
                        subtitle: context.strings.historyToggleBody,
                        value: settings.historyEnabled,
                        onChanged: (bool value) async {
                          final SavedController controller =
                              context.read<SavedController>();
                          await settings.setHistoryEnabled(value);
                          if (!value) await controller.clearHistory();
                        },
                      ),
                      const _PanelDivider(),
                      _ActionRow(
                        icon: Icons.translate_rounded,
                        title: bengali
                            ? 'অফলাইন অনুবাদ প্রস্তুত করুন'
                            : 'Prepare offline translation',
                        subtitle: bengali
                            ? 'ইংরেজি ও বাংলা ভাষার ফাইল ডাউনলোড করুন'
                            : 'Download English and Bengali language files',
                        onTap: () => _prepareOfflineTranslation(context),
                      ),
                      const _PanelDivider(),
                      _ActionRow(
                        icon: Icons.cleaning_services_outlined,
                        title: context.strings.clearCache,
                        subtitle: context.strings.clearCacheBody,
                        trailing: bengali
                            ? '${_bnNumber(feed.articles.length)}টি খবর'
                            : '${feed.articles.length}',
                        onTap: () => _confirmClearCache(context),
                      ),
                      const _PanelDivider(),
                      _ActionRow(
                        icon: Icons.history_rounded,
                        title: context.strings.historyTitle,
                        subtitle: bengali
                            ? '${_bnNumber(saved.history.length)}টি খবর সংরক্ষিত'
                            : '${saved.history.length} stories stored',
                        onTap: saved.history.isEmpty
                            ? null
                            : () async {
                                await context
                                    .read<SavedController>()
                                    .clearHistory();
                                if (!context.mounted) return;
                                context.showSnack(context.strings.cacheCleared);
                              },
                      ),
                    ],
                  ),
                  _SectionTitle(settings.strings.aboutPrivacy),
                  _Panel(
                    children: <Widget>[
                      _ActionRow(
                        icon: Icons.monitor_heart_outlined,
                        title: context.strings.sourceHealth,
                        subtitle: context.strings.sourceHealthBody,
                        onTap: () => openSourceHealth(context),
                      ),
                      const _PanelDivider(),
                      _ActionRow(
                        icon: Icons.info_outline_rounded,
                        title: context.strings.aboutPrivacy,
                        subtitle: '${context.strings.version} $appVersion',
                        onTap: () => Navigator.of(context).push<void>(
                          editorialRoute<void>(const AboutScreen(),
                              name: 'about'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: Tokens.gutter),
                    child: Text(
                      context.strings.publisherNotice,
                      style: context.texts.labelSmall?.copyWith(
                        fontSize: 10,
                        height: 1.65,
                        color: context.colors.onSurfaceVariant
                            .withValues(alpha: 0.9),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      '${context.strings.appName} · v$appVersion',
                      style: context.texts.labelSmall?.copyWith(fontSize: 9.5),
                    ),
                  ),
                  const SizedBox(height: 140),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClearCache(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(context.strings.clearCache),
        content: Text(context.strings.clearCacheBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.strings.clear),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await context.read<FeedController>().clearCache();
      await DefaultCacheManager().emptyCache();
      PaintingBinding.instance.imageCache
        ..clear()
        ..clearLiveImages();
      if (!context.mounted) return;
      context.showSnack(context.strings.cacheCleared);
    } catch (_) {
      if (!context.mounted) return;
      context.showSnack(
        context.isBengali
            ? 'সব অস্থায়ী ফাইল পরিষ্কার করা যায়নি। পরে আবার চেষ্টা করুন।'
            : 'Some temporary files could not be cleared. Try again later.',
      );
    }
  }

  static String _bnNumber(int value) {
    const List<String> digits = <String>[
      '০',
      '১',
      '২',
      '৩',
      '৪',
      '৫',
      '৬',
      '৭',
      '৮',
      '৯'
    ];
    return '$value'.split('').map((String c) {
      final int? digit = int.tryParse(c);
      return digit == null ? c : digits[digit];
    }).join();
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(Tokens.gutter + 4, 22, Tokens.gutter, 9),
      child: Eyebrow(title),
    );
  }
}

/// A glass panel that groups related rows.
class _Panel extends StatelessWidget {
  const _Panel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Tokens.gutter),
      child: GlassPanel(
        radius: Tokens.radiusMd,
        blur: 0,
        elevation: 0.5,
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      ),
    );
  }
}

class _PanelDivider extends StatelessWidget {
  const _PanelDivider();

  @override
  Widget build(BuildContext context) => const SoftRule(opacity: 0.7);
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool stacked = constraints.maxWidth < 390 ||
            MediaQuery.textScalerOf(context).scale(14) > 16.5;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(label, style: context.texts.labelLarge),
                    const SizedBox(height: 8),
                    child,
                  ],
                )
              : Row(
                  children: <Widget>[
                    Expanded(
                      flex: 4,
                      child: Text(label, style: context.texts.labelLarge),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 6,
                      child: child,
                    ),
                  ],
                ),
        );
      },
    );
  }
}

/// A segmented control that slides a capsule under the active choice.
class _Choice<T> extends StatelessWidget {
  const _Choice({
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final Motion motion = Motion.of(context);
    final bool dark = context.isDark;
    final int index = values.indexOf(selected).clamp(0, values.length - 1);
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Tokens.radiusPill),
        color: dark
            ? Colors.black.withValues(alpha: 0.28)
            : Colors.black.withValues(alpha: 0.05),
      ),
      child: Stack(
        children: <Widget>[
          AnimatedAlign(
            duration: motion.reduce
                ? Duration.zero
                : const Duration(milliseconds: 340),
            curve: Curves.easeOutBack,
            alignment: Alignment(
              values.length == 1 ? 0 : -1 + (2 / (values.length - 1)) * index,
              0,
            ),
            child: FractionallySizedBox(
              widthFactor: 1 / values.length,
              child: Container(
                key: ValueKey<String>('choice-selected-$index'),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Tokens.radiusPill),
                  color: context.colors.primary.withValues(
                    alpha: dark ? 0.24 : 0.13,
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: <Widget>[
              for (final T value in values)
                Expanded(
                  child: JellySurface(
                    onTap: () => onSelected(value),
                    scale: 0.93,
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 180),
                        textAlign: TextAlign.center,
                        style: context.texts.labelSmall!.copyWith(
                          fontSize: 10.8,
                          fontWeight: value == selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: value == selected
                              ? context.colors.onSurface
                              : context.colors.onSurfaceVariant,
                        ),
                        child: Text(
                          labelOf(value),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return JellySurface(
      onTap: () => onChanged(!value),
      scale: 0.995,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: context.texts.labelLarge),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: context.texts.labelSmall
                        ?.copyWith(fontSize: 10, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            JellySwitch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return JellySurface(
      onTap: onTap,
      scale: 0.995,
      enabled: onTap != null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: <Widget>[
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.colors.primary.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(Tokens.radiusXs),
              ),
              child: Icon(icon, size: 16, color: context.colors.primary),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: context.texts.labelLarge),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.labelSmall
                        ?.copyWith(fontSize: 10, height: 1.4),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: context.texts.labelSmall?.copyWith(fontSize: 10),
              ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: context.colors.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}

class _FontRow extends StatelessWidget {
  const _FontRow({required this.settings, required this.bengali});

  final SettingsController settings;
  final bool bengali;

  String _label(AppFontChoice value) => switch (value) {
        AppFontChoice.system => bengali ? 'সিস্টেমের ডিফল্ট' : 'System default',
        AppFontChoice.notoSans => 'Noto Sans Bengali',
        AppFontChoice.notoSerif => 'Noto Serif Bengali',
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          bengali ? 'অ্যাপের ফন্ট' : 'App font',
          style: context.texts.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: <Widget>[
            for (final AppFontChoice value in AppFontChoice.values)
              GlassChip(
                label: _label(value),
                icon: value == AppFontChoice.system
                    ? Icons.phone_android_rounded
                    : Icons.text_fields_rounded,
                selected: settings.font == value,
                dense: true,
                onTap: () => settings.setFont(value),
              ),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          bengali
              ? 'সিস্টেম ফন্ট না থাকলে Android বাংলা-সমর্থিত নেটিভ ফলব্যাক ব্যবহার করে।'
              : 'Android supplies its native Bengali fallback when the system font needs it.',
          style:
              context.texts.labelSmall?.copyWith(fontSize: 9.5, height: 1.45),
        ),
      ],
    );
  }
}

class _TextScaleRow extends StatelessWidget {
  const _TextScaleRow({required this.settings, required this.bengali});

  final SettingsController settings;
  final bool bengali;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Text(context.strings.textSize, style: context.texts.labelLarge),
            const Spacer(),
            Text(
              '${(settings.textScale * 100).round()}%',
              style: context.texts.labelSmall?.copyWith(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: context.colors.primary,
              ),
            ),
          ],
        ),
        SizedBox(
          height: 28,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              value: settings.textScale,
              min: AppPreferences.textScaleSteps.first,
              max: AppPreferences.textScaleSteps.last,
              divisions: AppPreferences.textScaleSteps.length - 1,
              onChanged: settings.setTextScale,
              onChangeEnd: (_) => Haptics.tick(),
            ),
          ),
        ),
        Text(
          settings.strings.appTagline,
          style: context.texts.headlineSmall?.copyWith(
            fontSize: 16,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}
