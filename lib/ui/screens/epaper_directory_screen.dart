import 'package:flutter/material.dart';

import '../../core/extensions.dart';
import '../../data/models/news_source.dart';
import '../../theme/materials.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../helpers/app_nav.dart';
import '../widgets/actions.dart';
import 'browser_screen.dart';
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
      backgroundColor: Colors.transparent,
      body: AuroraBackdrop(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(Tokens.gutter, 8, Tokens.gutter, 6),
                child: Row(
                  children: <Widget>[
                    GlassIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: context.strings.back,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.strings.epaperSectionTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.texts.titleLarge?.copyWith(
                          fontFamily: Tokens.serif,
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 120),
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Tokens.gutter,
                        6,
                        Tokens.gutter,
                        14,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Icon(
                            Icons.info_outline_rounded,
                            size: 14,
                            color: context.colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              context.strings.epaperNote,
                              style: context.texts.labelSmall?.copyWith(
                                fontSize: 10.8,
                                height: 1.55,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (editions.isEmpty)
                      EmptyState(
                        icon: Icons.menu_book_outlined,
                        title: context.strings.noEpaperListed,
                        body: context.strings.epaperNote,
                      )
                    else
                      for (final EpaperEdition edition in editions)
                        _EditionRow(
                          edition: edition,
                          source: registry.byId(edition.sourceId),
                          bengali: bengali,
                        ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditionRow extends StatelessWidget {
  const _EditionRow({
    required this.edition,
    required this.source,
    required this.bengali,
  });

  final EpaperEdition edition;
  final NewsSource? source;
  final bool bengali;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Tokens.gutter, 0, Tokens.gutter, 10),
      child: JellySurface(
        onTap: () => openInBrowser(
          context,
          url: edition.url,
          title: edition.localizedName(bengali: bengali),
          source: source,
        ),
        scale: 0.985,
        child: GlassPanel(
          radius: Tokens.radiusMd,
          blur: 0,
          elevation: 0.3,
          sheen: false,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              if (source != null)
                SourceAvatar(source: source!, size: 40)
              else
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.colors.surfaceContainerHighest,
                  ),
                  child: const Icon(Icons.menu_book_outlined, size: 18),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      edition.localizedName(bengali: bengali),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.titleSmall?.copyWith(
                        fontFamily: Tokens.serif,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      source?.localizedName(bengali: bengali) ?? edition.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.labelSmall?.copyWith(fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.open_in_new_rounded,
                size: 16,
                color: context.colors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
