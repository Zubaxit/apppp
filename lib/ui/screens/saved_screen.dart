import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/extensions.dart';
import '../../data/models/article.dart';
import '../../data/models/news_source.dart';
import '../../state/saved_controller.dart';
import '../../state/settings_controller.dart';
import '../helpers/app_nav.dart';
import '../widgets/article_card.dart';
import '../widgets/common.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void initState() {
    super.initState();
    // The app-bar action depends on the visible tab, so rebuild on change.
    _tabs.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabs.indexIsChanging) return;
    setState(() {});
  }

  @override
  void dispose() {
    _tabs
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SavedController saved = context.watch<SavedController>();
    final SettingsController settings = context.watch<SettingsController>();
    final SourceRegistry registry = context.registry;
    final bool bengali = context.isBengali;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.strings.savedTitle),
        bottom: TabBar(
          controller: _tabs,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: <Widget>[
            Tab(text: '${context.strings.savedTitle} (${saved.count})'),
            Tab(text: context.strings.historyTitle),
          ],
        ),
        actions: <Widget>[
          if (_tabs.index == 1 && settings.historyEnabled)
            IconButton(
              tooltip: context.strings.clear,
              onPressed: () => _confirmClearHistory(context),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: TabBarView(
        controller: _tabs,
        children: <Widget>[
          _ArticleList(
            loading: saved.isLoading,
            items: saved.saved,
            emptyIcon: Icons.bookmark_border_rounded,
            emptyTitle: context.strings.savedEmptyTitle,
            emptyBody: context.strings.savedEmptyBody,
            registry: registry,
            bengali: bengali,
          ),
          if (!settings.historyEnabled)
            EmptyState(
              icon: Icons.history_toggle_off_rounded,
              title: context.strings.historyDisabled,
              body: context.strings.historyToggleBody,
            )
          else
            _ArticleList(
              loading: saved.isLoading,
              items: saved.history,
              emptyIcon: Icons.history_rounded,
              emptyTitle: context.strings.historyEmptyTitle,
              emptyBody: context.strings.historyEmptyBody,
              registry: registry,
              bengali: bengali,
              showSavedDate: true,
            ),
        ],
      ),
    );
  }

  Future<void> _confirmClearHistory(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(context.strings.historyTitle),
        content: Text(context.strings.historyEmptyBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.strings.clear),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<SavedController>().clearHistory();
    }
  }
}

class _ArticleList extends StatelessWidget {
  const _ArticleList({
    required this.loading,
    required this.items,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyBody,
    required this.registry,
    required this.bengali,
    this.showSavedDate = false,
  });

  final bool loading;
  final List<SavedArticle> items;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyBody;
  final SourceRegistry registry;
  final bool bengali;
  final bool showSavedDate;

  @override
  Widget build(BuildContext context) {
    if (loading) return const ArticleSkeleton(count: 4);
    if (items.isEmpty) {
      return ListView(
        children: <Widget>[
          EmptyState(icon: emptyIcon, title: emptyTitle, body: emptyBody),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 30, top: 4),
      itemCount: items.length + (showSavedDate ? 0 : 1),
      separatorBuilder: (BuildContext context, int index) => Divider(
        height: 0.6,
        thickness: 0.6,
        indent: 20,
        endIndent: 20,
        color: context.colors.outlineVariant,
      ),
      itemBuilder: (BuildContext context, int index) {
        final int offset = showSavedDate ? 0 : 1;
        if (index == 0 && offset == 1) {
          // Say what "saved" means before showing the list, so a saved link is
          // never mistaken for an offline copy of the story.
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
            child: Text(
              context.strings.savedKindsNote,
              style: context.texts.labelSmall?.copyWith(
                fontSize: 10.8,
                height: 1.5,
                color: context.colors.onSurfaceVariant,
              ),
            ),
          );
        }
        final SavedArticle item = items[index - offset];
        final NewsSource? source = registry.byId(item.article.sourceId);
        final bool hasExcerpt = (item.article.excerpt ?? '').trim().isNotEmpty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ArticleCard(
              article: item.article,
              source: source,
              variant: showSavedDate ? ArticleCardVariant.saved : ArticleCardVariant.standard,
              onTap: () => openArticle(context, item.article),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Row(
                children: <Widget>[
                  Icon(
                    hasExcerpt ? Icons.notes_rounded : Icons.link_rounded,
                    size: 12,
                    color: context.colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    hasExcerpt
                        ? context.strings.savedExcerptBadge
                        : context.strings.savedLinkOnlyBadge,
                    style: context.texts.labelSmall?.copyWith(
                      fontSize: 10,
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
