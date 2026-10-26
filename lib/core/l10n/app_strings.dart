import 'package:flutter/widgets.dart';

import '../../data/models/app_preferences.dart';

/// Typed, Bengali-first interface strings.
///
/// Bengali is the default because the app's primary audience reads Bengali;
/// every string has an English counterpart so the UI can switch languages
/// without a restart.
abstract class AppStrings {
  const AppStrings();

  static AppStrings of(BuildContext context) =>
      AppStringsScope.of(context) ?? const BanglaStrings();

  static AppStrings forLanguage(AppLanguage language) =>
      language == AppLanguage.en
          ? const EnglishStrings()
          : const BanglaStrings();

  String get languageCode;

  // Identity
  String get appName;
  String get appTagline;

  // Navigation
  String get navHome;
  String get navCategories;
  String get navPapers;
  String get navSaved;
  String get navSettings;

  // Common actions
  String get back;
  String get retry;
  String get refresh;
  String get cancel;
  String get clear;
  String get all;
  String get viewAll;
  String get done;
  String get copyLink;
  String get linkCopied;
  String get openWebsite;
  String get openEpaper;
  String get openFailed;
  String get share;
  String get save;
  String get savedLabel;
  String get removeSaved;

  // Home
  String get latestNews;
  String get latestNewsSubtitle;
  String get firstLaunchWelcomeTitle;
  String get firstLaunchWelcomeBody;
  String get performanceTipTitle;
  String get performanceTipBody;
  String get performanceTipAction;
  String get breakingNews;
  String get breakingShort;
  String get followedPapers;
  String get featuredPapers;
  String get browseDirectory;
  String get feedEnd;
  String get emptyFeedTitle;
  String get emptyFeedBody;
  String get cachedNotice;
  String get offlineNotice;
  String get lastUpdated;
  String get neverUpdated;
  String get sourceStatus;
  String get noPublicationDate;
  String get readOriginal;
  String get relatedCoverage;
  String get relatedCoverageLoading;
  String get relatedCoverageEmpty;
  String get topicRailTitle;

  // Directory
  String get directoryTitle;
  String get searchHint;
  String get filterCategory;
  String get filterLanguage;
  String get filterTitle;
  String get filterDivision;
  String get allCategories;
  String get allLanguages;
  String get allDivisions;
  String get publicationsCount;
  String get openMainWebsite;
  String get follow;
  String get followingLabel;
  String get sharePublication;
  String get feedWorking;
  String get feedFailing;
  String get feedUnchecked;
  String get feedNotAvailable;
  String get epaperSectionTitle;
  String get epaperNote;
  String get noEpaperListed;
  String get aboutPublication;
  String get latestHeadlines;
  String get noHeadlinesYet;
  String get fetchHeadlines;
  String get verifiedWebsite;
  String get feedState;
  String get inYourFeed;
  String get readOnWeb;
  String get allPublications;
  String get verifiedOn;
  String get regionalSources;
  String get needsReview;
  String get broadcastNotice;

  // Categories
  String get categoriesTitle;
  String get categoriesSubtitle;
  String get categoryEmpty;

  // Saved
  String get savedTitle;
  String get savedEmptyTitle;
  String get savedEmptyBody;
  String get historyTitle;
  String get historyEmptyTitle;
  String get historyEmptyBody;
  String get historyDisabled;

  // Settings
  String get settingsTitle;
  String get appearance;
  String get theme;
  String get themeSystem;
  String get themeLight;
  String get themeDark;
  String get textSize;
  String get textSizeBody;
  String get appLanguage;
  String get bengali;
  String get english;
  String get feedPreferences;
  String get defaultFeed;
  String get latestFeed;
  String get followingFeed;
  String get autoRefresh;
  String get everyMinutes;
  String get dataAndStorage;
  String get clearCache;
  String get clearCacheBody;
  String get cacheCleared;
  String get historyToggle;
  String get historyToggleBody;
  String get breakingBannerToggle;
  String get breakingBannerBody;
  String get newsShield;
  String get newsShieldBody;
  String get reduceMotion;
  String get on;
  String get off;
  String get aboutPrivacy;
  String get version;
  String get sourceHealth;
  String get sourceHealthBody;

  // About
  String get aboutTitle;
  String get aboutBody;
  String get publisherNotice;
  String get privacyTitle;
  String get privacyBody;
  String get dataOnDevice;
  String get dataOnDeviceBody;
  String get registryTitle;
  String get registryBody;
  String get sourcesListed;
  String get sourcesWithWebsite;
  String get sourcesWithFeed;
  String get sourcesWithEpaper;
  String get licence;

  // Search
  String get searchTitle;
  String get recentSearches;
  String get noResultsTitle;
  String get noResultsBody;
  String get searchInPapers;
  String get searchInArticles;
  String get searchBothHint;

  // Health / errors
  String get loadError;
  String get errorBody;
  String get statusOk;
  String get statusFailing;
  String get statusUnknown;
  String get lastChecked;
  String get lastSuccess;
  String get never;
  String get recheckAll;
  String get checking;

  // Misc
  String get bySource;
  String get readingTime;
  String get excerptNotice;
  String get sourceCountShort;
  String get articleCountShort;
  String get offlineSavedNotice;
  String get saveLinkOnlyNotice;
  String get featuredStories;

