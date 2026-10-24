import 'package:bangladesh_newspaper_hub/data/models/article.dart';
import 'package:bangladesh_newspaper_hub/ui/screens/browser_screen.dart';
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

  @override
  void load(String value) {
    _url = value;
    _domain = Uri.parse(value).host.replaceFirst('www.', '');
    notifyListeners();
  }

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

  testWidgets('back arrow is disabled until the page has history', (WidgetTester tester) async {
    final TestHarness h = TestHarness();
    final FakeBrowserEngine engine = FakeBrowserEngine();
    await tester.pumpWidget(h.wrap(
      BrowserScreen(url: engine.url, engine: engine),
    ));
    engine.finishLoading();
    await tester.pumpAndSettle();

    IconButton back = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.arrow_back_rounded),
        matching: find.byType(IconButton),
      ),
    );
    expect(back.onPressed, isNull);

    engine.setCanGoBack(true);
    await tester.pumpAndSettle();
    back = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.arrow_back_rounded),
        matching: find.byType(IconButton),
      ),
    );
    expect(back.onPressed, isNotNull);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(engine.goBacks, 1);
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

    await tester.tap(find.byIcon(Icons.bookmark_border_rounded));
    await tester.pumpAndSettle();
    expect(find.text(h.settings.strings.saveLinkOnlyNotice), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, h.settings.strings.savedLabel));
    await tester.pumpAndSettle();

    expect(h.saved.count, 1);
    expect(h.saved.saved.single.article.link, article.link);
    expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
  });
}
