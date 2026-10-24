import 'package:flutter/material.dart';

import 'app.dart';
import 'data/feeds/feed_service.dart';
import 'data/feeds/news_http_client.dart';
import 'data/models/app_preferences.dart';
import 'data/models/news_source.dart';
import 'data/services/app_database.dart';
import 'data/services/article_repository.dart';
import 'services/connectivity_service.dart';
import 'services/preferences_store.dart';
import 'services/registry_loader.dart';
import 'state/feed_controller.dart';
import 'state/saved_controller.dart';
import 'state/settings_controller.dart';

/// Wires the object graph once, with injection points for tests.
class AppBootstrap {
  AppBootstrap({
    required this.registry,
    required this.database,
    required this.repository,
    required this.settings,
    required this.feed,
    required this.saved,
    required this.httpClient,
  });

  final SourceRegistry registry;
  final AppDatabase database;
  final ArticleRepository repository;
  final SettingsController settings;
  final FeedController feed;
  final SavedController saved;
  final NewsHttpClient httpClient;

  static Future<AppBootstrap> create({
    AssetBundle? bundle,
    AppDatabase? database,
    PreferencesStore? preferencesStore,
    NewsHttpClient? httpClient,
    ConnectivityService? connectivity,
    AppPreferences? initialPreferences,
  }) async {
    final SourceRegistry registry = await RegistryLoader.load(bundle: bundle);
    final AppDatabase db = database ?? await AppDatabase.open();
    final PreferencesStore store = preferencesStore ?? await SharedPreferencesStore.create();
    final AppPreferences prefs =
        initialPreferences ?? AppPreferences.decode(await store.read());

    final SettingsController settings =
        SettingsController(initial: prefs, store: store);
    final NewsHttpClient client = httpClient ?? NewsHttpClient();
    final ArticleRepository repository = ArticleRepository(
      registry: registry,
      stores: db.stores,
      feedService: FeedService(
        httpClient: client,
        metaStore: db.stores.feedMeta,
      ),
    );
    final FeedController feed = FeedController(
      repository: repository,
      settings: settings,
      registry: registry,
      connectivity: connectivity ?? ConnectivityService(),
    );
    final SavedController saved =
        SavedController(repository: repository, settings: settings);

    return AppBootstrap(
      registry: registry,
      database: db,
      repository: repository,
      settings: settings,
      feed: feed,
      saved: saved,
      httpClient: client,
    );
  }

  Widget buildRoot() => AppProviders(
        settings: settings,
        feed: feed,
        saved: saved,
        repository: repository,
        registry: registry,
        child: const NewspaperHubApp(),
      );

  Future<void> dispose() async {
    feed.dispose();
    saved.dispose();
    settings.dispose();
    httpClient.dispose();
    await database.close();
  }
}