  // Reader mode and translation
  String get readerMode;
  String get readerModeHint;
  String get translationLabel;
  String get showTranslation;
  String get hideTranslation;
  String get bengaliMeaning;
  String get translating;
  String get translationUnavailable;
  String get translationNotice;
  String get readerExtractionFailed;
  String get readerExtractionFailedBody;
  String get openOriginalPage;
  String get selectedText;
  String get copyText;
  String get textCopied;
  String get selectionUnsupported;
  String get machineTranslationNotice;
  String get topStory;
  String get readingProgress;
  String get aboutAuthorTitle;
  String get aboutAuthorSubtitle;
  String get editProfile;
  String get profileName;
  String get profileRole;
  String get profileBio;
  String get profileLongBio;
  String get profileInterests;
  String get profileLinks;
  String get profileSaved;
  String get profileReset;
  String get profileResetBody;
  String get translateTitle;
  String get translateAction;
  String get translateLoading;
  String get translateUnavailable;
  String get translateNoMatch;
  String get translateOfflineNote;
  String get translateWordByWord;
  String get translateCopy;
  String get translateSelectionHint;
  String get savedKindsNote;
  String get savedLinkOnlyBadge;
  String get savedExcerptBadge;
  String get readInApp;
  String get noFollowedPapers;
  String get noFollowedBody;
  String get regionalEmpty;
}

class BanglaStrings extends AppStrings {
  const BanglaStrings();

  @override
  String get languageCode => 'bn';

  @override
  String get appName => 'আমার নিউজ';
  @override
  String get appTagline => 'আপনার পত্রিকা, আপনার মতো';

  @override
  String get navHome => 'হোম';
  @override
  String get navCategories => 'বিষয়';
  @override
  String get navPapers => 'পত্রিকা';
  @override
  String get navSaved => 'সংরক্ষিত';
  @override
  String get navSettings => 'সেটিংস';

  @override
  String get retry => 'আবার চেষ্টা করুন';
  @override
  String get refresh => 'রিফ্রেশ';
  @override
  String get back => 'ফিরে যান';
  @override
  String get cancel => 'বাতিল';
  @override
  String get clear => 'মুছুন';
  @override
  String get all => 'সব';
  @override
  String get viewAll => 'সব দেখুন';
  @override
  String get done => 'সম্পন্ন';
  @override
  String get copyLink => 'লিংক কপি';
  @override
  String get linkCopied => 'লিংক কপি হয়েছে';
  @override
  String get openWebsite => 'ওয়েবসাইট খুলুন';
  @override
  String get openEpaper => 'ই-পেপার খুলুন';
  @override
  String get openFailed => 'লিংক খোলা যায়নি';
  @override
  String get share => 'শেয়ার';
  @override
  String get save => 'সংরক্ষণ';
  @override
  String get savedLabel => 'সংরক্ষিত';
  @override
  String get removeSaved => 'সংরক্ষণ বাতিল';

  @override
  String get latestNews => 'সর্বশেষ খবর';
  @override
  String get latestNewsSubtitle => 'সব পত্রিকা থেকে একসঙ্গে';
  @override
  String get firstLaunchWelcomeTitle => 'আমার নিউজে স্বাগতম!';
  @override
  String get firstLaunchWelcomeBody =>
      'প্রথমবার আপনার জন্য খবরগুলো গুছিয়ে আনতে একটু সময় লাগতে পারে। একটু অপেক্ষা করুন—খবর লোড হয়ে গেলেই পড়া শুরু করতে পারবেন।';
  @override
  String get performanceTipTitle => 'অ্যাপ একটু ধীর মনে হচ্ছে?';
  @override
  String get performanceTipBody =>
      'আপনার ফোনে Amar News আরও মসৃণভাবে চালাতে Settings থেকে Ultra-Light Performance Mode চালু করে দেখতে পারেন। এতে ভারী ভিজ্যুয়াল ইফেক্ট ও অপ্রয়োজনীয় অ্যানিমেশন কমে যাবে, আর খবর পড়া আরও স্বচ্ছন্দ হতে পারে।';
  @override
  String get performanceTipAction => 'Settings খুলুন';
  @override
  String get breakingNews => 'ব্রেকিং নিউজ';
  @override
  String get breakingShort => 'ব্রেকিং';
  @override
  String get followedPapers => 'আপনার অনুসরণ';
  @override
  String get featuredPapers => 'নির্বাচিত পত্রিকা';
  @override
  String get browseDirectory => 'সব পত্রিকা';
  @override
  String get feedEnd => 'আপনি সর্বশেষ খবর পর্যন্ত পৌঁছে গেছেন';
  @override
  String get emptyFeedTitle => 'এখনও কোনো খবর নেই';
  @override
  String get emptyFeedBody =>
      'ফিড থেকে খবর আনা যায়নি। ইন্টারনেট সংযোগ দেখে আবার চেষ্টা করুন, অথবা পত্রিকার ওয়েবসাইট থেকে সরাসরি পড়ুন।';
  @override
  String get cachedNotice => 'সংরক্ষিত (ক্যাশ) খবর দেখানো হচ্ছে';
  @override
  String get offlineNotice => 'ইন্টারনেট নেই — ক্যাশ করা খবর দেখানো হচ্ছে';
  @override
  String get lastUpdated => 'সর্বশেষ আপডেট';
  @override
  String get neverUpdated => 'এখনও আপডেট হয়নি';
  @override
  String get sourceStatus => 'উৎসের অবস্থা';
  @override
  String get noPublicationDate => 'প্রকাশের সময় পাওয়া যায়নি';
  @override
  String get readOriginal => 'মূল প্রতিবেদন পড়ুন';
  @override
  String get relatedCoverage => 'একই ঘটনা, বিভিন্ন সংবাদমাধ্যমে';
  @override
  String get relatedCoverageLoading => 'সম্পর্কিত খবর খোঁজা হচ্ছে…';
  @override
  String get relatedCoverageEmpty => 'কোনো সম্পর্কিত খবর পাওয়া যায়নি।';
  @override
  String get topicRailTitle => 'বিভাগ';

