import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/extensions.dart';
import '../../core/l10n/labels.dart';
import '../../data/models/article.dart';
import '../../data/models/news_source.dart';
import '../../state/feed_controller.dart';
import '../helpers/app_nav.dart';
import '../widgets/common.dart';
import '../widgets/feed_widgets.dart';
import 'epaper_directory_screen.dart';
import 'newspapers_screen.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  static const List<ArticleTopic> _topics = <ArticleTopic>[
    ArticleTopic.bangladesh,
    ArticleTopic.politics,
    ArticleTopic.economy,
    ArticleTopic.international,
    ArticleTopic.sports,
    ArticleTopic.entertainment,
    ArticleTopic.technology,
    ArticleTopic.education,
    ArticleTopic.health,
    ArticleTopic.lifestyle,
  ];

  @override
  Widget build(BuildContext context) {
    final bool bengali = context.isBengali;
    final FeedController feed = context.watch<FeedController>();
    final Map<ArticleTopic, int> counts = <ArticleTopic, int>{};
    for (final Article article in feed.articles) {
      counts[article.topic] = (counts[article.topic] ?? 0) + 1;
    }
    final SourceRegistry registry = context.registry;
    final List<String> divisions = registry.divisionsWithSources;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.strings.navCategories),
        actions: <Widget>[
          IconButton(
            tooltip: context.strings.sourceHealth,
            onPressed: () => openSourceHealth(context),
            icon: const Icon(Icons.monitor_heart_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 30),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Text(
              context.strings.categoriesSubtitle,
              style: context.texts.bodyMedium?.copyWith(color: context.texts.bodySmall?.color),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.55,
              ),
              itemCount: _topics.length,
              itemBuilder: (BuildContext context, int index) {
                final ArticleTopic topic = _topics[index];
                final int count = counts[topic] ?? 0;
                return _TopicCard(
                  topic: topic,
                  count: count,
                  onTap: () => openArticleList(
                    context,
                    title: Labels.topic(topic, bengali: bengali),
                    subtitle: bengali ? 'এই বিভাগের সর্বশেষ খবর' : 'Latest in this section',
                    topics: <ArticleTopic>{topic},
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 26),
          SectionHeader(
            title: context.strings.regionalSources,
            subtitle: bengali
                ? 'বিভাগ অনুযায়ী আঞ্চলিক পত্রিকা'
                : 'Regional publications by division',
          ),
          if (divisions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(context.strings.regionalEmpty, style: context.texts.bodySmall),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: divisions.map((String division) {
                  final int count =
                      registry.sources.where((NewsSource s) => s.division == division).length;
                  return ActionChip(
                    avatar: const Icon(Icons.map_outlined, size: 15),
                    label: Text('$division · $count'),
                    onPressed: () => _openRegional(context, division),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 22),
          SectionHeader(title: context.strings.browseDirectory),
          PrimaryActionCard(
            icon: Icons.newspaper_rounded,
            title: context.strings.directoryTitle,
            subtitle: bengali
                ? '${registry.sources.length}টি উৎস · ${registry.epapers.length}টি ই-পেপার'
                : '${registry.sources.length} sources · ${registry.epapers.length} e-papers',
            onTap: () => Navigator.of(context).push<void>(
              editorialRoute<void>(const NewspapersScreen(standalone: true), name: 'directory'),
            ),
          ),
          PrimaryActionCard(
            icon: Icons.menu_book_rounded,
            title: context.strings.epaperSectionTitle,
            subtitle: bengali ? 'পত্রিকার ই-পেপার সংস্করণ' : 'Publisher e-paper editions',
            onTap: () => Navigator.of(context).push<void>(
              editorialRoute<void>(const EpaperDirectoryScreen(), name: 'epapers'),
            ),
          ),
        ],
      ),
    );
  }

  void _openRegional(BuildContext context, String division) {
    Navigator.of(context).push<void>(
      editorialRoute<void>(
        NewspapersScreen(standalone: true, initialDivision: division),
        name: 'regional',
      ),
    );
  }
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({required this.topic, required this.count, required this.onTap});

  final ArticleTopic topic;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool bengali = context.isBengali;
    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.colors.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Labels.topicIcon(topic),
                  size: 18,
                  color: context.colors.primary,
                ),
              ),
              const Spacer(),
              Text(
                Labels.topic(topic, bengali: bengali),
                style: context.texts.titleSmall?.copyWith(fontSize: 14.5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                bengali ? '$count টি খবর' : '$count stories',
                style: context.texts.labelSmall?.copyWith(fontSize: 10.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
