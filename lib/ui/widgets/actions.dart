import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/extensions.dart';
import '../../data/models/article.dart';
import '../../state/saved_controller.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../screens/article_detail_screen.dart' show LinkLauncherShare;

/// Bookmark toggle with the app's fill animation.
///
/// The outline is replaced by the solid mark with a short overshoot, the icon
/// colour moves from muted ink to the printed red, and a light haptic confirms
/// the save. With reduced motion the state simply changes — no scale, no
/// fade-in, and never a spinner.
class BookmarkAction extends StatelessWidget {
  const BookmarkAction({
    super.key,
    required this.article,
    this.size = 20,
    this.dense = false,
    this.showSnack = true,
  });

  final Article article;
  final double size;
  final bool dense;
  final bool showSnack;

  @override
  Widget build(BuildContext context) {
    final SavedController savedController = context.watch<SavedController>();
    final bool saved = savedController.isSaved(article.id);
    final Motion motion = Motion.of(context);

    return IconButton(
      visualDensity: dense ? VisualDensity.compact : VisualDensity.standard,
      iconSize: size,
      padding: EdgeInsets.all(dense ? 4 : 8),
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      tooltip: saved ? context.strings.removeSaved : context.strings.save,
      icon: AnimatedSwitcher(
        duration: motion.tap,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (Widget child, Animation<double> animation) {
          if (motion.reduce) return child;
          return ScaleTransition(
            scale: Tween<double>(begin: 0.7, end: 1).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            ),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: Icon(
          saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          key: ValueKey<bool>(saved),
          color: saved ? context.colors.primary : context.colors.onSurfaceVariant,
        ),
      ),
      onPressed: () async {
        unawaited(Haptics.confirm());
        final bool nowSaved = await savedController.toggle(article);
        if (!showSnack || !context.mounted) return;
        context.showSnack(
          nowSaved ? context.strings.savedLabel : context.strings.removeSaved,
        );
      },
    );
  }
}

/// Share sheet action. Shares the original link, never a copy of the story.
class ShareAction extends StatelessWidget {
  const ShareAction({super.key, required this.article, this.size = 20, this.dense = false});

  final Article article;
  final double size;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: dense ? VisualDensity.compact : VisualDensity.standard,
      iconSize: size,
      padding: EdgeInsets.all(dense ? 4 : 8),
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      tooltip: context.strings.share,
      icon: Icon(Icons.ios_share_rounded, color: context.colors.onSurfaceVariant),
      onPressed: () => LinkLauncherShare.shareArticle(context, article),
    );
  }
}

/// Thin reading-progress rule pinned under the toolbar.
///
/// Driven by the scroll offset of the article body, so it costs one small paint
/// per frame and never rebuilds the text.
class ReadingProgressBar extends StatelessWidget {
  const ReadingProgressBar({super.key, required this.progress, this.height = 2});

  final double progress;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double value = progress.clamp(0.0, 1.0);
          return Align(
            alignment: AlignmentDirectional.centerStart,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 90),
              curve: Curves.easeOut,
              width: constraints.maxWidth * value,
              height: height,
              color: context.colors.primary,
            ),
          );
        },
      ),
    );
  }
}

/// Small monogram chip used where a publisher needs a mark but has no logo.
class InkDot extends StatelessWidget {
  const InkDot({super.key, this.color, this.size = 3});

  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color ?? context.colors.onSurfaceVariant.withValues(alpha: 0.5),
        shape: BoxShape.circle,
      ),
    );
  }
}

/// A hairline that fades out at its ends: quieter than a full-width rule.
class FadingRule extends StatelessWidget {
  const FadingRule({super.key, this.height = 0.8, this.inset = Tokens.gutter});

  final double height;
  final double inset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: inset),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              context.colors.outlineVariant.withValues(alpha: 0),
              context.colors.outlineVariant,
              context.colors.outlineVariant.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