  @override
  String get directoryTitle => 'পত্রিকা নির্দেশিকা';
  @override
  String get searchHint => 'পত্রিকা বা খবর খুঁজুন';
  @override
  String get filterCategory => 'ধরন';
  @override
  String get filterLanguage => 'ভাষা';
  @override
  String get filterTitle => 'ফিড ফিল্টার';
  @override
  String get filterDivision => 'বিভাগ';
  @override
  String get allCategories => 'সব ধরন';
  @override
  String get allLanguages => 'সব ভাষা';
  @override
  String get allDivisions => 'সব বিভাগ';
  @override
  String get publicationsCount => 'পত্রিকা';
  @override
  String get openMainWebsite => 'অফিসিয়াল ওয়েবসাইট';
  @override
  String get follow => 'অনুসরণ';
  @override
  String get followingLabel => 'অনুসরণ করছেন';
  @override
  String get sharePublication => 'পত্রিকা শেয়ার';
  @override
  String get feedWorking => 'লাইভ ফিড সচল';
  @override
  String get feedFailing => 'ফিড এখন পাওয়া যাচ্ছে না';
  @override
  String get feedUnchecked => 'ফিড এখনও যাচাই হয়নি';
  @override
  String get feedNotAvailable => 'কোনো ফিড নেই — ওয়েবসাইট ব্যবহার করুন';
  @override
  String get epaperSectionTitle => 'ই-পেপার সংস্করণ';
  @override
  String get epaperNote =>
      'ই-পেপার প্রকাশ করে পত্রিকা নিজেই। কিছু সংস্করণে সাবস্ক্রিপশন বা লগইন লাগতে পারে।';
  @override
  String get noEpaperListed => 'এই পত্রিকার কোনো ই-পেপার তালিকাভুক্ত নেই';
  @override
  String get aboutPublication => 'পত্রিকা সম্পর্কে';
  @override
  String get latestHeadlines => 'সর্বশেষ শিরোনাম';
  @override
  String get noHeadlinesYet => 'এখনও কোনো শিরোনাম সংরক্ষিত নেই';
  @override
  String get fetchHeadlines => 'শিরোনাম আনুন';
  @override
  String get verifiedWebsite => 'যাচাই করা অফিসিয়াল ঠিকানা';
  @override
  String get feedState => 'ফিডের অবস্থা';
  @override
  String get inYourFeed => 'আপনার ফিডে';
  @override
  String get readOnWeb => 'ওয়েবসাইটে পড়ুন';
  @override
  String get allPublications => 'সব প্রকাশনা';
  @override
  String get verifiedOn => 'যাচাইয়ের তারিখ';
  @override
  String get regionalSources => 'আঞ্চলিক পত্রিকা';
  @override
  String get needsReview => 'পুনরায় যাচাই প্রয়োজন';
  @override
  String get broadcastNotice =>
      'এগুলো সংবাদ সংস্থা বা সম্প্রচারমাধ্যম, পত্রিকা নয়।';

  @override
  String get categoriesTitle => 'বিষয় অনুযায়ী';
  @override
  String get categoriesSubtitle => 'আপনার আগ্রহের বিভাগ বেছে নিন';
  @override
  String get categoryEmpty => 'এই বিভাগে এখন কোনো খবর নেই';

  @override
  String get savedTitle => 'সংরক্ষিত';
  @override
  String get savedEmptyTitle => 'কোনো খবর সংরক্ষিত নেই';
  @override
  String get savedEmptyBody =>
      'খবরের পাশে বুকমার্ক আইকনে চাপ দিলে খবরটি এখানে জমা হবে।';
  @override
  String get historyTitle => 'পড়ার ইতিহাস';
  @override
  String get historyEmptyTitle => 'ইতিহাস এখন খালি';
  @override
  String get historyEmptyBody => 'যে খবরগুলো খুলবেন সেগুলো এখানে দেখা যাবে।';
  @override
  String get historyDisabled => 'পড়ার ইতিহাস সংরক্ষণ বন্ধ আছে';

