import 'package:flutter/material.dart';

import '../../core/extensions.dart';
import '../../data/models/article.dart';
import '../../data/models/news_source.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../screens/article_detail_screen.dart';
import '../screens/article_list_screen.dart';
import '../screens/newspapers_screen.dart';
import '../screens/source_detail_screen.dart';
import '../screens/source_health_screen.dart';
import '../services/link_launcher.dart';

/// Shared route builder: a calm fade + rise, disabled when motion is reduced.
Route<T> editorialRoute<T>(Widget page, {String? name}) {
  return PageRouteBuilder<T>(
    settings: RouteSettings(name: name),
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondary) =>
        page,
    transitionsBuilder: (BuildContext context, Animation<double> animation,
        Animation<double> secondary, Widget child) {
      final bool reduce = Motion.of(context).reduce;
      if (reduce) return child;
      final CurvedAnimation curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero)
              .animate(curved),
          child: child,
        ),
      );
    },
  );
}

void openArticle(BuildContext context, Article article) {
  Navigator.of(context).push<void>(
    editorialRoute<void>(ArticleDetailScreen(article: article), name: 'article'),
  );
}

void openSource(BuildContext context, NewsSource source) {
  Navigator.of(context).push<void>(
    editorialRoute<void>(SourceDetailScreen(source: source), name: 'source'),
  );
}

/// Opens the publication directory as a pushed page (used from empty states).
void openSourceDirectory(BuildContext context) {
  Navigator.of(context).push<void>(
    editorialRoute<void>(const NewspapersScreen(standalone: true), name: 'directory'),
  );
}

void openSourceHealth(BuildContext context) {
  Navigator.of(context).push<void>(
    editorialRoute<void>(const SourceHealthScreen(), name: 'health'),
  );
}

void openArticleList(
  BuildContext context, {
  required String title,
  Set<ArticleTopic> topics = const <ArticleTopic>{},
  Set<String> sourceIds = const <String>{},
  Set<SourceLanguage> languages = const <SourceLanguage>{},
  String? subtitle,
}) {
  Navigator.of(context).push<void>(
    editorialRoute<void>(
      ArticleListScreen(
        title: title,
        subtitle: subtitle,
        topics: topics,
        sourceIds: sourceIds,
        languages: languages,
      ),
      name: 'list',
    ),
  );
}

/// Opens a validated external URL and reports failures inline.
Future<void> openUrlFeedback(BuildContext context, String? url, {bool inApp = false}) async {
  final bool ok = await LinkLauncher.open(url, inApp: inApp);
  if (!ok && context.mounted) {
    context.showSnack(context.strings.openFailed);
  }
}
