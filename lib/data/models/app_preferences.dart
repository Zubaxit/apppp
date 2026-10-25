import 'dart:convert';

import 'article.dart';
import 'news_source.dart';

enum AppLanguage { bn, en }

enum AppThemeChoice { system, light, dark }

enum AppFontChoice { system, notoSans, notoSerif }

extension AppFontChoiceX on AppFontChoice {
  String? get family => switch (this) {
        AppFontChoice.system => null,
        AppFontChoice.notoSans => 'NotoSansBengali',
        AppFontChoice.notoSerif => 'NotoSerifBengali',
      };
}

enum MotionChoice { system, reduced }

enum DefaultFeed { latest, following }

/// Everything the user can personalize. Stored locally only; nothing is
/// uploaded anywhere.
class AppPreferences {
  const AppPreferences({
    this.language = AppLanguage.en,
    this.theme = AppThemeChoice.system,
    this.font = AppFontChoice.system,
    this.motion = MotionChoice.system,
    this.textScale = 1.0,
    this.defaultFeed = DefaultFeed.latest,
    this.followedSourceIds = const <String>{},
    this.preferredTopics = const <ArticleTopic>{},
    this.refreshMinutes = 30,
    this.historyEnabled = true,
    this.breakingBannerEnabled = true,
    this.newsShieldEnabled = true,
    this.newsShieldExceptions = const <String>{},
    this.searchHistory = const <String>[],
    this.onboardingComplete = false,
  });

  final AppLanguage language;
  final AppThemeChoice theme;
  final AppFontChoice font;
  final MotionChoice motion;

  /// Reading text multiplier applied to article bodies and headlines.
  final double textScale;
  final DefaultFeed defaultFeed;
  final Set<String> followedSourceIds;
  final Set<ArticleTopic> preferredTopics;

  /// Minimum gap between automatic refreshes, in minutes.
  final int refreshMinutes;
  final bool historyEnabled;
  final bool breakingBannerEnabled;

  /// Global News Shield policy and user-owned per-site allow-list.
  final bool newsShieldEnabled;
  final Set<String> newsShieldExceptions;
  final List<String> searchHistory;
  final bool onboardingComplete;

  bool get isBengali => language == AppLanguage.bn;

  AppPreferences copyWith({
    AppLanguage? language,
    AppThemeChoice? theme,
    AppFontChoice? font,
    MotionChoice? motion,
    double? textScale,
    DefaultFeed? defaultFeed,
    Set<String>? followedSourceIds,
    Set<ArticleTopic>? preferredTopics,
    int? refreshMinutes,
    bool? historyEnabled,
    bool? breakingBannerEnabled,
    bool? newsShieldEnabled,
    Set<String>? newsShieldExceptions,
    List<String>? searchHistory,
    bool? onboardingComplete,
  }) {
    return AppPreferences(
      language: language ?? this.language,
      theme: theme ?? this.theme,
      font: font ?? this.font,
      motion: motion ?? this.motion,
      textScale: textScale ?? this.textScale,
      defaultFeed: defaultFeed ?? this.defaultFeed,
      followedSourceIds: followedSourceIds ?? this.followedSourceIds,
      preferredTopics: preferredTopics ?? this.preferredTopics,
      refreshMinutes: refreshMinutes ?? this.refreshMinutes,
      historyEnabled: historyEnabled ?? this.historyEnabled,
      breakingBannerEnabled: breakingBannerEnabled ?? this.breakingBannerEnabled,
      newsShieldEnabled: newsShieldEnabled ?? this.newsShieldEnabled,
      newsShieldExceptions: newsShieldExceptions ?? this.newsShieldExceptions,
      searchHistory: searchHistory ?? this.searchHistory,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    );
  }

  AppPreferences toggleFollow(String sourceId) {
    final Set<String> next = Set<String>.of(followedSourceIds);
    if (!next.remove(sourceId)) next.add(sourceId);
    return copyWith(followedSourceIds: next);
  }