  @override
  String get settingsTitle => 'সেটিংস';
  @override
  String get appearance => 'চেহারা';
  @override
  String get theme => 'থিম';
  @override
  String get themeSystem => 'সিস্টেম';
  @override
  String get themeLight => 'হালকা';
  @override
  String get themeDark => 'গাঢ়';
  @override
  String get textSize => 'লেখার আকার';
  @override
  String get textSizeBody => 'শিরোনাম ও সারাংশের আকার বদলান';
  @override
  String get appLanguage => 'অ্যাপের ভাষা';
  @override
  String get bengali => 'বাংলা';
  @override
  String get english => 'English';
  @override
  String get feedPreferences => 'ফিড পছন্দ';
  @override
  String get defaultFeed => 'ডিফল্ট ফিড';
  @override
  String get latestFeed => 'সর্বশেষ খবর';
  @override
  String get followingFeed => 'অনুসরণ করা পত্রিকা';
  @override
  String get autoRefresh => 'রিজিউমে ক্যাশ যাচাই';
  @override
  String get everyMinutes => 'মিনিট পর পর';
  @override
  String get dataAndStorage => 'ডেটা ও স্টোরেজ';
  @override
  String get clearCache => 'অস্থায়ী স্টোরেজ পরিষ্কার করুন';
  @override
  String get clearCacheBody =>
      'ক্যাশ করা শিরোনাম ও ছবি মুছে যাবে। সংরক্ষিত খবর, শব্দের অর্থ, পড়ার ইতিহাস, অনুসরণ ও সেটিংস অক্ষত থাকবে।';
  @override
  String get cacheCleared => 'ক্যাশ মুছে ফেলা হয়েছে';
  @override
  String get historyToggle => 'পড়ার ইতিহাস';
  @override
  String get historyToggleBody => 'খোলা খবরের তালিকা এই ডিভাইসে রাখা হবে';
  @override
  String get breakingBannerToggle => 'ব্রেকিং নিউজ ব্যানার';
  @override
  String get breakingBannerBody =>
      'পত্রিকা নিজে ব্রেকিং হিসেবে চিহ্নিত করলে দেখানো হবে';
  @override
  String get newsShield => 'নিউজ শিল্ড';
  @override
  String get newsShieldBody => 'পরিচিত বিজ্ঞাপন ও ট্র্যাকার সীমিত করে';
  @override
  String get reduceMotion => 'অ্যানিমেশন কমান';
  @override
  String get on => 'চালু';
  @override
  String get off => 'বন্ধ';
  @override
  String get aboutPrivacy => 'অ্যাপ ও গোপনীয়তা';
  @override
  String get version => 'সংস্করণ';
  @override
  String get sourceHealth => 'উৎসের স্বাস্থ্য';
  @override
  String get sourceHealthBody => 'প্রতিটি পত্রিকার ফিড শেষ কবে আনা হয়েছে';

  @override
  String get aboutTitle => 'অ্যাপ সম্পর্কে';
  @override
  String get aboutBody =>
      'আমার নিউজ বাছাই করা বাংলাদেশি ও আন্তর্জাতিক সংবাদমাধ্যমের সর্বশেষ শিরোনাম একসঙ্গে পড়ার একটি অ্যাপ। '
      'শিরোনাম ও সারাংশ আসে পত্রিকার নিজস্ব আরএসএস ফিড থেকে; সম্পূর্ণ প্রতিবেদন পড়তে মূল ওয়েবসাইটে যেতে হয়।';
  @override
  String get publisherNotice =>
      'এই অ্যাপের সঙ্গে কোনো পত্রিকার অফিসিয়াল সম্পর্ক নেই। সব শিরোনাম, সারাংশ ও ছবি সংশ্লিষ্ট '
      'প্রকাশকের সম্পত্তি। অ্যাপ কেবল পত্রিকার অনুমোদিত ফিডে যা আছে তাই দেখায় এবং মূল প্রতিবেদনে লিংক দেয়।';
  @override
  String get privacyTitle => 'গোপনীয়তা';
  @override
  String get privacyBody =>
      'অ্যাপ কোনো অ্যাকাউন্ট চায় না, কোনো বিশ্লেষণ (analytics) বা বিজ্ঞাপন নেই এবং ব্যক্তিগত তথ্য সংগ্রহ করে না। '
      'পত্রিকার ফিড আনতে শুধু পত্রিকার সার্ভারে সাধারণ অনুরোধ যায়।';
  @override
  String get dataOnDevice => 'ডিভাইসে সংরক্ষিত তথ্য';
  @override
  String get dataOnDeviceBody =>
      'অনুসরণ করা পত্রিকা, সংরক্ষিত খবর, পড়ার ইতিহাস ও সেটিংস শুধু আপনার ডিভাইসে সংরক্ষিত থাকে। '
      'কোনো ক্লাউড সিঙ্ক নেই।';
  @override
  String get registryTitle => 'সোর্স তালিকা';
  @override
  String get registryBody =>
      'পত্রিকার তালিকা অ্যাপের সঙ্গে আসা একটি JSON তালিকা থেকে লোড হয়। নতুন পত্রিকা যোগ করতে অ্যাপের '
      'কোড বদলাতে হয় না। ফিডের ঠিকানা থাকলেও তা সচল কিনা তা অ্যাপ নিজেই যাচাই করে দেখায়।';
  @override
  String get sourcesListed => 'তালিকাভুক্ত উৎস';
  @override
  String get sourcesWithWebsite => 'অফিসিয়াল ওয়েবসাইট আছে';
  @override
  String get sourcesWithFeed => 'ফিড ঠিকানা কনফিগার করা';
  @override
  String get sourcesWithEpaper => 'ই-পেপার আছে';
  @override
  String get licence => 'ফন্ট: Noto Sans/Serif Bengali (SIL Open Font License)';

  @override
  String get searchTitle => 'খুঁজুন';
  @override
  String get recentSearches => 'সাম্প্রতিক খোঁজ';
  @override
  String get noResultsTitle => 'কিছু পাওয়া যায়নি';
  @override
  String get noResultsBody => 'বানান বদলে দেখুন বা ইংরেজিতে লিখুন।';
  @override
  String get searchInPapers => 'পত্রিকা';
  @override
  String get searchInArticles => 'খবর';
  @override
  String get searchBothHint => 'বাংলা বা ইংরেজিতে পত্রিকা ও খবর খুঁজুন';

