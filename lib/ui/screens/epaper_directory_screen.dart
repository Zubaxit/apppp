import 'package:flutter/material.dart';

import '../../core/extensions.dart';
import '../../data/models/news_source.dart';
import '../helpers/app_nav.dart';
import '../widgets/common.dart';

/// Directory of publisher-hosted e-paper editions.
///
/// The app never mirrors or downloads an edition; it opens the publisher's own
/// destination, because access terms are set by the publisher.
class EpaperDirectoryScreen extends StatelessWidget {
  const EpaperDirectoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final SourceRegistry registry = context.registry;
    final bool bengali = context.isBengali;
    final List<EpaperEdition> editions = registry.epapers;

    return Scaffold(
      appBar: AppBar(title: Text(context.strings.epaperSectionTitle)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 30),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colors.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.info_outline_rounded,
                    size: 15,
                    color: context.colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(context.strings.epaperNote, style: context.texts.labelSmall),
                  ),
                ],
              ),
            ),
          ),
          if (editions.isEmpty)
            EmptyState(
              icon: Icons.menu_book_outlined,
              title: context.strings.noEpaperListed,
              body: context.strings.epaperNote,
            )
          else
            ...editions.map((EpaperEdition edition) {
              final NewsSource? source = registry.byId(edition.sourceId);
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                leading: source == null
                    ? const Icon(Icons.menu_book_outlined)
                    : SourceAvatar(source: source, size: 40),
                title: Text(
                  edition.localizedName(bengali: bengali),
                  style: context.texts.titleSmall,
                ),
                subtitle: Text(
                  source?.localizedName(bengali: bengali) ?? edition.url,
                  style: context.texts.labelSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Icon(Icons.open_in_new_rounded, size: 18, color: context.colors.primary),
                onTap: () => openUrlFeedback(context, edition.url),
              );
            }),
        ],
      ),
    );
  }
}
