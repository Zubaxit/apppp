import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/utils/reader_extract.dart';
import '../../services/news_shield.dart';
import 'link_launcher.dart';
import 'reader_scripts.dart';

/// Minimal in-app browser surface.
///
/// The screen talks to this interface rather than to a plugin directly, so the
/// navigation chrome (back, reload, progress, error, external open) can be
/// widget-tested without a platform view.
abstract class BrowserEngine extends ChangeNotifier {
  String get url;
  String get domain;
  bool get loading;
  bool get canGoBack;
  String? get error;
  double get progress;

  void load(String url);
  Future<void> reload();
  Future<void> goBack();

  /// Asks the page history whether a previous document exists, and navigates to
  /// it when it does.
  ///
  /// Returns `true` only when this call actually started a history navigation —
  /// which is what the screen needs in order to decide whether Back belongs to
  /// the page or to the route. The answer comes from the platform view at call
  /// time rather than from the last notification, because history changes while
  /// a page is still loading and a cached answer is exactly what makes Back
  /// close the browser with pages still behind it.
  Future<bool> tryGoBack() async {
    if (!canGoBack) return false;
    await goBack();
    return true;
  }

  /// Re-reads the platform history. Cheap, idempotent, and called after every
  /// navigation event.
  Future<bool> syncHistory() async => canGoBack;

  /// Extracts the readable part of the loaded page, or `null` when this engine
  /// or this page cannot provide it.
  Future<ReaderDocument?> extractArticle() async => null;

  /// Installs the text-selection watcher. Empty selections are reported as an
  /// empty string so the screen can dismiss its action.
  void watchSelection(ValueChanged<String> onSelection) {}

  /// Runs a one-off translation/selection probe. Exposed for tests.
  bool get supportsReaderMode => false;

  /// Effective policy for the current site (global setting minus exception).
  bool get shieldEnabled => false;

  /// Changes protection for this live page. Implementations reload so rules are
  /// applied from the beginning of the next document.
  Future<void> setShieldEnabled(bool enabled) async {}

  /// The platform view. Tests provide a lightweight stand-in.
  Widget buildView(BuildContext context);
}

