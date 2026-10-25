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
      child: AppMotionScope(
        reduceMotion: settings.reduceMotion,
        child: MaterialApp(
          title: 'Amar News',
          debugShowCheckedModeBanner: false,
          themeMode: settings.themeMode,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          home: const AppShell(),
          builder: (BuildContext context, Widget? child) {
            // Clamp the OS font scale so the editorial grid stays intact on
            // devices with extreme accessibility settings.
            final MediaQueryData data = MediaQuery.of(context);
            final double scale = data.textScaler.scale(14) / 14;
            return MediaQuery(
              data: data.copyWith(
                textScaler: TextScaler.linear(scale.clamp(0.85, 1.6)),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
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
