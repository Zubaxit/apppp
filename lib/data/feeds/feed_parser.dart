import 'package:xml/xml.dart';

import '../../core/utils/ids.dart';
import '../../core/utils/url_safety.dart';
import '../models/article.dart';
import '../models/news_source.dart';
import 'topic_classifier.dart';

/// Per-source parsing tweaks. Kept in the registry-facing layer so a new
/// publisher can be added without touching the parser.
class FeedParserConfig {
  const FeedParserConfig({
    this.assumeUtcOffsetMinutes = 360,
    this.stripBreakingPrefix = true,
    this.maxItems = 200,
  });

  /// Offset applied when a feed date has no timezone (Bangladesh, UTC+6).
  final int assumeUtcOffsetMinutes;
  final bool stripBreakingPrefix;
  final int maxItems;
}

enum FeedFormatDetected { rss2, rdf, atom, unknown }

class FeedParseResult {
  const FeedParseResult({
    required this.articles,
    required this.format,
    this.warnings = const <String>[],
    this.recovered = false,
    this.nextPageUrl,
  });

  final List<Article> articles;
  final FeedFormatDetected format;
  final List<String> warnings;

  /// True when the document was not valid XML and was recovered with the
  /// tolerant regex path.
  final bool recovered;

  /// Explicit Atom/RSS continuation supplied by the publisher. Fetching is a
  /// gateway policy; the parser only reports it.
  final String? nextPageUrl;

  bool get isEmpty => articles.isEmpty;
}

/// Result of the pre-parse repair step: the body handed to the XML parser and
/// whether the publisher's markup actually had to be repaired.
class _PreparedXml {
  const _PreparedXml({required this.body, required this.repaired});

  final String body;
  final bool repaired;
}

/// Tolerant RSS / Atom / RDF parser.
///
/// Design goals:
///  * never throw because a publisher shipped broken XML;
///  * never invent a publication date;
///  * drop items that have no headline or no safe article URL;
///  * de-duplicate repeated items inside a single feed.
class FeedParser {
  const FeedParser();

  static final RegExp _itemBlockRe = RegExp(
      r'<(item|entry)(?:\s[^>]*)?>([\s\S]*?)</\1>',
      caseSensitive: false);
  static final RegExp _titleRe =
      RegExp(r'<title[^>]*>([\s\S]*?)</title>', caseSensitive: false);
  static final RegExp _linkTextRe =
      RegExp(r'<link[^>]*>([\s\S]*?)</link>', caseSensitive: false);
  static final RegExp _linkHrefRe = RegExp(
    r'''<link[^>]*href\s*=\s*["']([^"']+)["']''',
    caseSensitive: false,
  );
  static final RegExp _dateRe = RegExp(
    r'<(pubDate|published|updated|dc:date|date)[^>]*>([\s\S]*?)</\1>',
    caseSensitive: false,
  );
  static final RegExp _imgSrcRe = RegExp(
    r'''<img[^>]+src\s*=\s*["']([^"']+)["']''',
    caseSensitive: false,
  );

  FeedParseResult parse(
    String body, {
    required NewsSource source,
    required DateTime fetchedAt,
    FeedParserConfig config = const FeedParserConfig(),
  }) {
    final _PreparedXml prepared = _prepareXml(body);
    final String cleaned = prepared.body;
    // `repaired` is true only when the publisher's markup was genuinely broken
    // (bare '&', illegal control characters) — not for the routine
    // normalisation of HTML named entities.
    final bool repaired = prepared.repaired;
    final List<String> warnings = <String>[];
    XmlDocument? document;
    try {
      document = XmlDocument.parse(cleaned);
    } on XmlException catch (error) {
      warnings.add('Invalid XML: ${error.message}');
    }

    if (document != null) {
      final FeedFormatDetected format = _detectFormat(document);
      final List<Article> articles = _parseDocument(
        document,
        source: source,
        fetchedAt: fetchedAt,
        config: config,
        warnings: warnings,
      );
      if (articles.isEmpty && cleaned.contains('<item')) {
        // Valid root but items we could not map: try the tolerant path once.
        final List<Article> recovered = _parseWithRegex(
          cleaned,
          source: source,
          fetchedAt: fetchedAt,
          config: config,
          warnings: warnings,
        );
        if (recovered.isNotEmpty) {
          return FeedParseResult(
            articles: recovered,
            format: format,
            warnings: warnings,
            recovered: true,
            nextPageUrl: _nextPage(document),
          );
        }
      }
      return FeedParseResult(
        articles: articles,
        format: format,
        warnings: warnings,
        recovered: repaired,
        nextPageUrl: _nextPage(document),
      );
    }

    final List<Article> recovered = _parseWithRegex(
      cleaned,
      source: source,
      fetchedAt: fetchedAt,
      config: config,
      warnings: warnings,
    );
    return FeedParseResult(
      articles: recovered,
      format: FeedFormatDetected.unknown,
      warnings: warnings,
      recovered: true,
    );
  }