  AppPreferences toggleTopic(ArticleTopic topic) {
    final Set<ArticleTopic> next = Set<ArticleTopic>.of(preferredTopics);
    if (!next.remove(topic)) next.add(topic);
    return copyWith(preferredTopics: next);
  }

  AppPreferences addSearch(String query) {
    final String trimmed = query.trim();
    if (trimmed.isEmpty) return this;
    final List<String> next = <String>[
      trimmed,
      ...searchHistory.where((String item) => item.toLowerCase() != trimmed.toLowerCase()),
    ].take(8).toList();
    return copyWith(searchHistory: next);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'language': language.name,
        'theme': theme.name,
        'font': font.name,
        'motion': motion.name,
        'textScale': textScale,
        'defaultFeed': defaultFeed.name,
        'followedSourceIds': followedSourceIds.toList(),
        'preferredTopics': preferredTopics.map((ArticleTopic t) => t.name).toList(),
        'refreshMinutes': refreshMinutes,
        'historyEnabled': historyEnabled,
        'breakingBannerEnabled': breakingBannerEnabled,
        'newsShieldEnabled': newsShieldEnabled,
        'newsShieldExceptions': newsShieldExceptions.toList(),
        'searchHistory': searchHistory,
        'onboardingComplete': onboardingComplete,
      };

  String encode() => json.encode(toJson());

  static AppPreferences fromJsonMap(Map<String, dynamic> map) {
    T enumOr<T extends Enum>(List<T> values, Object? key, T fallback) {
      for (final T value in values) {
        if (value.name == key) return value;
      }
      return fallback;
    }

    return AppPreferences(
      language: enumOr(AppLanguage.values, map['language'], AppLanguage.en),
      theme: enumOr(AppThemeChoice.values, map['theme'], AppThemeChoice.system),
      font: enumOr(AppFontChoice.values, map['font'], AppFontChoice.system),
      motion: enumOr(MotionChoice.values, map['motion'], MotionChoice.system),
      textScale: (map['textScale'] as num?)?.toDouble() ?? 1.0,
      defaultFeed: enumOr(DefaultFeed.values, map['defaultFeed'], DefaultFeed.latest),
      followedSourceIds: <String>{
        for (final dynamic id in (map['followedSourceIds'] as List<dynamic>? ?? const <dynamic>[]))
          '$id',
      },
      preferredTopics: <ArticleTopic>{
        for (final dynamic topic in (map['preferredTopics'] as List<dynamic>? ?? const <dynamic>[]))
          ArticleTopicX.fromKey('$topic'),
      }..remove(ArticleTopic.other),
      refreshMinutes: (map['refreshMinutes'] as num?)?.toInt() ?? 30,
      historyEnabled: map['historyEnabled'] != false,
      breakingBannerEnabled: map['breakingBannerEnabled'] != false,
      newsShieldEnabled: map['newsShieldEnabled'] != false,
      newsShieldExceptions: <String>{
        for (final dynamic host in
            (map['newsShieldExceptions'] as List<dynamic>? ?? const <dynamic>[]))
          '$host',
      },
      searchHistory: <String>[
        for (final dynamic item in (map['searchHistory'] as List<dynamic>? ?? const <dynamic>[]))
          '$item',
      ],
      onboardingComplete: map['onboardingComplete'] == true,
    );
  }

  static AppPreferences decode(String? raw) {
    if (raw == null || raw.isEmpty) return const AppPreferences();
    try {
      final dynamic decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) return fromJsonMap(decoded);
    } catch (_) {
      // fall through to defaults
    }
    return const AppPreferences();
  }

  static const List<double> textScaleSteps = <double>[0.95, 1.0, 1.1, 1.25, 1.4];

  static const List<int> refreshOptions = <int>[15, 30, 60, 120, 240];

  /// Allowed language filters for source browsing.
  static const List<SourceLanguage> languages = SourceLanguage.values;
}
