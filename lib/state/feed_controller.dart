import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import '../core/utils/story_matcher.dart';
import '../data/models/article.dart';
import '../data/models/feed_query.dart';
import '../data/models/news_source.dart';
import '../data/models/source_health.dart';
import '../data/services/article_repository.dart';
import '../services/connectivity_service.dart';
import 'settings_controller.dart';

typedef ComparisonIndexer = Future<Map<String, List<Article>>> Function(
  List<Article> articles,
);

Future<Map<String, List<Article>>> _backgroundComparisonIndex(
  List<Article> articles,
) =>
    Isolate.run(() => StoryMatcher.index(articles));

/// Owns the unified feed: cached articles, per-source health, refresh policy
/// and the current filter.
class FeedController extends ChangeNotifier {
  FeedController({
    required this.repository,
    required this.settings,
    required this.registry,
    required this.connectivity,
    this.backgroundRefresh = true,
    this.autoRefreshInterval = const Duration(seconds: 120),
    this.comparisonIndexer = _backgroundComparisonIndex,
  });

  final ArticleRepository repository;
  final SettingsController settings;
  final SourceRegistry registry;
  final ConnectivityService connectivity;
  final ComparisonIndexer comparisonIndexer;

  /// Whether to arm the periodic foreground refresh timer. Production keeps it
  /// on; tests that do not exercise scheduling turn it off so no timer outlives
  /// the widget tree.
  final bool backgroundRefresh;

  /// Injected at a shorter duration in timer tests; production is exactly two
  /// minutes while Home is visible and the app is resumed.
  final Duration autoRefreshInterval;

  static const int pageSize = 80;

  FeedQuery _query = const FeedQuery(limit: pageSize);
  List<Article> _articles = const <Article>[];
  Map<String, List<Article>> _related = const <String, List<Article>>{};
  Map<String, SourceHealth> _health = const <String, SourceHealth>{};
  DateTime? _lastRefreshAt;
  DateTime? _lastAttemptAt;
  bool _busy = false;
  bool _loading = true;
  bool _comparisonIndexReady = false;
  bool _offline = false;
  String? _error;
  String? _lastFailureDetail;
  RefreshReport? _lastReport;
  String? get lastFailureDetail => _lastFailureDetail;
  int _progressDone = 0;
  int _progressTotal = 0;
  Timer? _timer;
  bool _disposed = false;
  bool _pollingActive = false;
  bool _viewportAtTop = true;
  bool _updatesPending = false;
  Future<void>? _refreshInFlight;
  DateTime? _lastManualRefreshStarted;
  int _comparisonRevision = 0;

  FeedQuery get query => _query;
  List<Article> get articles => _articles;
  List<Article> relatedFor(Article article) =>
      _related[article.id] ?? const <Article>[];
  Map<String, SourceHealth> get health => _health;
  DateTime? get lastRefreshAt => _lastRefreshAt;
  bool get isRefreshing => _busy;
  bool get isLoading => _loading;
  bool get comparisonIndexReady => _comparisonIndexReady;
  bool get isOffline => _offline;
  String? get lastError => _error;
  RefreshReport? get lastReport => _lastReport;
  int get progressDone => _progressDone;
  int get progressTotal => _progressTotal;
  double get progress => _progressTotal == 0 ? 0 : _progressDone / _progressTotal;
  bool get updatesPending => _updatesPending;

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
    _notify();
    await _rebuildComparisonIndex();
    _restartTimer();
    await refreshIfStale();
    _loading = false;
    _notify();
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
      _related = const <String, List<Article>>{};
      _comparisonIndexReady = true;
      _error = 'Could not read the local cache';
      if (kDebugMode) debugPrint('Feed cache read failed: $error');
    }
    if (notify) _notify();
  }

  /// Related Coverage used to rebuild an O(n²) comparison index on the UI
  /// isolate after every filter, search and pagination change. Rebuild only
  /// when cached articles change and perform the CPU work off the frame loop.
  Future<void> _rebuildComparisonIndex() async {
    final int revision = ++_comparisonRevision;
    _comparisonIndexReady = false;
    try {
      final List<Article> pool = await repository.comparisonCandidates();
      final Map<String, List<Article>> next = await comparisonIndexer(pool);
      if (_disposed || revision != _comparisonRevision) {
        return;
      }
      _related = next;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Related Coverage index failed: $error');
      }
    } finally {
      if (!_disposed && revision == _comparisonRevision) {
        _comparisonIndexReady = true;
        _notify();
      }
    }
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

  Future<void> refresh({
    bool force = false,
    Set<String>? onlySourceIds,
    bool silent = false,
  }) {
    final Future<void>? pending = _refreshInFlight;
    if (pending != null) {
      return pending;
    }
    if (force && onlySourceIds == null) {
      final DateTime now = DateTime.now().toUtc();
      final DateTime? previous = _lastManualRefreshStarted;
      if (previous != null &&
          now.difference(previous) < const Duration(seconds: 8)) {
        return Future<void>.value();
      }
      _lastManualRefreshStarted = now;
    }
    final Future<void> operation = _performRefresh(
      force: force,
      onlySourceIds: onlySourceIds,
      silent: silent,
    );
    _refreshInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_refreshInFlight, operation)) {
        _refreshInFlight = null;
      }
    });
  }

  Future<void> _performRefresh({
    required bool force,
    required Set<String>? onlySourceIds,
    required bool silent,
  }) async {
    _busy = true;
    _progressDone = 0;
    _progressTotal = 0;
    _error = null;
    if (!silent) _notify();

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
          if (!silent) _notify();
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
      if (silent && _pollingActive && !_viewportAtTop) {
        // Keep the visible list immutable while the reader is part-way down it.
        // The cache is current; Home applies it when the reader returns to the
        // top or taps the pending-update chip.
        _updatesPending = true;
      } else {
        await _reload(notify: false);
        _updatesPending = false;
      }
      unawaited(_rebuildComparisonIndex());
    } catch (error, stack) {
      // Keep the real cause for the diagnostics sheet; the headline message
      // stays human and localized.
      _lastFailureDetail = '$error';
      _error = settings.useBengali
          ? 'খবর হালনাগাদ করা যায়নি। ইন্টারনেট সংযোগ দেখে আবার চেষ্টা করুন।'
          : 'News could not be updated. Check your connection and try again.';
      if (kDebugMode) {
        debugPrint('Refresh failed: $error');
        debugPrintStack(stackTrace: stack);
      }
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
    _related = const <String, List<Article>>{};
    _comparisonIndexReady = true;
    _notify();
  }

  void setFeedViewportAtTop(bool value) {
    _viewportAtTop = value;
  }

  Future<void> applyPendingUpdates() async {
    if (!_updatesPending) return;
    await _reload(notify: false);
    _updatesPending = false;
    _notify();
  }

  /// Called by AppShell. IndexedStack keeps Home mounted, so tab visibility
  /// must be explicit rather than inferred from widget disposal.
  void setPollingActive(bool active) {
    if (_disposed || _pollingActive == active) return;
    _pollingActive = active;
    _restartTimer();
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = null;
    if (!backgroundRefresh || !_pollingActive || _disposed) return;
    _timer = Timer.periodic(autoRefreshInterval, (Timer timer) {
      // Conditional HTTP validators and the repository's source gap prevent
      // repeated downloads. `refresh` itself is single-flight.
      unawaited(refresh(silent: true));
    });
  }

  Future<void> onSettingsChanged() async {
    await _reload();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