/// `webview_flutter` implementation.
///
/// JavaScript is enabled because most publisher sites need it, but nothing is
/// injected into the page, no credentials are read and no paywall, login or
/// anti-bot measure is bypassed.
class WebViewBrowserEngine extends BrowserEngine {
  WebViewBrowserEngine({required String url, bool shieldEnabled = true})
      : _url = url,
        _domain = _domainOf(url),
        _shieldEnabled = shieldEnabled {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // Publisher pages frequently rely on the WebView's default opaque canvas.
      // A transparent canvas exposed Amar News's dark surface through BBC and
      // other transparent ad/embed slots, producing gray panels and dark text
      // on dark backgrounds. Keep publisher CSS untouched and provide the
      // standards-compatible white page canvas instead.
      ..setBackgroundColor(Colors.white)
      ..addJavaScriptChannel(
        ReaderScripts.channel,
        onMessageReceived: _onPageMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int value) {
            _progress = value / 100;
            notifyListeners();
          },
          onPageStarted: (String value) {
            _loading = true;
            _error = null;
            _url = value;
            _domain = _domainOf(value);
            notifyListeners();
            unawaited(_installShield());
            // A new document means the history changed shape; read it now rather
            // than waiting for `onPageFinished`, which a slow page may delay
            // until after the user has already pressed Back.
            unawaited(_refreshHistory());
          },
          onPageFinished: (String value) async {
            _loading = false;
            _url = value;
            _domain = _domainOf(value);
            await _refreshHistory();
            await _installShield();
            await _installSelectionWatcher();
            notifyListeners();
          },
          onNavigationRequest: (NavigationRequest request) {
            final Uri? target = Uri.tryParse(request.url);
            final String scheme = target?.scheme.toLowerCase() ?? '';
            if (scheme != 'http' && scheme != 'https') {
              // Downloads, telephone, email and app links belong to a capable
              // external handler rather than failing inside the WebView.
              unawaited(LinkLauncher.open(request.url));
              return NavigationDecision.prevent;
            }
            if (_shieldEnabled &&
                NewsShield.blocks(request.url, pageUrl: _url)) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onUrlChange: (UrlChange change) {
            final String? value = change.url;
            if (value == null || value.isEmpty) return;
            _url = value;
            _domain = _domainOf(value);
            notifyListeners();
          },
          onWebResourceError: (WebResourceError value) {
            // Only main-frame failures are user-visible; ad frames fail often.
            if (value.isForMainFrame == false) return;
            _error = value.description;
            _loading = false;
            notifyListeners();
          },
        ),
      )
      ..loadRequest(Uri.parse(url));
  }

  late final WebViewController _controller;
  String _url;
  String _domain;
  bool _loading = true;
  bool _canGoBack = false;
  String? _error;
  double _progress = 0;
  bool _shieldEnabled;

  ValueChanged<String>? _onSelection;
  Future<bool>? _historyInFlight;

  void _onPageMessage(JavaScriptMessage message) {
    if (message.message.isEmpty) {
      _onSelection?.call('');
      return;
    }
    final Object? decoded = jsonDecode(message.message);
    if (decoded is! Map<String, dynamic>) return;
    final Object? text = decoded['text'];
    _onSelection?.call(text is String ? text : '');
  }

  /// Coalesces concurrent history reads: a page that fires start, finish and a
  /// history-state change in the same frame asks the platform view once.
  Future<bool> _refreshHistory() {
    final Future<bool>? pending = _historyInFlight;
    if (pending != null) return pending;
    final Future<bool> running = _controller.canGoBack().then((bool value) {
      _historyInFlight = null;
      if (value != _canGoBack) {
        _canGoBack = value;
        notifyListeners();
      }
      return value;
    }, onError: (Object error) {
      _historyInFlight = null;
      return _canGoBack;
    });
    _historyInFlight = running;
    return running;
  }

  static String _domainOf(String value) {
    final Uri? uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) return '';
    return uri.host.replaceFirst('www.', '');
  }

  @override
  String get url => _url;

  @override
  String get domain => _domain;

  @override
  bool get loading => _loading;

  @override
  bool get canGoBack => _canGoBack;

  @override
  String? get error => _error;

  @override
  double get progress => _progress;

  @override
  void load(String url) {
    _controller.loadRequest(Uri.parse(url));
  }

  @override
  Future<void> reload() async {
    _error = null;
    _loading = true;
    notifyListeners();
    await _controller.reload();
  }

  @override
  Future<void> goBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      await _refreshHistory();
      notifyListeners();
    }
  }

  @override
  Future<bool> tryGoBack() async {
    // Asked live: the cached flag can be one navigation behind while a page is
    // still committing, and that is when users press Back.
    final bool available = await _refreshHistory();
    if (!available) {
      _canGoBack = false;
      notifyListeners();
      return false;
    }
    await _controller.goBack();
    await _refreshHistory();
    notifyListeners();
    return true;
  }

  @override
  Future<bool> syncHistory() => _refreshHistory();

  @override
  bool get supportsReaderMode => true;

  @override
  Future<ReaderDocument?> extractArticle() async {
    // Extraction runs in the page, where the DOM already is, so no HTML has to
    // cross the platform channel and no second network request is made.
    await _controller.runJavaScript(ReaderScripts.installGlobals);
    final Object result =
        await _controller.runJavaScriptReturningResult(ReaderScripts.extract);
    final String raw = result is String ? result : '$result';
    return ReaderDocument.parse(raw, pageUrl: _url);
  }

  @override
  void watchSelection(ValueChanged<String> onSelection) {
    _onSelection = onSelection;
    unawaited(_installSelectionWatcher());
  }

  Future<void> _installSelectionWatcher() async {
    if (_onSelection == null) return;
    try {
      await _controller.runJavaScript(ReaderScripts.installGlobals);
      await _controller.runJavaScript(ReaderScripts.watchSelection);
    } catch (_) {
      // The page can be between documents. onPageFinished retries without
      // altering publisher markup or selection behavior.
    }
  }

  @override
  bool get shieldEnabled => _shieldEnabled;

  @override
  Future<void> setShieldEnabled(bool enabled) async {
    if (_shieldEnabled == enabled) return;
    _shieldEnabled = enabled;
    notifyListeners();
    await _controller.reload();
  }

  Future<void> _installShield() async {
    try {
      await _controller.runJavaScript(
        NewsShield.script(enabled: _shieldEnabled),
      );
    } catch (_) {
      // Some pages are between documents when onPageStarted fires. The same
      // script is attempted again onPageFinished; failure must not break load.
    }
  }

  @override
  Widget buildView(BuildContext context) =>
      WebViewWidget(controller: _controller);
}