  @override
  String get loadError => 'লোড করা যায়নি';
  @override
  String get errorBody => 'কিছু একটা সমস্যা হয়েছে। আবার চেষ্টা করুন।';
  @override
  String get statusOk => 'সচল';
  @override
  String get statusFailing => 'বন্ধ';
  @override
  String get statusUnknown => 'অজানা';
  @override
  String get lastChecked => 'শেষ যাচাই';
  @override
  String get lastSuccess => 'শেষ সফল';
  @override
  String get never => 'কখনও নয়';
  @override
  String get recheckAll => 'সব আবার যাচাই করুন';
  @override
  String get checking => 'যাচাই চলছে…';

  @override
  String get bySource => 'সূত্র';
  @override
  String get readingTime => 'পড়ার সময়';
  @override
  String get excerptNotice =>
      'এটি পত্রিকার ফিডে প্রকাশিত সারাংশ। সম্পূর্ণ প্রতিবেদন মূল সাইটে পড়ুন।';
  @override
  String get sourceCountShort => 'উৎস';
  @override
  String get articleCountShort => 'খবর';
  @override
  String get offlineSavedNotice => 'অফলাইনে সংরক্ষিত কপি';
  @override
  String get saveLinkOnlyNotice =>
      'শুধু শিরোনাম, সারাংশ ও মূল লিংক সংরক্ষিত হবে — পুরো প্রতিবেদনের লেখা নয়। অফলাইনে থাকলে মূল পৃষ্ঠাটি খুলবে না।';
  @override
  String get readInApp => 'সম্পূর্ণ খবর পড়ুন';
  @override
  String get readerMode => 'পাঠ মোড';
  @override
  String get readerModeHint => 'বিজ্ঞাপন ও মেনু ছাড়া শুধু প্রতিবেদনটি';
  @override
  String get translationLabel => 'বাংলা অনুবাদ';
  @override
  String get showTranslation => 'অনুবাদ দেখাও';
  @override
  String get hideTranslation => 'অনুবাদ লুকাও';
  @override
  String get bengaliMeaning => 'বাংলা অর্থ';
  @override
  String get translating => 'অনুবাদ হচ্ছে…';
  @override
  String get translationUnavailable => 'এই মুহূর্তে অনুবাদ পাওয়া যাচ্ছে না';
  @override
  String get translationNotice =>
      'নিচের বাংলা যান্ত্রিক অনুবাদ, মূল ইংরেজি লেখকের লেখা নয়। অর্থ ও বাক্যগঠন ভুল হতে পারে।';
  @override
  String get readerExtractionFailed => 'পাঠ মোড চালু করা গেল না';
  @override
  String get readerExtractionFailedBody =>
      'এই পত্রিকার পাতাটি স্বয়ংক্রিয়ভাবে পড়া যায় না — সম্ভবত প্রতিবেদনটি স্ক্রিপ্টে তৈরি বা লগইন-সাপেক্ষ। মূল পাতাটি ব্রাউজারে পড়ুন।';
  @override
  String get openOriginalPage => 'মূল পাতায় ফিরে যান';
  @override
  String get selectedText => 'নির্বাচিত লেখা';
  @override
  String get copyText => 'কপি';
  @override
  String get textCopied => 'কপি হয়েছে';
  @override
  String get selectionUnsupported => 'এই পাতায় লেখা নির্বাচন করা যায় না';
  @override
  String get machineTranslationNotice =>
      'অনুবাদ যান্ত্রিক পরিষেবা থেকে আসে, তাই ইন্টারনেট প্রয়োজন। অফলাইনে শুধু শব্দের অর্থ পাওয়া যায়।';
  @override
  String get featuredStories => 'আজকের প্রধান খবর';
  @override
  String get topStory => 'প্রধান খবর';
  @override
  String get readingProgress => 'পঠন অগ্রগতি';
  @override
  String get aboutAuthorTitle => 'আমার সম্পর্কে';
  @override
  String get aboutAuthorSubtitle => 'এই অ্যাপের পেছনের মানুষ';
  @override
  String get editProfile => 'সম্পাদনা';
  @override
  String get profileName => 'নাম';
  @override
  String get profileRole => 'পরিচয়';
  @override
  String get profileBio => 'সংক্ষিপ্ত পরিচিতি';
  @override
  String get profileLongBio => 'বিস্তারিত';
  @override
  String get profileInterests => 'আগ্রহ (কমা দিয়ে আলাদা করুন)';
  @override
  String get profileLinks => 'লিংক (প্রতি লাইনে একটি)';
  @override
  String get profileSaved => 'প্রোফাইল সংরক্ষিত হয়েছে';
  @override
  String get profileReset => 'আগের অবস্থায় ফিরিয়ে নিন';
  @override
  String get profileResetBody =>
      'সংরক্ষিত পরিবর্তন মুছে প্রাথমিক প্রোফাইল ফিরে আসবে।';
  @override
  String get translateTitle => 'বাংলা অর্থ';
  @override
  String get translateAction => 'বাংলা অর্থ';
  @override
  String get translateLoading => 'শব্দ খোঁজা হচ্ছে…';
  @override
  String get translateUnavailable => 'অভিধানে এই অংশটি নেই';
  @override
  String get translateNoMatch => 'এই শব্দটি অভিধানে পাওয়া যায়নি';
  @override
  String get translateOfflineNote =>
      'অফলাইন অভিধান থেকে শব্দে-শব্দে অর্থ দেখানো হচ্ছে — এটি পূর্ণ অনুবাদ নয়।';
  @override
  String get translateWordByWord => 'শব্দে-শব্দে';
  @override
  String get translateCopy => 'অর্থ কপি করুন';
  @override
  String get translateSelectionHint =>
      'ইংরেজি শব্দ বা বাক্য নির্বাচন করে বাংলা অর্থ দেখুন';
  @override
  String get savedKindsNote =>
      'সংরক্ষিত আইটেম দুই রকম: শুধু লিংক, অথবা লিংকের সঙ্গে প্রকাশকের দেওয়া সারাংশ। '
      'সম্পূর্ণ প্রতিবেদন অফলাইনে সংরক্ষণ করা হয় না।';
  @override
  String get savedLinkOnlyBadge => 'শুধু লিংক';
  @override
  String get savedExcerptBadge => 'সারাংশসহ';
  @override
  String get noFollowedPapers => 'এখনও কোনো পত্রিকা অনুসরণ করছেন না';
  @override
  String get noFollowedBody =>
      'পত্রিকা নির্দেশিকা থেকে পছন্দের পত্রিকা অনুসরণ করুন।';
  @override
  String get regionalEmpty =>
      'এই বিভাগের কোনো আঞ্চলিক পত্রিকা এখনও তালিকাভুক্ত নয়';
}

