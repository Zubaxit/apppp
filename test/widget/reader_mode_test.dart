import 'package:bangladesh_newspaper_hub/core/utils/reader_extract.dart';
import 'package:bangladesh_newspaper_hub/theme/motion.dart';
import 'package:bangladesh_newspaper_hub/ui/screens/reader_mode_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/test_app.dart';

ReaderDocument document({int paragraphs = 2}) {
  return ReaderDocument(
    title: 'শিরোনাম / An English headline',
    site: 'thedailystar.net',
    byline: 'Staff Reporter',
    published: '2026-10-25',
    blocks: <ReaderBlock>[
      for (int i = 0; i < paragraphs; i++)
        ReaderBlock(text: 'English paragraph $i about the economy. ' * 6),
    ],
  );
}

void main() {
  testWidgets('each English paragraph keeps its original and gains the Bengali below',
      (WidgetTester tester) async {
    final TestHarness h = TestHarness();
    await tester.pumpWidget(h.wrap(
      ReaderModeScreen(document: document(), translator: FakeTranslator()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('English paragraph 0 about the economy. ' * 6), findsOneWidget);
    expect(find.text('English paragraph 1 about the economy. ' * 6), findsOneWidget);
    expect(find.textContaining('বাংলা:'), findsNWidgets(2));
    expect(find.textContaining('MyMemory'), findsNothing,
        reason: 'the provider named is the one actually used');
    expect(find.textContaining('Fake'), findsWidgets);
  });

  testWidgets('translations can be hidden, and the English is untouched',
      (WidgetTester tester) async {
    final TestHarness h = TestHarness();
    await tester.pumpWidget(h.wrap(
      ReaderModeScreen(document: document(), translator: FakeTranslator()),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('বাংলা:'), findsNWidgets(2));

    // The switch in the bottom bar.
    await tester.tap(find.byType(JellySwitch));
    await tester.pumpAndSettle();

    expect(find.textContaining('বাংলা:'), findsNothing);
    expect(find.text('English paragraph 0 about the economy. ' * 6), findsOneWidget);
  });

  testWidgets('one failed paragraph shows its own error and a retry',
      (WidgetTester tester) async {
    final TestHarness h = TestHarness();
    await tester.pumpWidget(h.wrap(
      ReaderModeScreen(
        document: document(paragraphs: 2),
        translator: FakeTranslator(failOn: <String>['paragraph 1']),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('quota reached'), findsOneWidget);
    expect(find.text(h.settings.strings.retry), findsWidgets);
    // The healthy paragraph is still translated.
    expect(find.textContaining('বাংলা:'), findsOneWidget);
  });

  testWidgets('the reading surface starts untranslated when asked to',
      (WidgetTester tester) async {
    final TestHarness h = TestHarness();
    final FakeTranslator translator = FakeTranslator();
    await tester.pumpWidget(h.wrap(
      ReaderModeScreen(
        document: document(),
        translator: translator,
        startTranslated: false,
      ),
    ));
    await tester.pumpAndSettle();

    expect(translator.requests, isEmpty, reason: 'no request until the reader asks');
    expect(find.textContaining('বাংলা:'), findsNothing);
    expect(find.text('English paragraph 0 about the economy. ' * 6), findsOneWidget);
  });

  testWidgets('a machine result is always labelled as machine output',
      (WidgetTester tester) async {
    final TestHarness h = TestHarness();
    await tester.pumpWidget(h.wrap(
      ReaderModeScreen(document: document(), translator: FakeTranslator()),
    ));
    await tester.pumpAndSettle();
    expect(find.text(h.settings.strings.translationNotice), findsOneWidget);
  });
}
