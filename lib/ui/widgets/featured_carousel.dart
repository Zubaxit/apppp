import 'package:flutter/material.dart';

import '../../core/extensions.dart';
import '../../data/models/article.dart';
import '../../data/models/news_source.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../widgets/actions.dart';
import '../widgets/common.dart';
import '../widgets/editorial.dart';

/// The featured band at the top of the front page.
///
/// A horizontally swiped rail of the day's leading stories, taken straight from
/// whatever the feeds delivered — there is no editorially invented content here.
/// It only appears when at least [minimumStories] real articles with images are
/// available; below that the plain lead story carries the page instead of a
/// carousel pretending to have depth.
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
  final PageController _controller = PageController(viewportFraction: 0.91);
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
        .take(6)
        .toList(growable: false);
    if (items.length < widget.minimumStories) return const SizedBox.shrink();

    final Motion motion = Motion.of(context);
    const double gutter = Tokens.gutter;
    final double panelWidth = MediaQuery.sizeOf(context).width - gutter * 2;
    final double scale =
        (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(0.9, 1.5);
    final double imageHeight = panelWidth * 0.56;
    final double height = imageHeight + 88 * scale + 46;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(gutter, 18, gutter, 10),
          child: Kicker(widget.label ?? context.strings.featuredStories),
        ),
        SizedBox(
          height: height,
          child: PageView.builder(
            controller: _controller,
            padEnds: false,
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            onPageChanged: (int page) {
              if (page != _page) setState(() => _page = page);
            },
            itemBuilder: (BuildContext context, int index) {
              final Article article = items[index];
              return Padding(
                padding: EdgeInsetsDirectional.only(start: index == 0 ? gutter : 10),
                child: _FeaturedPanel(
                  article: article,
                  source: widget.sourceFor(article),
                  imageHeight: imageHeight,
                  onOpen: () => widget.onOpen(article),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: gutter),
          child: Row(
            children: <Widget>[
              for (int i = 0; i < items.length; i++)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 5),
                  child: AnimatedContainer(
                    duration: motion.standard,
                    curve: Tokens.easeStandard,
                    width: i == _page ? 22 : 7,
                    height: 2.5,
                    decoration: BoxDecoration(
                      color: i == _page
                          ? context.colors.primary
                          : context.colors.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              const Spacer(),
              BookmarkAction(article: items[_page.clamp(0, items.length - 1)], dense: true),
            ],
          ),
        ),
      ],
    );
  }
}

class _FeaturedPanel extends StatelessWidget {
  const _FeaturedPanel({
    required this.article,
    required this.source,
    required this.imageHeight,
    required this.onOpen,
  });

  final Article article;
  final NewsSource? source;
  final double imageHeight;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onOpen,
      scale: 0.99,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(Tokens.radiusSm),
            child: SizedBox(
              height: imageHeight,
              width: double.infinity,
              child: RemoteImage(url: article.imageUrl!),
            ),
          ),
          const SizedBox(height: 12),
          Attribution(article: article, source: source, compact: true),
          const SizedBox(height: 6),
          Flexible(
            child: Text(
              article.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: context.texts.headlineSmall?.copyWith(
                fontFamily: Tokens.serif,
                fontSize: 20,
                height: 1.32,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
