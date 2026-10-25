import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// A deliberately small subset of EasyList/EasyPrivacy that Android WebView can
/// enforce without pretending to be a browser-extension engine.
///
/// The pinned `webview_flutter` API cannot intercept every native subresource.
/// News Shield therefore installs at page start where possible and blocks
/// JavaScript fetch/XHR/beacon/resource insertions, then applies conservative
/// cosmetic selectors. Initial parser-created subresources can escape before
/// injection; this limitation is documented and never described as complete ad
/// blocking.
class NewsShield {
  const NewsShield._();

  static const String asset = 'assets/filters/news_shield_hosts.txt';
  static const Duration updateInterval = Duration(days: 7);
  static const int maxHosts = 4000;
  static const String _cacheKey = 'news_shield_filter_cache_v1';
  static const String _updatedKey = 'news_shield_filter_updated_v1';
  static const List<String> updateUrls = <String>[
    'https://easylist.to/easylist/easylist_adservers.txt',
    'https://easylist.to/easylist/easyprivacy.txt',
  ];

  static Set<String> _hosts = <String>{};
  static DateTime? _updatedAt;

  static Set<String> get hosts => Set<String>.unmodifiable(_hosts);
  static DateTime? get updatedAt => _updatedAt;

  /// Loads local/cache rules before the first browser can be opened. Updating is
  /// explicitly background work and never delays app startup or navigation.
  static Future<void> load({AssetBundle? bundle}) async {
    final AssetBundle source = bundle ?? rootBundle;
    final String bundled = await source.loadString(asset);
    _hosts = _parse(bundled);
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? cached = prefs.getString(_cacheKey);
      final int? millis = prefs.getInt(_updatedKey);
      final Set<String> parsed = cached == null ? <String>{} : _parse(cached);
      if (parsed.length >= 50) _hosts = parsed;
      if (millis != null) {
        _updatedAt = DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
      }
      if (_updatedAt == null ||
          DateTime.now().toUtc().difference(_updatedAt!) >= updateInterval) {
        unawaited(update());
      }
    } catch (_) {
      // The validated bundled fallback remains active.
    }
  }

  /// Downloads no more than once a week. Both responses are validated before
  /// replacing the old set; any failure leaves the last-known-good list intact.
  static Future<bool> update({http.Client? client}) async {
    final http.Client transport = client ?? http.Client();
    try {
      final Set<String> next = <String>{};
      for (final String value in updateUrls) {
        final http.Response response = await transport
            .get(Uri.parse(value), headers: <String, String>{
              'Accept': 'text/plain',
              'User-Agent': 'AmarNews/1.2 NewsShield',
            })
            .timeout(const Duration(seconds: 20));
        if (response.statusCode != 200 || response.body.length < 10000) {
          return false;
        }
        next.addAll(_parse(response.body));
      }
      if (next.length < 200) return false;
      final List<String> ordered = next.toList()..sort();
      _hosts = ordered.take(maxHosts).toSet();
      _updatedAt = DateTime.now().toUtc();
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, _hosts.join('\n'));
      await prefs.setInt(_updatedKey, _updatedAt!.millisecondsSinceEpoch);
      return true;
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    } finally {
      if (client == null) transport.close();
    }
  }

  static Set<String> _parse(String text) {
    final Set<String> out = <String>{};
    final RegExp host = RegExp(
      r'^\|\|([a-z0-9][a-z0-9.-]*\.[a-z]{2,})\^(?:\$third-party)?$',
    );
    final RegExp plain = RegExp(r'^[a-z0-9][a-z0-9.-]*\.[a-z]{2,}$');
    for (final String raw in const LineSplitter().convert(text)) {
      final String line = raw.trim().toLowerCase();
      if (line.isEmpty || line.startsWith('!') || line.startsWith('@@')) {
        continue;
      }
      final RegExpMatch? match = host.firstMatch(line);
      final String? value = match?.group(1) ?? (plain.hasMatch(line) ? line : null);
      if (value == null || value.contains('..')) continue;
      out.add(value);
      if (out.length >= maxHosts) break;
    }
    return out;
  }

  static bool blocks(String requestUrl, {required String pageUrl}) {
    final Uri? request = Uri.tryParse(requestUrl);
    final Uri? page = Uri.tryParse(pageUrl);
    if (request == null || request.host.isEmpty) return false;
    if (page != null && _sameSite(request.host, page.host)) return false;
    return _matches(request.host.toLowerCase());
  }

  static bool _matches(String host) {
    String candidate = host;
    while (candidate.contains('.')) {
      if (_hosts.contains(candidate)) return true;
      candidate = candidate.substring(candidate.indexOf('.') + 1);
    }
    return false;
  }

  static bool _sameSite(String first, String second) {
    String base(String value) {
      final List<String> labels = value.toLowerCase().split('.');
      return labels.length < 2
          ? value.toLowerCase()
          : labels.sublist(labels.length - 2).join('.');
    }
    return base(first) == base(second);
  }

  /// Installs real request guards for requests initiated after the script is in
  /// place, and conservative cosmetic filtering that reclaims banner space.
  static String script({required bool enabled}) {
    final String encoded = jsonEncode(_hosts.toList(growable: false));
    return '''
(function () {
  var hosts = $encoded;
  var rules = Object.create(null);
  for (var i = 0; i < hosts.length; i++) rules[hosts[i]] = true;
  var shield = window.__amarNewsShield || {};
  shield.active = ${enabled ? 'true' : 'false'};
  shield.rules = rules;
  shield.page = location.hostname.toLowerCase();
  function base(h) { var p=h.split('.'); return p.length < 2 ? h : p.slice(-2).join('.'); }
  function blocked(value) {
    if (!shield.active) return false;
    try {
      var h = new URL(value, location.href).hostname.toLowerCase();
      if (!h || base(h) === base(shield.page)) return false;
      var c = h;
      while (c.indexOf('.') >= 0) {
        if (shield.rules[c]) return true;
        c = c.substring(c.indexOf('.') + 1);
      }
    } catch (_) {}
    return false;
  }
  shield.blocked = blocked;
  if (!shield.installed) {
    shield.installed = true;
    var originalFetch = window.fetch;
    if (originalFetch) window.fetch = function(input, init) {
      var url = typeof input === 'string' ? input : (input && input.url);
      return blocked(url) ? Promise.reject(new TypeError('Blocked by News Shield')) : originalFetch.call(this, input, init);
    };
    var originalOpen = XMLHttpRequest.prototype.open;
    XMLHttpRequest.prototype.open = function(method, url) {
      this.__amarBlocked = blocked(url);
      if (this.__amarBlocked) return;
      return originalOpen.apply(this, arguments);
    };
    var originalSend = XMLHttpRequest.prototype.send;
    XMLHttpRequest.prototype.send = function() {
      if (this.__amarBlocked) { try { this.abort(); } catch (_) {} return; }
      return originalSend.apply(this, arguments);
    };
    if (navigator.sendBeacon) {
      var originalBeacon = navigator.sendBeacon.bind(navigator);
      navigator.sendBeacon = function(url, data) { return blocked(url) ? false : originalBeacon(url, data); };
    }
    var originalAppend = Node.prototype.appendChild;
    Node.prototype.appendChild = function(node) {
      var url = node && (node.src || node.href);
      if (url && blocked(url)) return node;
      return originalAppend.call(this, node);
    };
  }
  window.__amarNewsShield = shield;
  var style = document.getElementById('amar-news-shield-style');
  if (!shield.active) { if (style) style.remove(); return 'off'; }
  if (!style) {
    style = document.createElement('style');
    style.id = 'amar-news-shield-style';
    style.textContent = [
      'iframe[src*="doubleclick.net"],iframe[src*="googlesyndication.com"]',
      '.advertisement,.advertisement-container,.ad-banner,.ads-banner',
      '#advertisement,#ad-banner,#google_ads_iframe_container',
      '[data-ad-slot],[data-ad-client]'
    ].join(',') + '{display:none!important;min-height:0!important;height:0!important;margin:0!important;padding:0!important}';
    (document.head || document.documentElement).appendChild(style);
  }
  var attrs = document.querySelectorAll('script[src],iframe[src],img[src],link[href]');
  for (var j = 0; j < attrs.length; j++) {
    var u = attrs[j].src || attrs[j].href;
    if (blocked(u)) attrs[j].remove();
  }
  return 'on';
})();
''';
  }
}
