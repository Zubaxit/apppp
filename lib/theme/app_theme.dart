import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

/// Amar News colour system: pale grey paper, graphite type, one printed red.
///
/// Widgets never pick a colour by hand; every surface resolves through here or
/// [Tokens], which is what keeps eight screens looking like one product.
class AppColors {
  const AppColors._();

  static const Color brandRed = Tokens.accent;
  static const Color brandRedBright = Tokens.accentSoft;
  static const Color brandRedTint = Tokens.accentTint;

  static const Color flagRed = Tokens.signal;
  static const Color paper = Tokens.paper;
  static const Color paperDeep = Tokens.paperSunken;
  static const Color ink = Tokens.ink;
  static const Color inkSoft = Tokens.inkMuted;
  static const Color inkFaint = Tokens.inkFaint;
  static const Color line = Tokens.hairline;

  static const Color nightBg = Tokens.nightBg;
  static const Color nightSurface = Tokens.nightRaised;
  static const Color nightSurfaceAlt = Tokens.nightRaised;
  static const Color nightLine = Tokens.nightHairline;
  static const Color nightInk = Tokens.nightInk;
  static const Color nightInkSoft = Tokens.nightInkMuted;

  /// Readable red for charcoal surfaces.
  static const Color redOnDark = Tokens.accentNight;

  static const Color success = Tokens.success;
  static const Color warning = Tokens.warning;
  static const Color danger = Tokens.danger;
}

class AppTheme {
  const AppTheme._();

  static const String _sans = 'NotoSansBengali';
  static const String _serif = 'NotoSerifBengali';

