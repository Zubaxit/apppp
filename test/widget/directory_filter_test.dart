import 'package:bangladesh_newspaper_hub/data/models/news_source.dart';
import 'package:bangladesh_newspaper_hub/theme/materials.dart';
import 'package:bangladesh_newspaper_hub/ui/screens/newspapers_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/test_app.dart';

void main() {
  SourceRegistry regionalRegistry() {
    return SourceRegistry(
      sources: <NewsSource>[
        sampleSource(id: 'prothomalo', name: 'Prothom Alo', nameBn: 'প্রথম আলো', curated: true),
        sampleSource(
          id: 'azadi',
          name: 'Dainik Azadi',
          nameBn: 'দৈনিক আজাদী',
          website: 'https://www.azadibangla.com/',
          feedUrl: 'https://www.azadibangla.com/feed',
          categories: const <SourceCategory>[SourceCategory.regional],
          division: 'Chattogram',
          district: 'Chattogram',
        ),
        sampleSource(
          id: 'sylhet_mirror',
          name: 'Sylhet Mirror',
          nameBn: 'সিলেট মিরর',
          website: 'https://www.sylhetmirror.com/',
          feedUrl: null,
          categories: const <SourceCategory>[SourceCategory.regional],
          division: 'Sylhet',
          district: 'Sylhet',
        ),
      ],
      epapers: const <EpaperEdition>[],
      updatedAt: DateTime.utc(2026, 10, 24),
      about: 'Regional filter test registry',
    );
  }

  testWidgets('division chips narrow the directory to that division', (WidgetTester tester) async {
    final TestHarness h = TestHarness(registry: regionalRegistry());
    await tester.pumpWidget(h.wrap(const NewspapersScreen()));
    await tester.pumpAndSettle();

    // Division filters are glass chips; the Bengali names come from the label
    // map, not the raw data value.
    expect(find.widgetWithText(GlassChip, 'চট্টগ্রাম'), findsOneWidget);
    expect(find.widgetWithText(GlassChip, 'সিলেট'), findsOneWidget);
    expect(find.text('প্রথম আলো'), findsWidgets);

    await tester.tap(find.widgetWithText(GlassChip, 'চট্টগ্রাম'));
    await tester.pumpAndSettle();

    expect(find.text('দৈনিক আজাদী'), findsOneWidget);
    expect(find.text('সিলেট মিরর'), findsNothing);
    expect(find.text('প্রথম আলো'), findsNothing);

    // The district row only lists the districts inside the chosen division.
    expect(find.widgetWithText(GlassChip, 'Chattogram'), findsOneWidget);
    expect(find.widgetWithText(GlassChip, 'Sylhet'), findsNothing);
  });

  testWidgets('arriving with a division preselects it', (WidgetTester tester) async {
    final TestHarness h = TestHarness(registry: regionalRegistry());
    await tester.pumpWidget(h.wrap(const NewspapersScreen(standalone: true, initialDivision: 'Sylhet')));
    await tester.pumpAndSettle();

    expect(find.text('সিলেট মিরর'), findsOneWidget);
    expect(find.text('দৈনিক আজাদী'), findsNothing);

    // Choosing "all divisions" returns to the curated front of the directory.
    await tester.tap(find.widgetWithText(GlassChip, h.settings.strings.allDivisions));
    await tester.pumpAndSettle();
    expect(find.text('দৈনিক আজাদী'), findsNothing);
    expect(find.text('প্রথম আলো'), findsWidgets);
  });

  testWidgets('a division with no publication says so instead of showing nothing', (WidgetTester tester) async {
    final TestHarness h = TestHarness(registry: regionalRegistry());
    await tester.pumpWidget(h.wrap(const NewspapersScreen(standalone: true, initialDivision: 'Rajshahi')));
    await tester.pumpAndSettle();

    expect(find.text(h.settings.strings.regionalEmpty), findsOneWidget);
  });
}
