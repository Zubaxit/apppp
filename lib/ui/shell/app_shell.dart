import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/extensions.dart';
import '../../data/models/app_preferences.dart';
import '../../state/feed_controller.dart';
import '../../state/saved_controller.dart';
import '../../state/settings_controller.dart';
import '../screens/categories_screen.dart';
import '../screens/home_screen.dart';
import '../screens/newspapers_screen.dart';
import '../screens/saved_screen.dart';
import '../screens/settings_screen.dart';

/// Bottom-navigation shell. Each tab keeps its own scroll state; the detail
/// routes are pushed on the root navigator so the Android back button behaves
/// predictably (pop the detail, then switch to Home).
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _index = 0;
  bool _started = false;

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
    super.dispose();
  }

  void _onDestinationSelected(int index) {
    if (index == _index) return;
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        if (_index != 0) setState(() => _index = 0);
      },
      child: Scaffold(
        body: IndexedStack(index: _index, children: _tabs),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _onDestinationSelected,
          destinations: <Widget>[
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home_rounded),
              label: settings.strings.navHome,
            ),
            NavigationDestination(
              icon: const Icon(Icons.grid_view_outlined),
              selectedIcon: const Icon(Icons.grid_view_rounded),
              label: settings.strings.navCategories,
            ),
            NavigationDestination(
              icon: const Icon(Icons.newspaper_outlined),
              selectedIcon: const Icon(Icons.newspaper_rounded),
              label: settings.strings.navPapers,
            ),
            NavigationDestination(
              icon: const Icon(Icons.bookmark_border_rounded),
              selectedIcon: const Icon(Icons.bookmark_rounded),
              label: settings.strings.navSaved,
            ),
            NavigationDestination(
              icon: const Icon(Icons.tune_outlined),
              selectedIcon: const Icon(Icons.tune_rounded),
              label: settings.strings.navSettings,
            ),
          ],
        ),
      ),
    );
  }
}
