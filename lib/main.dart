import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'bootstrap.dart';
import 'core/l10n/app_strings.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';
import 'ui/widgets/brand.dart';

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
          return _BootstrapError(
              message: '${snapshot.error ?? 'Unknown error'}', onRetry: _retry);
        }
        return snapshot.data!.buildRoot();
      },
    );
  }
}

/// The opening moment: the mark rises once, the wordmark settles, and a thin
/// rule sweeps under it while the registry and database load. It is one short
/// beat — no logo animation to sit through — and it disappears the instant
/// bootstrap resolves.
class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Tokens.emphasized,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const AppStrings strings = EnglishStrings();
    final ThemeData theme = AppTheme.light();
    final bool reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final CurvedAnimation rise = CurvedAnimation(
      parent: _controller,
      curve: Tokens.easeEmphasized,
    );

    final Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const AmarNewsMark(size: 78),
        const SizedBox(height: 22),
        Wordmark(text: strings.appName, subtitle: strings.appTagline, size: 27),
        const SizedBox(height: 30),
        SizedBox(
          width: 64,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: const LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Color(0x1A191A1B),
              color: Tokens.accent,
            ),
          ),
        ),
      ],
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: AppStringsScope(
        strings: strings,
        child: Scaffold(
          backgroundColor: AppColors.paper,
          body: SafeArea(
            child: Center(
              child: reduce
                  ? content
                  : AnimatedBuilder(
                      animation: rise,
                      child: content,
                      builder: (BuildContext context, Widget? child) {
                        return Opacity(
                          opacity: rise.value,
                          child: Transform.translate(
                            offset: Offset(0, (1 - rise.value) * 10),
                            child: child,
                          ),
                        );
                      },
                    ),
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
    const AppStrings strings = EnglishStrings();
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
                  const Icon(Icons.error_outline_rounded,
                      size: 40, color: AppColors.flagRed),
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
