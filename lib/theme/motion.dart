import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

/// The app's single motion vocabulary.
///
/// Every duration and curve the interface uses comes from [Tokens]; this class
/// adds the reduced-motion decision and the reusable behaviours. Animations are
/// deliberately short: the longest thing a reader ever waits for is 460 ms, and
/// nothing loops except the loading shimmer.
@immutable
class Motion {
  const Motion({required this.reduce});

  final bool reduce;

  static Motion of(BuildContext context) {
    final bool systemReduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final bool appReduce = AppMotionScope.of(context);
    return Motion(reduce: systemReduce || appReduce);
  }

  Duration get tap => reduce ? Duration.zero : Tokens.tap;
  Duration get standard => reduce ? Duration.zero : Tokens.standard;
  Duration get emphasized => reduce ? Duration.zero : Tokens.emphasized;
  Duration get slow => reduce ? Duration.zero : Tokens.slow;

  // Legacy names used by older widgets.
  Duration get fast => tap;
  Duration get medium => standard;

  Curve get curve => Tokens.easeStandard;
  Curve get enter => Tokens.easeEmphasized;
  Curve get exit => Tokens.easeExit;

  /// A rise-and-fade entrance, tuned by index so a list staggers rather than
  /// marching. Returns the child untouched when motion is reduced.
  Widget entrance({
    required Widget child,
    required Animation<double> animation,
    double from = 16,
  }) {
    if (reduce) return child;
    final CurvedAnimation curved = CurvedAnimation(
      parent: animation,
      curve: Tokens.easeEmphasized,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0, from / 100),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

/// Where a "reduce motion" preference is published to the tree.
class AppMotionScope extends InheritedWidget {
  const AppMotionScope({super.key, required this.reduceMotion, required super.child});

  final bool reduceMotion;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppMotionScope>()?.reduceMotion ?? false;

  @override
  bool updateShouldNotify(AppMotionScope oldWidget) =>
      oldWidget.reduceMotion != reduceMotion;
}

/// Haptics, kept in one place so the app never buzzes more than it should.
class Haptics {
  const Haptics._();

  /// A barely-there tick for selection changes.
  static Future<void> tick() => HapticFeedbackProxy.selection();

  /// A slightly firmer acknowledgement for a completed action (saving).
  static Future<void> confirm() => HapticFeedbackProxy.light();
}

/// Indirection so tests can silence haptics without a platform channel.
class HapticFeedbackProxy {
  const HapticFeedbackProxy._();

  static bool enabled = true;

  static Future<void> selection() async {
    if (!enabled) return;
    await _run(HapticFeedback.selectionClick);
  }

  static Future<void> light() async {
    if (!enabled) return;
    await _run(HapticFeedback.lightImpact);
  }

  static Future<void> _run(Future<void> Function() call) async {
    try {
      await call();
    } catch (_) {
      // A device without a haptic engine must never break a tap.
    }
  }
}
