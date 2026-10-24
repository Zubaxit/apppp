import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

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

  /// The platform view. Tests provide a lightweight stand-in.
  Widget buildView(BuildContext context);
}

/// `webview_flutter` implementation.
///
/// JavaScript is enabled because most publisher sites need it, but nothing is
/// injected into the page, no credentials are read and no paywall, login or
/// anti-bot measure is bypassed.
class WebViewBrowserEngine extends BrowserEngine {
  WebViewBrowserEngine({required String url})
      : _url = url,
        _domain = _domainOf(url) {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
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
          },
          onPageFinished: (String value) async {
            _loading = false;
            _url = value;
            _domain = _domainOf(value);
            _canGoBack = await _controller.canGoBack();
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
      _canGoBack = await _controller.canGoBack();
      notifyListeners();
    }
  }

  @override
  Widget buildView(BuildContext context) => WebViewWidget(controller: _controller);
}