class EnglishStrings extends AppStrings {
  const EnglishStrings();

  @override
  String get languageCode => 'en';

  @override
  String get appName => 'Amar News';
  @override
  String get appTagline => 'Your newspapers, the way you read';

  @override
  String get navHome => 'Home';
  @override
  String get navCategories => 'Topics';
  @override
  String get navPapers => 'Papers';
  @override
  String get navSaved => 'Saved';
  @override
  String get navSettings => 'Settings';

  @override
  String get retry => 'Try again';
  @override
  String get refresh => 'Refresh';
  @override
  String get back => 'Back';
  @override
  String get cancel => 'Cancel';
  @override
  String get clear => 'Clear';
  @override
  String get all => 'All';
  @override
  String get viewAll => 'View all';
  @override
  String get done => 'Done';
  @override
  String get copyLink => 'Copy link';
  @override
  String get linkCopied => 'Link copied';
  @override
  String get openWebsite => 'Open website';
  @override
  String get openEpaper => 'Open e-paper';
  @override
  String get openFailed => 'Could not open the link';
  @override
  String get share => 'Share';
  @override
  String get save => 'Save';
  @override
  String get savedLabel => 'Saved';
  @override
  String get removeSaved => 'Remove bookmark';

  @override
  String get latestNews => 'Latest news';
  @override
  String get latestNewsSubtitle => 'From every publication, together';
  @override
  String get firstLaunchWelcomeTitle => 'Welcome to Amar News!';
  @override
  String get firstLaunchWelcomeBody =>
      'It may take a little longer to get your news ready the first time. Please bear with us while everything loads. Once your news is ready, you can start reading.';
  @override
  String get performanceTipTitle => 'Want a smoother experience?';
  @override
  String get performanceTipBody =>
      'If Amar News feels a little slow on your phone, try enabling Ultra-Light Performance Mode in Settings. It reduces heavy visual effects and unnecessary animations, which may help the app feel more responsive.';
  @override
  String get performanceTipAction => 'Open Settings';
  @override
  String get breakingNews => 'Breaking news';
  @override
  String get breakingShort => 'BREAKING';
  @override
  String get followedPapers => 'You follow';
  @override
  String get featuredPapers => 'Featured publications';
  @override
  String get browseDirectory => 'All publications';
  @override
  String get feedEnd => "You've reached the end of the feed";
  @override
  String get emptyFeedTitle => 'No headlines yet';
  @override
  String get emptyFeedBody =>
      'We could not load any headlines. Check your connection and try again, or open a publication directly.';
  @override
  String get cachedNotice => 'Showing saved (cached) headlines';
  @override
  String get offlineNotice => 'No connection — showing cached headlines';
  @override
  String get lastUpdated => 'Last updated';
  @override
  String get neverUpdated => 'Not updated yet';
  @override
  String get sourceStatus => 'Source status';
  @override
  String get noPublicationDate => 'Publication time not provided';
  @override
  String get readOriginal => 'Read the original story';
  @override
  String get relatedCoverage => 'Related Coverage';
  @override
  String get relatedCoverageLoading => 'Looking for related coverage…';
  @override
  String get relatedCoverageEmpty => 'No related news found.';
  @override
  String get topicRailTitle => 'Sections';

