import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/extensions.dart';
import '../../data/models/app_preferences.dart';
import '../../state/feed_controller.dart';
import '../../state/saved_controller.dart';
import '../../state/settings_controller.dart';
import '../../theme/materials.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../screens/categories_screen.dart';
import '../screens/home_screen.dart';
import '../screens/newspapers_screen.dart';
import '../screens/saved_screen.dart';
import '../screens/settings_screen.dart';

/// The app shell: five tabs, a floating glass navigation bar, and one shared
/// springy selection indicator.
///
/// Each tab keeps its own scroll state in an [IndexedStack]; the bar floats over
/// the content with a real blur so headlines slide beneath it. Back navigation
/// pops details first, then returns to Home, then exits.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  int _index = 0;
  bool _started = false;

  late final AnimationController _tabFade;

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
    _tabFade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: 1,
    );
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
    feed.setPollingActive(_index == 0);
    if (settings.defaultFeed == DefaultFeed.following &&
        settings.followedSourceIds.isNotEmpty) {
      await feed.setFollowedOnly(true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabFade.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!mounted) return;
    final FeedController feed = context.read<FeedController>();
    final bool resumed = state == AppLifecycleState.resumed;
    feed.setPollingActive(resumed && _index == 0);
    if (resumed) {
      unawaited(feed.refreshIfStale());
      unawaited(context.read<SavedController>().refreshHistory());
    }
  }

  void _select(int index) {
    if (index == _index) return;
    unawaited(Haptics.tick());
    setState(() => _index = index);
    context.read<FeedController>().setPollingActive(index == 0);
    _tabFade
      ..value = 0
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final SettingsController settings = context.watch<SettingsController>();
    final int savedCount = context.select<SavedController, int>(
      (SavedController controller) => controller.count,
    );

    return PopScope(
      // Back on a non-home tab returns to Home; on Home it leaves the app.
      canPop: _index == 0,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        if (_index != 0) _select(0);
      },
      child: Scaffold(
        extendBody: true,
        backgroundColor: Colors.transparent,
        body: AuroraBackdrop(
          child: Stack(
            children: <Widget>[
              FadeTransition(
                opacity: _tabFade,
                child: IndexedStack(index: _index, children: _tabs),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _FloatingNav(
                  index: _index,
                  onSelected: _select,
                  savedCount: savedCount,
                  labels: <String>[
                    settings.strings.navHome,
                    settings.strings.navCategories,
                    settings.strings.navPapers,
                    settings.strings.navSaved,
                    settings.strings.navSettings,
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

/// The floating navigation bar.
///
/// A single glass capsule, inset from the screen edges, sitting above the
/// gesture bar. The selected item gets a tinted capsule that animates across
/// with a spring curve, and each item compresses on touch.
class _FloatingNav extends StatelessWidget {
  const _FloatingNav({
    required this.index,
    required this.onSelected,
    required this.labels,
    required this.savedCount,
  });

  final int index;
  final ValueChanged<int> onSelected;
  final List<String> labels;
  final int savedCount;

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
    final bool dark = context.isDark;
    final double bottomInset = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset > 0 ? 10 : 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Tokens.radiusXl),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: Tokens.blurStrong,
            sigmaY: Tokens.blurStrong,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Tokens.radiusXl),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dark
                    ? <Color>[
                        Colors.white.withValues(alpha: 0.10),
                        Colors.white.withValues(alpha: 0.045),
                      ]
                    : <Color>[
                        Colors.white.withValues(alpha: 0.88),
                        Colors.white.withValues(alpha: 0.64),
                      ],
              ),
              border: Border.all(
                color: dark
                    ? Colors.white.withValues(alpha: 0.14)
                    : Colors.white.withValues(alpha: 0.9),
                width: 0.9,
              ),
              boxShadow: Tokens.shadow(context, lift: 1),
            ),
            child: Stack(
              children: <Widget>[
                AnimatedAlign(
                  duration:
                      motion.reduce ? Duration.zero : const Duration(milliseconds: 420),
                  curve: Curves.easeOutBack,
                  alignment: Alignment(
                    -1 + (2 / (_icons.length - 1)) * index,
                    0,
                  ),
                  child: FractionallySizedBox(
                    widthFactor: 1 / _icons.length,
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(Tokens.radiusLg),
                        color: context.colors.primary.withValues(alpha: 0.10),
                        border: Border.all(
                          color: context.colors.primary.withValues(alpha: 0.18),
                          width: 0.9,
                        ),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: <Widget>[
                    for (int i = 0; i < _icons.length; i++)
                      Expanded(
                        child: _NavItem(
                          icon: _icons[i],
                          activeIcon: _activeIcons[i],
                          label: labels[i],
                          active: i == index,
                          badge: i == 3 && savedCount > 0 ? savedCount : null,
                          onTap: () => onSelected(i),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final Motion motion = Motion.of(context);
    final Color color =
        active ? context.colors.primary : context.colors.onSurfaceVariant;
    return Semantics(
      selected: active,
      button: true,
      label: label,
      child: JellySurface(
        onTap: onTap,
        scale: 0.9,
        child: SizedBox(
          height: 52,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  AnimatedSwitcher(
                    duration: motion.standard,
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      if (motion.reduce) return child;
                      return ScaleTransition(
                        scale: Tween<double>(begin: 0.82, end: 1).animate(
                          CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
                        ),
                        child: FadeTransition(opacity: animation, child: child),
                      );
                    },
                    child: Icon(
                      active ? activeIcon : icon,
                      key: ValueKey<bool>(active),
                      size: 21,
                      color: color,
                    ),
                  ),
                  if (badge != null)
                    Positioned(
                      right: -7,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: context.colors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$badge',
                          style: const TextStyle(
                            fontFamily: Tokens.sans,
                            fontSize: 8,
                            height: 1.3,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.texts.labelSmall?.copyWith(
                  fontSize: 9,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                  letterSpacing: 0.1,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
