import 'package:flutter/material.dart';

/// Amar News design tokens — "paper over glass".
///
/// The interface is built from three layers:
///
///   1. an *aurora* backdrop (soft, static, warm-grey blooms) that gives the
///      translucent materials something to refract;
///   2. *glass* chrome and controls that float above the content with real
///      backdrop blur, a translucent gradient fill, a hairline and a top sheen;
///   3. *editorial* content — flat paper, serif type and hairlines — that never
///      gets glass, so reading is never reduced by a filter.
///
/// Every colour, radius, blur and duration in the app resolves here.
class Tokens {
  const Tokens._();

  // ---------------------------------------------------------------- colour
  /// Warm pale grey — the app's paper, one step off white so glass reads.
  static const Color paper = Color(0xFFF3F1EE);
  static const Color paperRaised = Color(0xFFFBFAF8);
  static const Color paperSunken = Color(0xFFE8E5E0);

  /// Graphite ink, not black: high contrast without a harsh screen.
  static const Color ink = Color(0xFF17181A);
  static const Color inkMuted = Color(0xFF54575C);
  static const Color inkFaint = Color(0xFF8A8E94);

  /// The single accent: a printed deep red.
  static const Color accent = Color(0xFFAE1B27);
  static const Color accentSoft = Color(0xFFCB4A55);
  static const Color accentTint = Color(0xFFF7E6E8);

  /// Breaking news gets its own signal colour so the accent stays a brand cue.
  static const Color signal = Color(0xFFBF1224);

  /// Semantic states, used only where they carry meaning.
  static const Color success = Color(0xFF1E6B48);
  static const Color warning = Color(0xFF94600A);
  static const Color danger = Color(0xFFB0231C);

  static const Color hairline = Color(0xFFE0DCD6);
  static const Color hairlineStrong = Color(0xFFC9C4BC);

  /// Glass bases (the fill is translucent; these are the colours being mixed).
  static const Color glassLight = Color(0xFFFFFFFF);
  static const Color glassDark = Color(0xFF18191C);

  /// Night edition: rich charcoal, never pure black.
  static const Color nightBg = Color(0xFF0B0C0E);
  static const Color nightRaised = Color(0xFF15171A);
  static const Color nightSunken = Color(0xFF07080A);
  static const Color nightInk = Color(0xFFF2F1EE);
  static const Color nightInkMuted = Color(0xFFAEAFB3);
  static const Color nightInkFaint = Color(0xFF7F8288);
  static const Color nightHairline = Color(0xFF2A2C31);

  /// Readable red on charcoal (the deep red would sink into it).
  static const Color accentNight = Color(0xFFF2606B);

  /// Aurora blooms: almost grey, one of them faintly warm, used at low opacity.
  static const List<Color> auroraLight = <Color>[
    Color(0xFFE7E3DC),
    Color(0xFFEDE7E4),
    Color(0xFFE3E6E8),
  ];
  static const List<Color> auroraDark = <Color>[
    Color(0xFF1B1D21),
    Color(0xFF22191B),
    Color(0xFF141A1E),
  ];

  // ------------------------------------------------------------- typography
  static const String serif = 'NotoSerifBengali';
  static const String sans = 'NotoSansBengali';

  static const double displaySize = 34;
  static const double headlineSize = 25;
  static const double titleSize = 19;
  static const double leadSize = 16;
  static const double bodySize = 15;
  static const double captionSize = 12.5;
  static const double labelSize = 11.5;

  // ---------------------------------------------------------------- spacing
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Page gutter — every screen starts from this edge.
  static const double gutter = 20;

  // ----------------------------------------------------------------- shapes
  static const double radiusXs = 7;
  static const double radiusSm = 11;
  static const double radiusMd = 16;
  static const double radiusLg = 22;
  static const double radiusXl = 30;
  static const double radiusPill = 999;

  // ------------------------------------------------------------------- blur
  /// Blur sigmas. Chrome that must stay legible over busy photos uses
  /// [blurStrong]; floating bars use [blurBar]; small controls use [blurSoft].
  static const double blurSoft = 12;
  static const double blurBar = 22;
  static const double blurStrong = 30;

  // ----------------------------------------------------------------- motion
  /// Interaction durations for the non-spring parts of the system. Anything
  /// that responds to a finger uses a spring instead (see `Springs`).
  static const Duration tap = Duration(milliseconds: 120);
  static const Duration standard = Duration(milliseconds: 220);
  static const Duration emphasized = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 460);

  // Legacy aliases.
  static const Duration fast = tap;
  static const Duration base = standard;

  static const Curve easing = Curves.easeOutCubic;
  static const Curve easeStandard = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Curve easeEmphasized = Cubic(0.2, 0.8, 0.2, 1);
  static const Curve easeExit = Cubic(0.4, 0.0, 1.0, 1.0);
  static const Curve easeOvershoot = Curves.easeOutBack;
  static const Curve eased = Curves.easeOutCubic;

  // Legacy aliases.
  static const Curve emphasizedCurve = easeEmphasized;

  // -------------------------------------------------------------- elevation
  /// Soft, layered shadows. Two stops: a wide ambient one and a tight contact
  /// one, which is what makes a surface read as floating rather than smudged.
  static List<BoxShadow> shadow(BuildContext context, {double lift = 1}) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    if (dark) {
      return <BoxShadow>[
        BoxShadow(
          color: const Color(0xFF000000).withValues(alpha: 0.40 * lift),
          blurRadius: 26 * lift,
          offset: Offset(0, 12 * lift),
        ),
      ];
    }
    return <BoxShadow>[
      BoxShadow(
        color: const Color(0xFF2A2A2E).withValues(alpha: 0.10 * lift),
        blurRadius: 30 * lift,
        offset: Offset(0, 14 * lift),
      ),
      BoxShadow(
        color: const Color(0xFF2A2A2E).withValues(alpha: 0.06 * lift),
        blurRadius: 6 * lift,
        offset: Offset(0, 2 * lift),
      ),
    ];
  }
}
