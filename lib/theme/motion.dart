import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

/// Spring descriptions used by the jelly interaction system.
///
/// These are physical, not decorative: a press compresses fast (high stiffness,
/// high damping so it does not wobble under a finger), and a release settles
/// with a touch of overshoot (lower damping) so the surface feels elastic.
/// Tuning is per element size — a small chip can afford more travel than a
/// full-width card.
class Springs {
  const Springs._();

  static const SpringDescription press =
      SpringDescription(mass: 1, stiffness: 900, damping: 30);
  static const SpringDescription release =
      SpringDescription(mass: 1, stiffness: 400, damping: 17);
  static const SpringDescription settle =
      SpringDescription(mass: 1, stiffness: 320, damping: 24);
  static const SpringDescription nav =
      SpringDescription(mass: 1, stiffness: 380, damping: 20);
  static const SpringDescription sheet =
      SpringDescription(mass: 1, stiffness: 300, damping: 26);
}

/// Where the "reduce motion" preference is published to the tree.
class AppMotionScope extends InheritedWidget {
  const AppMotionScope({super.key, required this.reduceMotion, required super.child});

  final bool reduceMotion;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppMotionScope>()?.reduceMotion ?? false;

  @override
  bool updateShouldNotify(AppMotionScope oldWidget) =>
      oldWidget.reduceMotion != reduceMotion;
}

/// The app's motion vocabulary.
///
/// [Motion.of] is the only way widgets read durations, and it also answers
/// whether motion is reduced (OS setting or in-app setting). When it is, the
/// springs collapse to a single short step and the interaction still gives
/// feedback through colour and a 1-frame state change.
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

  // Legacy names used by a few widgets.
  Duration get fast => tap;
  Duration get medium => standard;

  Curve get curve => Tokens.easeStandard;
  Curve get enter => Tokens.easeEmphasized;
  Curve get exit => Tokens.easeExit;
}

/// Haptics, in one place so the app never buzzes more than it should.
class Haptics {
  const Haptics._();

  static Future<void> tick() => HapticFeedbackProxy.selection();
  static Future<void> confirm() => HapticFeedbackProxy.light();
}

/// Indirection so widget tests can silence haptics without a platform channel.
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

/// The jelly interaction primitive.
///
/// Everything pressable in the app goes through this widget. It compresses on
/// touch-down with a stiff spring, springs back with mild overshoot on release,
/// lifts a soft shadow while held, and adds a light haptic on activation.
///
/// It never claims a vertical drag, so list scrolling still wins the gesture
/// arena: the pointer handlers only observe, the tap comes from a
/// [GestureDetector] that competes normally.
class JellySurface extends StatefulWidget {
  const JellySurface({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.965,
    this.haptic = true,
    this.behavior = HitTestBehavior.opaque,
    this.lift = 0,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// How far the surface compresses. Small controls can travel further than
  /// large cards, which look wrong if they visibly shrink.
  final double scale;
  final bool haptic;
  final HitTestBehavior behavior;


  /// Extra translation (px) applied while held — used sparingly for buttons.
  final double lift;
  final bool enabled;

  @override
  State<JellySurface> createState() => _JellySurfaceState();
}

class _JellySurfaceState extends State<JellySurface>
    with SingleTickerProviderStateMixin {
  // Created eagerly in initState: a controller that is first touched inside
  // dispose() would ask a deactivated element for its ticker.
  late final AnimationController _spring;
  bool _held = false;

  /// Read once per dependency change: the press handlers must never touch the
  /// element tree, because a tap can be released while the tree is unmounting.
  bool _reduce = false;

  @override
  void initState() {
    super.initState();
    _spring = AnimationController.unbounded(vsync: this, value: 1);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = Motion.of(context).reduce;
  }

  @override
  void dispose() {
    _spring.dispose();
    super.dispose();
  }

  bool get _interactive => widget.enabled && widget.onTap != null;

  void _press() {
    if (!mounted || !_interactive) return;
    setState(() => _held = true);
    if (_reduce) {
      _spring.value = widget.scale;
      return;
    }
    _spring.animateWith(
      SpringSimulation(Springs.press, _spring.value, widget.scale, 0),
    );
  }

  void _release() {
    if (!mounted) return;
    if (_held) setState(() => _held = false);
    if (_reduce) {
      _spring.value = 1;
      return;
    }
    _spring.animateWith(SpringSimulation(Springs.release, _spring.value, 1, 0));
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = widget.child;

    if (!_interactive) return content;

    // The press is driven by raw pointer events, not by the tap recogniser, so
    // the surface compresses on touch-down instead of after the tap deadline.
    return Listener(
      behavior: widget.behavior,
      onPointerDown: (_) => _press(),
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: GestureDetector(
        behavior: widget.behavior,
        // Pointer events give the instant compression; the tap callbacks are a
        // second, recogniser-driven trigger so the surface also responds on
        // platforms that resolve the arena before delivering raw events.
        onTapDown: (_) => _press(),
        onTapUp: (_) => _release(),
        onTapCancel: _release,
        onTap: () {
          if (widget.haptic) unawaited(Haptics.tick());
          widget.onTap!();
        },
        onLongPress: widget.onLongPress,
        child: AnimatedBuilder(
        animation: _spring,
        // The child is captured once: only the transform repaints.
        child: content,
        builder: (BuildContext context, Widget? child) {
          final double value = _spring.value;
          final double pressed =
              ((1 - value) / (1 - widget.scale).abs()).clamp(0.0, 1.0);
            return Transform.translate(
              offset: Offset(0, widget.lift * pressed),
              child: Transform.scale(scale: value, child: child),
            );
          },
        ),
      ),
    );
  }
}

/// A jelly button with two weights. Used where the design needs a control that
/// reads as a control — "Read in app", retry, follow — instead of a bare row.
class JellyButton extends StatelessWidget {
  const JellyButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.filled = true,
    this.expand = false,
    this.compact = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool filled;
  final bool expand;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color fg = filled
        ? Colors.white
        : (dark ? Tokens.nightInk : Tokens.ink);
    final Widget body = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 14 : 20,
        vertical: compact ? 9 : 13,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Tokens.radiusPill),
        gradient: filled
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[Color(0xFFC02A35), Tokens.accent],
              )
            : null,
        color: filled ? null : (dark ? Tokens.nightRaised : Tokens.paperRaised),
        border: filled
            ? null
            : Border.all(color: dark ? Tokens.nightHairline : Tokens.hairline),
        boxShadow: filled ? Tokens.shadow(context, lift: 0.55) : null,
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: compact ? 16 : 18, color: fg),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: Tokens.sans,
              fontSize: compact ? 13 : 14.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
              color: fg,
            ),
          ),
        ],
      ),
    );

    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: JellySurface(
        onTap: onPressed,
        scale: 0.955,
        enabled: onPressed != null,
        child: body,
      ),
    );
  }
}

