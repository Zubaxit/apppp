import 'dart:convert';

import 'package:bangladesh_newspaper_hub/core/utils/reader_extract.dart';
import 'package:bangladesh_newspaper_hub/data/models/article.dart';
import 'package:bangladesh_newspaper_hub/theme/motion.dart';
import 'package:bangladesh_newspaper_hub/ui/screens/browser_screen.dart';
import 'package:bangladesh_newspaper_hub/ui/screens/reader_mode_screen.dart';
import 'package:bangladesh_newspaper_hub/ui/services/browser_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/test_app.dart';

/// Stands in for the platform web view so the reader chrome is testable.
class FakeBrowserEngine extends BrowserEngine {
  FakeBrowserEngine({String url = 'https://www.prothomalo.com/bangladesh/abcdef'})
      : _url = url,
        _domain = Uri.parse(url).host.replaceFirst('www.', '');

  String _url;
  String _domain;
  bool _loading = true;
  bool _canGoBack = false;
  String? _error;
  int reloads = 0;
  int goBacks = 0;

  @override
  String get url => _url;
  @override
  String get domain => _domain;
  @override
  bool get loading => _loading;
  @override
  bool get canGoBack => _canGoBack;
  @override
  String? get error => _error;
  @override
  double get progress => 0.4;

  void finishLoading() {
    _loading = false;
    notifyListeners();
  }

  void setCanGoBack(bool value) {
    _canGoBack = value;
    notifyListeners();
  }

  void fail(String message) {
    _error = message;
    _loading = false;
    notifyListeners();
  }

  /// What the next extraction returns; `null` makes `extractArticle` fail the
  /// way an unreadable page does.
  String? extraction;

  int tryGoBacks = 0;
  int syncs = 0;
  ValueChanged<String>? onSelection;

  @override
  void load(String value) {
    _url = value;
    _domain = Uri.parse(value).host.replaceFirst('www.', '');
    notifyListeners();
  }

  @override
  Future<bool> tryGoBack() async {
    tryGoBacks += 1;
    if (!_canGoBack) return false;
    // A real engine navigates and the history may then end; the default fake
    // keeps history so the "back twice" case can be asserted.
    return true;
  }

  @override
  Future<bool> syncHistory() async {
    syncs += 1;
    return _canGoBack;
  }

  @override
  bool get supportsReaderMode => true;

  @override
  Future<ReaderDocument?> extractArticle() async =>
      extraction == null ? null : ReaderDocument.parse(extraction);

  @override
  void watchSelection(ValueChanged<String> onSelection) {
    this.onSelection = onSelection;
  }

  /// Simulates the page reporting a new text selection.
  void select(String text) => onSelection?.call(text);

  @override
  Future<void> reload() async {
    reloads += 1;
    _loading = true;
    if (reloads > 1) _error = null;
    notifyListeners();
  }

  @override
  Future<void> goBack() async {
    goBacks += 1;
    notifyListeners();
  }

  @override
  Widget buildView(BuildContext context) => const Center(
        child: Text('publisher-page', textDirection: TextDirection.ltr),
      );
}

