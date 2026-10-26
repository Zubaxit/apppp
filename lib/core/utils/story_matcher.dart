import '../../data/models/article.dart';
import 'text_utils.dart';

/// Deterministic, explainable grouping of coverage of the same event.
///
/// This is intentionally conservative. It requires several informative tokens,
/// a close publication-time window and strong title/description overlap. Sharing
/// only a person, organisation, place or broad topic is never enough.
class StoryMatcher {
  const StoryMatcher._();

  static const Duration window = Duration(hours: 72);
  static const Duration followUpWindow = Duration(days: 7);
  static const double threshold = 0.56;

  static const Set<String> _stop = <String>{
    'the', 'a', 'an', 'and', 'or', 'of', 'to', 'in', 'on', 'for', 'from',
    'with', 'at', 'by', 'after', 'before', 'over', 'under', 'new', 'latest',
    'today', 'says', 'said', 'news', 'report', 'বাংলাদেশ', 'ঢাকা', 'এই', 'ও',
    'এ', 'এর', 'যে', 'করে', 'করেছে', 'হয়', 'হবে', 'থেকে', 'নিয়ে', 'আরও',
    'খবর', 'সংবাদ', 'আজ', 'নতুন', 'একটি', 'জন্য',
  };

  /// Small bilingual concept bridge. It does not rewrite the headline shown to
  /// users; it only lets clearly equivalent Bangla/English event words meet.
  static const Map<String, String> _aliases = <String, String>{
    'election': 'নির্বাচন',
    'poll': 'নির্বাচন',
    'government': 'সরকার',
    'minister': 'মন্ত্রী',
    'prime': 'প্রধানমন্ত্রী',
    'president': 'রাষ্ট্রপতি',
    'court': 'আদালত',
    'supreme': 'সুপ্রিম',
    'arrested': 'গ্রেপ্তার',
    'arrest': 'গ্রেপ্তার',
    'killed': 'নিহত',
    'dies': 'নিহত',
    'dead': 'নিহত',
    'fire': 'আগুন',
    'flood': 'বন্যা',
    'storm': 'ঝড়',
    'cyclone': 'ঘূর্ণিঝড়',
    'earthquake': 'ভূমিকম্প',
    'protest': 'বিক্ষোভ',
    'strike': 'ধর্মঘট',
    'budget': 'বাজেট',
    'bank': 'ব্যাংক',
    'cricket': 'ক্রিকেট',
    'football': 'ফুটবল',
    'match': 'ম্যাচ',
    'university': 'বিশ্ববিদ্যালয়',
    'exam': 'পরীক্ষা',
    'written': 'লিখিত',
    'published': 'প্রকাশ',
    'পরীক্ষার': 'পরীক্ষা',
    'নিয়োগের': 'নিয়োগ',
    'ফলাফলের': 'ফলাফল',
    'results': 'ফলাফল',
    'result': 'ফলাফল',
    'job': 'চাকরি',
    'recruitment': 'নিয়োগ',
    'scholarship': 'বৃত্তি',
    'blaze': 'আগুন',
    'cox': 'কক্সবাজার',
    'coxs': 'কক্সবাজার',
    'chattogram': 'চট্টগ্রাম',
    'chittagong': 'চট্টগ্রাম',
    'dhaka': 'ঢাকা',
    'sylhet': 'সিলেট',
    'khulna': 'খুলনা',
    'investigation': 'তদন্ত',
    'investigates': 'তদন্ত',
    'update': 'আপডেট',
    'followup': 'আপডেট',
  };

  static const Set<String> _followUpTerms = <String>{
    'তদন্ত', 'আপডেট', 'গ্রেপ্তার', 'আদালত', 'নিহত', 'হাসপাতাল',
  };

  /// Language-neutral event and entity concepts used only as a conservative
  /// fallback when ordinary token overlap cannot bridge two scripts. Entries
  /// describe reusable concepts, not article-title exceptions.
  static const Map<String, String> _semanticAliases = <String, String>{
    // Places and named entities.
    'brazil': 'named:place:brazil',
    'brazilian': 'named:place:brazil',
    'ব্রাজিল': 'named:place:brazil',
    'serbia': 'named:place:serbia',
    'serbian': 'named:place:serbia',
    'সার্বিয়া': 'named:place:serbia',
    'সার্বিয়া': 'named:place:serbia',
    'lula': 'named:person:lula',
    'লুলা': 'named:person:lula',
    'vucic': 'named:person:vucic',
    'ভুচিচ': 'named:person:vucic',
    'ভুসিচ': 'named:person:vucic',
    'ভুচিক': 'named:person:vucic',
    'bolsonaro': 'named:person:bolsonaro',
    'বলসোনারো': 'named:person:bolsonaro',

    // Event type, actors and outcomes.
    'election': 'event:election',
    'elections': 'event:election',
    'poll': 'event:election',
    'polls': 'event:election',
    'reelection': 'event:election',
    'reelected': 'event:election',
    'নির্বাচন': 'event:election',
    'ভোট': 'event:election',
    'win': 'outcome:win',
    'wins': 'outcome:win',
    'won': 'outcome:win',
    'winner': 'outcome:win',
    'victory': 'outcome:win',
    'জয়': 'outcome:win',
    'জয়': 'outcome:win',
    'বিজয়': 'outcome:win',
    'বিজয়': 'outcome:win',
    'জিতলেন': 'outcome:win',
    'জিতেছেন': 'outcome:win',
    'জয়ী': 'outcome:win',
    'জয়ী': 'outcome:win',
    'student': 'actor:student',
    'students': 'actor:student',
    'শিক্ষার্থী': 'actor:student',
    'ছাত্র': 'actor:student',
    'challenger': 'actor:challenger',
    'challengers': 'actor:challenger',
    'প্রতিদ্বন্দ্বী': 'actor:challenger',
  };

