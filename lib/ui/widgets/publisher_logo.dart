import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/extensions.dart';
import '../../data/models/news_source.dart';
import '../../theme/tokens.dart';

/// A publisher's own mark, at the size the interface needs it.
///
/// The app identifies a publisher by the publisher's identity, not by a letter
/// drawn in the app's typeface. The mark is fetched from the publisher's own
/// site — the maintainer's explicit asset if the registry carries one,
/// otherwise the touch icon the site advertises, otherwise its favicon — and
/// served from the image disk cache, so a second build of the same row is a
/// cache hit rather than a request.
///
/// Everything about this widget is designed to fail quietly:
///
/// * it is drawn at a fixed size, so a logo arriving late cannot shift layout;
/// * it is decoded at the tile's own pixel width, so a 48 dp monogram never
///   pulls a 512 px source into memory;
/// * below 24 dp no request is made at all — a wordmark is illegible there, so
///   the monogram is both the better mark and the cheaper one;
/// * when every candidate fails — no network, no icon, a corrupt file — it
///   paints the publisher's serif monogram on the same tile, never a broken
///   image glyph, and never an invented logo.
class PublisherLogo extends StatefulWidget {
  const PublisherLogo({
    super.key,
    required this.source,
    this.size = 44,
    this.tile = true,
    this.solid,
  });

  final NewsSource source;
  final double size;

  /// Whether the mark sits on its own bordered tile. Inline uses inside a line
  /// of text pass `false` and get only the image.
  final bool tile;

  /// Turns the network lookup off for an environment that has no image stack
  /// (widget tests) or for a caller that must not fetch anything. The tile and
  /// the monogram fallback are unaffected.
  static bool remoteEnabled = true;

  /// Overrides the tile fill (used for the filled accent variant).
  final Color? solid;

  @override
  State<PublisherLogo> createState() => _PublisherLogoState();
}

class _PublisherLogoState extends State<PublisherLogo> {
  /// Index into [NewsSource.logoUrls]; equal to the length means "give up and
  /// draw the monogram".
  int _candidate = 0;

  @override
  void didUpdateWidget(PublisherLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source.id != widget.source.id) _candidate = 0;
  }

  void _next() {
    // Never mutate state during build: the error widget is built inside the
    // image's own build pass.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final int total = widget.source.logoUrls.length;
      if (_candidate >= total) return;
      setState(() => _candidate += 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = context.isDark;
    final double size = widget.size;
    final List<String> urls = widget.source.logoUrls;
    final bool showMonogram = _candidate >= urls.length;
    final BorderRadius shape = BorderRadius.circular(size * 0.3);

    Widget content;
    // Under 24 dp a wordmark is a smudge; the monogram reads better and saves
    // the river a request per row.
    if (!PublisherLogo.remoteEnabled || showMonogram || size < 24) {
      content = _Monogram(source: widget.source, size: size, solid: widget.solid);
    } else {
      final int pixels = (size * (MediaQuery.maybeDevicePixelRatioOf(context) ?? 2))
          .round()
          .clamp(48, 192);
      content = CachedNetworkImage(
        imageUrl: urls[_candidate],
        // A mark is a small asset; ask the codec for the tile, not the source.
        memCacheWidth: pixels,
        maxWidthDiskCache: pixels,
        fadeInDuration: const Duration(milliseconds: 140),
        fadeOutDuration: Duration.zero,
        fit: BoxFit.contain,
        placeholder: (BuildContext context, String value) =>
            _Monogram(source: widget.source, size: size, solid: widget.solid),
        errorWidget: (BuildContext context, String value, Object error) {
          _next();
          return _Monogram(source: widget.source, size: size, solid: widget.solid);
        },
      );
    }

    if (!widget.tile) return content;

    // Publisher icons are drawn for white paper; keeping the tile light in both
    // themes is what makes a dark or thin wordmark legible at 20 dp.
    final Color fill = widget.solid ??
        (dark ? const Color(0xFFF1EFEC) : Colors.white);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      padding: EdgeInsets.all(size * 0.11),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: shape,
        border: Border.all(
          color: dark ? Colors.white.withValues(alpha: 0.14) : Tokens.hairline,
          width: 0.9,
        ),
      ),
      // Clipped so a wide wordmark is cropped to the tile instead of spilling.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.2),
        child: content,
      ),
    );
  }
}

/// The honest fallback: the publisher's own initials, set in the app's serif.
class _Monogram extends StatelessWidget {
  const _Monogram({required this.source, required this.size, this.solid});

  final NewsSource source;
  final double size;
  final Color? solid;

  @override
  Widget build(BuildContext context) {
    final Color ink = solid == null
        ? context.colors.primary
        : context.colors.onPrimary;
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Text(
          source.monogram,
          maxLines: 1,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: Tokens.serif,
            fontSize: size * 0.4,
            height: 1.0,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
        ),
      ),
    );
  }
}
