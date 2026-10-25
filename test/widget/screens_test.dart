import 'package:bangladesh_newspaper_hub/core/utils/bengali_text.dart';
import 'package:bangladesh_newspaper_hub/data/models/app_preferences.dart';
import 'package:bangladesh_newspaper_hub/data/models/article.dart';
import 'package:bangladesh_newspaper_hub/data/models/news_source.dart';
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
    AppPreferences prefs = const AppPreferences(),
  }) {
    return TestHarness(
      prefs: prefs,
      stores: fakeStores(seed: artwork),
    );
  }

  group('HomeScreen', () {
    testWidgets('renders aggregated Bengali headlines with source and time', (WidgetTester tester) async {
      final TestHarness h = harness(artwork: <Article>[bnArticle, enArticle]);
      await tester.pumpWidget(h.wrap(const HomeScreen()));
      await h.feed.start();
      await tester.pumpAndSettle();

      expect(find.text('বাংলাদেশে নতুন উদ্যোগ ঘোষণা করেছে সরকার'), findsOneWidget);
      expect(find.text('প্রথম আলো'), findsWidgets);
      expect(find.text('২ ঘণ্টা আগে'), findsWidgets);
      expect(find.text('সর্বশেষ খবর'), findsOneWidget);
    });

    testWidgets('shows a useful empty state when no feed is available', (WidgetTester tester) async {
      final TestHarness h = TestHarness(stores: fakeStores(), online: false);
      await tester.pumpWidget(h.wrap(const HomeScreen()));
      await h.feed.start();
      await tester.pumpAndSettle();

      expect(find.text('এখনও কোনো খবর নেই'), findsOneWidget);
      expect(find.text('আবার চেষ্টা করুন'), findsWidgets);
    });

    testWidgets('marks cached content instead of pretending it is live', (WidgetTester tester) async {
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

    testWidgets('unfollowing the last publication shows the same All-news escape',
        (WidgetTester tester) async {
      final TestHarness h = harness(
        artwork: <Article>[bnArticle],
        prefs: const AppPreferences(
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

    testWidgets('real feed metadata exposes Source Comparison without injection',
        (WidgetTester tester) async {
      final Article first = sampleArticle(
        title: 'Supreme Court suspends election order after emergency hearing',
        link: 'https://www.prothomalo.com/court-report',
        language: SourceLanguage.en,
      );
      final Article second = sampleArticle(
        sourceId: 'daily_star',
        title: 'Election order suspended by Supreme Court after emergency hearing',
        link: 'https://www.thedailystar.net/court-report',
        language: SourceLanguage.en,
      );
      final TestHarness h = harness(artwork: <Article>[first, second]);
      await tester.pumpWidget(h.wrap(const HomeScreen()));
      await h.feed.start();
      await tester.pumpAndSettle();

      final Finder comparison =
          find.text('একই ঘটনা, বিভিন্ন সংবাদমাধ্যমে').first;
      expect(comparison, findsOneWidget);
      await tester.ensureVisible(comparison);
      await tester.tap(comparison);
      await tester.pumpAndSettle();
      final bool openedRealReport = find.text(first.link).evaluate().isNotEmpty ||
          find.text(second.link).evaluate().isNotEmpty;
      expect(openedRealReport, isTrue);
    });

    testWidgets('shows breaking stories only when the publisher flagged one', (WidgetTester tester) async {
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
    testWidgets('lists publications and filters by search query', (WidgetTester tester) async {
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

    testWidgets('shows no-results state for a nonsense query', (WidgetTester tester) async {
      final TestHarness h = harness();
      await tester.pumpWidget(h.wrap(const NewspapersScreen(standalone: true)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'zzzzqqq');
      await tester.pumpAndSettle();
      expect(find.text('কিছু পাওয়া যায়নি'), findsOneWidget);
    });

    testWidgets('language filter narrows the list', (WidgetTester tester) async {
      final TestHarness h = harness();
      await tester.pumpWidget(h.wrap(const NewspapersScreen(standalone: true)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ইংরেজি').first);
      await tester.pumpAndSettle();
      expect(find.text('The Daily Star'), findsWidgets);
      expect(find.text('প্রথম আলো'), findsNothing);
    });

    testWidgets('following a publication persists in settings', (WidgetTester tester) async {
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
    testWidgets('website, follow and e-paper actions are present and enabled', (WidgetTester tester) async {
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

    testWidgets('publication without a feed offers website only', (WidgetTester tester) async {
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
    testWidgets('bookmarking from a card adds it to Saved and survives restart', (WidgetTester tester) async {
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
    testWidgets('shows the missing-date note instead of a fake timestamp', (WidgetTester tester) async {
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
    testWidgets('finds publications and headlines, and separates the groups', (WidgetTester tester) async {
      final TestHarness h = harness(artwork: <Article>[enArticle]);
      await tester.pumpWidget(h.wrap(const SearchScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'exports');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('খবর'), findsWidgets);
      expect(find.text(enArticle.title), findsOneWidget);
    });

    testWidgets('archive mode stays visibly separate and returns retained metadata',
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

    testWidgets('shows recent searches and empty state', (WidgetTester tester) async {
      final TestHarness h = harness(prefs: const AppPreferences(searchHistory: <String>['প্রথম আলো']));
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
    testWidgets('switching theme and text size updates preferences', (WidgetTester tester) async {
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

    testWidgets('language switch changes the UI strings', (WidgetTester tester) async {
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

    testWidgets('font selection applies globally and system default restores it',
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

    testWidgets('About is concise and shows only the confirmed developer identity',
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
    });

    testWidgets('About respects reduced motion and settles without a loop',
        (WidgetTester tester) async {
      final TestHarness h = harness(
        prefs: const AppPreferences(motion: MotionChoice.reduced),
      );
      await tester.pumpWidget(h.wrap(const AboutScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Md. Emon'), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('EpaperDirectoryScreen', () {
    testWidgets('lists publisher e-paper editions', (WidgetTester tester) async {
      final TestHarness h = harness();
      await tester.pumpWidget(h.wrap(const EpaperDirectoryScreen()));
      await tester.pumpAndSettle();
      expect(find.text('প্রথম আলো ই-পেপার'), findsOneWidget);
    });
  });

  group('typography', () {
    test('Bengali numerals are used for relative times in the Bengali UI', () {
      final DateTime now = DateTime.utc(2026, 10, 24, 12);
      expect(
        BengaliText.relative(now.subtract(const Duration(minutes: 5)), bengali: true, now: now),
        '৫ মিনিট আগে',
      );
    });
  });

  group('dark theme', () {
    testWidgets('home renders in dark mode', (WidgetTester tester) async {
      final TestHarness h = harness(
        artwork: <Article>[bnArticle],
        prefs: const AppPreferences(theme: AppThemeChoice.dark),
      );
      await tester.pumpWidget(h.wrap(const HomeScreen(), brightness: Brightness.dark));
      await h.feed.start();
      await tester.pumpAndSettle();
      expect(find.text(bnArticle.title), findsOneWidget);
      final ThemeData theme = Theme.of(tester.element(find.byType(HomeScreen)));
      expect(theme.brightness, Brightness.dark);
    });
  });

  group('ArticleDetailScreen redesign', () {
    testWidgets('has no native scrollbar and exposes real comparison in freed space',
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

      await h.settings.setLanguage(AppLanguage.en);
      await tester.pumpAndSettle();
      expect(find.text('Read full story'), findsOneWidget);
    });
  });

  group('AppShell navigation', () {
    testWidgets('switches tabs and stays on Home after switching', (WidgetTester tester) async {
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
      final NavigatorState navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(navigator.canPop(), isFalse);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('pushed article detail can be popped back to the list', (WidgetTester tester) async {
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
    testWidgets('renders on a small phone without overflow', (WidgetTester tester) async {
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

    testWidgets('survives an ultra-narrow 320dp viewport', (WidgetTester tester) async {
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

    testWidgets('renders on a tablet width without overflow', (WidgetTester tester) async {
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