void main() {
  testWidgets('reader chrome shows the real domain, never a bare title', (WidgetTester tester) async {
    final TestHarness h = TestHarness();
    final FakeBrowserEngine engine = FakeBrowserEngine();
    await tester.pumpWidget(h.wrap(
      BrowserScreen(url: engine.url, title: 'নির্বাচনী প্রস্তুতি', engine: engine),
    ));
    engine.finishLoading();
    await tester.pumpAndSettle();

    expect(find.text('prothomalo.com'), findsOneWidget);
    expect(find.text('নির্বাচনী প্রস্তুতি'), findsOneWidget);
    expect(find.text('publisher-page'), findsOneWidget);
  });

  testWidgets('back is disabled until the page has history', (WidgetTester tester) async {
    final TestHarness h = TestHarness();
    final FakeBrowserEngine engine = FakeBrowserEngine();
    await tester.pumpWidget(h.wrap(
      BrowserScreen(url: engine.url, engine: engine),
    ));
    engine.finishLoading();
    await tester.pumpAndSettle();

    Finder back = find.byKey(const ValueKey<String>('browser-back'));
    expect(tester.widget<JellySurface>(back).enabled, isFalse);

    engine.setCanGoBack(true);
    await tester.pumpAndSettle();
    back = find.byKey(const ValueKey<String>('browser-back'));
    expect(tester.widget<JellySurface>(back).enabled, isTrue);

    await tester.tap(back);
    await tester.pumpAndSettle();
    expect(engine.tryGoBacks, 1,
        reason: 'the toolbar asks the live page history, like system back');
  });

  testWidgets('the controls sit on one row at an ordinary phone width',
      (WidgetTester tester) async {
    final TestHarness h = TestHarness();
    final FakeBrowserEngine engine = FakeBrowserEngine();
    await tester.binding.setSurfaceSize(const Size(412, 892));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(h.wrap(
      BrowserScreen(url: engine.url, title: 'নির্বাচনী প্রস্তুতি', engine: engine),
    ));
    engine.finishLoading();
    await tester.pumpAndSettle();

    // The bar is a single line of chrome, not a panel with a second row.
    expect(tester.getSize(find.byType(BrowserToolbar)).height, lessThan(72));

    final double rowY = tester.getCenter(
      find.byKey(const ValueKey<String>('browser-close')),
    ).dy;
    for (final BrowserTool tool in BrowserTool.values) {
      final Finder disc = find.byKey(ValueKey<String>('browser-${tool.name}'));
      expect(disc, findsOneWidget, reason: '${tool.name} missing');
      expect(
        (tester.getCenter(disc).dy - rowY).abs(),
        lessThan(1.5),
        reason: '${tool.name} is not on the toolbar row',
      );
      // Every control keeps a real touch target and stays inside the screen.
      expect(tester.getSize(disc).width, greaterThanOrEqualTo(32));
      expect(tester.getTopRight(disc).dx, lessThanOrEqualTo(412));
    }

    // The address field keeps the leftover width and is never squeezed out.
    final Rect pill = tester.getRect(find.byType(BrowserToolbar));
    expect(pill.width, greaterThan(300));
    expect(find.text('prothomalo.com'), findsOneWidget);
  });

  testWidgets('a narrow phone keeps every control usable, without overflow',
      (WidgetTester tester) async {
    final TestHarness h = TestHarness();
    final FakeBrowserEngine engine = FakeBrowserEngine();
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(h.wrap(
      BrowserScreen(url: engine.url, title: 'খুব দীর্ঘ একটি শিরোনাম যা কখনই পুরোটা দেখানো উচিত নয়', engine: engine),
    ));
    engine.finishLoading();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    for (final BrowserTool tool in BrowserTool.values) {
      final Finder disc = find.byKey(ValueKey<String>('browser-${tool.name}'));
      expect(disc, findsOneWidget, reason: '${tool.name} missing at 320 dp');
      expect(tester.getTopRight(disc).dx, lessThanOrEqualTo(320));
      expect(tester.getSize(disc).width, greaterThanOrEqualTo(32));
    }
    // The domain survives; the long headline is ellipsised rather than wrapping.
    expect(find.text('prothomalo.com'), findsOneWidget);
    final Text headline = tester.widget<Text>(find.textContaining('খুব দীর্ঘ'));
    expect(headline.maxLines, 1);
    expect(headline.overflow, TextOverflow.ellipsis);
  });

  testWidgets('load failure offers retry instead of a blank page', (WidgetTester tester) async {
    final TestHarness h = TestHarness();
    final FakeBrowserEngine engine = FakeBrowserEngine();
    await tester.pumpWidget(h.wrap(
      BrowserScreen(url: engine.url, engine: engine),
    ));
    engine.fail('net::ERR_NAME_NOT_RESOLVED');
    await tester.pumpAndSettle();

    expect(find.text('publisher-page'), findsNothing);
    expect(find.textContaining('ERR_NAME_NOT_RESOLVED'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, h.settings.strings.retry));
    await tester.pumpAndSettle();
    expect(engine.reloads, 1);
  });

  testWidgets('saving asks first and stores only a headline link', (WidgetTester tester) async {
    final Article article = sampleArticle();
    final TestHarness h = TestHarness();
    final FakeBrowserEngine engine = FakeBrowserEngine(url: article.link);
    await tester.pumpWidget(h.wrap(
      BrowserScreen(url: article.link, title: article.title, engine: engine, article: article),
    ));
    engine.finishLoading();
    await tester.pumpAndSettle();
    expect(h.saved.count, 0);

    await tester.tap(find.byKey(const ValueKey<String>('browser-bookmark')));
    await tester.pumpAndSettle();
    expect(find.text(h.settings.strings.saveLinkOnlyNotice), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, h.settings.strings.savedLabel));
    await tester.pumpAndSettle();

    expect(h.saved.count, 1);
    expect(h.saved.saved.single.article.link, article.link);
    expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
  });
  group('system back follows the page history', () {
    testWidgets('a back press inside the browser walks the page, not the route',
        (WidgetTester tester) async {
      final TestHarness h = TestHarness();
      final FakeBrowserEngine engine = FakeBrowserEngine();
      await tester.pumpWidget(h.wrap(
        BrowserScreen(url: engine.url, engine: engine),
      ));
      engine.finishLoading();
      engine.setCanGoBack(true);
      await tester.pumpAndSettle();

      // The system back gesture reaches the route's PopScope.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(engine.tryGoBacks, 1, reason: 'the page history was asked first');
      expect(find.byType(BrowserScreen), findsOneWidget,
          reason: 'the browser must not close while the page has history');
    });

    testWidgets('with no page history the same press leaves the browser',
        (WidgetTester tester) async {
      final TestHarness h = TestHarness();
      final FakeBrowserEngine engine = FakeBrowserEngine();
      await tester.pumpWidget(h.wrap(
        Builder(
          builder: (BuildContext context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext context) =>
                    BrowserScreen(url: engine.url, engine: engine),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(BrowserScreen), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(engine.tryGoBacks, 1, reason: 'the page history was asked first');
      expect(find.byType(BrowserScreen), findsNothing,
          reason: 'with nothing left in the page the route is the next step');
    });

    testWidgets('a second press while the first is resolving does not navigate twice',
        (WidgetTester tester) async {
      final TestHarness h = TestHarness();
      final FakeBrowserEngine engine = FakeBrowserEngine();
      await tester.pumpWidget(h.wrap(
        BrowserScreen(url: engine.url, engine: engine),
      ));
      engine.finishLoading();
      engine.setCanGoBack(true);
      await tester.pumpAndSettle();

      final Future<void> first = tester.binding.handlePopRoute();
      final Future<void> second = tester.binding.handlePopRoute();
      await Future.wait<void>(<Future<void>>[first, second]);
      await tester.pumpAndSettle();

      expect(engine.tryGoBacks, 1, reason: 'the guard makes back single-shot');
    });
  });

  group('reader mode', () {
    testWidgets('the reader control reads the page and shows English with Bengali',
        (WidgetTester tester) async {
      final TestHarness h = TestHarness();
      final FakeBrowserEngine engine = FakeBrowserEngine()
        ..extraction = jsonEncode(<String, Object?>{
          'ok': true,
          'title': 'Climate talks resume',
          'byline': 'Staff Reporter',
          'site': 'thedailystar.net',
          'blocks': <Map<String, Object>>[
            <String, Object>{
              'text': 'The first paragraph of the article explains the situation. ' * 4,
              'heading': false,
            },
            <String, Object>{
              'text': 'The second paragraph adds the reaction of the officials. ' * 4,
              'heading': false,
            },
          ],
        });
      await tester.pumpWidget(h.wrap(
        BrowserScreen(
          url: engine.url,
          engine: engine,
          translator: FakeTranslator(),
        ),
      ));
      engine.finishLoading();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('browser-reader')));
      await tester.pumpAndSettle();

      expect(find.text('Climate talks resume'), findsOneWidget);
      expect(find.textContaining('The first paragraph'), findsOneWidget,
          reason: 'the English original stays on screen');
      expect(find.textContaining('বাংলা:'), findsNothing,
          reason: 'translation defaults OFF in every reader session');
      await tester.tap(find.byKey(const ValueKey<String>('translation-start')));
      await tester.pumpAndSettle();
      expect(find.textContaining('বাংলা:'), findsWidgets,
          reason: 'the translation sits under it');
    });

    testWidgets('a page that cannot be read says so and offers the site',
        (WidgetTester tester) async {
      final TestHarness h = TestHarness();
      final FakeBrowserEngine engine = FakeBrowserEngine()..extraction = null;
      await tester.pumpWidget(h.wrap(
        BrowserScreen(url: engine.url, engine: engine, translator: FakeTranslator()),
      ));
      engine.finishLoading();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('browser-reader')));
      await tester.pumpAndSettle();

      expect(find.text(h.settings.strings.readerExtractionFailed), findsOneWidget);
      expect(find.text(h.settings.strings.readerExtractionFailedBody), findsOneWidget);
      expect(find.byType(ReaderModeScreen), findsNothing);
    });
  });

  group('word and sentence translation', () {
    testWidgets('a selection offers বাংলা অর্থ and the sheet keeps the original',
        (WidgetTester tester) async {
      final TestHarness h = TestHarness();
      final FakeBrowserEngine engine = FakeBrowserEngine();
      await tester.pumpWidget(h.wrap(
        BrowserScreen(url: engine.url, engine: engine, translator: FakeTranslator()),
      ));
      engine.finishLoading();
      await tester.pumpAndSettle();

      expect(find.text(h.settings.strings.bengaliMeaning), findsNothing);
      engine.select('sustainable development');
      await tester.pumpAndSettle();

      expect(find.text(h.settings.strings.bengaliMeaning), findsOneWidget);
      await tester.tap(find.text(h.settings.strings.bengaliMeaning));
      await tester.pumpAndSettle();

      // The selected English is preserved verbatim, and the machine answer is
      // labelled as machine output.
      expect(find.text('sustainable development'), findsWidgets);
      expect(find.textContaining('বাংলা:'), findsWidgets);
      expect(find.textContaining('MyMemory'), findsNothing,
          reason: 'the fake translator is attributed as "Fake"');
      expect(find.textContaining('Fake'), findsWidgets);
    });

    testWidgets('clearing the selection puts the action away', (WidgetTester tester) async {
      final TestHarness h = TestHarness();
      final FakeBrowserEngine engine = FakeBrowserEngine();
      await tester.pumpWidget(h.wrap(
        BrowserScreen(url: engine.url, engine: engine, translator: FakeTranslator()),
      ));
      engine.finishLoading();
      await tester.pumpAndSettle();

      engine.select('a word');
      await tester.pumpAndSettle();
      expect(find.text(h.settings.strings.bengaliMeaning), findsOneWidget);

      engine.select('');
      await tester.pumpAndSettle();
      expect(find.text(h.settings.strings.bengaliMeaning), findsNothing);
    });
  });

}