  @override
  String get directoryTitle => 'Newspaper directory';
  @override
  String get searchHint => 'Search publications or headlines';
  @override
  String get filterCategory => 'Type';
  @override
  String get filterLanguage => 'Language';
  @override
  String get filterTitle => 'Filter feed';
  @override
  String get filterDivision => 'Division';
  @override
  String get allCategories => 'All types';
  @override
  String get allLanguages => 'All languages';
  @override
  String get allDivisions => 'All divisions';
  @override
  String get publicationsCount => 'publications';
  @override
  String get openMainWebsite => 'Official website';
  @override
  String get follow => 'Follow';
  @override
  String get followingLabel => 'Following';
  @override
  String get sharePublication => 'Share publication';
  @override
  String get feedWorking => 'Live feed working';
  @override
  String get feedFailing => 'Feed currently unavailable';
  @override
  String get feedUnchecked => 'Feed not checked yet';
  @override
  String get feedNotAvailable => 'No feed — use the website';
  @override
  String get epaperSectionTitle => 'E-paper editions';
  @override
  String get epaperNote =>
      'E-papers are hosted by the publisher. Some editions require a subscription or login.';
  @override
  String get noEpaperListed => 'No e-paper listed for this publication';
  @override
  String get aboutPublication => 'About this publication';
  @override
  String get latestHeadlines => 'Latest headlines';
  @override
  String get noHeadlinesYet => 'No headlines cached yet';
  @override
  String get fetchHeadlines => 'Fetch headlines';
  @override
  String get verifiedWebsite => 'Curated official address';
  @override
  String get feedState => 'Feed state';
  @override
  String get inYourFeed => 'In your feed';
  @override
  String get readOnWeb => 'Read on the web';
  @override
  String get allPublications => 'All publications';
  @override
  String get verifiedOn => 'Verified on';
  @override
  String get regionalSources => 'Regional newspapers';
  @override
  String get needsReview => 'Needs re-verification';
  @override
  String get broadcastNotice =>
      'These are news agencies and broadcasters, not newspapers.';

  @override
  String get categoriesTitle => 'Browse by topic';
  @override
  String get categoriesSubtitle => 'Pick the sections you care about';
  @override
  String get categoryEmpty => 'No headlines in this section yet';

  @override
  String get savedTitle => 'Saved';
  @override
  String get savedEmptyTitle => 'Nothing saved yet';
  @override
  String get savedEmptyBody =>
      'Tap the bookmark icon on any story to keep it here.';
  @override
  String get historyTitle => 'Reading history';
  @override
  String get historyEmptyTitle => 'History is empty';
  @override
  String get historyEmptyBody => 'Stories you open will appear here.';
  @override
  String get historyDisabled => 'Reading history is turned off';

  @override
  String get settingsTitle => 'Settings';
  @override
  String get appearance => 'Appearance';
  @override
  String get theme => 'Theme';
  @override
  String get themeSystem => 'System';
  @override
  String get themeLight => 'Light';
  @override
  String get themeDark => 'Dark';
  @override
  String get textSize => 'Text size';
  @override
  String get textSizeBody => 'Adjust headline and summary size';
  @override
  String get appLanguage => 'App language';
  @override
  String get bengali => 'বাংলা';
  @override
  String get english => 'English';
  @override
  String get feedPreferences => 'Feed preferences';
  @override
  String get defaultFeed => 'Default feed';
  @override
  String get latestFeed => 'Latest news';
  @override
  String get followingFeed => 'Followed publications';
  @override
  String get autoRefresh => 'Cache check on resume';
  @override
  String get everyMinutes => 'minutes';
  @override
  String get dataAndStorage => 'Data & storage';
  @override
  String get clearCache => 'Clear temporary storage';
  @override
  String get clearCacheBody =>
      'Cached headlines and images will be removed. Saved stories, vocabulary meanings, reading history, follows and settings stay.';
  @override
  String get cacheCleared => 'Cache cleared';
  @override
  String get historyToggle => 'Reading history';
  @override
  String get historyToggleBody =>
      'Keep a list of opened stories on this device';
  @override
  String get breakingBannerToggle => 'Breaking news banner';
  @override
  String get breakingBannerBody =>
      'Only shown when a publisher labels a story as breaking';
  @override
  String get newsShield => 'News Shield';
  @override
  String get newsShieldBody =>
      'Limits known ads and trackers in the in-app browser';
  @override
  String get reduceMotion => 'Reduce motion';
  @override
  String get on => 'On';
  @override
  String get off => 'Off';
  @override
  String get aboutPrivacy => 'About & privacy';
  @override
  String get version => 'Version';
  @override
  String get sourceHealth => 'Source health';
  @override
  String get sourceHealthBody => 'When each publication feed was last fetched';

  @override
  String get aboutTitle => 'About this app';
  @override
  String get aboutBody =>
      'Amar News brings selected Bangladeshi and international news sources together in one reading '
      'experience. Headlines and excerpts come from the publishers\' own RSS feeds; full stories are read '
      'on the publisher\'s website.';
  @override
  String get publisherNotice =>
      'This app has no official affiliation with any newspaper. All headlines, excerpts and images belong '
      'to their publishers. The app shows only what each publisher exposes in its feed and always links back '
      'to the original story.';
  @override
  String get privacyTitle => 'Privacy';
  @override
  String get privacyBody =>
      'No account is required. There is no analytics, no advertising and no personal data collection. '
      'Fetching a feed simply requests it from the publisher’s server.';
  @override
  String get dataOnDevice => 'Data stored on this device';
  @override
  String get dataOnDeviceBody =>
      'Followed publications, bookmarks, reading history and settings are stored only on your device. '
      'There is no cloud sync.';
  @override
  String get registryTitle => 'Source catalogue';
  @override
  String get registryBody =>
      'The publication catalogue is loaded from a JSON file shipped with the app, so adding a publication '
      'never requires changing the app code. Where a feed URL is configured, the app verifies at runtime '
      'whether it actually works and shows that state.';
  @override
  String get sourcesListed => 'Listed sources';
  @override
  String get sourcesWithWebsite => 'With official website';
  @override
  String get sourcesWithFeed => 'Feed URL configured';
  @override
  String get sourcesWithEpaper => 'With e-paper';
  @override
  String get licence =>
      'Fonts: Noto Sans/Serif Bengali (SIL Open Font License)';

