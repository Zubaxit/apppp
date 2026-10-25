import 'package:bangladesh_newspaper_hub/core/l10n/app_strings.dart';
import 'package:bangladesh_newspaper_hub/data/models/article.dart';
import 'package:bangladesh_newspaper_hub/theme/app_theme.dart';
import 'package:bangladesh_newspaper_hub/theme/motion.dart';
import 'package:bangladesh_newspaper_hub/ui/widgets/editorial_story.dart';
import 'package:bangladesh_newspaper_hub/ui/widgets/feed_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../support/fakes.dart';
import '../support/test_app.dart';

/// The interaction layer is the part of the redesign a test can actually hold on
/// to: does touch-down compress the surface, does the spring settle back, does
/// reduced motion keep the feedback without the bounce, and do the new feed
/// controls report what the reader chose.
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

  double scaleOf(WidgetTester tester) {
    final Iterable<Transform> transforms = tester
        .widgetList<Transform>(find.descendant(
          of: find.byType(JellySurface),
          matching: find.byType(Transform),
        ))
        .toList();
    expect(transforms, isNotEmpty, reason: 'jelly surface must build a transform');
    return transforms.last.transform.getMaxScaleOnAxis();
  }

  group('JellySurface', () {
    testWidgets('compresses on touch-down and settles back on release',
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

      expect(scaleOf(tester), moreOrLessEquals(1, epsilon: 0.001));

      final TestGesture gesture =
          await tester.startGesture(tester.getCenter(find.byType(JellySurface)));
      await tester.pump(const Duration(milliseconds: 40));
      // Touch-down already registers; the reader never waits for the release.
      expect(scaleOf(tester), lessThan(0.99));

      await gesture.up();
      await tester.pumpAndSettle();
      expect(scaleOf(tester), moreOrLessEquals(1, epsilon: 0.01));
      expect(taps, 1);
    });

    testWidgets('reduced motion keeps the tap but drops the bounce',
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
          reduceMotion: true,
        ),
      );

      final TestGesture gesture =
          await tester.startGesture(tester.getCenter(find.byType(JellySurface)));
      await tester.pump(const Duration(milliseconds: 40));
      // Reduced motion is a static state change, not a spring animation.
      expect(scaleOf(tester), moreOrLessEquals(0.9, epsilon: 0.001));

      await gesture.up();
      await tester.pumpAndSettle();
      expect(scaleOf(tester), moreOrLessEquals(1, epsilon: 0.001));
      expect(taps, 1);
    });

    testWidgets('a disabled surface is not tappable', (WidgetTester tester) async {
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
