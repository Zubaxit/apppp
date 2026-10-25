import 'dart:math' as math;

import 'package:bangladesh_newspaper_hub/theme/motion.dart';
import 'package:bangladesh_newspaper_hub/theme/tokens.dart';
import 'package:bangladesh_newspaper_hub/ui/widgets/actions.dart';
import 'package:bangladesh_newspaper_hub/ui/widgets/common.dart';
import 'package:bangladesh_newspaper_hub/ui/widgets/editorial_story.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/test_app.dart';

/// Guards on the render-pipeline costs that were actually fixed in this pass.
///
/// These do not measure frame time — a headless test cannot. They pin the
/// structural properties that caused the cost: how many backdrop filters a
/// screen instantiates, how many tickers a skeleton opens, how many transforms
/// a press animates, and whether scrolling state rebuilds content.
void main() {
  group('skeletons', () {
    testWidgets('one pulse for the whole skeleton, not one per block',
        (WidgetTester tester) async {
      final TestHarness h = TestHarness();
      await tester.pumpWidget(h.wrap(const ArticleSkeleton(count: 4)));
      await tester.pump();

      expect(find.byType(ShimmerBox), findsWidgets);
      expect(find.byType(ShimmerScope), findsOneWidget);

      // Every block is stateless: it listens to the scope's single controller
      // instead of owning a repeating one.
      for (final Element element in tester.elementList(find.byType(ShimmerBox))) {
        expect(element, isA<StatelessElement>());
      }
    });

    testWidgets('without a scope the blocks are inert rather than animating alone',
        (WidgetTester tester) async {
      final TestHarness h = TestHarness();
      await tester.pumpWidget(h.wrap(
        const Center(child: ShimmerBox(height: 20, width: 40)),
      ));
      await tester.pump(const Duration(milliseconds: 400));
      // No controller anywhere: nothing schedules frames while the page idles.
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('glass budget', () {
    testWidgets('a river row costs no backdrop filter', (WidgetTester tester) async {
      final TestHarness h = TestHarness();
      await tester.pumpWidget(h.wrap(
        NewsCard(
          article: sampleArticle(imageUrl: 'https://media.example.org/a.jpg'),
          source: sampleSource(),
          onTap: () {},
        ),
      ));
      await tester.pump();
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('the lead card pays for zero blurs over its scrim',
        (WidgetTester tester) async {
      final TestHarness h = TestHarness();
      await tester.pumpWidget(h.wrap(
        LeadStory(
          article: sampleArticle(imageUrl: 'https://media.example.org/a.jpg'),
          source: sampleSource(),
          onTap: () {},
        ),
      ));
      await tester.pump();
      expect(find.byType(BackdropFilter), findsNothing);
    });
  });

  group('jelly press', () {
    testWidgets('a press animates one transform over a cached raster',
        (WidgetTester tester) async {
      final TestHarness h = TestHarness();
      int taps = 0;
      await tester.pumpWidget(h.wrap(
        Center(
          child: JellySurface(
            onTap: () => taps++,
            child: const SizedBox(width: 120, height: 48, child: Text('ট্যাপ')),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final Finder surface = find.byType(JellySurface);
      // One transform, and the content behind it is a repaint boundary: the
      // press moves a layer instead of relaying out or repainting the card.
      expect(
        find.descendant(of: surface, matching: find.byType(Transform)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: surface, matching: find.byType(RepaintBoundary)),
        findsWidgets,
      );

      await tester.tap(find.text('ট্যাপ'));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });
  });

  group('reading progress', () {
    testWidgets('the rule follows a notifier without rebuilding the page',
        (WidgetTester tester) async {
      final TestHarness h = TestHarness();
      final ValueNotifier<double> progress = ValueNotifier<double>(0.25);
      addTearDown(progress.dispose);

      await tester.pumpWidget(h.wrap(
        SizedBox(
          width: 200,
          child: ReadingProgressBar(progress: progress),
        ),
      ));
      await tester.pump();
      expect(tester.getSize(find.byType(ReadingProgressBar)).width, 200);
      expect(
        tester.getSize(find.byType(FractionallySizedBox)).width,
        closeTo(50, 1),
      );

      progress.value = 0.75;
      await tester.pump();
      expect(
        tester.getSize(find.byType(FractionallySizedBox)).width,
        closeTo(150, 1),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('motion tokens', () {
    testWidgets('central haptic surface invokes its action exactly once',
        (WidgetTester tester) async {
      HapticFeedbackProxy.enabled = false;
      addTearDown(() => HapticFeedbackProxy.enabled = true);
      int calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: JellySurface(
            onTap: () => calls += 1,
            child: const SizedBox(width: 80, height: 48),
          ),
        ),
      );

      await tester.tap(find.byType(JellySurface));
      await tester.pump();
      expect(calls, 1);
    });

    test('the press and release springs still overshoot on purpose', () {
      // Expressive springs are part of the design; this pins them so a later
      // "performance" pass cannot quietly replace them with a fade.
      expect(Springs.press.stiffness, greaterThan(Springs.release.stiffness));
      expect(Springs.release.damping, lessThan(Springs.settle.damping));
      final double dampingRatio = Springs.release.damping /
          (2 * math.sqrt(Springs.release.stiffness * Springs.release.mass));
      expect(dampingRatio, lessThan(1.0),
          reason: 'damping ratio < 1 is what makes the release elastic');
      expect(Tokens.slow.inMilliseconds, greaterThan(0));
    });
  });
}
