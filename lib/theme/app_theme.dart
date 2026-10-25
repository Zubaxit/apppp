import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

/// Amar News colour system: graphite on warm paper, with one printed red.
///
/// Every surface, border and accent the interface uses resolves here or in
/// [Tokens]; no widget picks a colour by hand, which is what keeps a grayscale
/// interface from drifting into grey mush.
class AppColors {
  const AppColors._();

  /// The brand accent. Deep enough to print, bright enough to read on glass.
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

  /// Readable red for dark surfaces (a deep red would disappear on graphite).
  static const Color redOnDark = Tokens.accentNight;

  /// Semantic states.
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
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.inkSoft,
      error: Tokens.danger,
      surfaceContainerHighest: AppColors.paperDeep,
      outline: Tokens.hairlineStrong,
      outlineVariant: AppColors.line,
    );
    return _build(
      scheme: scheme,
      background: AppColors.paper,
      surfaceAlt: AppColors.paperDeep,
      inkSoft: AppColors.inkSoft,
      divider: AppColors.line,
      brightness: Brightness.light,
    );
  }

  static ThemeData dark() {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: AppColors.brandRed,
      brightness: Brightness.dark,
    ).copyWith(
      primary: Tokens.accentNight,
      onPrimary: const Color(0xFF2A0308),
      secondary: const Color(0xFFFF9AA0),
      surface: AppColors.nightSurface,
      onSurface: AppColors.nightInk,
      onSurfaceVariant: Tokens.nightInkMuted,
      error: Tokens.accentNight,
      surfaceContainerHighest: AppColors.nightSurfaceAlt,
      outline: const Color(0xFF3A3A3E),
      outlineVariant: AppColors.nightLine,
    );
    return _build(
      scheme: scheme,
      background: AppColors.nightBg,
      surfaceAlt: AppColors.nightSurfaceAlt,
      inkSoft: AppColors.nightInkSoft,
      divider: AppColors.nightLine,
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
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      dividerColor: divider,
      dividerTheme: DividerThemeData(color: divider, thickness: 0.8, space: 0.8),
      fontFamily: _sans,
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        systemOverlayStyle: brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        titleTextStyle: text.titleLarge?.copyWith(
          fontFamily: _serif,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceAlt,
        selectedColor: scheme.primary,
        side: BorderSide(color: divider),
        labelStyle: text.labelLarge,
        secondaryLabelStyle: text.labelLarge?.copyWith(color: scheme.onPrimary),
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
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : inkSoft,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        hintStyle: text.bodyMedium?.copyWith(color: inkSoft),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.2),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: brightness == Brightness.dark
            ? AppColors.nightSurfaceAlt
            : AppColors.ink,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: brightness == Brightness.dark ? AppColors.nightInk : Colors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: inkSoft,
        textColor: scheme.onSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: _EditorialPageTransitionBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static TextTheme _textTheme(ColorScheme scheme, Color inkSoft) {
    final Color strong = scheme.onSurface;
    return TextTheme(
      // Serif display faces carry the editorial identity.
      displayLarge: TextStyle(
        fontFamily: _serif,
        fontSize: 34,
        height: 1.28,
        fontWeight: FontWeight.w700,
        color: strong,
        letterSpacing: -0.2,
      ),
      displayMedium: TextStyle(
        fontFamily: _serif,
        fontSize: 28,
        height: 1.3,
        fontWeight: FontWeight.w700,
        color: strong,
      ),
      displaySmall: TextStyle(
        fontFamily: _serif,
        fontSize: 24,
        height: 1.32,
        fontWeight: FontWeight.w600,
        color: strong,
      ),
      headlineLarge: TextStyle(
        fontFamily: _serif,
        fontSize: 22,
        height: 1.34,
        fontWeight: FontWeight.w700,
        color: strong,
      ),
      headlineMedium: TextStyle(
        fontFamily: _serif,
        fontSize: 19,
        height: 1.36,
        fontWeight: FontWeight.w600,
        color: strong,
      ),
      headlineSmall: TextStyle(
        fontFamily: _serif,
        fontSize: 17,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: strong,
      ),
      titleLarge: TextStyle(
        fontFamily: _sans,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: strong,
      ),
      titleMedium: TextStyle(
        fontFamily: _sans,
        fontSize: 15.5,
        fontWeight: FontWeight.w600,
        color: strong,
      ),
      titleSmall: TextStyle(
        fontFamily: _sans,
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: strong,
      ),
      bodyLarge: TextStyle(fontFamily: _sans, fontSize: 16, height: 1.6, color: strong),
      bodyMedium: TextStyle(fontFamily: _sans, fontSize: 14.5, height: 1.55, color: strong),
      bodySmall: TextStyle(fontFamily: _sans, fontSize: 12.5, height: 1.45, color: inkSoft),
      labelLarge: TextStyle(
        fontFamily: _sans,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: strong,
      ),
      labelMedium: TextStyle(
        fontFamily: _sans,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: inkSoft,
      ),
      labelSmall: TextStyle(
        fontFamily: _sans,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: inkSoft,
        letterSpacing: 0.3,
      ),
    );
  }

  /// Serif style used by headline widgets, honouring the user's text scale.
  static TextStyle headlineStyle(ThemeData theme, {double scale = 1, bool hero = false}) {
    final TextStyle base = hero
        ? (theme.textTheme.displaySmall ?? const TextStyle())
        : (theme.textTheme.headlineMedium ?? const TextStyle());
    return base.copyWith(fontSize: (base.fontSize ?? 18) * scale);
  }
}

/// A calm fade + small rise, used for every pushed route.
class _EditorialPageTransitionBuilder extends PageTransitionsBuilder {
  const _EditorialPageTransitionBuilder();

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
    final CurvedAnimation fade = CurvedAnimation(
      parent: animation,
      curve: Tokens.easeStandard,
      reverseCurve: Tokens.easeExit,
    );
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.035),
          end: Offset.zero,
        ).animate(fade),
        child: child,
      ),
    );
  }
}