  static ThemeData light() {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: AppColors.brandRed,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.brandRed,
      onPrimary: Colors.white,
      secondary: AppColors.brandRedBright,
      surface: Tokens.paperRaised,
      onSurface: Tokens.ink,
      onSurfaceVariant: Tokens.inkMuted,
      error: Tokens.danger,
      surfaceContainerHighest: Tokens.paperSunken,
      outline: Tokens.hairlineStrong,
      outlineVariant: Tokens.hairline,
    );
    return _build(
      scheme: scheme,
      background: Tokens.paper,
      surfaceAlt: Tokens.paperSunken,
      inkSoft: Tokens.inkMuted,
      divider: Tokens.hairline,
      brightness: Brightness.light,
    );
  }

  static ThemeData dark() {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: Tokens.accent,
      brightness: Brightness.dark,
    ).copyWith(
      primary: Tokens.accentNight,
      onPrimary: const Color(0xFF2A0409),
      secondary: const Color(0xFFFF9CA2),
      surface: Tokens.nightRaised,
      onSurface: Tokens.nightInk,
      onSurfaceVariant: Tokens.nightInkMuted,
      error: Tokens.accentNight,
      surfaceContainerHighest: Tokens.nightRaised,
      outline: const Color(0xFF3A3D43),
      outlineVariant: Tokens.nightHairline,
    );
    return _build(
      scheme: scheme,
      background: Tokens.nightBg,
      surfaceAlt: Tokens.nightRaised,
      inkSoft: Tokens.nightInkMuted,
      divider: Tokens.nightHairline,
      brightness: Brightness.dark,
    );
  }

  static ThemeData _build({
    required ColorScheme scheme,
    required Color background,
    required Color surfaceAlt,
    required Color inkSoft,
    required Color divider,
    required Brightness brightness,
  }) {
    final TextTheme text = _textTheme(scheme, inkSoft);
    final bool dark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      dividerColor: divider,
      dividerTheme: DividerThemeData(color: divider, thickness: 0.9, space: 0.9),
      fontFamily: _sans,
      textTheme: text,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      visualDensity: VisualDensity.standard,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: _JellyPageTransitionBuilder(),
          TargetPlatform.iOS: _JellyPageTransitionBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleTextStyle: text.titleLarge?.copyWith(
          fontFamily: _serif,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: dark ? Tokens.nightRaised : Tokens.paperRaised,
        selectedColor: scheme.primary.withValues(alpha: dark ? 0.22 : 0.12),
        side: BorderSide(color: divider),
        labelStyle: text.labelLarge,
        secondaryLabelStyle: text.labelLarge?.copyWith(color: scheme.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        showCheckmark: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: 0.14),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStatePropertyAll<TextStyle?>(
          text.labelMedium?.copyWith(fontSize: 11.5, fontWeight: FontWeight.w600),
        ),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>(
          (Set<WidgetState> states) => IconThemeData(
            size: 23,
            color: states.contains(WidgetState.selected) ? scheme.primary : inkSoft,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.66),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: text.bodyMedium?.copyWith(color: inkSoft),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Tokens.radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Tokens.radiusMd),
          borderSide: BorderSide(color: divider, width: 0.9),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Tokens.radiusMd),
          borderSide: BorderSide(color: scheme.primary.withValues(alpha: 0.6)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? Tokens.nightInk : Tokens.ink,
        contentTextStyle: TextStyle(
          fontFamily: _sans,
          fontSize: 13,
          color: dark ? Tokens.ink : Tokens.nightInk,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tokens.radiusMd),
        ),
        insetPadding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: dark ? Tokens.nightRaised : Tokens.paperRaised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tokens.radiusLg),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: dark ? Tokens.nightRaised : Tokens.paperRaised,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: dark ? Tokens.nightRaised : Tokens.paperRaised,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Tokens.radiusXl)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          textStyle: const TextStyle(
            fontFamily: _sans,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Tokens.radiusPill),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: divider),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: const TextStyle(
            fontFamily: _sans,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Tokens.radiusPill),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: const TextStyle(
            fontFamily: _sans,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: dark ? Tokens.nightInk : Tokens.ink,
          borderRadius: BorderRadius.circular(Tokens.radiusXs),
        ),
        textStyle: TextStyle(
          fontFamily: _sans,
          fontSize: 11,
          color: dark ? Tokens.ink : Tokens.nightInk,
        ),
      ),
    );
  }

  static TextTheme _textTheme(ColorScheme scheme, Color inkSoft) {
    final Color ink = scheme.onSurface;
    TextStyle serif(double size, FontWeight weight, double height) => TextStyle(
          fontFamily: _serif,
          fontSize: size,
          fontWeight: weight,
          height: height,
          color: ink,
          letterSpacing: -0.1,
        );
    TextStyle sans(double size, FontWeight weight, double height, {Color? color}) =>
        TextStyle(
          fontFamily: _sans,
          fontSize: size,
          fontWeight: weight,
          height: height,
          color: color ?? ink,
        );

    return TextTheme(
      displayLarge: serif(36, FontWeight.w700, 1.22),
      displayMedium: serif(31, FontWeight.w700, 1.26),
      displaySmall: serif(27, FontWeight.w700, 1.3),
      headlineLarge: serif(23, FontWeight.w700, 1.34),
      headlineMedium: serif(20, FontWeight.w700, 1.36),
      headlineSmall: serif(17.5, FontWeight.w600, 1.4),
      titleLarge: serif(18, FontWeight.w700, 1.35),
      titleMedium: sans(15, FontWeight.w700, 1.4),
      titleSmall: sans(13.5, FontWeight.w700, 1.4),
      bodyLarge: sans(16, FontWeight.w400, 1.7),
      bodyMedium: sans(14.5, FontWeight.w400, 1.65),
      bodySmall: sans(12.5, FontWeight.w400, 1.55, color: inkSoft),
      labelLarge: sans(12.5, FontWeight.w700, 1.3),
      labelMedium: sans(11.5, FontWeight.w600, 1.3),
      labelSmall: sans(10.5, FontWeight.w600, 1.3, color: inkSoft),
    );
  }

  /// Serif style used by headline widgets, honouring the user's text scale.
  static TextStyle headlineStyle(ThemeData theme, {double scale = 1, bool hero = false}) {
    final TextStyle base =
        (hero ? theme.textTheme.displaySmall : theme.textTheme.headlineSmall) ??
            const TextStyle();
    return base.copyWith(fontSize: (base.fontSize ?? 18) * scale);
  }
}

/// A spring-feeling route transition: the incoming page rises, scales from 0.97
/// and fades, while the outgoing page recedes very slightly. Not a generic fade:
/// there is a small scale + parallax so a push reads as depth.
class _JellyPageTransitionBuilder extends PageTransitionsBuilder {
  const _JellyPageTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final bool reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) return child;

    final CurvedAnimation entering = CurvedAnimation(
      parent: animation,
      curve: const Cubic(0.17, 0.84, 0.28, 1),
      reverseCurve: Curves.easeInCubic,
    );
    final CurvedAnimation leaving = CurvedAnimation(
      parent: secondaryAnimation,
      curve: const Cubic(0.3, 0.0, 0.6, 1),
    );

    return FadeTransition(
      opacity: entering,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.035),
          end: Offset.zero,
        ).animate(entering),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.972, end: 1).animate(entering),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset.zero,
              end: const Offset(0, -0.018),
            ).animate(leaving),
            child: child,
          ),
        ),
      ),
    );
  }
}
