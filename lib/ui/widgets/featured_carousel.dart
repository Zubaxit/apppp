import 'package:flutter/material.dart';

import '../../core/extensions.dart';
import '../../data/models/article.dart';
import '../../data/models/news_source.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import 'actions.dart';
import 'common.dart';
import 'editorial.dart';

/// The featured band: a landscape editorial card per story, with the headline
/// and publisher line set into a scrim over the photograph, and page dots
/// centred underneath.
///
/// The card is full-bleed inside the page gutter, exactly as the reference sets
/// it: one landscape photograph per page, the headline and publisher line in a
/// scrim over the bottom of the image, dots centred underneath. Dragging moves
/// the photograph slightly faster than its frame, so the card reads as a window
/// rather than a tile, and releasing settles on a page.
class FeaturedCarousel extends StatefulWidget {
  const FeaturedCarousel({
    super.key,
    required this.articles,
    required this.sourceFor,
    required this.onOpen,
    this.minimumStories = 3,
    this.label,
  });

  final List<Article> articles;
  final NewsSource? Function(Article article) sourceFor;
  final ValueChanged<Article> onOpen;
  final int minimumStories;
  final String? label;

  static bool qualifies(List<Article> articles, {int minimumStories = 3}) =>
      articles.where((Article a) => a.imageUrl != null).length >= minimumStories;

  @override
  State<FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends State<FeaturedCarousel> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Article> items = widget.articles
        .where((Article a) => a.imageUrl != null)
        .take(7)
        .toList(growable: false);
    if (items.length < widget.minimumStories) return const SizedBox.shrink();

    final double width = MediaQuery.sizeOf(context).width;
    final double cardWidth = width - Tokens.gutter * 1.2;
    final double height = (cardWidth * 0.62).clamp(190.0, 340.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          height: height,
          child: PageView.builder(
            controller: _controller,
            padEnds: true,
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            onPageChanged: (int page) {
              if (page != _page) setState(() => _page = page);
            },
            itemBuilder: (BuildContext context, int index) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Tokens.gutter * 0.6,
                ),
                child: _FeaturedCard(
                  article: items[index],
                  source: widget.sourceFor(items[index]),
                  onOpen: () => widget.onOpen(items[index]),
                  parallax: _controller,
                  index: index,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (int i = 0; i < items.length; i++)
                JellySurface(
                  onTap: () => _controller.animateToPage(
                    i,
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutCubic,
                  ),
                  scale: 0.8,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
                    child: AnimatedContainer(
                      duration: Motion.of(context).standard,
                      curve: Tokens.easeStandard,
                      width: i == _page ? 16 : 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: i == _page
                            ? context.colors.primary
                            : context.colors.onSurfaceVariant.withValues(alpha: 0.32),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({
    required this.article,
    required this.source,
    required this.onOpen,
    required this.parallax,
    required this.index,
  });

  final Article article;
  final NewsSource? source;
  final VoidCallback onOpen;
  final PageController parallax;
  final int index;

  @override
  Widget build(BuildContext context) {
    return JellySurface(
      onTap: onOpen,
      scale: 0.985,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Tokens.radiusLg),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            AnimatedBuilder(
              animation: parallax,
              builder: (BuildContext context, Widget? child) {
                double delta = 0;
                if (parallax.hasClients && parallax.position.haveDimensions) {
                  delta = (parallax.page ?? index.toDouble()) - index;
                }
                // One matrix for the drift and the 1.07 crop scale: a single
                // transform layer over a cached photograph raster, so dragging
                // the rail moves pixels instead of repainting the image.
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..translate(
                      delta * MediaQuery.sizeOf(context).width * 0.055,
                    )
                    ..scale(1.07),
                  child: child,
                );
              },
              child: RepaintBoundary(
                child: RemoteImage(
                  url: article.imageUrl!,
                  // The card is full-bleed inside the gutter; decode for that,
                  // not for the 1600 px the publisher uploaded.
                  decodeWidth:
                      MediaQuery.sizeOf(context).width - Tokens.gutter * 1.2,
                ),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: <double>[0.0, 0.35, 0.62, 1.0],
                  colors: <Color>[
                    Color(0x59000000),
                    Color(0x0D000000),
                    Color(0x66000000),
                    Color(0xD9000000),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      if (article.breaking)
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: context.colors.error,
                            borderRadius: BorderRadius.circular(Tokens.radiusXs),
                          ),
                          child: Text(
                            context.strings.breakingShort,
                            style: const TextStyle(
                              fontFamily: Tokens.sans,
                              fontSize: 8.5,
                              height: 1.2,
                              letterSpacing: 0.8,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      const Spacer(),
                      BookmarkAction(
                        article: article,
                        dense: true,
                        onDark: true,
                        showSnack: false,
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    article.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: Tokens.serif,
                      fontSize: 21,
                      height: 1.34,
                      letterSpacing: -0.2,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      shadows: <Shadow>[
                        Shadow(color: Color(0x80000000), blurRadius: 18, offset: Offset(0, 2)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      if (source != null)
                        Container(
                          width: 17,
                          height: 17,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            source!.monogram.characters.take(1).toString(),
                            style: const TextStyle(
                              fontFamily: Tokens.serif,
                              fontSize: 8.5,
                              height: 1,
                              fontWeight: FontWeight.w700,
                              color: Tokens.accent,
                            ),
                          ),
                        ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Attribution(
                          article: article,
                          source: source,
                          compact: true,
                          onDark: true,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        context.strings.readInApp,
                        style: TextStyle(
                          fontFamily: Tokens.sans,
                          fontSize: 9.5,
                          letterSpacing: 0.4,
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withValues(alpha: 0.82),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 14,
                        color: Colors.white70,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
