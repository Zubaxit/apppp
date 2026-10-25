import 'package:flutter/material.dart';

import '../../core/extensions.dart';
import '../../services/profile_store.dart';
import '../../theme/materials.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../services/link_launcher.dart';
import '../widgets/actions.dart';
import '../widgets/brand.dart';
import 'settings_screen.dart' show SettingsScreen;

/// A deliberately short About page: what Amar News does, then the confirmed
/// developer identity. No biography, contact details or invented credentials.
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key, this.store});

  static const String developerProfileUrl =
      'https://www.facebook.com/muhammad.emon.738798';

  /// Kept for source compatibility with older callers. Profile editing no
  /// longer appears here because the product brief permits only name + photo.
  final ProfileStore? store;

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (Motion.of(context).reduce) {
      _reveal.value = 1;
    } else {
      _reveal.forward();
    }
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool bengali = context.isBengali;
    final String purpose = bengali
        ? 'আমার নিউজ একটি সহজ, ব্যক্তিগতকরণযোগ্য সংবাদ অ্যাপ। বিভিন্ন '
            'সংবাদমাধ্যমের খবর এক জায়গায় পড়ুন, গুরুত্বপূর্ণ বিষয় অনুসরণ করুন '
            'এবং একই ঘটনা সম্পর্কে একাধিক সূত্রের প্রতিবেদন দেখুন। আপনার পছন্দ, '
            'পাঠাভ্যাস ও ভাষার সঙ্গে মিলিয়ে সংবাদপাঠের অভিজ্ঞতা সাজিয়ে নিন।'
        : 'Amar News is a simple, customizable news reader that brings reports '
            'from multiple publishers into one place. Follow the topics and '
            'publications you care about, compare coverage of the same event, '
            'and shape a reading experience that suits your preferences.';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AuroraBackdrop(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Tokens.gutter,
                  8,
                  Tokens.gutter,
                  10,
                ),
                child: Row(
                  children: <Widget>[
                    GlassIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: context.strings.back,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.strings.aboutTitle,
                        style: context.texts.titleLarge?.copyWith(
                          fontFamily: Tokens.serif,
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      'v${SettingsScreen.appVersion}',
                      style: context.texts.labelSmall?.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    Tokens.gutter,
                    14,
                    Tokens.gutter,
                    48,
                  ),
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const AmarNewsMark(size: 58),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Text(
                            context.strings.appName,
                            style: context.texts.headlineSmall?.copyWith(
                              fontFamily: Tokens.serif,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    GlassPanel(
                      blur: 0,
                      elevation: 0.2,
                      sheen: false,
                      radius: Tokens.radiusMd,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            purpose,
                            style: context.texts.bodyMedium?.copyWith(
                              height: 1.6,
                              fontSize: 13.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    _DeveloperReveal(animation: _reveal),
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

/// One finite signature animation: red light enters, the glass card resolves,
/// then a reflection crosses it. It runs once when About opens and collapses to
/// the final frame for reduced motion.
class _DeveloperReveal extends StatelessWidget {
  const _DeveloperReveal({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        final double value = animation.value;
        final double reveal = Curves.easeOutCubic.transform(
          ((value - 0.12) / 0.58).clamp(0.0, 1.0),
        );
        final double sweep = ((value - 0.48) / 0.52).clamp(0.0, 1.0);
        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned(
              left: -24 + (52 * value),
              right: 80 - (52 * value),
              top: -12,
              child: Opacity(
                opacity: (1 - value).clamp(0.0, 0.45),
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        Colors.transparent,
                        context.colors.primary,
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Opacity(
              opacity: reveal,
              child: Transform.translate(
                offset: Offset(0, 16 * (1 - reveal)),
                child: child,
              ),
            ),
            if (sweep > 0 && sweep < 1)
              Positioned.fill(
                child: IgnorePointer(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(Tokens.radiusLg),
                    child: FractionalTranslation(
                      translation: Offset(-1.15 + (2.3 * sweep), 0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Transform.rotate(
                          angle: -0.16,
                          child: Container(
                            width: 34,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: <Color>[
                                  Colors.transparent,
                                  Colors.white.withValues(alpha: 0.16),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      child: Semantics(
        link: true,
        button: true,
        label: 'Md. Emon — Facebook',
        child: JellySurface(
          scale: 0.985,
          onTap: () async {
            final bool opened =
                await LinkLauncher.open(AboutScreen.developerProfileUrl);
            if (!opened && context.mounted) {
              context.showSnack(
                context.isBengali
                    ? 'ব্রাউজারে প্রোফাইলটি খোলা যায়নি'
                    : 'Could not open the profile in a browser',
              );
            }
          },
          child: GlassPanel(
            radius: Tokens.radiusLg,
            blur: 8,
            elevation: 0.5,
            sheen: false,
            padding: const EdgeInsets.all(16),
            child: Row(
          children: <Widget>[
            Semantics(
              image: true,
              label: 'Md. Emon',
              child: ClipOval(
                child: Image.asset(
                  'assets/developer/md_emon.jpg',
                  width: 88,
                  height: 88,
                  fit: BoxFit.cover,
                  cacheWidth: 264,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
            const SizedBox(width: 17),
            Expanded(
              child: Text(
                'Md. Emon',
                style: context.texts.headlineSmall?.copyWith(
                  fontFamily: Tokens.serif,
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ),
              const SizedBox(width: 8),
              Icon(
                Icons.open_in_new_rounded,
                size: 17,
                color: context.colors.primary,
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}
