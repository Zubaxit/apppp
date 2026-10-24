/// Validation for every external URL the app can open.
///
/// The app never opens a URL straight from a feed without passing it through
/// [UrlSafety]. Only http(s) links with a host are allowed; `javascript:`,
/// `data:`, `file:`, `intent:` and other dangerous schemes are rejected.
class UrlSafety {
  const UrlSafety._();

  static const Set<String> _blockedSchemes = <String>{
    'javascript',
    'data',
    'file',
    'intent',
    'content',
    'blob',
    'about',
    'chrome',
    'vbscript',
  };

  static final RegExp _hostRe = RegExp(r'^[a-z0-9.-]+$');

  /// Returns a canonical https URL, or null when the input is not safe.
  static String? sanitize(String? raw, {bool allowHttp = true}) {
    if (raw == null) return null;
    var value = raw.trim();
    if (value.isEmpty) return null;
    if (value.startsWith('//')) value = 'https:$value';
    if (value.startsWith('www.')) value = 'https://$value';
    final Uri? uri = Uri.tryParse(value);
    if (uri == null) return null;
    final String scheme = uri.scheme.toLowerCase();
    if (_blockedSchemes.contains(scheme)) return null;
    if (scheme != 'https' && scheme != 'http') return null;
    if (!allowHttp && scheme != 'https') return null;
    final String host = uri.host.toLowerCase();
    if (host.isEmpty || !_hostRe.hasMatch(host)) return null;
    if (host == 'localhost' || host.startsWith('127.') || host == '0.0.0.0') {
      return null;
    }
    if (!host.contains('.')) return null;
    if (uri.userInfo.isNotEmpty) return null;
    if (!_isAllowedPath(uri.path)) return null;
    // `replace(fragment: '')` would leave a trailing '#' (an empty fragment is
    // still a fragment), so drop it explicitly.
    return uri.replace(scheme: 'https').removeFragment().toString();
  }

  static const Set<String> _trackingParams = <String>{
    'utm_source', 'utm_medium', 'utm_campaign', 'utm_term', 'utm_content',
    'utm_id', 'utm_name', 'utm_reader', 'utm_brand', 'utm_social',
    'fbclid', 'gclid', 'dclid', 'msclkid', 'mc_cid', 'mc_eid',
    'amp', 'output', 'ref', 'referrer', 'wt_mc', 'at_medium', 'at_campaign',
    's_cid', 'ito', 'share', 'fb_action_ids', 'fb_action_types',
  };

  /// Removes campaign/tracking parameters from an already-safe URL while
  /// keeping every parameter the publisher may need to resolve the article.
  static String stripTracking(String url) {
    final Uri? uri = Uri.tryParse(url);
    if (uri == null || uri.query.isEmpty) return url;
    final List<MapEntry<String, String>> kept = uri.queryParameters.entries
        .where((MapEntry<String, String> e) => !_trackingParams.contains(e.key.toLowerCase()))
        .toList();
    final String query = kept.isEmpty
        ? ''
        : '?${kept.map((MapEntry<String, String> e) => '${e.key}=${e.value}').join('&')}';
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: uri.path,
      query: query.isEmpty ? null : query.substring(1),
    ).toString();
  }

  static bool isSafe(String? raw) => sanitize(raw) != null;

  /// Used to group links by publisher host (e.g. for source attribution).
  static String? hostOf(String? raw) {
    final String? safe = sanitize(raw);
    if (safe == null) return null;
    return Uri.parse(safe).host.toLowerCase().replaceFirst('www.', '');
  }

  static bool sameHost(String? a, String? b) {
    final String? hostA = hostOf(a);
    final String? hostB = hostOf(b);
    return hostA != null && hostA == hostB;
  }

  /// Blocks paths that look like binary downloads or credential prompts.
  static bool _isAllowedPath(String path) {
    final String lower = path.toLowerCase();
    const List<String> blockedExtensions = <String>[
      '.exe', '.apk', '.dmg', '.msi', '.bat', '.cmd', '.sh', '.jar', '.scr',
    ];
    for (final String ext in blockedExtensions) {
      if (lower.endsWith(ext)) return false;
    }
    return true;
  }
}