  String? _nextPage(XmlDocument document) {
    for (final XmlElement link
        in document.descendants.whereType<XmlElement>()) {
      if (link.name.local.toLowerCase() != 'link') {
        continue;
      }
      if ((link.getAttribute('rel') ?? '').toLowerCase() != 'next') {
        continue;
      }
      final String value = (link.getAttribute('href') ?? link.innerText).trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  FeedFormatDetected _detectFormat(XmlDocument document) {
    final XmlElement root = document.rootElement;
    final String rootName = root.name.local.toLowerCase();
    if (rootName == 'feed') {
      return FeedFormatDetected.atom;
    }
    if (rootName == 'rdf') {
      return FeedFormatDetected.rdf;
    }
    if (rootName == 'rss') {
      return FeedFormatDetected.rss2;
    }
    if (root.findAllElements('channel').isNotEmpty) {
      return FeedFormatDetected.rss2;
    }
    if (root.findAllElements('entry').isNotEmpty) {
      return FeedFormatDetected.atom;
    }
    return FeedFormatDetected.unknown;
  }

  List<Article> _parseDocument(
    XmlDocument document, {
    required NewsSource source,
    required DateTime fetchedAt,
    required FeedParserConfig config,
    required List<String> warnings,
  }) {
    final List<XmlElement> nodes = <XmlElement>[
      ...document.rootElement.findAllElements('item'),
      ...document.rootElement.findAllElements('entry'),
    ];
    final List<Article> articles = <Article>[];
    for (final XmlElement node in nodes) {
      final Article? article = _articleFromElement(
        node,
        source: source,
        fetchedAt: fetchedAt,
        config: config,
        warnings: warnings,
      );
      if (article != null) articles.add(article);
      if (articles.length >= config.maxItems) break;
    }
    return _dedupe(articles);
  }

  Article? _articleFromElement(
    XmlElement node, {
    required NewsSource source,
    required DateTime fetchedAt,
    required FeedParserConfig config,
    required List<String> warnings,
  }) {
    final String title = _cleanText(_childText(node, <String>['title']));
    final String? link = _extractLink(node);
    final String? description = _firstNonEmpty(<String?>[
      _childText(node, <String>['description']),
      _childText(node, <String>['summary']),
      _childText(node, <String>['content']),
    ]);
    final String contentRaw = _childText(node, <String>['encoded', 'content']);
    final String? dateRaw = _firstNonEmpty(<String?>[
      _childText(node, <String>['pubdate']),
      _childText(node, <String>['published']),
      _childText(node, <String>['updated']),
      _childText(node, <String>['date']),
      _childText(node, <String>['created']),
    ]);
    final List<String> categories = <String>[
      for (final XmlElement element in node.findAllElements('category'))
        if (_cleanText(_textOf(element)).isNotEmpty)
          _cleanText(_textOf(element)),
    ];
    for (final XmlElement element in node.findAllElements('category')) {
      final String? term = _attr(element, <String>['term', 'label']);
      if (term != null && term.isNotEmpty && !categories.contains(term)) {
        categories.add(term);
      }
    }

    return _buildArticle(
      source: source,
      fetchedAt: fetchedAt,
      config: config,
      warnings: warnings,
      rawTitle: title,
      link: link,
      description: description,
      contentRaw: contentRaw,
      dateRaw: dateRaw,
      categories: categories,
      guid: _firstNonEmpty(<String?>[
        _childText(node, <String>['guid']),
        _childText(node, <String>['id']),
      ]),
      author: _firstNonEmpty(<String?>[
        _childText(node, <String>['creator']),
        _childText(node, <String>['author']),
      ]),
      imageHint: _imageFromMedia(node),
    );
  }

  List<Article> _parseWithRegex(
    String body, {
    required NewsSource source,
    required DateTime fetchedAt,
    required FeedParserConfig config,
    required List<String> warnings,
  }) {
    final List<Article> articles = <Article>[];
    for (final RegExpMatch match in _itemBlockRe.allMatches(body)) {
      if (articles.length >= config.maxItems) break;
      final String block = match.group(2) ?? '';
      final String? rawTitle = _firstGroup(_titleRe, block);
      final String? linkText = _firstGroup(_linkTextRe, block);
      final String? linkHref = _firstGroup(_linkHrefRe, block);
      final String? dateRaw = _firstGroup(_dateRe, block);
      final String? description = _firstGroup(
        RegExp(r'<description[^>]*>([\s\S]*?)</description>',
            caseSensitive: false),
        block,
      );
      final String? content = _firstGroup(
        RegExp(r'<content:encoded[^>]*>([\s\S]*?)</content:encoded>',
            caseSensitive: false),
        block,
      );
      final String? guid = _firstGroup(
        RegExp(r'<guid[^>]*>([\s\S]*?)</guid>', caseSensitive: false),
        block,
      );
      final List<String> categories = <String>[
        for (final RegExpMatch m in RegExp(
                r'<category[^>]*>([\s\S]*?)</category>',
                caseSensitive: false)
            .allMatches(block))
          _cleanText(m.group(1) ?? ''),
      ];
      final String? imageHint = _firstGroup(_imgSrcRe, block);
      final Article? article = _buildArticle(
        source: source,
        fetchedAt: fetchedAt,
        config: config,
        warnings: warnings,
        rawTitle: _cleanText(rawTitle ?? ''),
        link: (linkText != null && linkText.trim().isNotEmpty)
            ? linkText.trim()
            : linkHref,
        description: description,
        contentRaw: content,
        dateRaw: _cleanText(dateRaw ?? ''),
        categories: categories,
        guid: _cleanText(guid ?? ''),
        author: null,
        imageHint: imageHint,
      );
      if (article != null) articles.add(article);
    }
    return _dedupe(articles);
  }

  Article? _buildArticle({
    required NewsSource source,
    required DateTime fetchedAt,
    required FeedParserConfig config,
    required List<String> warnings,
    required String rawTitle,
    required String? link,
    required String? description,
    required String? contentRaw,
    required String? dateRaw,
    required List<String> categories,
    required String? guid,
    required String? author,
    required String? imageHint,
  }) {
    String title = _cleanText(rawTitle);
    if (title.isEmpty) {
      warnings.add('Skipped item without a headline');
      return null;
    }
    final String? safeLinkRaw = UrlSafety.sanitize(link);
    // Publish the canonical URL: tracking parameters removed, fragment gone.
    final String? safeLink =
        safeLinkRaw == null ? null : UrlSafety.stripTracking(safeLinkRaw);
    if (safeLink == null) {
      warnings.add('Skipped "$title": missing or unsafe link');
      return null;
    }

    bool breaking = false;
    for (final String category in categories) {
      final String key = category.toLowerCase();
      if (key.contains('breaking') || category.contains('ব্রেকিং')) {
        breaking = true;
      }
    }
    final RegExp breakingPrefix = RegExp(
        r'^\s*(ব্রেকিং\s*নিউজ|ব্রেকিং|breaking news|breaking)\s*[:\-–|]\s*',
        caseSensitive: false);
    if (breakingPrefix.hasMatch(title)) {
      breaking = true;
      if (config.stripBreakingPrefix) {
        title = title.replaceFirst(breakingPrefix, '').trim();
      }
    }
    if (title.isEmpty) return null;

    final DateTime? publishedAt = _parseDate(dateRaw, config);
    final String? excerptSource = _pickExcerpt(description, contentRaw);
    final String? image = UrlSafety.sanitize(
      _firstNonEmpty(<String?>[
        imageHint,
        _firstImageIn(description),
        _firstImageIn(contentRaw)
      ]),
    );
    final String? publisherCategory =
        categories.isEmpty ? null : categories.first;
    final ArticleTopic topic = TopicClassifier.classify(
      title: title,
      categories: categories,
      excerpt: excerptSource,
      language: source.language,
    );

    if (publishedAt == null) {
      warnings.add('No usable publication date for "$title"');
    }

    return Article.create(
      sourceId: source.id,
      title: title,
      link: safeLink,
      excerpt: excerptSource,
      imageUrl: image,
      publishedAt: publishedAt,
      fetchedAt: fetchedAt,
      guid: guid,
      author: TextUtilsStrip.strip(author),
      topic: topic,
      publisherCategory: TextUtilsStrip.strip(publisherCategory),
      language: source.language,
      tags: categories.take(6).toList(),
      breaking: breaking,
    );
  }

  String? _pickExcerpt(String? description, String? content) {
    final String descriptionText = _cleanText(description ?? '');
    if (descriptionText.isNotEmpty && descriptionText.length >= 40) {
      return _limit(descriptionText, 320);
    }
    final String contentText = _cleanText(content ?? '');
    if (contentText.isNotEmpty) {
      return _limit(contentText, 320);
    }
    return descriptionText.isEmpty ? null : _limit(descriptionText, 320);
  }

  String _limit(String input, int max) =>
      input.length <= max ? input : '${input.substring(0, max).trimRight()}…';

  List<Article> _dedupe(List<Article> input) {
    final Set<String> seenIds = <String>{};
    final Set<String> seenTitles = <String>{};
    final List<Article> output = <Article>[];
    for (final Article article in input) {
      final String titleKey =
          '${article.sourceId}|${article.title.toLowerCase()}';
      if (seenIds.contains(article.id) || seenTitles.contains(titleKey)) {
        continue;
      }
      seenIds.add(article.id);
      seenTitles.add(titleKey);
      output.add(article);
    }
    return output;
  }

  // ---------------------------------------------------------------------------
  // Date parsing
  // ---------------------------------------------------------------------------

  static const Map<String, int> _months = <String, int>{
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };

  static final RegExp _rfc822 = RegExp(
    r'^(?:[A-Za-z]{3},\s*)?(\d{1,2})\s+([A-Za-z]{3,9})\s+(\d{2,4})\s+'
    r'(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([+-]\d{4}|[A-Za-z]{1,5})?',
  );
  static final RegExp _isoLike = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})[T\s](\d{2}):(\d{2})(?::(\d{2}))?\s*'
    r'(Z|[+-]\d{2}:?\d{2})?',
  );

  /// Parses RFC 822, RFC 3339 and `yyyy-MM-dd HH:mm:ss` style dates.
  ///
  /// Returns null when the value cannot be understood — the app then shows the
  /// item without a publication date rather than inventing one.
  DateTime? _parseDate(String? raw, FeedParserConfig config) {
    if (raw == null) return null;
    final String value = raw.trim();
    if (value.isEmpty) return null;

    final RegExpMatch? iso = _isoLike.firstMatch(value);
    if (iso != null) {
      final DateTime? parsed = DateTime.tryParse(
        value.replaceFirst(' ', 'T').replaceFirst(RegExp(r'\s+'), ''),
      );
      if (parsed != null) return parsed.toUtc();
      return _compose(
        year: int.parse(iso.group(1)!),
        month: int.parse(iso.group(2)!),
        day: int.parse(iso.group(3)!),
        hour: int.parse(iso.group(4)!),
        minute: int.parse(iso.group(5)!),
        second: int.tryParse(iso.group(6) ?? '0') ?? 0,
        offset: _parseOffset(iso.group(7)),
        config: config,
      );
    }

    final RegExpMatch? rfc = _rfc822.firstMatch(value);
    if (rfc != null) {
      final int? month = _months[rfc.group(2)!.toLowerCase().substring(0, 3)];
      if (month == null) return null;
      var year = int.parse(rfc.group(3)!);
      if (year < 100) year += year < 70 ? 2000 : 1900;
      return _compose(
        year: year,
        month: month,
        day: int.parse(rfc.group(1)!),
        hour: int.parse(rfc.group(4)!),
        minute: int.parse(rfc.group(5)!),
        second: int.tryParse(rfc.group(6) ?? '0') ?? 0,
        offset: _parseOffset(rfc.group(7)),
        config: config,
      );
    }

    final DateTime? fallback = DateTime.tryParse(value);
    if (fallback != null) return fallback.toUtc();
    return null;
  }

  DateTime? _compose({
    required int year,
    required int month,
    required int day,
    required int hour,
    required int minute,
    required int second,
    required int? offset,
    required FeedParserConfig config,
  }) {
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    if (hour > 23 || minute > 59 || second > 60) return null;
    final int effectiveOffset = offset ?? config.assumeUtcOffsetMinutes;
    final DateTime utc = DateTime.utc(year, month, day, hour, minute, second)
        .subtract(Duration(minutes: effectiveOffset));
    // Guard against obviously bogus dates (pre-internet or far future).
    final int yearNow = DateTime.now().toUtc().year;
    if (utc.year < 1995 || utc.year > yearNow + 1) return null;
    if (utc.isAfter(DateTime.now().toUtc().add(const Duration(days: 1)))) {
      return null;
    }
    return utc;
  }

  int? _parseOffset(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final String value = raw.trim().toUpperCase();
    if (value == 'Z' || value == 'GMT' || value == 'UT' || value == 'UTC') {
      return 0;
    }
    final RegExpMatch? match =
        RegExp(r'^([+-])(\d{2}):?(\d{2})$').firstMatch(value);
    if (match != null) {
      final int hours = int.parse(match.group(2)!);
      final int minutes = int.parse(match.group(3)!);
      final int total = hours * 60 + minutes;
      return match.group(1) == '-' ? -total : total;
    }
    const Map<String, int> zones = <String, int>{
      'EST': -300,
      'EDT': -240,
      'CST': -360,
      'CDT': -300,
      'MST': -420,
      'MDT': -360,
      'PST': -480,
      'PDT': -420,
      'BST': 60,
      'CET': 60,
      'CEST': 120,
      'IST': 330,
    };
    return zones[value];
  }

  // ---------------------------------------------------------------------------
  // XML helpers
  // ---------------------------------------------------------------------------

  _PreparedXml _prepareXml(String input) {
    var value = input;
    var repaired = false;
    if (value.startsWith('\uFEFF')) value = value.substring(1);
    // Remove characters that are illegal in XML 1.0.
    final String beforeControl = value;
    value = value.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');
    if (value != beforeControl) repaired = true;
    // Repair bare ampersands ('&' that does not start a valid entity), which
    // are the most common cause of otherwise unparseable publisher feeds.
    final String beforeAmpersand = value;
    value = value.replaceAllMapped(
      RegExp(
          r'&(?!(?:#[0-9]{1,7}|#x[0-9a-fA-F]{1,6}|[a-zA-Z][a-zA-Z0-9]{1,10});)'),
      (Match _) => '&amp;',
    );
    if (value != beforeAmpersand) repaired = true;
    // Repair the most common entity problems without touching valid entities.
    const Map<String, String> named = <String, String>{
      'nbsp': '&#160;',
      'mdash': '&#8212;',
      'ndash': '&#8211;',
      'lsquo': '&#8216;',
      'rsquo': '&#8217;',
      'ldquo': '&#8220;',
      'rdquo': '&#8221;',
      'hellip': '&#8230;',
      'bull': '&#8226;',
      'middot': '&#183;',
      'copy': '&#169;',
      'reg': '&#174;',
      'trade': '&#8482;',
      'euro': '&#8364;',
      'pound': '&#163;',
      'laquo': '&#171;',
      'raquo': '&#187;',
      'deg': '&#176;',
    };
    value = value.replaceAllMapped(
      RegExp(r'&([a-zA-Z][a-zA-Z0-9]{1,10});'),
      (Match match) {
        final String name = match.group(1)!;
        if (<String>['amp', 'lt', 'gt', 'quot', 'apos'].contains(name)) {
          return match.group(0)!;
        }
        final String? replacement = named[name];
        return replacement ?? '&amp;${match.group(1)};';
      },
    );
    return _PreparedXml(body: value, repaired: repaired);
  }

  String _cleanText(String input) {
    var value = input;
    if (value.contains('CDATA[')) {
      value =
          value.replaceAll(RegExp(r'<!\[CDATA\['), '').replaceAll(']]>', '');
    }
    return TextUtilsStrip.strip(value) ?? '';
  }

  String _textOf(XmlNode node) {
    final StringBuffer buffer = StringBuffer();
    void visit(XmlNode current) {
      if (current is XmlText) {
        buffer.write(current.value);
      } else if (current is XmlCDATA) {
        buffer.write(current.value);
      } else {
        for (final XmlNode child in current.children) {
          visit(child);
        }
      }
    }

    visit(node);
    return buffer.toString();
  }

  String _childText(XmlElement parent, List<String> localNames) {
    final List<String> wanted =
        localNames.map((String n) => n.toLowerCase()).toList();
    for (final XmlElement child in parent.childElements) {
      if (wanted.contains(child.name.local.toLowerCase())) {
        return _textOf(child);
      }
    }
    // Atom authors are nested one level deeper.
    for (final XmlElement child in parent.childElements) {
      if (child.name.local.toLowerCase() == 'author') {
        for (final XmlElement nested in child.childElements) {
          if (wanted.contains(nested.name.local.toLowerCase())) {
            return _textOf(nested);
          }
        }
      }
    }
    return '';
  }

  String? _extractLink(XmlElement node) {
    for (final XmlElement child in node.childElements) {
      if (child.name.local.toLowerCase() != 'link') continue;
      final String? href = _attr(child, <String>['href']);
      final String? rel = _attr(child, <String>['rel']);
      if (href != null && href.isNotEmpty) {
        if (rel == null || rel == 'alternate' || rel.isEmpty) return href;
        continue;
      }
      final String text = _textOf(child).trim();
      if (text.isNotEmpty) return text;
    }
    // Fall back to a permalink guid.
    for (final XmlElement child in node.childElements) {
      if (child.name.local.toLowerCase() != 'guid') continue;
      final String text = _textOf(child).trim();
      final bool isPerma =
          (_attr(child, <String>['isPermaLink']) ?? 'true') != 'false';
      if (isPerma && text.startsWith('http')) return text;
    }
    return null;
  }

  String? _imageFromMedia(XmlElement node) {
    for (final XmlElement element in node.findAllElements('*')) {
      final String local = element.name.local.toLowerCase();
      if (local == 'thumbnail' ||
          local == 'content' ||
          local == 'enclosure' ||
          local == 'image') {
        final String? url = _attr(element, <String>['url', 'href']);
        if (url == null || url.isEmpty) continue;
        final String? type = _attr(element, <String>['type', 'medium']);
        if (type != null &&
            (type.toLowerCase().contains('video') ||
                type.toLowerCase().contains('audio'))) {
          continue;
        }
        return url;
      }
    }
    return null;
  }

  String? _firstImageIn(String? html) {
    if (html == null) return null;
    final RegExpMatch? match = _imgSrcRe.firstMatch(html);
    if (match == null) return null;
    final String src = match.group(1) ?? '';
    if (src.startsWith('data:')) return null;
    return src;
  }

  String? _attr(XmlElement element, List<String> localNames) {
    final List<String> wanted =
        localNames.map((String n) => n.toLowerCase()).toList();
    for (final XmlAttribute attribute in element.attributes) {
      if (wanted.contains(attribute.name.local.toLowerCase())) {
        final String value = attribute.value.trim();
        if (value.isNotEmpty) return value;
      }
    }
    return null;
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final String? value in values) {
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  String? _firstGroup(RegExp pattern, String input) {
    final RegExpMatch? match = pattern.firstMatch(input);
    if (match == null) return null;
    return match.group(1);
  }
}

/// Small helper so the parser stays free of UI concerns.
class TextUtilsStrip {
  const TextUtilsStrip._();

  static String? strip(String? value) {
    if (value == null) return null;
    var text = value;
    if (text.contains('<')) {
      text = text.replaceAll(RegExp(r'<[^>]*>'), ' ');
    }
    text = text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return text.isEmpty ? null : text;
  }
}

/// Exposed for tests and diagnostics: the canonicalized id of a raw link.
String debugArticleIdFor(String sourceId, String link, String title) =>
    Ids.articleId(sourceId: sourceId, link: link, title: title);
