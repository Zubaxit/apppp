import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'bootstrap.dart';
import 'core/l10n/app_strings.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BootstrapGate());
}

/// Shows a quiet brand splash while the registry, database and preferences
/// load, then hands over to the app. A failure here is recoverable: the user
/// can retry without reinstalling.
class BootstrapGate extends StatefulWidget {
  const BootstrapGate({super.key});

  @override
  State<BootstrapGate> createState() => _BootstrapGateState();
}

class _BootstrapGateState extends State<BootstrapGate> {
  Future<AppBootstrap>? _future;

  @override
  void initState() {
    super.initState();
    _future = AppBootstrap.create();
  }

  void _retry() {
    setState(() {
      _future = AppBootstrap.create();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppBootstrap>(
      future: _future,
      builder: (BuildContext context, AsyncSnapshot<AppBootstrap> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _SplashScreen();
        }
        if (snapshot.hasError || snapshot.data == null) {
          if (kDebugMode) {
            debugPrint('Bootstrap failed: ${snapshot.error}');
          }
          return _BootstrapError(message: '${snapshot.error ?? 'Unknown error'}', onRetry: _retry);
        }
        return snapshot.data!.buildRoot();
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    const AppStrings strings = BanglaStrings();
    final ThemeData theme = AppTheme.light();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: AppStringsScope(
        strings: strings,
        child: Scaffold(
          backgroundColor: AppColors.paper,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.brandGreen,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.newspaper_rounded, color: Colors.white, size: 32),
                ),
                const SizedBox(height: 18),
                Text(
                  strings.appName,
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(strings.appTagline, style: theme.textTheme.bodySmall),
                const SizedBox(height: 26),
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BootstrapError extends StatelessWidget {
  const _BootstrapError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    const AppStrings strings = BanglaStrings();
    final ThemeData theme = AppTheme.light();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: AppStringsScope(
        strings: strings,
        child: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.error_outline_rounded, size: 40, color: AppColors.flagRed),
                  const SizedBox(height: 14),
                  Text(strings.loadError, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    strings.errorBody,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 18),
                  FilledButton(onPressed: onRetry, child: Text(strings.retry)),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