/// A springy switch with a glass track. Replaces the platform switch so the
/// control matches the rest of the surfaces and animates on every tap.
class JellySwitch extends StatelessWidget {
  const JellySwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.width = 46,
    this.height = 28,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final Motion motion = Motion.of(context);
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final double knob = height - 6;
    return JellySurface(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      scale: 0.94,
      enabled: onChanged != null,
      child: AnimatedContainer(
        duration: motion.standard,
        curve: Tokens.easeStandard,
        width: width,
        height: height,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(height),
          color: value
              ? scheme.primary
              : (dark ? Tokens.nightRaised : Tokens.paperSunken),
          border: Border.all(
            color: value
                ? scheme.primary
                : (dark ? Tokens.nightHairline : Tokens.hairline),
            width: 0.9,
          ),
        ),
        child: AnimatedAlign(
          duration: motion.reduce ? Duration.zero : const Duration(milliseconds: 260),
          curve: Curves.easeOutBack,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: knob,
            height: knob,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 5,
                  offset: const Offset(0, 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A one-shot entrance for page content: rises and fades on a spring, with a
/// short stagger per index. Applied to the first few items only — never to
/// list rows that scroll into view, which would animate during scrolling.
class Reveal extends StatefulWidget {
  const Reveal({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = 18,
    this.maxIndex = 5,
  });

  final Widget child;
  final int index;
  final double offset;
  final int maxIndex;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _delay;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    final int step = widget.index.clamp(0, widget.maxIndex) * 55;
    _delay = Timer(Duration(milliseconds: step), () {
      if (mounted) _controller.animateTo(1, curve: Curves.easeOutCubic);
    });
  }

  @override
  void dispose() {
    _delay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Motion.of(context).reduce) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (BuildContext context, Widget? child) {
        final double t = _controller.value;
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - t) * widget.offset),
            child: child,
          ),
        );
      },
    );
  }
}

/// Small deferred block used by the skeleton shimmer: a soft, honest placeholder
/// that does not loop unless the surrounding screen is genuinely waiting.
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({
    super.key,
    required this.height,
    this.width,
    this.radius = Tokens.radiusSm,
    this.animate = true,
  });

  final double height;
  final double? width;
  final double radius;
  final bool animate;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox> with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool reduce = Motion.of(context).reduce;
    if (widget.animate && !reduce && _controller == null) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1500),
      )..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color ink = Theme.of(context).colorScheme.onSurface;
    final Color base = ink.withValues(alpha: 0.055);
    final Color bright = ink.withValues(alpha: 0.095);
    final AnimationController? controller = _controller;
    if (controller == null) {
      return Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      );
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) => Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          color: Color.lerp(base, bright, controller.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

