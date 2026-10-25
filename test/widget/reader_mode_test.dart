import 'package:bangladesh_newspaper_hub/core/utils/reader_extract.dart';
import 'package:bangladesh_newspaper_hub/theme/motion.dart';
import 'package:bangladesh_newspaper_hub/ui/screens/reader_mode_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/test_app.dart';

ReaderDocument document({int paragraphs = 2, bool bengali = false}) {
  final String paragraph = bengali
      ? 'বাংলাদেশের অর্থনীতি ও মানুষের জীবন নিয়ে এই প্রতিবেদনে বিস্তারিত তথ্য তুলে ধরা হয়েছে। '
      : 'English paragraph about the economy, public policy and daily life. ';
  return ReaderDocument(
    title: bengali ? 'বাংলা সংবাদ শিরোনাম' : 'An English headline',
    site: 'thedailystar.net',
    byline: 'Staff Reporter',
    published: '2026-10-25',
    blocks: <ReaderBlock>[
      for (int i = 0; i < paragraphs; i++) ReaderBlock(text: paragraph * 4),
    ],
  );
}

void main() {
  testWidgets('translation is OFF by default and starts only after a tap',
      (WidgetTester tester) async {
    final TestHarness h = TestHarness();
    final FakeTranslator translator = FakeTranslator();
    await tester.pumpWidget(h.wrap(
      ReaderModeScreen(document: document(), translator: translator),
    ));
    await tester.pumpAndSettle();

    expect(translator.requests, isEmpty);
    expect(find.textContaining('বাংলা:'), findsNothing);
    expect(find.text(h.settings.strings.translating), findsNothing);
    expect(find.text(h.settings.strings.showTranslation), findsWidgets);

    await tester.tap(find.byKey(const ValueKey<String>('translation-start')));
    await tester.pumpAndSettle();
    expect(translator.requests, hasLength(1),
        reason: 'identical paragraphs share one request');
    expect(find.textContaining('বাংলা:'), findsNWidgets(2));
    expect(find.textContaining('Fake'), findsOneWidget,
        reason: 'machine output names the actual provider');
  });

  testWidgets('repeated toggles have one authoritative state',
      (WidgetTester tester) async {
    final TestHarness h = TestHarness();
    await tester.pumpWidget(h.wrap(
      ReaderModeScreen(document: document(), translator: FakeTranslator()),
    ));
    await tester.tap(find.byKey(const ValueKey<String>('translation-start')));
    await tester.pumpAndSettle();
    expect(find.textContaining('বাংলা:'), findsNWidgets(2));

    await tester.tap(find.byKey(const ValueKey<String>('translation-switch')));
    await tester.pumpAndSettle();
    expect(find.textContaining('বাংলা:'), findsNothing);
    expect(find.byType(JellySwitch), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('translation-switch')));
    await tester.pumpAndSettle();
    expect(find.textContaining('বাংলা:'), findsNWidgets(2));
  });

  testWidgets('turning OFF during loading ignores stale responses',
      (WidgetTester tester) async {
    final TestHarness h = TestHarness();
    final FakeTranslator slow =
        FakeTranslator(delay: const Duration(milliseconds: 300));
    await tester.pumpWidget(h.wrap(
      ReaderModeScreen(document: document(), translator: slow),
    ));
    await tester.tap(find.byKey(const ValueKey<String>('translation-start')));
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.text(h.settings.strings.translating), findsWidgets);

    await tester.tap(find.byKey(const ValueKey<String>('translation-switch')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('বাংলা:'), findsNothing);
    expect(find.text(h.settings.strings.translating), findsNothing);
    expect(find.byType(JellySwitch), findsOneWidget);
  });

  testWidgets('a Bengali article has no translation controls',
      (WidgetTester tester) async {
    final TestHarness h = TestHarness();
    final FakeTranslator translator = FakeTranslator();
    await tester.pumpWidget(h.wrap(
      ReaderModeScreen(document: document(bengali: true), translator: translator),
    ));
    await tester.pumpAndSettle();

    expect(translator.requests, isEmpty);
    expect(find.byType(JellySwitch), findsNothing);
    expect(find.text(h.settings.strings.showTranslation), findsNothing);
    expect(find.byIcon(Icons.translate_rounded), findsNothing);
  });

  testWidgets('reopening Reader Mode starts OFF again',
      (WidgetTester tester) async {
    final TestHarness h = TestHarness();
    final FakeTranslator first = FakeTranslator();
    await tester.pumpWidget(h.wrap(
      ReaderModeScreen(document: document(), translator: first),
    ));
    await tester.tap(find.byKey(const ValueKey<String>('translation-start')));
    await tester.pumpAndSettle();
    expect(first.requests, isNotEmpty);

    final FakeTranslator reopened = FakeTranslator();
    await tester.pumpWidget(h.wrap(
      ReaderModeScreen(document: document(), translator: reopened),
    ));
    await tester.pumpAndSettle();
    expect(reopened.requests, isEmpty);
    expect(find.textContaining('বাংলা:'), findsNothing);
  });

  testWidgets('one failed paragraph is honest and does not hide the other',
      (WidgetTester tester) async {
    final TestHarness h = TestHarness();
    final ReaderDocument different = ReaderDocument(
      title: 'An English headline',
      blocks: <ReaderBlock>[
        ReaderBlock(text: 'A healthy English paragraph about public policy. ' * 5),
        ReaderBlock(text: 'A poison English paragraph about the economy. ' * 5),
      ],
    );
    await tester.pumpWidget(h.wrap(
      ReaderModeScreen(
        document: different,
        translator: FakeTranslator(failOn: <String>['poison']),
      ),
    ));
    await tester.tap(find.byKey(const ValueKey<String>('translation-start')));
    await tester.pumpAndSettle();

    expect(find.text('quota reached'), findsOneWidget);
    expect(find.text(h.settings.strings.retry), findsWidgets);
    expect(find.textContaining('বাংলা:'), findsOneWidget);
  });
}
