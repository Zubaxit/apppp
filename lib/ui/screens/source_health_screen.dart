import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/extensions.dart';
import '../../core/utils/bengali_text.dart';
import '../../data/models/news_source.dart';
import '../../data/models/source_health.dart';
import '../../state/feed_controller.dart';
import '../../theme/materials.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../widgets/actions.dart';
import '../widgets/common.dart';

/// Transparency screen: which feeds the app could actually reach, when, and
/// what went wrong for the rest. A failing feed never hides the directory.
class SourceHealthScreen extends StatelessWidget {
  const SourceHealthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final SourceRegistry registry = context.registry;
    final FeedController feed = context.watch<FeedController>();
    final bool bengali = context.isBengali;
    final List<NewsSource> sources = registry.feedSources.toList()
      ..sort((NewsSource a, NewsSource b) {
        final int rankA = _rank(feed.healthFor(a.id));
        final int rankB = _rank(feed.healthFor(b.id));
        if (rankA != rankB) return rankA.compareTo(rankB);
        return a.name.compareTo(b.name);
      });
    final int ok = sources
        .where((NewsSource s) => feed.healthFor(s.id)?.status == SourceHealthStatus.ok)
        .length;
    final int failing = sources
        .where((NewsSource s) => feed.healthFor(s.id)?.status == SourceHealthStatus.failing)
        .length;

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
                        context.strings.sourceHealth,
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
                    JellySurface(
                      onTap: feed.isRefreshing
                          ? null
                          : () => feed.refresh(force: true),
                      scale: 0.88,
                      child: SizedBox(
                        width: 38,
                        height: 38,
                        child: Center(
                          child: feed.isRefreshing
                              ? const SizedBox(
                                  width: 17,
                                  height: 17,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(
                                  Icons.sync_rounded,
                                  size: 19,
                                  color: context.colors.onSurfaceVariant,
                                ),
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
          GlassPanel(
            radius: Tokens.radiusMd,
            blur: 0,
            elevation: 0.4,
            sheen: false,
            padding: const EdgeInsets.all(16),
            tint: context.colors.primary.withValues(alpha: 0.05),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  bengali
                      ? '$ok / ${sources.length}টি ফিড সচল'
                      : '$ok of ${sources.length} feeds working',
                  style: context.texts.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  bengali
                      ? 'প্রতিটি পত্রিকার ফিড আলাদাভাবে আনা হয়। একটি বন্ধ থাকলেও বাকিগুলো কাজ করে।'
                      : 'Each feed is fetched independently. One failure never blocks the rest.',
                  style: context.texts.labelSmall?.copyWith(height: 1.5),
                ),
                if (failing > 0) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    bengali ? '$failingটি ফিড এখন পাওয়া যাচ্ছে না' : '$failing feeds unreachable',
                    style: context.texts.labelSmall?.copyWith(color: context.colors.error),
                  ),
                ],
                if (feed.lastRefreshAt != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    '${context.strings.lastUpdated}: '
                    '${BengaliText.dateTime(feed.lastRefreshAt!, bengali: bengali)}',
                    style: context.texts.labelSmall?.copyWith(fontSize: 10.5),
                  ),
                ],
              ],
            ),
          ),
          ...sources.map((NewsSource source) {
            final SourceHealth? health = feed.healthFor(source.id);
            final bool failingRow = health?.status == SourceHealthStatus.failing;
            return Column(
              children: <Widget>[
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                  leading: SourceAvatar(source: source, size: 36),
                  title: Text(
                    source.localizedName(bengali: bengali),
                    style: context.texts.titleSmall?.copyWith(fontSize: 13.5),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const SizedBox(height: 3),
                      Text(
                        '${health?.lastSuccessAt == null ? context.strings.never : BengaliText.dateTime(health!.lastSuccessAt!, bengali: bengali)}'
                        ' · ${health?.itemCount ?? 0}'
                        '${bengali ? 'টি আইটেম' : ' items'}',
                        style: context.texts.labelSmall?.copyWith(fontSize: 10.5),
                      ),
                      if (failingRow && health?.lastError != null)
                        Text(
                          health!.lastError!,
                          style: context.texts.labelSmall?.copyWith(
                            color: context.colors.error,
                            fontSize: 10.5,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                  trailing: IconButton(
                    tooltip: context.strings.retry,
                    onPressed: feed.isRefreshing
                        ? null
                        : () => context.read<FeedController>().refreshSource(source.id),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                  ),
                ),
                Divider(
                  height: 0.6,
                  thickness: 0.6,
                  indent: 72,
                  endIndent: 20,
                  color: context.colors.outlineVariant,
                ),
              ],
            );
          }),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              bengali
                  ? 'ফিডের ঠিকানা সোর্স তালিকায় সংরক্ষিত থাকে এবং অ্যাপ চালানোর সময় যাচাই হয়। কোনো ফিড বন্ধ থাকলে পত্রিকার ওয়েবসাইট সবসময় খোলা যায়।'
                  : 'Feed endpoints come from the source registry and are verified at runtime. '
                      'A publication website always remains reachable even when its feed fails.',
              style: context.texts.labelSmall?.copyWith(height: 1.6, fontSize: 10.5),
            ),
          ),
          const SizedBox(height: 20),
          if (failing > 0)
            Center(
              child: OutlinedButton.icon(
                onPressed: feed.isRefreshing ? null : () => feed.refresh(force: true),
                icon: const Icon(Icons.sync_rounded, size: 16),
                label: Text(context.strings.recheckAll),
              ),
            ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              context.strings.appName,
              style: context.texts.labelSmall?.copyWith(
                fontSize: 10,
                color: context.colors.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
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

  static int _rank(SourceHealth? health) {
    switch (health?.status) {
      case SourceHealthStatus.failing:
        return 0;
      case SourceHealthStatus.ok:
        return 1;
      case SourceHealthStatus.disabled:
        return 2;
      case SourceHealthStatus.unknown:
      case null:
        return 3;
    }
  }
}
