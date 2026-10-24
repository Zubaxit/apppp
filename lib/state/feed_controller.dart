import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/models/article.dart';
import '../data/models/feed_query.dart';
import '../data/models/news_source.dart';
import '../data/models/source_health.dart';
import '../data/services/article_repository.dart';
import '../services/connectivity_service.dart';
import 'settings_controller.dart';

/// Owns the unified feed: cached articles, per-source health, refresh policy
/// and the current filter.
class FeedController extends ChangeNotifier {
  FeedController({
    required this.repository,
    required this.settings,
    required this.registry,
    required this.connectivity,
    this.backgroundRefresh = true,
  });

  final ArticleRepository repository;
  final SettingsController settings;
  final SourceRegistry registry;
  final ConnectivityService connectivity;

  /// Whether to arm the periodic foreground refresh timer. Production keeps it
  /// on; tests that do not exercise scheduling turn it off so no timer outlives
  /// the widget tree.
  final bool backgroundRefresh;

  static const int pageSize = 80;

  FeedQuery _query = const FeedQuery(limit: pageSize);
  List<Article> _articles = const <Article>[];
  Map<String, SourceHealth> _health = const <String, SourceHealth>{};
  DateTime? _lastRefreshAt;
  DateTime? _lastAttemptAt;
  bool _busy = false;
  bool _loading = true;
  bool _offline = false;
  String? _error;
  RefreshReport? _lastReport;
  int _progressDone = 0;
  int _progressTotal = 0;
  Timer? _timer;
  bool _disposed = false;

  FeedQuery get query => _query;
  List<Article> get articles => _articles;
  Map<String, SourceHealth> get health => _health;
  DateTime? get lastRefreshAt => _lastRefreshAt;
  bool get isRefreshing => _busy;
  bool get isLoading => _loading;
  bool get isOffline => _offline;
  String? get lastError => _error;
  RefreshReport? get lastReport => _lastReport;
  int get progressDone => _progressDone;
  int get progressTotal => _progressTotal;
  double get progress => _progressTotal == 0 ? 0 : _progressDone / _progressTotal;

  /// True when the newest cached article was fetched before the last update.
  bool get isShowingCached {
    if (_articles.isEmpty) return false;
    final DateTime newest = _articles.first.fetchedAt.toUtc();
    final DateTime? last = _lastRefreshAt;
    if (last == null) return true;
    return newest.isBefore(last.subtract(const Duration(minutes: 1)));
  }

  bool get isStale {
    final DateTime? last = _lastRefreshAt;
    if (last == null) return true;
    return DateTime.now().toUtc().difference(last).inMinutes >= settings.refreshMinutes;
  }

  List<Article> get breakingArticles {
    if (!settings.breakingBannerEnabled) return const <Article>[];
    return _articles.where((Article a) => a.breaking).take(4).toList();
  }

  SourceHealth? healthFor(String sourceId) => _health[sourceId];

  List<Article> get followedArticles {
    final Set<String> followed = settings.followedSourceIds;
    if (followed.isEmpty) return const <Article>[];
    return _articles.where((Article a) => followed.contains(a.sourceId)).toList();
  }

  Future<void> start() async {
    _lastRefreshAt = await repository.lastRefreshAt();
    _lastAttemptAt = await repository.lastAttemptAt();
    _health = await repository.healthMap();
    await _reload(notify: false);
    _loading = false;
    _notify();
    _restartTimer();
    await refreshIfStale();
  }

  Future<void> _reload({bool notify = true}) async {
    try {
      _articles = await repository.loadFeed(
        _query,
        followedSourceIds: settings.followedSourceIds,
      );
      _error = null;
    } catch (error) {
      _articles = const <Article>[];
      _error = 'Could not read the local cache';
      if (kDebugMode) debugPrint('Feed cache read failed: $error');
    }
    if (notify) _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> applyQuery(FeedQuery next) async {
    if (next == _query) return;
    _query = next.copyWith(limit: pageSize);
    await _reload();
  }

  Future<void> setFollowedOnly(bool followedOnly) async {
    await applyQuery(_query.copyWith(followedOnly: followedOnly));
  }

  Future<void> setSourceFilter(Set<String> sourceIds) async {
    await applyQuery(_query.copyWith(sourceIds: sourceIds, limit: pageSize));
  }

  Future<void> setTopicFilter(Set<ArticleTopic> topics) async {
    await applyQuery(_query.copyWith(topics: topics));
  }

  Future<void> searchArticles(String text) async {
    await applyQuery(_query.copyWith(text: text));
  }

  Future<void> loadMore() async {
    if (_articles.length < _query.limit) return;
    _query = _query.copyWith(limit: _query.limit + pageSize);
    await _reload();
  }

  /// Refresh only when the cached data is older than the configured interval.
  Future<void> refreshIfStale() async {
    if (!isStale || _busy) return;
    final DateTime? lastAttempt = _lastAttemptAt;
    if (lastAttempt != null) {
      final Duration sinceAttempt = DateTime.now().toUtc().difference(lastAttempt);
      // Guards against the user flipping between tabs in a tight loop.
      if (sinceAttempt.inSeconds < 90) return;
    }
    await refresh();
  }

  Future<void> refresh({bool force = false, Set<String>? onlySourceIds}) async {
    if (_busy) return;
    _busy = true;
    _progressDone = 0;
    _progressTotal = 0;
    _error = null;
    _notify();

    final bool online = await connectivity.isOnline();
    if (!online) {
      _offline = true;
      _busy = false;
      _lastAttemptAt = DateTime.now().toUtc();
      _notify();
      return;
    }

    try {
      final RefreshReport report = await repository.refresh(
        force: force,
        onlySourceIds: onlySourceIds,
        onProgress: (int done, int total) {
          _progressDone = done;
          _progressTotal = total;
          _notify();
        },
      );
      _lastReport = report;
      _lastAttemptAt = report.finishedAt;
      _lastRefreshAt = await repository.lastRefreshAt();
      _health = await repository.healthMap();
      _offline = false;
      if (report.sourcesSucceeded == 0 && report.sourcesFailed > 0) {
        // Per-source errors are surfaced through the health list; only a real
        // connectivity loss is reported as "offline".
        _offline = !(await connectivity.isOnline());
      }
      await _reload(notify: false);
    } catch (error) {
      _error = 'Refresh failed';
      if (kDebugMode) debugPrint('Refresh failed: $error');
    } finally {
      _busy = false;
      _loading = false;
      _notify();
    }
  }

  Future<void> refreshSource(String sourceId) async {
    await refresh(force: true, onlySourceIds: <String>{sourceId});
    await reloadCache();
  }

  Future<void> reloadCache() async {
    _lastRefreshAt = await repository.lastRefreshAt();
    _health = await repository.healthMap();
    await _reload();
  }

  Future<void> clearCache() async {
    await repository.clearCache();
    _lastRefreshAt = null;
    _articles = const <Article>[];
    _notify();
  }

  void _restartTimer() {
    _timer?.cancel();
    if (!backgroundRefresh) return;
    final int minutes = settings.refreshMinutes.clamp(15, 240);
    _timer = Timer.periodic(Duration(minutes: minutes), (Timer timer) {
      // Best-effort foreground refresh; Android may throttle or kill the app,
      // so this is not presented to the user as guaranteed background refresh.
      unawaited(refreshIfStale());
    });
  }

  Future<void> onSettingsChanged() async {
    _restartTimer();
    await _reload();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
