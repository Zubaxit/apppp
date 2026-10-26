import 'dart:convert';

import 'package:bangladesh_newspaper_hub/services/translation_service.dart';
import 'package:bangladesh_newspaper_hub/ui/widgets/translation_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

class _PayloadBundle extends CachingAssetBundle {
  _PayloadBundle(this.payload);

  final String payload;

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(utf8.encoder.convert(payload));
}

class _MissingBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      throw FlutterError('missing asset');
}

const String _payload =
    '{"words":{"news":"সংবাদ","poem":"কবিতা","report":"প্রতিবেদন"}}';

void main() {
  testWidgets('a known word shows its glossary meaning',
      (WidgetTester tester) async {
    final TestHarness h = TestHarness();
    final TranslationService service =
        TranslationService(bundle: _PayloadBundle(_payload));
    await tester.pumpWidget(
      h.wrap(TranslationSheet(text: 'A poem about the news', service: service)),
    );
    await tester.pumpAndSettle();

    // The notice is explicit that this is a glossary, not a translation.
    expect(find.textContaining('অফলাইন অভিধান থেকে'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'poem');
    await tester.pumpAndSettle();
    expect(find.text('কবিতা'), findsWidgets);
  });

  testWidgets('an unknown word says so instead of inventing a meaning',
      (WidgetTester tester) async {
    final TestHarness h = TestHarness();
    final TranslationService service =
        TranslationService(bundle: _PayloadBundle(_payload));
    await tester.pumpWidget(
      h.wrap(TranslationSheet(text: 'news', service: service)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'quixotic');
    await tester.pumpAndSettle();
    expect(find.text('এই শব্দটি অভিধানে পাওয়া যায়নি'), findsOneWidget);
  });

  testWidgets('a missing glossary asset shows an unavailable state',
      (WidgetTester tester) async {
    final TestHarness h = TestHarness();
    final TranslationService service =
        TranslationService(bundle: _MissingBundle());
    await tester.pumpWidget(
      h.wrap(TranslationSheet(text: 'news report', service: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('অভিধানে এই অংশটি নেই'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('word chips look up the tapped word',
      (WidgetTester tester) async {
    final TestHarness h = TestHarness();
    final TranslationService service =
        TranslationService(bundle: _PayloadBundle(_payload));
    await tester.pumpWidget(
      h.wrap(TranslationSheet(text: 'report and poem', service: service)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('report · প্রতিবেদন'));
    await tester.pumpAndSettle();
    expect(find.text('প্রতিবেদন'), findsWidgets);
  });
}