  static String _foldLatin(String value) => value
      .replaceAll(RegExp('[čć]'), 'c')
      .replaceAll('š', 's')
      .replaceAll('ž', 'z')
      .replaceAll('đ', 'd');

  static String _normalizedText(Article article) => TextUtils.searchNormalize(
        _foldLatin('${article.title} ${article.excerpt ?? ''}'.toLowerCase()),
      );

  static List<String> _tokens(Article article) {
    final String raw = _normalizedText(article);
    return raw
        .split(' ')
        .map((String token) => _aliases[token] ?? token)
        .where((String token) => token.length >= 3 && !_stop.contains(token))
        .toSet()
        .toList(growable: false);
  }

  static Set<String> _semanticTokens(Article article) {
    final Set<String> concepts = <String>{};
    for (final String token in _normalizedText(article).split(' ')) {
      final String? direct = _semanticAliases[token];
      if (direct != null) {
        concepts.add(direct);
        continue;
      }
      // Bengali case markers are attached to names (লুলার, ব্রাজিলে,
      // ভুচিচের). Resolve a known base instead of stemming arbitrary words.
      for (final String suffix in const <String>[
        'দের', 'টির', 'ের', 'য়ের', 'য়ের', 'তে', 'য়', 'য়', 'র', 'ে',
      ]) {
        if (token.length <= suffix.length + 2 || !token.endsWith(suffix)) {
          continue;
        }
        final String? base =
            _semanticAliases[token.substring(0, token.length - suffix.length)];
        if (base != null) {
          concepts.add(base);
          break;
        }
      }
    }
    return concepts;
  }

  static bool _semanticMatch(
    Article first,
    Article second,
    Duration? distance,
  ) {
    // Cross-script concepts are deliberately stricter than lexical matching:
    // both reports need precise timing, two shared named entities, and a shared
    // event/outcome. Country or politician mentions alone can never match.
    if (distance == null || distance > window) return false;
    final Set<String> common =
        _semanticTokens(first).intersection(_semanticTokens(second));
    final int named =
        common.where((String value) => value.startsWith('named:')).length;
    final int eventSignals = common
        .where((String value) =>
            value.startsWith('event:') || value.startsWith('outcome:'))
        .length;
    return named >= 2 && eventSignals >= 1 && common.length >= 3;
  }

  static String canonicalUrl(String value) {
    final Uri? uri = Uri.tryParse(value);
    if (uri == null) return value.trim().toLowerCase();
    final Map<String, String> query = Map<String, String>.of(uri.queryParameters)
      ..removeWhere((String key, String value) {
        final String lower = key.toLowerCase();
        return lower.startsWith('utm_') ||
            lower == 'fbclid' ||
            lower == 'gclid' ||
            lower == 'ref';
      });
    final String encodedQuery = query.entries
        .map((MapEntry<String, String> entry) =>
            '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}')
        .join('&');
    return uri
        .replace(
          fragment: '',
          query: encodedQuery,
          path: uri.path.replaceAll(RegExp(r'/+$'), ''),
        )
        .toString()
        .toLowerCase();
  }

  static bool matches(Article first, Article second) {
    if (first.sourceId == second.sourceId) return false;
    if (canonicalUrl(first.link) == canonicalUrl(second.link)) return false;
    final DateTime? a = first.publishedAt;
    final DateTime? b = second.publishedAt;
    final Duration? distance = a == null || b == null
        ? null
        : Duration(seconds: a.difference(b).inSeconds.abs());
    if (distance != null && distance > followUpWindow) return false;

    final Set<String> left = _tokens(first).toSet();
    final Set<String> right = _tokens(second).toSet();
    if (left.length >= 4 && right.length >= 4) {
      final Set<String> common = left.intersection(right);
      if (common.length >= 3) {
        final int denominator =
            left.length < right.length ? left.length : right.length;
        final double containment = common.length / denominator;
        final double jaccard = common.length / left.union(right).length;
        final bool closeEnough = containment >= threshold && jaccard >= 0.34;
        final bool timingFits = distance == null ||
            distance <= window ||
            left.union(right).intersection(_followUpTerms).isNotEmpty;
        if (closeEnough && timingFits) return true;
      }
    }
    return _semanticMatch(first, second, distance);
  }

  /// Builds once after repository load/refresh — never from a widget build.
  static Map<String, List<Article>> index(List<Article> articles) {
    final Map<String, List<Article>> out = <String, List<Article>>{};
    final Set<String> seenUrls = <String>{};
    final List<Article> unique = <Article>[];
    for (final Article article in articles) {
      if (seenUrls.add(canonicalUrl(article.link))) unique.add(article);
    }
    for (int i = 0; i < unique.length; i++) {
      for (int j = i + 1; j < unique.length; j++) {
        final Article a = unique[i];
        final Article b = unique[j];
        if (!matches(a, b)) continue;
        (out[a.id] ??= <Article>[]).add(b);
        (out[b.id] ??= <Article>[]).add(a);
      }
    }
    for (final MapEntry<String, List<Article>> entry in out.entries) {
      final Map<String, Article> byPublisher = <String, Article>{};
      for (final Article article in entry.value) {
        final Article? existing = byPublisher[article.sourceId];
        if (existing == null || article.sortKey.isAfter(existing.sortKey)) {
          byPublisher[article.sourceId] = article;
        }
      }
      final List<Article> distinct = byPublisher.values.toList()
        ..sort((Article a, Article b) => b.sortKey.compareTo(a.sortKey));
      entry.value
        ..clear()
        ..addAll(distinct);
    }
    return out;
  }
}
