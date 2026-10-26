import 'package:bangladesh_newspaper_hub/core/utils/bengali_text.dart';
import 'package:bangladesh_newspaper_hub/data/models/app_preferences.dart';
import 'package:bangladesh_newspaper_hub/data/models/article.dart';
import 'package:bangladesh_newspaper_hub/data/models/news_source.dart';
import 'package:bangladesh_newspaper_hub/data/models/vocabulary_entry.dart';
import 'package:bangladesh_newspaper_hub/state/feed_controller.dart';
import 'package:bangladesh_newspaper_hub/theme/tokens.dart';
import 'package:bangladesh_newspaper_hub/ui/screens/about_screen.dart';
import 'package:bangladesh_newspaper_hub/ui/screens/article_detail_screen.dart';
import 'package:bangladesh_newspaper_hub/ui/screens/epaper_directory_screen.dart';
import 'package:bangladesh_newspaper_hub/ui/screens/home_screen.dart';
import 'package:bangladesh_newspaper_hub/ui/screens/newspapers_screen.dart';
import 'package:bangladesh_newspaper_hub/ui/screens/saved_screen.dart';
import 'package:bangladesh_newspaper_hub/ui/screens/search_screen.dart';
import 'package:bangladesh_newspaper_hub/ui/screens/settings_screen.dart';
import 'package:bangladesh_newspaper_hub/ui/screens/source_detail_screen.dart';
import 'package:bangladesh_newspaper_hub/ui/shell/app_shell.dart';
import 'package:bangladesh_newspaper_hub/ui/widgets/actions.dart';
import 'package:bangladesh_newspaper_hub/ui/widgets/article_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/test_app.dart';

