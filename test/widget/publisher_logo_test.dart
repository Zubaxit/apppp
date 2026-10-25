import 'package:bangladesh_newspaper_hub/data/models/news_source.dart';
import 'package:bangladesh_newspaper_hub/services/publisher_logos.dart';
import 'package:bangladesh_newspaper_hub/theme/tokens.dart';
import 'package:bangladesh_newspaper_hub/ui/widgets/publisher_logo.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/test_app.dart';

void main() {
  group('publisher icon resolution', () {
    NewsSource source({String? logoUrl}) => sampleSource(
          website: 'https://www.prothomalo.com/',
          logoUrl: logoUrl,
        );

    test('a verified asset wins, then the touch icon, then the favicon', () {
      expect(
        source(logoUrl: 'https://cdn.example.org/prothomalo-touch.png').logoUrls,
        <String>[
          'https://cdn.example.org/prothomalo-touch.png',
          'https://www.prothomalo.com/apple-touch-icon.png',
          'https://www.prothomalo.com/favicon.ico',
        ],
      );
      expect(source().logoUrls, <String>[
        'https://www.prothomalo.com/apple-touch-icon.png',
        'https://www.prothomalo.com/favicon.ico',
      ]);
    });

    test('the candidates always stay on the publisher\'s own origin', () {
      for (final String url in source().logoUrls) {
        expect(Uri.parse(url).host, 'www.prothomalo.com');
        expect(Uri.parse(url).scheme, 'https');
      }
    });

    test('a registry entry keeps its identity when it carries no asset', () {
      final NewsSource plain = source();
      expect(plain.hasLogo, isTrue, reason: 'the derived candidates exist');
      expect(plain.logoUrl, isNull, reason: 'no asset is invented');
      expect(plain.name, 'Prothom Alo');
      expect(plain.feedClaim, sampleSource().feedClaim,
          reason: 'a missing icon must never change feed status');
      expect(plain.feedUrl, sampleSource().feedUrl,
          reason: 'a missing icon must never change the feed URL');
    });

    test('an entry with no usable website has no candidates and still loads', () {
      final NewsSource broken = sampleSource(website: '');
      expect(broken.logoUrls, isEmpty);
      expect(broken.hasLogo, isFalse);
    });

    test('the asset survives a registry round-trip', () {
      final NewsSource original = source(logoUrl: 'https://cdn.example.org/a.png');
      final NewsSource copy = NewsSource.fromMap(original.toMap());
      expect(copy.logoUrl, 'https://cdn.example.org/a.png');
      expect(copy.logoUrls, original.logoUrls);
    });
  });

  group('publisher mark rendering', () {
    testWidgets('without an image the tile shows the monogram, never a broken glyph',
        (WidgetTester tester) async {
      final TestHarness h = TestHarness();
      await tester.pumpWidget(h.wrap(
        const Center(child: PublisherLogo(source: _ProthomAlo(), size: 44)),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(CachedNetworkImage), findsNothing);
      expect(find.text(_monogram), findsOneWidget);
      expect(find.byIcon(Icons.broken_image), findsNothing);
      expect(find.byIcon(Icons.image_not_supported_outlined), findsNothing);
      expect(tester.getSize(find.byType(PublisherLogo)), const Size(44, 44));
    });

    testWidgets('the mark keeps its box whatever arrives, so rows never jump',
        (WidgetTester tester) async {
      final TestHarness h = TestHarness();
      await tester.pumpWidget(h.wrap(
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            PublisherLogo(source: _ProthomAlo(), size: 40),
            SizedBox(width: 8),
            PublisherLogo(source: _DailyStar(), size: 40),
          ],
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(PublisherLogo).first), const Size(40, 40));
      expect(tester.getSize(find.byType(PublisherLogo).last), const Size(40, 40));
    });

    testWidgets('the accent-filled variant inverts its monogram', (WidgetTester tester) async {
      final TestHarness h = TestHarness();
      await tester.pumpWidget(h.wrap(
        const Center(
          child: PublisherLogo(source: _ProthomAlo(), size: 34, solid: Tokens.accent),
        ),
      ));
      await tester.pumpAndSettle();

      final Text monogram = tester.widget<Text>(find.text(_monogram));
      expect(monogram.style?.color, isNot(Tokens.accent));
      expect(monogram.style?.fontFamily, Tokens.serif);
    });
  });

  group('bundled marks', () {
    testWidgets('a bundled asset is painted instead of a monogram or a request',
        (WidgetTester tester) async {
      final TestHarness h = TestHarness();
      PublisherLogos.debugSet(const <String, String>{
        'prothomalo': 'assets/publishers/prothomalo.png',
      });
      addTearDown(() => PublisherLogos.debugSet(const <String, String>{}));

      await tester.pumpWidget(h.wrap(
        const Center(child: PublisherLogo(source: _ProthomAlo(), size: 44)),
      ));
      await tester.pump();

      final Finder image = find.descendant(
        of: find.byType(PublisherLogo),
        matching: find.byType(Image),
      );
      expect(image, findsOneWidget, reason: 'the bundled file is used');
      // A cacheWidth wraps the provider in ResizeImage; the bundled file is
      // still the source, decoded once at the size the avatar needs.
      final Image widget = tester.widget<Image>(image);
      expect(widget.image, isA<ResizeImage>());
      final ResizeImage resized = widget.image as ResizeImage;
      expect(resized.imageProvider, isA<AssetImage>());
      expect((resized.imageProvider as AssetImage).assetName,
          'assets/publishers/prothomalo.png');
      expect(find.byType(CachedNetworkImage), findsNothing,
          reason: 'no network request for a mark that ships with the app');
    });

    testWidgets('a publisher with no bundled mark still falls back cleanly',
        (WidgetTester tester) async {
      final TestHarness h = TestHarness();
      PublisherLogos.debugSet(const <String, String>{
        'prothomalo': 'assets/publishers/prothomalo.png',
      });
      addTearDown(() => PublisherLogos.debugSet(const <String, String>{}));

      await tester.pumpWidget(h.wrap(
        const Center(child: PublisherLogo(source: _DailyStar(), size: 44)),
      ));
      await tester.pump();

      expect(find.byType(Image), findsNothing);
      expect(find.text(_dailyStarMonogram), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

/// The publisher's own initials, as the model derives them.
String get _monogram => const _ProthomAlo().monogram;
String get _dailyStarMonogram => const _DailyStar().monogram;

class _ProthomAlo extends NewsSource {
  const _ProthomAlo()
      : super(
          id: 'prothomalo',
          name: 'Prothom Alo',
          website: 'https://www.prothomalo.com/',
          language: SourceLanguage.bn,
          type: PublicationType.dailyNewspaper,
          feedClaim: FeedClaim.verifiedWorking,
        );
}

class _DailyStar extends NewsSource {
  const _DailyStar()
      : super(
          id: 'daily_star',
          name: 'The Daily Star',
          website: 'https://www.thedailystar.net/',
          language: SourceLanguage.en,
          type: PublicationType.dailyNewspaper,
          feedClaim: FeedClaim.verifiedWorking,
        );
}