  @override
  String get searchTitle => 'Search';
  @override
  String get recentSearches => 'Recent searches';
  @override
  String get noResultsTitle => 'No matches';
  @override
  String get noResultsBody => 'Try a different spelling, or search in Bengali.';
  @override
  String get searchInPapers => 'Publications';
  @override
  String get searchInArticles => 'Headlines';
  @override
  String get searchBothHint =>
      'Search publications and headlines in Bengali or English';

  @override
  String get loadError => 'Could not load';
  @override
  String get errorBody => 'Something went wrong. Please try again.';
  @override
  String get statusOk => 'Working';
  @override
  String get statusFailing => 'Failing';
  @override
  String get statusUnknown => 'Unknown';
  @override
  String get lastChecked => 'Last checked';
  @override
  String get lastSuccess => 'Last success';
  @override
  String get never => 'Never';
  @override
  String get recheckAll => 'Re-check all sources';
  @override
  String get checking => 'Checking…';

  @override
  String get bySource => 'Source';
  @override
  String get readingTime => 'Reading time';
  @override
  String get excerptNotice =>
      'This is the excerpt the publisher included in its feed. Read the full story on the original site.';
  @override
  String get sourceCountShort => 'sources';
  @override
  String get articleCountShort => 'stories';
  @override
  String get offlineSavedNotice => 'Offline saved copy';
  @override
  String get saveLinkOnlyNotice =>
      'Only the headline, excerpt and original link are saved — not the full article text. The page will not open while you are offline.';
  @override
  String get readInApp => 'Read full story';
  @override
  String get readerMode => 'Reader mode';
  @override
  String get readerModeHint => 'The article alone, without menus or adverts';
  @override
  String get translationLabel => 'Bengali translation';
  @override
  String get showTranslation => 'Show translation';
  @override
  String get hideTranslation => 'Hide translation';
  @override
  String get bengaliMeaning => 'বাংলা অর্থ';
  @override
  String get translating => 'Translating…';
  @override
  String get translationUnavailable => 'Translation is not available right now';
  @override
  String get translationNotice =>
      'The Bengali below is machine output, not the author\'s writing. Meaning and grammar can be wrong.';
  @override
  String get readerExtractionFailed => 'Reader mode could not start';
  @override
  String get readerExtractionFailedBody =>
      'This publisher\'s page cannot be read automatically — it is probably built by scripts or behind a login. Read the original page in the browser instead.';
  @override
  String get openOriginalPage => 'Return to the original page';
  @override
  String get selectedText => 'Selected text';
  @override
  String get copyText => 'Copy';
  @override
  String get textCopied => 'Copied';
  @override
  String get selectionUnsupported => 'Text cannot be selected on this page';
  @override
  String get machineTranslationNotice =>
      'Translation comes from a machine service, so it needs an internet connection. Offline, only the word glossary is available.';
  @override
  String get featuredStories => 'Top stories';
  @override
  String get topStory => 'Top story';
  @override
  String get readingProgress => 'Reading progress';
  @override
  String get aboutAuthorTitle => 'About the author';
  @override
  String get aboutAuthorSubtitle => 'The person behind this app';
  @override
  String get editProfile => 'Edit';
  @override
  String get profileName => 'Name';
  @override
  String get profileRole => 'Short line';
  @override
  String get profileBio => 'Short biography';
  @override
  String get profileLongBio => 'More detail';
  @override
  String get profileInterests => 'Interests (comma separated)';
  @override
  String get profileLinks => 'Links (one per line)';
  @override
  String get profileSaved => 'Profile saved';
  @override
  String get profileReset => 'Restore the starting profile';
  @override
  String get profileResetBody =>
      'Your edits are removed and the starting profile returns.';
  @override
  String get translateTitle => 'Bengali meaning';
  @override
  String get translateAction => 'বাংলা অর্থ';
  @override
  String get translateLoading => 'Looking up…';
  @override
  String get translateUnavailable => 'Not in the dictionary';
  @override
  String get translateNoMatch => 'No dictionary entry for this word';
  @override
  String get translateOfflineNote =>
      'Word-by-word meanings from the offline glossary — this is not a full translation.';
  @override
  String get translateWordByWord => 'Word by word';
  @override
  String get translateCopy => 'Copy meaning';
  @override
  String get translateSelectionHint =>
      'Select English text to see a Bengali meaning';
  @override
  String get savedKindsNote =>
      'Saved items are either a link alone, or a link with the excerpt the publisher provided. '
      'Full stories are never stored offline.';
  @override
  String get savedLinkOnlyBadge => 'Link only';
  @override
  String get savedExcerptBadge => 'With excerpt';
  @override
  String get noFollowedPapers => 'You are not following any publication yet';
  @override
  String get noFollowedBody =>
      'Browse the directory and follow the papers you read.';
  @override
  String get regionalEmpty =>
      'No regional publications listed for this division yet';
}

/// Provides [AppStrings] to the widget tree without a heavyweight i18n package.
class AppStringsScope extends InheritedWidget {
  const AppStringsScope(
      {super.key, required this.strings, required super.child});

  final AppStrings strings;

  static AppStrings? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppStringsScope>()?.strings;

  @override
  bool updateShouldNotify(AppStringsScope oldWidget) =>
      oldWidget.strings != strings;
}