void main() {
  final Article bnArticle = sampleArticle(
    title: 'বাংলাদেশে নতুন উদ্যোগ ঘোষণা করেছে সরকার',
    publishedAt: DateTime.now().toUtc().subtract(const Duration(hours: 2)),
  );
  final Article enArticle = sampleArticle(
    sourceId: 'daily_star',
    title: 'Bangladesh exports rise sharply this quarter',
    language: SourceLanguage.en,
    topic: ArticleTopic.economy,
  );

  TestHarness harness({
    List<Article> artwork = const <Article>[],
    AppPreferences prefs = const AppPreferences(language: AppLanguage.bn),
  }) {
    return TestHarness(
      prefs: prefs,
      stores: fakeStores(seed: artwork),
    );
  }

  group('HomeScreen', () {
    testWidgets('shows the one-time welcome only during a genuine first load',
        (WidgetTester tester) async {
      final FakeFeedGateway gateway = FakeFeedGateway(
        articlesBySource: <String, List<Article>>{
          'prothomalo': <Article>[bnArticle],
        },
        delay: const Duration(milliseconds: 50),
      );
      final TestHarness h = TestHarness(
        prefs: const AppPreferences(),
        gateway: gateway,
      );
      await tester.pumpWidget(h.wrap(const HomeScreen()));
      final Future<void> starting = h.feed.start();
      await tester.pump(const Duration(milliseconds: 10));

      expect(find.text('Welcome to Amar News!'), findsOneWidget);
      expect(
        find.text(
          'It may take a little longer to get your news ready the first time. Please bear with us while everything loads. Once your news is ready, you can start reading.',
        ),
        findsOneWidget,
      );
      expect(find.text('No headlines yet'), findsNothing);

      // Advance the widget-test clock so the intentionally slow fake request
      // can complete before awaiting its Future.
      await tester.pump(const Duration(milliseconds: 60));
      await starting;
      await tester.pumpAndSettle();
      expect(find.text('Welcome to Amar News!'), findsNothing);
      expect(h.settings.prefs.onboardingComplete, isTrue);
    });

    testWidgets('renders aggregated Bengali headlines with source and time',
        (WidgetTester tester) async {
      final TestHarness h = harness(artwork: <Article>[bnArticle, enArticle]);
      await tester.pumpWidget(h.wrap(const HomeScreen()));
      await h.feed.start();
      await tester.pumpAndSettle();

      expect(
          find.text('বাংলাদেশে নতুন উদ্যোগ ঘোষণা করেছে সরকার'), findsOneWidget);
      expect(find.text('প্রথম আলো'), findsWidgets);
      expect(find.text('২ ঘণ্টা আগে'), findsWidgets);
      expect(find.text('সর্বশেষ খবর'), findsOneWidget);
    });

    testWidgets('shows a useful empty state when no feed is available',
        (WidgetTester tester) async {
      final TestHarness h = TestHarness(stores: fakeStores(), online: false);
      await tester.pumpWidget(h.wrap(const HomeScreen()));
      await h.feed.start();
      await tester.pumpAndSettle();

      expect(find.text('এখনও কোনো খবর নেই'), findsOneWidget);
      expect(find.text('আবার চেষ্টা করুন'), findsWidgets);
    });

    testWidgets('marks cached content instead of pretending it is live',
        (WidgetTester tester) async {
      // Every publisher fails: the headlines on screen can only come from the
      // local cache, so the UI must say so rather than claim a live feed.
      final TestHarness h = TestHarness(
        stores: fakeStores(seed: <Article>[bnArticle]),
        gateway: FakeFeedGateway(failing: <String>{'prothomalo', 'daily_star'}),
      );
      await tester.pumpWidget(h.wrap(const HomeScreen()));
      await h.feed.start();
      await tester.pumpAndSettle();

      expect(find.text(bnArticle.title), findsOneWidget);
      expect(find.textContaining('ক্যাশ'), findsWidgets);
    });

    testWidgets('topic chip filters the feed', (WidgetTester tester) async {
      final TestHarness h = harness(artwork: <Article>[bnArticle, enArticle]);
      await tester.pumpWidget(h.wrap(const HomeScreen()));
      await h.feed.start();
      await tester.pumpAndSettle();

      await tester.tap(find.text('অর্থনীতি').first);
      await tester.pumpAndSettle();

      expect(h.feed.query.topics, <ArticleTopic>{ArticleTopic.economy});
      expect(find.text(enArticle.title), findsOneWidget);
      expect(find.text(bnArticle.title), findsNothing);
    });

    testWidgets('zero follows can return directly to the existing All feed',
        (WidgetTester tester) async {
      final TestHarness h = harness(artwork: <Article>[bnArticle]);
      await tester.pumpWidget(h.wrap(const HomeScreen()));
      await h.feed.start();
      await h.feed.setFollowedOnly(true);
      await tester.pumpAndSettle();

      expect(find.text('এখনও কোনো পত্রিকা অনুসরণ করছেন না'), findsOneWidget);
      expect(find.text('সব খবর দেখুন'), findsOneWidget);
      expect(find.text('আবার চেষ্টা করুন'), findsNothing,
          reason: 'no follows is not presented as a network failure');

      await tester.tap(find.text('সব খবর দেখুন'));
      await tester.pumpAndSettle();
      expect(h.feed.query.followedOnly, isFalse);
      expect(find.text(bnArticle.title), findsOneWidget);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets(
        'unfollowing the last publication shows the same All-news escape',
        (WidgetTester tester) async {
      final TestHarness h = harness(
        artwork: <Article>[bnArticle],
        prefs: const AppPreferences(
          language: AppLanguage.bn,
          followedSourceIds: <String>{'prothomalo'},
        ),
      );
      await tester.pumpWidget(h.wrap(const HomeScreen()));
      await h.feed.start();
      await h.feed.setFollowedOnly(true);
      await h.settings.toggleFollow('prothomalo');
      await h.feed.onSettingsChanged();
      await tester.pumpAndSettle();

      expect(find.text('সব খবর দেখুন'), findsOneWidget);
      expect(find.text('সব পত্রিকা'), findsOneWidget);
    });

    testWidgets(
        'real feed metadata exposes Source Comparison without injection',
        (WidgetTester tester) async {
      final Article first = sampleArticle(
        title: 'Supreme Court suspends election order after emergency hearing',
        link: 'https://www.prothomalo.com/court-report',
        language: SourceLanguage.en,
      );
      final Article second = sampleArticle(
        sourceId: 'daily_star',
        title:
            'Election order suspended by Supreme Court after emergency hearing',
        link: 'https://www.thedailystar.net/court-report',
        language: SourceLanguage.en,
      );
      final TestHarness h = harness(artwork: <Article>[first, second]);
      await tester.pumpWidget(h.wrap(const HomeScreen()));
      await h.feed.start();
      await tester.pumpAndSettle();

      expect(find.text('একই ঘটনা, বিভিন্ন সংবাদমাধ্যমে'), findsWidgets);
      expect(h.feed.relatedFor(first), contains(second));
      expect(h.feed.relatedFor(second), contains(first));
    });

    testWidgets('shows breaking stories only when the publisher flagged one',
        (WidgetTester tester) async {
      final Article breaking = sampleArticle(
        title: 'জরুরি সিদ্ধান্ত ঘোষণা',
        breaking: true,
        publishedAt: DateTime.now().toUtc(),
      );
      final TestHarness h = harness(artwork: <Article>[breaking]);
      await tester.pumpWidget(h.wrap(const HomeScreen()));
      await h.feed.start();
      await tester.pumpAndSettle();

      // The banner uses the localized label; Bengali has no letter case, so the
      // upper-case call is a no-op in a Bengali UI.
      expect(find.text('ব্রেকিং নিউজ'), findsOneWidget);
      expect(find.text('ব্রেকিং'), findsWidgets);
    });
  });

  group('NewspapersScreen', () {
    testWidgets('lists publications and filters by search query',
        (WidgetTester tester) async {
      final TestHarness h = harness();
      await tester.pumpWidget(h.wrap(const NewspapersScreen(standalone: true)));
      await tester.pumpAndSettle();

      expect(find.text('প্রথম আলো'), findsWidgets);
      expect(find.text('The Daily Star'), findsWidgets);

      await tester.enterText(find.byType(TextField), 'daily');
      await tester.pumpAndSettle();
      expect(find.text('The Daily Star'), findsWidgets);
      expect(find.text('বণিক বার্তা'), findsNothing);

      await tester.enterText(find.byType(TextField), 'বণিক');
      await tester.pumpAndSettle();
      expect(find.text('বণিক বার্তা'), findsWidgets);
      expect(find.text('The Daily Star'), findsNothing);
    });

    testWidgets('shows no-results state for a nonsense query',
        (WidgetTester tester) async {
      final TestHarness h = harness();
      await tester.pumpWidget(h.wrap(const NewspapersScreen(standalone: true)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'zzzzqqq');
      await tester.pumpAndSettle();
      expect(find.text('কিছু পাওয়া যায়নি'), findsOneWidget);
    });

    testWidgets('language filter narrows the list',
        (WidgetTester tester) async {
      final TestHarness h = harness();
      await tester.pumpWidget(h.wrap(const NewspapersScreen(standalone: true)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ইংরেজি').first);
      await tester.pumpAndSettle();
      expect(find.text('The Daily Star'), findsWidgets);
      expect(find.text('প্রথম আলো'), findsNothing);
    });

    testWidgets('following a publication persists in settings',
        (WidgetTester tester) async {
      final TestHarness h = harness();
      await tester.pumpWidget(h.wrap(const NewspapersScreen(standalone: true)));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add_circle_outline_rounded).first);
      await tester.pump();
      expect(h.settings.followedSourceIds, isNotEmpty);
      await tester.pumpAndSettle();
    });
  });

  group('SourceDetailScreen', () {
    testWidgets('website, follow and e-paper actions are present and enabled',
        (WidgetTester tester) async {
      final TestHarness h = harness();
      final NewsSource source = h.registry.byId('prothomalo')!;
      await tester.pumpWidget(h.wrap(SourceDetailScreen(source: source)));
      await tester.pumpAndSettle();

      expect(find.text('প্রথম আলো'), findsWidgets);
      expect(find.text('অফিসিয়াল ওয়েবসাইট'), findsOneWidget);
      expect(find.text('অনুসরণ'), findsOneWidget);
      expect(find.text('ই-পেপার খুলুন'), findsOneWidget);
      expect(find.text('পত্রিকা সম্পর্কে'), findsOneWidget);
      expect(find.textContaining('Feed fetched and parsed'), findsNothing);
      expect(find.textContaining('valid XML'), findsNothing);
      expect(find.text(source.feedUrl!), findsNothing);
    });

    testWidgets('publication without a feed offers website only',
        (WidgetTester tester) async {
      final TestHarness h = harness();
      final NewsSource source = h.registry.byId('bonik_barta')!;
      await tester.pumpWidget(h.wrap(SourceDetailScreen(source: source)));
      await tester.pumpAndSettle();

      expect(find.text('কোনো ফিড নেই — ওয়েবসাইট ব্যবহার করুন'), findsWidgets);
      expect(find.text('শিরোনাম আনুন'), findsNothing);
    });

    testWidgets('follow button toggles state', (WidgetTester tester) async {
      final TestHarness h = harness();
      final NewsSource source = h.registry.byId('prothomalo')!;
      await tester.pumpWidget(h.wrap(SourceDetailScreen(source: source)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('অনুসরণ'));
      await tester.pump();
      expect(h.settings.isFollowing('prothomalo'), isTrue);
      await tester.pumpAndSettle();
      expect(find.text('অনুসরণ করছেন'), findsWidgets);
    });
  });

  group('SavedScreen', () {
    testWidgets('bookmarking from a card adds it to Saved and survives restart',
        (WidgetTester tester) async {
      final Article article = sampleArticle(title: 'সংরক্ষণের জন্য খবর');
      final TestHarness h = harness(artwork: <Article>[article]);

      await tester.pumpWidget(h.wrap(const SavedScreen()));
      await h.saved.load();
      await tester.pumpAndSettle();
      expect(find.text('কোনো খবর সংরক্ষিত নেই'), findsOneWidget);

      await h.saved.toggle(article);
      await tester.pumpAndSettle();
      expect(find.text('সংরক্ষণের জন্য খবর'), findsOneWidget);

      // A fresh controller reading the same store behaves like a restart.
      final TestHarness h2 = TestHarness(stores: h.stores);
      await tester.pumpWidget(h2.wrap(const SavedScreen()));
      await h2.saved.load();
      await tester.pumpAndSettle();
      expect(find.text('সংরক্ষণের জন্য খবর'), findsOneWidget);
    });

    testWidgets('unbookmarking removes the story', (WidgetTester tester) async {
      final TestHarness h = harness();
      final Article article = sampleArticle(title: 'মুছে ফেলার খবর');
      await h.saved.load();
      await h.saved.toggle(article);
      await tester.pumpWidget(h.wrap(const SavedScreen()));
      await tester.pumpAndSettle();

      final Finder bookmark = find.byIcon(Icons.bookmark_rounded).first;
      await tester.ensureVisible(bookmark);
      await tester.pump();
      await tester.tap(bookmark);
      await tester.pumpAndSettle();
      expect(find.text('মুছে ফেলার খবর'), findsNothing);
    });
  });

  group('ArticleCard', () {
    testWidgets('shows the missing-date note instead of a fake timestamp',
        (WidgetTester tester) async {
      final Article undated = Article.create(
        sourceId: 'prothomalo',
        title: 'তারিখ ছাড়া খবর',
        link: 'https://www.prothomalo.com/undated-card',
      );
      final TestHarness h = harness();
      await tester.pumpWidget(h.wrap(
        Scaffold(
          body: ArticleCard(
            article: undated,
            source: h.registry.byId('prothomalo'),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('প্রকাশের সময় পাওয়া যায়নি'), findsOneWidget);
    });
  });

  group('SearchScreen', () {
    testWidgets('finds publications and headlines, and separates the groups',
        (WidgetTester tester) async {
      final TestHarness h = harness(artwork: <Article>[enArticle]);
      await tester.pumpWidget(h.wrap(const SearchScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'exports');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('খবর'), findsWidgets);
      expect(find.text(enArticle.title), findsOneWidget);
    });

    testWidgets(
        'archive mode stays visibly separate and returns retained metadata',
        (WidgetTester tester) async {
      final Article retained = sampleArticle(
        title: 'বিশেষ পুরোনো প্রতিবেদন',
        publishedAt: DateTime.now().toUtc().subtract(const Duration(days: 20)),
      );
      final TestHarness h = harness(artwork: <Article>[retained]);
      await tester.pumpWidget(h.wrap(const SearchScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('পুরোনো খবর খুঁজুন'));
      await tester.enterText(find.byType(TextField), 'বিশেষ পুরোনো');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.textContaining('লাইভ ফিড থেকে আলাদা'), findsOneWidget);
      expect(find.text(retained.title), findsOneWidget);
    });

    testWidgets('shows recent searches and empty state',
        (WidgetTester tester) async {
      final TestHarness h = harness(
          prefs: const AppPreferences(
        language: AppLanguage.bn,
        searchHistory: <String>['প্রথম আলো'],
      ));
      await tester.pumpWidget(h.wrap(const SearchScreen()));
      await tester.pumpAndSettle();

      expect(find.text('সাম্প্রতিক খোঁজ'), findsOneWidget);
      expect(find.text('প্রথম আলো'), findsWidgets);

      await tester.enterText(find.byType(TextField), 'qqqqqq');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('কিছু পাওয়া যায়নি'), findsOneWidget);
    });
  });

  group('SettingsScreen', () {
    testWidgets('selected choices use a clean primary pill without stray border',
        (WidgetTester tester) async {
      final TestHarness h = harness();
      await tester.pumpWidget(h.wrap(const SettingsScreen()));
      await tester.pumpAndSettle();
      final Container selected = tester.widget<Container>(
        find.byKey(const ValueKey<String>('choice-selected-0')).first,
      );
      final BoxDecoration decoration = selected.decoration! as BoxDecoration;
      expect(decoration.border, isNull);
      expect(decoration.boxShadow, isNull);
      expect(decoration.color, isNotNull);
      expect(decoration.color!.r, greaterThan(decoration.color!.b));
    });

    testWidgets('feed choices adapt at 320dp with large text in dark theme',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final TestHarness h = TestHarness(
        prefs: const AppPreferences(
          language: AppLanguage.en,
          theme: AppThemeChoice.dark,
          textScale: 1.4,
          webViewTourComplete: true,
        ),
      );
      await tester.pumpWidget(
        h.wrap(const SettingsScreen(), brightness: Brightness.dark),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Default feed'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Latest'), findsOneWidget);
      expect(find.text('Following'), findsOneWidget);
      expect(find.text('15m'), findsOneWidget);
      expect(find.text('240m'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('pinned heading has an opaque surface above scrolling content',
        (WidgetTester tester) async {
      final TestHarness h = harness();
      await tester.pumpWidget(h.wrap(const SettingsScreen()));
      await tester.pumpAndSettle();
      final SliverAppBar bar = tester.widget<SliverAppBar>(
        find.byType(SliverAppBar),
      );
      expect(bar.pinned, isTrue);
      expect(bar.backgroundColor?.a, 1.0);
    });

    testWidgets(
        'integration toggles change independently without deleting data',
        (WidgetTester tester) async {
      final TestHarness h = harness();
      await h.saved.load();
      await h.saved.saveVocabulary(VocabularyEntry(
        word: 'policy',
        meaningBn: 'নীতি',
        savedAt: DateTime.utc(2026, 10, 26),
      ));
      await tester.pumpWidget(h.wrap(const SettingsScreen()));
      await tester.pumpAndSettle();
      await h.settings.setVocabularyIntegrationEnabled(false);
      await h.settings.setTtsIntegrationEnabled(false);
      await h.settings.setUltraLightMode(true);
      await tester.pump();
      expect(h.settings.vocabularyIntegrationEnabled, isFalse);
      expect(h.settings.ttsIntegrationEnabled, isFalse);
      expect(h.settings.translationIntegrationEnabled, isTrue);
      expect(h.settings.ultraLightMode, isTrue);
      expect(h.saved.vocabulary, hasLength(1));
    });

    testWidgets('switching theme and text size updates preferences',
        (WidgetTester tester) async {
      final TestHarness h = harness();
      await tester.pumpWidget(h.wrap(const SettingsScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('গাঢ়'));
      await tester.pump();
      expect(h.settings.prefs.theme, AppThemeChoice.dark);
      await tester.pumpAndSettle();

      await tester.drag(find.byType(Slider).first, const Offset(60, 0));
      await tester.pumpAndSettle();
      expect(h.settings.textScale, greaterThan(1.0));
    });

    testWidgets('language switch changes the UI strings',
        (WidgetTester tester) async {
      final TestHarness h = harness();
      await tester.pumpWidget(h.wrap(const SettingsScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('English'));
      await tester.pump();
      expect(h.settings.prefs.language, AppLanguage.en);
      expect(find.text('Settings'), findsWidgets);
      // Section headers are rendered upper-case by the settings screen.
      expect(find.text('APPEARANCE'), findsWidgets);
    });

    testWidgets(
        'font selection applies globally and system default restores it',
        (WidgetTester tester) async {
      final TestHarness h = harness();
      await tester.pumpWidget(h.wrap(const SettingsScreen()));
      await tester.pumpAndSettle();

      expect(h.settings.font, AppFontChoice.system);
      expect(Tokens.sans, isNull);
      expect(find.text('সিস্টেমের ডিফল্ট'), findsOneWidget);
      expect(find.text('Noto Sans Bengali'), findsOneWidget);
      expect(find.text('Noto Serif Bengali'), findsOneWidget);

      await h.settings.setFont(AppFontChoice.notoSans);
      await tester.pumpAndSettle();
      expect(h.settings.font, AppFontChoice.notoSans);
      expect(Tokens.sans, 'NotoSansBengali');

      await h.settings.setFont(AppFontChoice.notoSerif);
      await tester.pumpAndSettle();
      expect(Tokens.serif, 'NotoSerifBengali');

      await h.settings.setFont(AppFontChoice.system);
      await tester.pumpAndSettle();
      expect(h.settings.font, AppFontChoice.system);
      expect(Tokens.sans, isNull);
    });

    testWidgets(
        'About is concise and shows only the confirmed developer identity',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final TestHarness h = harness();
      await tester.pumpWidget(h.wrap(const AboutScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Md. Emon'), findsOneWidget);
      expect(find.byType(Image), findsWidgets);
      expect(find.textContaining('ব্রজলাল কলেজ'), findsNothing);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(AboutScreen.developerProfileUrl,
          'https://www.facebook.com/muhammad.emon.738798');
      expect(find.byIcon(Icons.open_in_new_rounded), findsOneWidget);
      expect(find.textContaining('আমার নিউজ একটি সহজ'), findsOneWidget);

      await h.settings.setLanguage(AppLanguage.en);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Amar News is a simple, customizable news reader'),
        findsOneWidget,
      );
      expect(find.text('Md. Emon'), findsOneWidget);
    });

    testWidgets('About respects reduced motion and settles without a loop',
        (WidgetTester tester) async {
      final TestHarness h = harness(
        prefs: const AppPreferences(
          language: AppLanguage.bn,
          motion: MotionChoice.reduced,
        ),
      );
      await tester.pumpWidget(h.wrap(const AboutScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Md. Emon'), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('EpaperDirectoryScreen', () {
    testWidgets('lists publisher e-paper editions',
        (WidgetTester tester) async {
      final TestHarness h = harness();
      await tester.pumpWidget(h.wrap(const EpaperDirectoryScreen()));
      await tester.pumpAndSettle();
      expect(find.text('প্রথম আলো ই-পেপার'), findsOneWidget);
    });
  });

  group('typography', () {
    testWidgets(
        'global text scale reaches feed, detail, controls, settings and About',
        (WidgetTester tester) async {
      final Article related = sampleArticle(
        sourceId: 'daily_star',
        title: 'Related publisher report for typography',
        link: 'https://www.thedailystar.net/type-related',
      );
      final TestHarness h = harness(artwork: <Article>[bnArticle]);
      await tester.pumpWidget(h.wrap(const HomeScreen()));
      await h.feed.start();
      await tester.pumpAndSettle();
      expect(
        MediaQuery.textScalerOf(tester.element(find.text(bnArticle.title)))
            .scale(10),
        closeTo(10, 0.01),
      );

      await h.settings.setTextScale(1.4);
      await tester.pumpAndSettle();
      expect(
        MediaQuery.textScalerOf(tester.element(find.text(bnArticle.title)))
            .scale(10),
        greaterThan(12),
      );

      await tester.pumpWidget(h.wrap(
        ArticleDetailScreen(article: bnArticle, related: <Article>[related]),
      ));
      await tester.pumpAndSettle();
      for (final Finder finder in <Finder>[
        find.text('সম্পূর্ণ খবর পড়ুন'),
        find.text('একই ঘটনা, বিভিন্ন সংবাদমাধ্যমে'),
        find.text(related.title),
      ]) {
        expect(
          MediaQuery.textScalerOf(tester.element(finder)).scale(10),
          greaterThan(12),
        );
      }

      await tester.pumpWidget(h.wrap(const SettingsScreen()));
      await tester.pumpAndSettle();
      expect(
        MediaQuery.textScalerOf(tester.element(find.text('সেটিংস').first))
            .scale(10),
        greaterThan(12),
      );

      await tester.pumpWidget(h.wrap(const AboutScreen()));
      await tester.pumpAndSettle();
      final Finder aboutCopy = find.textContaining('আমার নিউজ একটি সহজ');
      expect(
        MediaQuery.textScalerOf(tester.element(aboutCopy)).scale(10),
        greaterThan(12),
      );
    });

    test('Bengali numerals are used for relative times in the Bengali UI', () {
      final DateTime now = DateTime.utc(2026, 10, 24, 12);
      expect(
        BengaliText.relative(now.subtract(const Duration(minutes: 5)),
            bengali: true, now: now),
        '৫ মিনিট আগে',
      );
    });
  });

  group('dark theme', () {
    testWidgets('home renders in dark mode', (WidgetTester tester) async {
      final TestHarness h = harness(
        artwork: <Article>[bnArticle],
        prefs: const AppPreferences(
          language: AppLanguage.bn,
          theme: AppThemeChoice.dark,
        ),
      );
      await tester
          .pumpWidget(h.wrap(const HomeScreen(), brightness: Brightness.dark));
      await h.feed.start();
      await tester.pumpAndSettle();
      expect(find.text(bnArticle.title), findsOneWidget);
      final ThemeData theme = Theme.of(tester.element(find.byType(HomeScreen)));
      expect(theme.brightness, Brightness.dark);
    });
  });

  group('ArticleDetailScreen redesign', () {
    testWidgets(
        'has no native scrollbar and exposes real comparison in freed space',
        (WidgetTester tester) async {
      final Article primary = sampleArticle(title: 'মূল খবরের শিরোনাম');
      final Article other = sampleArticle(
        sourceId: 'daily_star',
        title: 'অন্য প্রকাশকের আসল শিরোনাম',
        link: 'https://www.thedailystar.net/original-comparison',
      );
      final TestHarness h = harness();
      await tester.pumpWidget(h.wrap(
        ArticleDetailScreen(article: primary, related: <Article>[other]),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(Scrollbar), findsNothing);
      expect(find.byType(RawScrollbar), findsNothing);
      expect(find.byType(ReadingProgressBar), findsNothing,
          reason: 'the red horizontal rule was the reading-progress painter');
      expect(find.text('সম্পূর্ণ খবর পড়ুন'), findsOneWidget);
      expect(find.text('মূল প্রতিবেদন পড়ুন'), findsNothing);
      expect(find.text('লিংক কপি করুন'), findsNothing);
      expect(find.text('শেয়ার'), findsNothing);
      expect(find.text('একই ঘটনা, বিভিন্ন সংবাদমাধ্যমে'), findsOneWidget);
      expect(find.text('আরও 1টি সংবাদমাধ্যমে'), findsOneWidget);
      expect(find.text(other.title), findsOneWidget);
      expect(find.text('ওয়েবসাইট খুলুন'), findsNothing);
      expect(find.text('পত্রিকা সম্পর্কে'), findsNothing);
      expect(find.text('অনুসরণ'), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('publisher-identity')),
      );
      final double buttonY = tester
          .getTopLeft(find.byKey(const ValueKey<String>('read-full-story')))
          .dy;
      final double comparisonY = tester
          .getTopLeft(
              find.byKey(const ValueKey<String>('source-comparison-section')))
          .dy;
      final double publisherY = tester
          .getTopLeft(find.byKey(const ValueKey<String>('publisher-identity')))
          .dy;
      expect(buttonY, lessThan(comparisonY));
      expect(comparisonY, lessThan(publisherY));

      await h.settings.setLanguage(AppLanguage.en);
      await tester.pumpAndSettle();
      expect(find.text('Read full story'), findsOneWidget);
      expect(find.text('Related Coverage'), findsOneWidget);

      final NavigatorState navigator =
          tester.state<NavigatorState>(find.byType(Navigator).first);
      await tester.ensureVisible(find.text(other.title));
      await tester.tap(find.text(other.title));
      await tester.pumpAndSettle();
      expect(navigator.canPop(), isTrue,
          reason: 'a comparison row opens that real report in article detail');
    });

    testWidgets(
        'keeps native detail scrolling without painting a progress line',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(720, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final TestHarness h = harness();
      final Article longArticle = sampleArticle(
        title: bnArticle.title,
        excerpt: List<String>.filled(
          30,
          'This feed excerpt makes the native detail surface vertically scrollable.',
        ).join(' '),
      );
      await tester.pumpWidget(h.wrap(
        ArticleDetailScreen(article: longArticle, related: const <Article>[]),
      ));
      await tester.pumpAndSettle();

      final Finder title = find.text(longArticle.title);
      final double before = tester.getTopLeft(title).dy;
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(title).dy, lessThan(before));
      expect(find.byType(ReadingProgressBar), findsNothing);
      expect(find.byType(Scrollbar), findsNothing);
      expect(find.byType(RawScrollbar), findsNothing);
    });

    testWidgets('reacts when the live comparison index becomes available',
        (WidgetTester tester) async {
      final DateTime now = DateTime.now().toUtc();
      final Article primary = sampleArticle(
        title: 'Supreme Court suspends election order after emergency hearing',
        link: 'https://www.prothomalo.com/dynamic-court-report',
        language: SourceLanguage.en,
        publishedAt: now,
      );
      final Article other = sampleArticle(
        sourceId: 'daily_star',
        title:
            'Election order suspended by Supreme Court after emergency hearing',
        link: 'https://www.thedailystar.net/dynamic-court-report',
        language: SourceLanguage.en,
        publishedAt: now,
      );
      final TestHarness h = TestHarness(
        prefs: const AppPreferences(language: AppLanguage.bn),
        stores: fakeStores(),
        gateway: FakeFeedGateway(
          articlesBySource: <String, List<Article>>{
            'prothomalo': <Article>[primary],
            'daily_star': <Article>[other],
          },
        ),
      );
      await tester.pumpWidget(h.wrap(
        ArticleDetailScreen(article: primary, related: const <Article>[]),
      ));
      await tester.pumpAndSettle();
      expect(find.text('সম্পর্কিত খবর খোঁজা হচ্ছে…'), findsOneWidget);

      await h.feed.start();
      await tester.pumpAndSettle();

      expect(find.text('একই ঘটনা, বিভিন্ন সংবাদমাধ্যমে'), findsOneWidget);
      expect(find.text(other.title), findsOneWidget);
    });

    testWidgets(
        'renders observed bilingual election coverage outside the visible feed',
        (WidgetTester tester) async {
      final DateTime now = DateTime.now().toUtc();
      final Article dw = sampleArticle(
        sourceId: 'daily_star',
        title: 'Brazilian leftist President Lula wins reelection against '
            'conservative challenger Flavio Bolsonaro',
        link: 'https://www.dw.com/en/brazil-election-result/a-123',
        excerpt:
            'Lula won Brazil’s presidential election and secured another term.',
        language: SourceLanguage.en,
        publishedAt: now.subtract(const Duration(hours: 4)),
      );
      final Article prothomAlo = sampleArticle(
        title: 'ব্রাজিলে লুলার নাটকীয় জয়',
        link: 'https://www.prothomalo.com/world/brazil-lula-win',
        excerpt:
            'প্রেসিডেন্ট নির্বাচনে প্রতিদ্বন্দ্বীকে হারিয়ে জয়ী হয়েছেন লুলা।',
        publishedAt: now.subtract(const Duration(hours: 3, minutes: 45)),
      );
      final List<Article> newer = List<Article>.generate(
        FeedController.pageSize + 5,
        (int index) => sampleArticle(
          title: 'স্বতন্ত্র সাম্প্রতিক সংবাদ $index',
          link: 'https://www.prothomalo.com/unrelated-$index',
          publishedAt: now.subtract(Duration(minutes: index)),
        ),
      );
      final TestHarness h = harness(
        artwork: <Article>[...newer, dw, prothomAlo],
      );
      await h.feed.start();
      expect(h.feed.articles, isNot(contains(dw)));
      expect(h.feed.relatedFor(dw), contains(prothomAlo));

      await tester.pumpWidget(h.wrap(
        ArticleDetailScreen(article: dw, related: const <Article>[]),
      ));
      await tester.pumpAndSettle();

      expect(find.text('একই ঘটনা, বিভিন্ন সংবাদমাধ্যমে'), findsOneWidget);
      expect(find.text(prothomAlo.title), findsOneWidget);
      expect(find.text('কোনো সম্পর্কিত খবর পাওয়া যায়নি।'), findsNothing);
      await tester.ensureVisible(find.text(prothomAlo.title));
      await tester.tap(find.text(prothomAlo.title));
      await tester.pumpAndSettle();
      expect(find.text(prothomAlo.title), findsWidgets);
    });

    testWidgets('merges archive and live matches and excludes duplicates',
        (WidgetTester tester) async {
      final DateTime now = DateTime.now().toUtc();
      Article event(String source, String title, String link) => sampleArticle(
            sourceId: source,
            title: title,
            link: link,
            language: SourceLanguage.en,
            publishedAt: now,
          );
      final Article primary = event(
        'prothomalo',
        'Cyclone forces coastal evacuation before landfall tonight',
        'https://www.prothomalo.com/cyclone-main',
      );
      final Article archive = event(
        'daily_star',
        'Coastal evacuation begins as cyclone nears landfall tonight',
        'https://www.thedailystar.net/cyclone-archive',
      );
      final Article live = event(
        'bonik_barta',
        'Cyclone nears landfall tonight after coastal evacuation begins',
        'https://www.bonikbarta.com/cyclone-live',
      );
      final Article samePublisher = event(
        'prothomalo',
        'Coastal evacuation begins before cyclone landfall tonight',
        'https://www.prothomalo.com/cyclone-update',
      );
      final Article duplicateUrl = event(
        'bonik_barta',
        archive.title,
        '${archive.link}?utm_source=duplicate',
      );
      final TestHarness h = harness(
        artwork: <Article>[
          primary,
          archive,
          live,
          samePublisher,
          duplicateUrl,
        ],
      );
      await h.feed.start();
      await tester.pumpWidget(h.wrap(
        ArticleDetailScreen(article: primary, related: <Article>[archive]),
      ));
      await tester.pumpAndSettle();

      expect(find.text(archive.title), findsOneWidget);
      expect(find.text(live.title), findsOneWidget);
      expect(find.text(samePublisher.title), findsNothing);
      expect(find.text(archive.title), findsOneWidget);
      expect(find.text(duplicateUrl.link), findsNothing);

      for (final Article candidate in <Article>[archive, live]) {
        await tester.ensureVisible(find.text(candidate.title));
        await tester.tap(find.text(candidate.title));
        await tester.pumpAndSettle();
        expect(find.text(candidate.title), findsWidgets);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
      }
    });

    testWidgets('renders a localized completed empty comparison state',
        (WidgetTester tester) async {
      final TestHarness h = harness();
      await h.feed.start();
      await tester.pumpWidget(h.wrap(
        ArticleDetailScreen(article: bnArticle, related: const <Article>[]),
      ));
      await tester.pumpAndSettle();

      expect(find.text('একই ঘটনা, বিভিন্ন সংবাদমাধ্যমে'), findsOneWidget);
      expect(find.text('কোনো সম্পর্কিত খবর পাওয়া যায়নি।'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('source-comparison-empty')),
        findsOneWidget,
      );

      await h.settings.setLanguage(AppLanguage.en);
      await tester.pumpAndSettle();
      expect(find.text('Related Coverage'), findsOneWidget);
      expect(find.text('No related news found.'), findsOneWidget);
    });
  });

  group('AppShell navigation', () {
    testWidgets('performance tip waits five seconds after first successful load',
        (WidgetTester tester) async {
      final TestHarness h = harness(
        artwork: <Article>[bnArticle],
        prefs: const AppPreferences(
          language: AppLanguage.en,
          onboardingComplete: false,
          performanceTipComplete: false,
        ),
      );
      await tester.pumpWidget(h.wrap(const AppShell()));
      for (int i = 0;
          i < 10 && !h.settings.prefs.onboardingComplete;
          i++) {
        await tester.pump();
      }
      expect(h.settings.prefs.onboardingComplete, isTrue);
      expect(find.byKey(const ValueKey<String>('performance-tip')), findsNothing);

      await tester.pump(const Duration(milliseconds: 4999));
      expect(find.byKey(const ValueKey<String>('performance-tip')), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byKey(const ValueKey<String>('performance-tip')), findsOneWidget);
      expect(find.text('Want a smoother experience?'), findsOneWidget);
      expect(
        find.text(
          'If Amar News feels a little slow on your phone, try enabling Ultra-Light Performance Mode in Settings. It reduces heavy visual effects and unnecessary animations, which may help the app feel more responsive.',
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('performance-tip-dismiss')),
      );
      await tester.pumpAndSettle();
      expect(h.settings.performanceTipComplete, isTrue);

      await tester.pumpWidget(h.wrap(AppShell(key: UniqueKey())));
      await tester.pump(const Duration(seconds: 6));
      expect(find.byKey(const ValueKey<String>('performance-tip')), findsNothing);
    });

    testWidgets('failed offline first load never schedules performance tip',
        (WidgetTester tester) async {
      final TestHarness h = TestHarness(
        prefs: const AppPreferences(
          onboardingComplete: false,
          performanceTipComplete: false,
        ),
        online: false,
      );
      await tester.pumpWidget(h.wrap(const AppShell()));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 6));
      expect(find.byKey(const ValueKey<String>('performance-tip')), findsNothing);
      expect(h.settings.performanceTipComplete, isFalse);
    });

    testWidgets('performance tip action safely selects Settings in Bengali',
        (WidgetTester tester) async {
      final TestHarness h = harness(
        artwork: <Article>[bnArticle],
        prefs: const AppPreferences(
          language: AppLanguage.bn,
          onboardingComplete: false,
          performanceTipComplete: false,
        ),
      );
      await tester.pumpWidget(h.wrap(const AppShell()));
      for (int i = 0;
          i < 10 && !h.settings.prefs.onboardingComplete;
          i++) {
        await tester.pump();
      }
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('অ্যাপ একটু ধীর মনে হচ্ছে?'), findsOneWidget);
      expect(find.text('Settings খুলুন'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey<String>('performance-tip-settings')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('nav-item-4-true')),
        findsOneWidget,
      );
    });

    testWidgets('meaningful settled scroll briefly transforms navigation',
        (WidgetTester tester) async {
      final List<Article> articles = List<Article>.generate(
        25,
        (int index) => sampleArticle(
          title: 'Bounce story $index',
          link: 'https://example.com/bounce-$index',
        ),
      );
      final TestHarness h = harness(artwork: articles);
      await tester.pumpWidget(h.wrap(const AppShell(), reduceMotion: false));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byType(CustomScrollView).first),
      );
      for (int i = 0; i < 5; i++) {
        await gesture.moveBy(const Offset(0, -90));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pump(const Duration(milliseconds: 250));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 100));
      final Transform bounce = tester.widget<Transform>(
        find.byKey(const ValueKey<String>('scroll-nav-bounce')),
      );
      expect(bounce.transform.getTranslation().y, isNot(0));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Transform>(
              find.byKey(const ValueKey<String>('scroll-nav-bounce')),
            )
            .transform
            .getTranslation()
            .y,
        0,
      );
    });

    testWidgets('reduced motion suppresses scroll navigation bounce',
        (WidgetTester tester) async {
      final TestHarness h = TestHarness(
        prefs: const AppPreferences(
          language: AppLanguage.bn,
          motion: MotionChoice.reduced,
          webViewTourComplete: true,
        ),
      );
      await tester.pumpWidget(h.wrap(const AppShell()));
      await tester.pumpAndSettle();
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byType(CustomScrollView).first),
      );
      await gesture.moveBy(const Offset(0, -200));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 100));
      final Transform bounce = tester.widget<Transform>(
        find.byKey(const ValueKey<String>('scroll-nav-bounce')),
      );
      expect(bounce.transform.getTranslation().y, 0);
    });

    testWidgets(
        'reselecting Home refreshes once and returns its feed to the top',
        (WidgetTester tester) async {
      final List<Article> articles = List<Article>.generate(
        35,
        (int index) => sampleArticle(
          title: 'দীর্ঘ সংবাদ তালিকার শিরোনাম $index',
          link: 'https://www.prothomalo.com/reselect-$index',
          publishedAt:
              DateTime.now().toUtc().subtract(Duration(minutes: index)),
        ),
      );
      final TestHarness h = harness(artwork: articles);
      await tester.pumpWidget(h.wrap(const AppShell()));
      await tester.pumpAndSettle();

      final CustomScrollView homeScroll =
          tester.widget<CustomScrollView>(find.byType(CustomScrollView).first);
      await tester.drag(
          find.byType(CustomScrollView).first, const Offset(0, -900));
      await tester.pumpAndSettle();
      expect(homeScroll.controller!.offset, greaterThan(100));
      final int callsBefore = h.gateway.calls;

      await tester.tap(find.text('হোম'));
      await tester.tap(find.text('হোম'));
      await tester.pumpAndSettle();

      expect(homeScroll.controller!.offset, 0);
      expect(
        h.gateway.calls - callsBefore,
        h.registry.feedSources.length,
        reason: 'rapid reselection starts one repository refresh only',
      );
    });

    testWidgets('switches tabs and stays on Home after switching',
        (WidgetTester tester) async {
      final TestHarness h = harness(artwork: <Article>[bnArticle]);
      await tester.pumpWidget(h.wrap(const AppShell()));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      await tester.tap(find.text('পত্রিকা'));
      await tester.pumpAndSettle();
      expect(find.byType(NewspapersScreen), findsOneWidget);

      await tester.tap(find.text('সেটিংস'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);

      // Back from a non-home tab returns to Home instead of exiting.
      final NavigatorState navigator =
          tester.state<NavigatorState>(find.byType(Navigator).first);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(navigator.canPop(), isFalse);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('pushed article detail can be popped back to the list',
        (WidgetTester tester) async {
      final TestHarness h = harness(artwork: <Article>[bnArticle]);
      await tester.pumpWidget(h.wrap(const HomeScreen()));
      await h.feed.start();
      await tester.pumpAndSettle();

      await tester.tap(find.text(bnArticle.title));
      await tester.pumpAndSettle();
      expect(find.text('সম্পূর্ণ খবর পড়ুন'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('মূল প্রতিবেদন পড়ুন'), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });

  group('background refresh timer', () {
    testWidgets('runs only while explicitly visible and cancels on dispose',
        (WidgetTester tester) async {
      final TestHarness h = harness();
      final FeedController feed = FeedController(
        repository: h.repository,
        settings: h.settings,
        registry: h.registry,
        connectivity: FakeConnectivity(),
        backgroundRefresh: true,
        autoRefreshInterval: const Duration(milliseconds: 20),
        comparisonIndexer: (List<Article> articles) async =>
            <String, List<Article>>{},
      );
      await tester.pumpWidget(h.wrap(const SizedBox.shrink()));
      await feed.start();
      final Object? initial = feed.lastReport;

      feed.setPollingActive(true);
      await tester.pump(const Duration(milliseconds: 25));
      expect(feed.lastReport, isNot(same(initial)));

      feed.setPollingActive(false);
      final Object? paused = feed.lastReport;
      await tester.pump(const Duration(milliseconds: 50));
      expect(feed.lastReport, same(paused));

      feed.dispose();
      await tester.pumpAndSettle();
    });
  });

  group('responsive layout', () {
    testWidgets('renders on a small phone without overflow',
        (WidgetTester tester) async {
      // 360 x 640 dp: a common small Android phone.
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final TestHarness h = harness(artwork: <Article>[bnArticle, enArticle]);
      await tester.pumpWidget(h.wrap(const HomeScreen()));
      await h.feed.start();
      // Capture layout errors ourselves so the full diagnostics (including the
      // offending widget and its source line) reach the CI log.
      final List<FlutterErrorDetails> layoutErrors = <FlutterErrorDetails>[];
      final previousHandler = FlutterError.onError;
      FlutterError.onError = layoutErrors.add;
      await tester.pumpAndSettle();
      FlutterError.onError = previousHandler;
      for (final FlutterErrorDetails details in layoutErrors) {
        debugPrint('LAYOUT-ERROR: $details');
      }
      expect(layoutErrors, isEmpty);
      expect(find.text(bnArticle.title), findsOneWidget);
    });

    testWidgets('survives an ultra-narrow 320dp viewport',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(640, 960);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      final TestHarness h = harness(artwork: <Article>[bnArticle]);
      await tester.pumpWidget(h.wrap(const HomeScreen()));
      await h.feed.start();
      final List<FlutterErrorDetails> layoutErrors = <FlutterErrorDetails>[];
      final previousHandler = FlutterError.onError;
      FlutterError.onError = layoutErrors.add;
      await tester.pumpAndSettle();
      FlutterError.onError = previousHandler;
      for (final FlutterErrorDetails details in layoutErrors) {
        debugPrint('LAYOUT-ERROR: $details');
      }
      expect(layoutErrors, isEmpty);
    });

    testWidgets('renders on a tablet width without overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 2560);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      final TestHarness h = harness(artwork: <Article>[bnArticle]);
      await tester.pumpWidget(h.wrap(const NewspapersScreen(standalone: true)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
