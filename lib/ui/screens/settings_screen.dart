import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/extensions.dart';
import '../../data/models/app_preferences.dart';
import '../../state/feed_controller.dart';
import '../../state/saved_controller.dart';
import '../../state/settings_controller.dart';
import '../helpers/app_nav.dart';
import 'about_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const String appVersion = '1.1.0 (2)';

  @override
  Widget build(BuildContext context) {
    final SettingsController settings = context.watch<SettingsController>();
    final FeedController feed = context.watch<FeedController>();
    final SavedController saved = context.watch<SavedController>();
    final bool bengali = context.isBengali;

    return Scaffold(
      appBar: AppBar(title: Text(context.strings.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: <Widget>[
          _SectionTitle(settings.strings.appearance),
          _Card(
            children: <Widget>[
              _LabeledRow(
                label: context.strings.theme,
                child: SegmentedButton<AppThemeChoice>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  segments: <ButtonSegment<AppThemeChoice>>[
                    ButtonSegment<AppThemeChoice>(
                      value: AppThemeChoice.system,
                      label: Text(context.strings.themeSystem,
                          style: context.texts.labelSmall),
                    ),
                    ButtonSegment<AppThemeChoice>(
                      value: AppThemeChoice.light,
                      label: Text(context.strings.themeLight,
                          style: context.texts.labelSmall),
                    ),
                    ButtonSegment<AppThemeChoice>(
                      value: AppThemeChoice.dark,
                      label: Text(context.strings.themeDark,
                          style: context.texts.labelSmall),
                    ),
                  ],
                  selected: <AppThemeChoice>{settings.prefs.theme},
                  onSelectionChanged: (Set<AppThemeChoice> value) =>
                      settings.setTheme(value.first),
                ),
              ),
              const Divider(height: 22),
              _LabeledRow(
                label: context.strings.appLanguage,
                child: SegmentedButton<AppLanguage>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  segments: <ButtonSegment<AppLanguage>>[
                    ButtonSegment<AppLanguage>(
                      value: AppLanguage.bn,
                      label: Text(context.strings.bengali, style: context.texts.labelSmall),
                    ),
                    ButtonSegment<AppLanguage>(
                      value: AppLanguage.en,
                      label: Text('English', style: context.texts.labelSmall),
                    ),
                  ],
                  selected: <AppLanguage>{settings.prefs.language},
                  onSelectionChanged: (Set<AppLanguage> value) =>
                      settings.setLanguage(value.first),
                ),
              ),
              const Divider(height: 22),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(context.strings.textSize, style: context.texts.labelLarge),
                      const Spacer(),
                      Text(
                        '${(settings.textScale * 100).round()}%',
                        style: context.texts.labelSmall,
                      ),
                    ],
                  ),
                  Text(context.strings.textSizeBody, style: context.texts.labelSmall),
                  Slider(
                    value: settings.textScale,
                    min: AppPreferences.textScaleSteps.first,
                    max: AppPreferences.textScaleSteps.last,
                    divisions: AppPreferences.textScaleSteps.length - 1,
                    onChanged: settings.setTextScale,
                  ),
                  Text(
                    bengali
                        ? 'বাংলাদেশের পত্রিকা এক জায়গায়'
                        : 'Bangladesh newspapers, in one place',
                    style: context.texts.headlineSmall?.copyWith(
                      fontSize: 17 * settings.textScale,
                    ),
                  ),
                ],
              ),
              const Divider(height: 22),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: settings.reduceMotion,
                onChanged: settings.setReduceMotion,
                title: Text(context.strings.reduceMotion, style: context.texts.labelLarge),
                subtitle: Text(
                  bengali ? 'সিস্টেম সেটিংসকেও সম্মান করা হয়' : 'System settings are respected too',
                  style: context.texts.labelSmall,
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: settings.breakingBannerEnabled,
                onChanged: settings.setBreakingBannerEnabled,
                title: Text(context.strings.breakingBannerToggle,
                    style: context.texts.labelLarge),
                subtitle: Text(context.strings.breakingBannerBody,
                    style: context.texts.labelSmall),
              ),
            ],
          ),
          _SectionTitle(settings.strings.feedPreferences),
          _Card(
            children: <Widget>[
              _LabeledRow(
                label: context.strings.defaultFeed,
                child: SegmentedButton<DefaultFeed>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  segments: <ButtonSegment<DefaultFeed>>[
                    ButtonSegment<DefaultFeed>(
                      value: DefaultFeed.latest,
                      label: Text(context.strings.latestFeed, style: context.texts.labelSmall),
                    ),
                    ButtonSegment<DefaultFeed>(
                      value: DefaultFeed.following,
                      label: Text(context.strings.followingFeed,
                          style: context.texts.labelSmall),
                    ),
                  ],
                  selected: <DefaultFeed>{settings.defaultFeed},
                  onSelectionChanged: (Set<DefaultFeed> value) async {
                    await settings.setDefaultFeed(value.first);
                    if (context.mounted) {
                      await context.read<FeedController>().onSettingsChanged();
                    }
                  },
                ),
              ),
              const Divider(height: 22),
              _LabeledRow(
                label: context.strings.autoRefresh,
                child: DropdownButton<int>(
                  value: settings.refreshMinutes,
                  isDense: true,
                  underline: const SizedBox.shrink(),
                  style: context.texts.labelMedium,
                  items: AppPreferences.refreshOptions
                      .map((int minutes) => DropdownMenuItem<int>(
                            value: minutes,
                            child: Text(
                              '${bengali ? _bnNumber(minutes) : minutes} '
                              '${context.strings.everyMinutes}',
                              style: context.texts.labelMedium,
                            ),
                          ))
                      .toList(),
                  onChanged: (int? value) async {
                    if (value == null) return;
                    await settings.setRefreshMinutes(value);
                    if (context.mounted) {
                      await context.read<FeedController>().onSettingsChanged();
                    }
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  bengali
                      ? 'অ্যাপ চালু থাকলে এই বিরতিতে ফিড আনা হয়। অ্যান্ড্রয়েড ব্যাকগ্রাউন্ডে সময় নির্দিষ্ট নয়।'
                      : 'Feeds refresh at this interval while the app is open. Android does not guarantee exact background timing.',
                  style: context.texts.labelSmall?.copyWith(fontSize: 10.5),
                ),
              ),
            ],
          ),
          _SectionTitle(settings.strings.dataAndStorage),
          _Card(
            children: <Widget>[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: settings.historyEnabled,
                onChanged: (bool value) async {
                  final SavedController saved = context.read<SavedController>();
                  await settings.setHistoryEnabled(value);
                  if (!value) await saved.clearHistory();
                },
                title: Text(context.strings.historyToggle, style: context.texts.labelLarge),
                subtitle: Text(context.strings.historyToggleBody,
                    style: context.texts.labelSmall),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.strings.clearCache, style: context.texts.labelLarge),
                subtitle: Text(context.strings.clearCacheBody, style: context.texts.labelSmall),
                trailing: Text(
                  bengali ? '${_bnNumber(feed.articles.length)}টি খবর' : '${feed.articles.length}',
                  style: context.texts.labelSmall,
                ),
                onTap: () => _confirmClearCache(context),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.strings.historyTitle, style: context.texts.labelLarge),
                subtitle: Text(
                  bengali
                      ? '${_bnNumber(saved.history.length)}টি খবর সংরক্ষিত'
                      : '${saved.history.length} stories stored',
                  style: context.texts.labelSmall,
                ),
                trailing: const Icon(Icons.delete_outline_rounded, size: 20),
                onTap: saved.history.isEmpty
                    ? null
                    : () async {
                        await context.read<SavedController>().clearHistory();
                        if (!context.mounted) return;
                        context.showSnack(context.strings.cacheCleared);
                      },
              ),
            ],
          ),
          _SectionTitle(settings.strings.aboutPrivacy),
          _Card(
            children: <Widget>[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.monitor_heart_outlined, color: context.colors.primary),
                title: Text(context.strings.sourceHealth, style: context.texts.labelLarge),
                subtitle: Text(context.strings.sourceHealthBody,
                    style: context.texts.labelSmall),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => openSourceHealth(context),
              ),
              const Divider(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.info_outline_rounded, color: context.colors.primary),
                title: Text(context.strings.aboutPrivacy, style: context.texts.labelLarge),
                subtitle: Text(
                  '${context.strings.version} $appVersion',
                  style: context.texts.labelSmall,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push<void>(
                  editorialRoute<void>(const AboutScreen(), name: 'about'),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Column(
              children: <Widget>[
                Text(
                  context.strings.publisherNotice,
                  style: context.texts.labelSmall?.copyWith(
                    fontSize: 10.5,
                    color: context.texts.labelSmall?.color?.withValues(alpha: 0.8),
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  '${context.strings.appName} · v$appVersion',
                  style: context.texts.labelSmall?.copyWith(fontSize: 10),
                ),
              ],
            ),
          ),
        ],
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
    await context.read<FeedController>().clearCache();
    if (!context.mounted) return;
    context.showSnack(context.strings.cacheCleared);
  }

  static String _bnNumber(int value) {
    const List<String> digits = <String>['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
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
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Text(
        title.toUpperCase(),
        style: context.texts.labelSmall?.copyWith(
          letterSpacing: 1.1,
          fontWeight: FontWeight.w700,
          fontSize: 10.5,
          color: context.colors.primary,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _LabeledRow extends StatelessWidget {
  const _LabeledRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: Text(label, style: context.texts.labelLarge)),
        const SizedBox(width: 8),
        Flexible(child: child),
      ],
    );
  }
}
