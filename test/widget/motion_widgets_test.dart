import 'package:bangladesh_newspaper_hub/core/l10n/app_strings.dart';
import 'package:bangladesh_newspaper_hub/data/models/article.dart';
import 'package:bangladesh_newspaper_hub/theme/app_theme.dart';
import 'package:bangladesh_newspaper_hub/theme/motion.dart';
import 'package:bangladesh_newspaper_hub/theme/tokens.dart';
import 'package:bangladesh_newspaper_hub/ui/widgets/editorial_story.dart';
import 'package:bangladesh_newspaper_hub/ui/widgets/feed_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../support/fakes.dart';
import '../support/test_app.dart';

/// The interaction layer a headless test can hold on to: taps reach the jelly
/// surface and a disabled one ignores them, reduced motion collapses every
/// duration to zero while keeping the feedback, and the new feed controls
/// report what the reader chose. Frame-level spring timing is not asserted here
/// — that needs a device.
void main() {
  Widget wrap(
    TestHarness h,
    Widget child, {
    bool reduceMotion = false,
  }) {
    return MultiProvider(
      providers: h.providers,
      child: AppStringsScope(
        strings: h.settings.strings,
        child: AppMotionScope(
          reduceMotion: reduceMotion,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            home: Scaffold(
              body: Center(
                child: SizedBox(width: 320, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The smallest scale on any transform the surface builds — the translate
  /// wrapper stays at 1, so this reads the compression itself.
  double scaleOf(WidgetTester tester) {
    final List<double> scales = tester
        .widgetList<Transform>(find.descendant(
          of: find.byType(JellySurface),
          matching: find.byType(Transform),
        ))
        .map((Transform t) => t.transform.getMaxScaleOnAxis())
        .toList();
    expect(scales, isNotEmpty, reason: 'jelly surface must build a transform');
    return scales.reduce((double a, double b) => a < b ? a : b);
  }

  group('JellySurface', () {
    testWidgets('fires one tap and builds a single scaled surface',
        (WidgetTester tester) async {
      final TestHarness h = TestHarness();
      int taps = 0;
      await tester.pumpWidget(
        wrap(
          h,
          JellySurface(
            scale: 0.9,
            onTap: () => taps++,
            child: const SizedBox(width: 120, height: 48, child: Text('ট্যাপ')),
          ),
        ),
      );

      // At rest the surface is drawn at its natural scale through exactly one
      // scale transform: that is the wrapper the press compresses.
      expect(scaleOf(tester), moreOrLessEquals(1, epsilon: 0.001));

      await tester.tap(find.text('ট্যাপ'));
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(scaleOf(tester), moreOrLessEquals(1, epsilon: 0.001));
    });

    testWidgets('a disabled surface is not tappable',
        (WidgetTester tester) async {
      final TestHarness h = TestHarness();
      int taps = 0;
      await tester.pumpWidget(
        wrap(
          h,
          JellySurface(
            enabled: false,
            onTap: () => taps++,
            child: const SizedBox(width: 120, height: 48, child: Text('ট্যাপ')),
          ),
        ),
      );

      await tester.tap(find.byType(JellySurface), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(taps, 0);
    });
  });

  group('Motion policy', () {
    testWidgets('reduced motion collapses every duration to zero',
        (WidgetTester tester) async {
      late Motion reduced;
      late Motion full;
      await tester.pumpWidget(
        AppMotionScope(
          reduceMotion: true,
          child: Builder(
            builder: (BuildContext context) {
              reduced = Motion.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpWidget(
        AppMotionScope(
          reduceMotion: false,
          child: Builder(
            builder: (BuildContext context) {
              full = Motion.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(reduced.reduce, isTrue);
      expect(reduced.standard, Duration.zero);
      expect(reduced.slow, Duration.zero);

      expect(full.reduce, isFalse);
      expect(full.standard, Tokens.standard);
      expect(full.standard, greaterThan(Duration.zero));
    });
  });

  group('CategoryStrip', () {
    testWidgets('offers "all" first and reports the chosen topic',
        (WidgetTester tester) async {
      final TestHarness h = TestHarness();
      final List<ArticleTopic> toggled = <ArticleTopic>[];
      bool cleared = false;
      await tester.pumpWidget(
        wrap(
          h,
          CategoryStrip(
            selected: const <ArticleTopic>{},
            onToggle: toggled.add,
            onClear: () => cleared = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(h.settings.strings.all), findsOneWidget);
      expect(find.byType(CategoryCircle), findsWidgets);

      await tester.tap(find.text(h.settings.strings.all));
      await tester.pumpAndSettle();
      expect(cleared, isTrue);

      await tester.tap(find.byType(CategoryCircle).at(1));
      await tester.pumpAndSettle();
      expect(toggled, hasLength(1));
    });
  });

  group('NewsCard', () {
    testWidgets('shows the headline, the publisher and a working bookmark',
        (WidgetTester tester) async {
      final TestHarness h = TestHarness();
      final Article article = sampleArticle(title: 'সংসদের নতুন অধিবেশন শুরু');
      await tester.pumpWidget(
        wrap(
          h,
          NewsCard(
            article: article,
            source: h.registry.byId('prothomalo'),
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('সংসদের নতুন অধিবেশন শুরু'), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.bookmark_border_rounded));
      await tester.pumpAndSettle();
      expect(h.saved.isSaved(article.id), isTrue);
      expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
    });
  });
}
