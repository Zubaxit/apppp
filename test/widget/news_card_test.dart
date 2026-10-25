import 'package:bangladesh_newspaper_hub/data/models/article.dart';
import 'package:bangladesh_newspaper_hub/data/models/news_source.dart';
import 'package:bangladesh_newspaper_hub/ui/widgets/common.dart';
import 'package:bangladesh_newspaper_hub/ui/widgets/editorial_story.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/test_app.dart';

void main() {
  testWidgets('every card reserves art space and missing art uses one local fallback',
      (WidgetTester tester) async {
    final TestHarness h = TestHarness();
    await tester.pumpWidget(h.wrap(
      NewsCard(
        article: sampleArticle(imageUrl: null),
        source: h.registry.byId('prothomalo'),
        related: const <Article>[],
        onTap: () {},
      ),
    ));
    await tester.pump();

    expect(find.byType(AspectRatio), findsOneWidget);
    expect(find.byType(NewsImageFallback), findsOneWidget);
    expect(find.byIcon(Icons.image_not_supported_outlined), findsNothing);
  });

  testWidgets('Same Story expands distinct real reports inside the same card',
      (WidgetTester tester) async {
    final TestHarness h = TestHarness();
    final Article primary = sampleArticle(title: 'Primary report');
    final Article other = sampleArticle(
      sourceId: 'daily_star',
      title: 'The other publisher headline',
      language: SourceLanguage.en,
      link: 'https://www.thedailystar.net/original-report',
    );
    await tester.pumpWidget(h.wrap(
      NewsCard(
        article: primary,
        source: h.registry.byId(primary.sourceId),
        related: <Article>[other],
        onTap: () {},
      ),
    ));
    await tester.pump();

    expect(find.textContaining('আরও 1টি'), findsOneWidget);
    expect(find.text(other.title), findsNothing);
    final Finder row = find.byKey(ValueKey<String>('same-story-${primary.id}'));
    await tester.ensureVisible(row);
    await tester.pump();
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.text(other.title), findsOneWidget);
    expect(find.text(primary.title), findsOneWidget,
        reason: 'the primary is not repeated in the expanded list');
  });
}
