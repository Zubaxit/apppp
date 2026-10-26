import 'dart:convert';

/// One block of an extracted article.
///
/// The English original is kept verbatim: the reader never replaces the
/// publisher's words with a translation, it places the translation beneath them.
class ReaderBlock {
  const ReaderBlock({
    required this.text,
    this.heading = false,
    this.imageUrl,
  });

  final String text;

  /// `h2`/`h3` blocks are rendered as a sub-heading rather than body text.
  final bool heading;

  /// Useful article images, in document order. The URL is supplied by the
  /// already-open page; no second HTML fetch is performed.
  final String? imageUrl;
  bool get isImage => imageUrl != null;
}

/// The readable part of a publisher's page.
///
/// Everything here came out of the page that the user is looking at: no second
/// request, no scraping service, and no invented text. When extraction cannot
/// find an article, [ReaderDocument.parse] returns `null` and the screen tells
/// the user rather than showing an empty reading surface.
class ReaderDocument {
  const ReaderDocument({
    required this.title,
    required this.blocks,
    this.byline,
    this.published,
    this.site,
    this.url,
  });

  static const int maxBlocks = 400;
  static const int maxBlockLength = 4000;

  final String title;
  final List<ReaderBlock> blocks;
  final String? byline;
  final String? published;
  final String? site;
  final String? url;

  /// Paragraphs only (no sub-headings) — what gets translated.
  List<String> get paragraphs => <String>[
        for (final ReaderBlock block in blocks)
          if (!block.heading && !block.isImage) block.text,
      ];

  int get characterCount =>
      blocks.fold<int>(0, (int sum, ReaderBlock b) => sum + b.text.length);

  /// Parses the payload produced by `ReaderScripts.extract`.
  ///
  /// Returns `null` when the page could not be read as an article, including
  /// when the JSON is malformed — a failure must be reported, never papered over
  /// with a blank reader.
  static ReaderDocument? parse(String? raw, {String? pageUrl}) {
    if (raw == null || raw.trim().isEmpty) return null;

    Object? decoded;
    try {
      decoded = jsonDecode(_unwrap(raw));
    } catch (_) {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;
    if (decoded['ok'] != true) return null;

    final List<ReaderBlock> blocks = <ReaderBlock>[];
    final Object? rawBlocks = decoded['blocks'];
    if (rawBlocks is List<dynamic>) {
      final Set<String> seen = <String>{};
      for (final Object? item in rawBlocks) {
        if (item is! Map<String, dynamic>) continue;
        final String? image = _safeImage(item['image']);
        final String text = _clean('${item['text'] ?? ''}');
        if (image != null) {
          if (!seen.add(image)) continue;
          blocks.add(ReaderBlock(text: text, imageUrl: image));
        } else {
          if (text.length < 2) continue;
          if (!seen.add(text)) continue;
          blocks.add(ReaderBlock(
            text: text.length > maxBlockLength
                ? text.substring(0, maxBlockLength)
                : text,
            heading: item['heading'] == true,
          ));
        }
        if (blocks.length >= maxBlocks) break;
      }
    }

    final int prose = blocks
        .where((ReaderBlock b) => !b.heading && !b.isImage)
        .fold<int>(0, (int sum, ReaderBlock b) => sum + b.text.length);
    if (blocks.length < 2 || prose < 200) return null;

    final String title = _clean('${decoded['title'] ?? ''}');
    return ReaderDocument(
      title: title.isEmpty ? '—' : title,
      blocks: List<ReaderBlock>.unmodifiable(blocks),
      byline: _optional(decoded['byline']),
      published: _optional(decoded['published']),
      site: _optional(decoded['site']),
      url: _optional(decoded['url']) ?? pageUrl,
    );
  }

  /// Android's `evaluateJavascript` returns a JSON-encoded string, so the
  /// payload can arrive wrapped in one more pair of quotes.
  static String _unwrap(String raw) {
    String value = raw.trim();
    if (value.length > 1 && value.startsWith('"') && value.endsWith('"')) {
      try {
        final Object? inner = jsonDecode(value);
        if (inner is String) value = inner;
      } catch (_) {
        // Not double-encoded after all; fall through with the raw text.
      }
    }
    return value;
  }

  static String? _safeImage(Object? value) {
    final String text = _clean('${value ?? ''}');
    final Uri? uri = Uri.tryParse(text);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
    return uri.toString();
  }

  static String? _optional(Object? value) {
    final String text = _clean('${value ?? ''}');
    return text.isEmpty ? null : text;
  }

  static String _clean(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').trim();
}
