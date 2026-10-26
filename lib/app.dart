import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'core/l10n/app_strings.dart';
import 'data/models/app_preferences.dart';
import 'data/models/news_source.dart';
import 'data/services/article_repository.dart';
import 'state/feed_controller.dart';
import 'state/saved_controller.dart';
import 'state/settings_controller.dart';
import 'theme/app_theme.dart';
import 'theme/materials.dart';
import 'theme/motion.dart';
import 'theme/tokens.dart';
import 'ui/shell/app_shell.dart';

class NewspaperHubApp extends StatelessWidget {
  const NewspaperHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    final SettingsController settings = context.watch<SettingsController>();
    Tokens.configureFont(settings.font.family);
    return AppStringsScope(
      strings: settings.strings,
      child: AppEffectsScope(
        ultraLight: settings.ultraLightMode,
        child: AppMotionScope(
          reduceMotion: settings.reduceMotion || settings.ultraLightMode,
          child: MaterialApp(
            title: 'Amar News',
            debugShowCheckedModeBanner: false,
            themeMode: settings.themeMode,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            home: const AppShell(),
            builder: (BuildContext context, Widget? child) {
              // Apply the app preference at the root so every native Text widget
              // scales once: headlines, metadata, controls, dialogs and pages.
              // Publisher WebViews remain independent third-party documents.
              final MediaQueryData data = MediaQuery.of(context);
              final double systemScale = data.textScaler.scale(14) / 14;
              final double effectiveScale =
                  (systemScale * settings.textScale).clamp(0.85, 2.0);
              return MediaQuery(
                data: data.copyWith(
                  textScaler: TextScaler.linear(effectiveScale),
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Provider graph for the whole app, constructed once during bootstrap.
class AppProviders extends StatelessWidget {
  const AppProviders({
    super.key,
    required this.settings,
    required this.feed,
    required this.saved,
    required this.repository,
    required this.registry,
    required this.child,
  });

  final SettingsController settings;
  final FeedController feed;
  final SavedController saved;
  final ArticleRepository repository;
  final SourceRegistry registry;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<SettingsController>.value(value: settings),
        ChangeNotifierProvider<FeedController>.value(value: feed),
        ChangeNotifierProvider<SavedController>.value(value: saved),
        Provider<ArticleRepository>.value(value: repository),
        Provider<SourceRegistry>.value(value: registry),
      ],
      child: child,
    );
  }
}
