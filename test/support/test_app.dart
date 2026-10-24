import 'package:bangladesh_newspaper_hub/core/l10n/app_strings.dart';
import 'package:bangladesh_newspaper_hub/data/models/app_preferences.dart';
import 'package:bangladesh_newspaper_hub/data/models/article.dart';
import 'package:bangladesh_newspaper_hub/data/models/news_source.dart';
import 'package:bangladesh_newspaper_hub/data/services/article_repository.dart';
import 'package:bangladesh_newspaper_hub/data/services/stores.dart';
import 'package:bangladesh_newspaper_hub/services/connectivity_service.dart';
import 'package:bangladesh_newspaper_hub/services/preferences_store.dart';
import 'package:bangladesh_newspaper_hub/state/feed_controller.dart';
import 'package:bangladesh_newspaper_hub/state/saved_controller.dart';
import 'package:bangladesh_newspaper_hub/state/settings_controller.dart';
import 'package:bangladesh_newspaper_hub/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'fakes.dart';

/// Connectivity stub: tests default to "online" but can force offline mode.
class FakeConnectivity implements ConnectivityService {
  FakeConnectivity({this.online = true});

  bool online;

  @override
  Future<bool> isOnline() async => online;
}

class TestHarness {
  TestHarness({
    SourceRegistry? registry,
    AppPreferences prefs = const AppPreferences(),
    AppStores? stores,
    FakeFeedGateway? gateway,
    bool online = true,
  })  : registry = registry ?? testRegistry(),
        stores = stores ?? fakeStores(),
        gateway = gateway ?? FakeFeedGateway() {
    settings = SettingsController(
      initial: prefs,
      store: InMemoryPreferencesStore(prefs.encode()),
    );
    repository = ArticleRepository(
      registry: this.registry,
      stores: this.stores,
      feedService: this.gateway,
    );
    feed = FeedController(
      repository: repository,
      settings: settings,
      registry: this.registry,
      connectivity: FakeConnectivity(online: online),
      // Widget tests assert on rendered state; the periodic refresh timer is
      // covered by its own test instead of arming one in every test.
      backgroundRefresh: false,
    );
    saved = SavedController(repository: repository, settings: settings);
    // The controllers are app-scoped in production, so nothing else disposes
    // them; in a test the periodic refresh timer would otherwise outlive the
    // widget tree and fail teardown.
    addTearDown(() {
      feed.dispose();
      saved.dispose();
      settings.dispose();
    });
  }

  final SourceRegistry registry;
  final AppStores stores;
  final FakeFeedGateway gateway;
  late final SettingsController settings;
  late final ArticleRepository repository;
  late final FeedController feed;
  late final SavedController saved;

  List<SingleChildWidget> get providers => <SingleChildWidget>[
        ChangeNotifierProvider<SettingsController>.value(value: settings),
        ChangeNotifierProvider<FeedController>.value(value: feed),
        ChangeNotifierProvider<SavedController>.value(value: saved),
        Provider<ArticleRepository>.value(value: repository),
        Provider<SourceRegistry>.value(value: registry),
      ];

  /// Pumps [child] inside the full app chrome (strings, motion, theme).
  Widget wrap(Widget child, {Brightness brightness = Brightness.light}) {
    return MultiProvider(
      providers: providers,
      child: Builder(
        builder: (BuildContext context) {
          return AnimatedBuilder(
            animation: settings,
            builder: (BuildContext context, Widget? _) {
              return AppStringsScope(
                strings: settings.strings,
                child: AppMotionScope(
                  reduceMotion: true,
                  child: MaterialApp(
                    debugShowCheckedModeBanner: false,
                    theme: brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
                    // Screens are always mounted inside a Scaffold in the app
                    // (AppShell), so the harness mirrors that.
                    home: Scaffold(body: child),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Small registry used by widget tests (two sources, one Bengali one English).
SourceRegistry testRegistry({List<Article> articles = const <Article>[]}) {
  return SourceRegistry(
    sources: <NewsSource>[
      sampleSource(),
      sampleSource(
        id: 'daily_star',
        name: 'The Daily Star',
        nameBn: 'দ্য ডেইলি স্টার',
        website: 'https://www.thedailystar.net/',
        feedUrl: 'https://www.thedailystar.net/rss/all',
        language: SourceLanguage.en,
        categories: const <SourceCategory>[SourceCategory.english],
      ),
      sampleSource(
        id: 'bonik_barta',
        name: 'Bonik Barta',
        nameBn: 'বণিক বার্তা',
        website: 'https://www.bonikbarta.com/',
        feedUrl: null,
        categories: const <SourceCategory>[SourceCategory.business],
      ),
    ],
    epapers: <EpaperEdition>[
      const EpaperEdition(
        id: 'epaper_prothomalo',
        sourceId: 'prothomalo',
        name: 'Prothom Alo E-Paper',
        nameBn: 'প্রথম আলো ই-পেপার',
        url: 'https://epaper.prothomalo.com/',
      ),
    ],
    updatedAt: DateTime.utc(2026, 10, 24),
    about: 'Test registry',
  );
}
