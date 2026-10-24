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
    return uri.replace(scheme: 'https', fragment: '').toString();
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
