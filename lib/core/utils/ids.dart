import 'text_utils.dart';

/// Stable identifier helpers.
///
/// Article ids must not change between refreshes, otherwise bookmarks would
/// break. We therefore derive the id from the canonical article URL (tracks
/// stripped) and fall back to the title when a feed has no usable link.
class Ids {
  const Ids._();

  static const Set<String> _trackingParams = <String>{
    'utm_source', 'utm_medium', 'utm_campaign', 'utm_term', 'utm_content',
    'utm_id', 'fbclid', 'gclid', 'amp', 'output', 'ref', 'referrer',
    'wt_mc', 'at_medium', 'at_campaign', 's_cid',
  };

  /// Removes tracking parameters, fragments and trailing slashes.
  static String canonicalUrl(String raw) {
    final Uri? uri = Uri.tryParse(raw.trim());
    if (uri == null) return raw.trim().toLowerCase();
    final Map<String, String> kept = <String, String>{};
    uri.queryParameters.forEach((String key, String value) {
      if (!_trackingParams.contains(key.toLowerCase())) kept[key] = value;
    });
    final String host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
    var path = uri.path;
    while (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    final String query = kept.isEmpty
        ? ''
        : '?${(kept.keys.toList()..sort()).map((String k) => '$k=${kept[k]}').join('&')}';
    final String scheme = uri.scheme.isEmpty ? 'https' : uri.scheme.toLowerCase();
    return '$scheme://$host$path$query';
  }

  /// 32-bit FNV-1a. Always non-negative, cheap, deterministic.
  static String _fnv32(String input, int seed) {
    var hash = seed;
    for (var i = 0; i < input.length; i++) {
      final int unit = input.codeUnitAt(i);
      hash = ((hash ^ (unit & 0xFF)) * 0x01000193) & 0xFFFFFFFF;
      if (unit > 0xFF) {
        hash = ((hash ^ (unit >> 8)) * 0x01000193) & 0xFFFFFFFF;
      }
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  /// 64-bit identifier assembled from two independent 32-bit hashes.
  static String stableHash64(String input) =>
      '${_fnv32(input, 0x811c9dc5)}${_fnv32(input, 0x01000193)}';

  static String articleId({required String sourceId, required String link, required String title}) {
    final String canonical = link.trim().isEmpty
        ? 'title:${TextUtils.compactKey(title)}'
        : canonicalUrl(link);
    return stableHash64('$sourceId|$canonical');
  }

  /// Key used to spot likely duplicate coverage of the same story.
  ///
  /// Uses the most "content-bearing" words of the headline, sorted, bucketed by
  /// the publication day. This only ever links stories for display; each story
  /// keeps its own publisher, headline and URL.
  static String? storyClusterKey(String title, DateTime? publishedAt) {
    final List<String> tokens = TextUtils.searchNormalize(title)
        .split(' ')
        .where((String t) => t.length >= 3 && !_stopWords.contains(t))
        .toList();
    if (tokens.length < 3) return null;
    final Map<String, int> unique = <String, int>{};
    for (final String token in tokens) {
      unique[token] = (unique[token] ?? 0) + 1;
    }
    final List<String> keys = unique.keys.toList()..sort();
    final String signature = keys.take(8).join('-');
    final DateTime? day = publishedAt?.toUtc();
    final String bucket = day == null
        ? 'unknown'
        : '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    return '$signature|$bucket';
  }

  static const Set<String> _stopWords = <String>{
    // English
    'the', 'and', 'for', 'with', 'from', 'that', 'this', 'has', 'have', 'was',
    'were', 'will', 'are', 'but', 'not', 'you', 'its', 'his', 'her', 'they',
    'said', 'says', 'after', 'over', 'into', 'about', 'more', 'than', 'who',
    'how', 'why', 'what', 'when', 'where', 'all', 'new', 'may', 'can', 'out',
    'amid', 'one', 'two', 'three', 'news', 'today',
    // Bengali
    'এবং', 'করে', 'করা', 'হয়', 'হয়েছে', 'থেকে', 'জন্য', 'সঙ্গে', 'কিন্তু',
    'একটি', 'এই', 'সেই', 'তিনি', 'আরও', 'বলে', 'যায়', 'হবে', 'নিয়ে', 'পর',
    'আজ', 'খবর', 'নিউজ', 'তার', 'যে', 'কে', 'ও', 'এ', 'কি',
  };
}
