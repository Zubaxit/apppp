import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/extensions.dart';
import '../../data/models/app_preferences.dart';
import '../../state/feed_controller.dart';
import '../../state/saved_controller.dart';
import '../../state/settings_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../screens/categories_screen.dart';
import '../screens/home_screen.dart';
import '../screens/newspapers_screen.dart';
import '../screens/saved_screen.dart';
import '../screens/settings_screen.dart';
import '../widgets/editorial.dart';

/// Bottom-navigation shell. Each tab keeps its own scroll state; the detail
/// routes are pushed on the root navigator so the Android back button behaves
/// predictably (pop the detail, then switch to Home).
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  int _index = 0;
  bool _started = false;

  /// Drives the short fade-through when a tab changes. The tab itself is an
  /// IndexedStack child, so its scroll position and state survive the fade.
  late final AnimationController _tabFade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: 1,
  );

  static const List<Widget> _tabs = <Widget>[
    HomeScreen(),
    CategoriesScreen(),
    NewspapersScreen(),
    SavedScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_start()));
  }

  Future<void> _start() async {
    if (_started || !mounted) return;
    _started = true;
    final FeedController feed = context.read<FeedController>();
    final SavedController saved = context.read<SavedController>();
    final SettingsController settings = context.read<SettingsController>();
    await saved.load();
    await feed.start();
    if (settings.defaultFeed == DefaultFeed.following && settings.followedSourceIds.isNotEmpty) {
      await feed.setFollowedOnly(true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && mounted) {
      unawaited(context.read<FeedController>().refreshIfStale());
      unawaited(context.read<SavedController>().refreshHistory());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabFade.dispose();
    super.dispose();
  }

  void _switchTo(int index) {
    if (index == _index) return;
    if (!Motion.of(context).reduce) {
      _tabFade
        ..value = 0
        ..forward();
    }
    setState(() => _index = index);
  }

  void _onDestinationSelected(int index) => _switchTo(index);

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        if (_index != 0) _switchTo(0);
      },
      child: Scaffold(
        extendBody: true,
        body: FadeTransition(
          opacity: CurvedAnimation(parent: _tabFade, curve: Curves.easeOut),
          child: IndexedStack(index: _index, children: _tabs),
        ),
        bottomNavigationBar: _GlassNav(
          index: _index,
          onSelected: _onDestinationSelected,
          labels: <String>[
            settings.strings.navHome,
            settings.strings.navCategories,
            settings.strings.navPapers,
            settings.strings.navSaved,
            settings.strings.navSettings,
          ],
        ),
      ),
    );
  }
}

/// Floating, frosted navigation bar.
///
/// Kept short and quiet: five destinations, no labels shouting, a soft tinted
/// capsule behind the active icon.
class _GlassNav extends StatelessWidget {
  const _GlassNav({
    required this.index,
    required this.onSelected,
    required this.labels,
  });

  final int index;
  final ValueChanged<int> onSelected;
  final List<String> labels;

  static const List<IconData> _icons = <IconData>[
    Icons.article_outlined,
    Icons.grid_view_outlined,
    Icons.menu_book_outlined,
    Icons.bookmark_border_rounded,
    Icons.tune_rounded,
  ];

  static const List<IconData> _activeIcons = <IconData>[
    Icons.article_rounded,
    Icons.grid_view_rounded,
    Icons.menu_book_rounded,
    Icons.bookmark_rounded,
    Icons.tune_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final Motion motion = Motion.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.paddingOf(context).bottom > 0 ? 10 : 14,
      ),
      child: GlassBar(
        radius: 26,
        floating: true,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            for (int i = 0; i < _icons.length; i++)
              Expanded(
                child: Semantics(
                  selected: i == index,
                  button: true,
                  label: labels[i],
                  child: Pressable(
                    onTap: () => onSelected(i),
                    scale: 0.94,
                    child: AnimatedContainer(
                      duration: motion.fast,
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: i == index
                            ? context.colors.primary.withValues(alpha: 0.10)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            i == index ? _activeIcons[i] : _icons[i],
                            size: 21,
                            color: i == index
                                ? context.colors.primary
                                : context.colors.onSurfaceVariant,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            labels[i],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.texts.labelSmall?.copyWith(
                              fontSize: 9.5,
                              fontWeight:
                                  i == index ? FontWeight.w700 : FontWeight.w500,
                              letterSpacing: 0.1,
                              color: i == index
                                  ? context.colors.primary
                                  : context.colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
