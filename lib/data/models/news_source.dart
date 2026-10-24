import 'dart:convert';

import '../../core/utils/bengali_text.dart';
import '../../core/utils/text_utils.dart';

/// High-level grouping used by the directory tabs and filters.
enum SourceCategory { national, english, online, business, regional, broadcast }

enum PublicationType {
  dailyNewspaper,
  onlinePortal,
  weekly,
  magazine,
  newsAgency,
  broadcaster,
  unknown,
}

enum SourceLanguage { bn, en }

enum SourceStatus { active, needsReview, inactive }

/// How confident we are that a feed URL belongs to the publisher.
enum FeedClaim { officialDocumented, candidate, none }

enum FeedFormat { rss, atom, unknown }

extension SourceCategoryX on SourceCategory {
  String get key => name;
  static SourceCategory? fromKey(String? key) {
    for (final SourceCategory value in SourceCategory.values) {
      if (value.name == key) return value;
    }
    return null;
  }
}

extension PublicationTypeX on PublicationType {
  static PublicationType fromKey(String? key) {
    for (final PublicationType value in PublicationType.values) {
      if (value.name == key) return value;
    }
    return PublicationType.unknown;
  }

  bool get isNewspaper =>
      this == PublicationType.dailyNewspaper ||
      this == PublicationType.onlinePortal ||
      this == PublicationType.weekly;
}

extension SourceLanguageX on SourceLanguage {
  static SourceLanguage fromKey(String? key) =>
      key == 'en' ? SourceLanguage.en : SourceLanguage.bn;
}

/// A single publication in the curated registry.
///
/// Everything the UI needs to render a directory entry lives here; the UI never
/// hard-codes publication names or URLs.
class NewsSource {
  const NewsSource({
    required this.id,
    required this.name,
    this.nameBn,
    this.aliases = const <String>[],
    required this.website,
    this.feedUrl,
    this.feedFormat,
    this.feedClaim = FeedClaim.none,
    required this.language,
    required this.type,
    this.categories = const <SourceCategory>[],
    this.division,
    this.district,
    this.status = SourceStatus.active,
    this.featured = false,
    this.epaperUrl,
    this.notes = '',
  });

  final String id;
  final String name;
  final String? nameBn;
  final List<String> aliases;
  final String website;
  final String? feedUrl;
  final FeedFormat? feedFormat;
  final FeedClaim feedClaim;
  final SourceLanguage language;
  final PublicationType type;
  final List<SourceCategory> categories;
  final String? division;
  final String? district;
  final SourceStatus status;
  final bool featured;
  final String? epaperUrl;
  final String notes;

  bool get hasFeed => (feedUrl ?? '').isNotEmpty;
  bool get hasEpaper => (epaperUrl ?? '').isNotEmpty;
  bool get isActive => status == SourceStatus.active;
  bool get isRegional => categories.contains(SourceCategory.regional);
  bool get isBusiness => categories.contains(SourceCategory.business);

  /// "প্রথম আলো" in a Bengali-first UI, "Prothom Alo" otherwise.
  String localizedName({required bool bengali}) {
    if (bengali) {
      final String? bn = TextUtils.nullIfBlank(nameBn);
      if (bn != null) return bn;
    }
    return name;
  }

  /// The other-language name, used as a subtitle in the directory.
  String? secondaryName({required bool bengali}) {
    final String? other = bengali ? TextUtils.nullIfBlank(name) : TextUtils.nullIfBlank(nameBn);
    if (other == null) return null;
    return other == localizedName(bengali: bengali) ? null : other;
  }

  /// Two-character monogram used when no permitted logo asset exists.
  String get monogram {
    final String base = TextUtils.nullIfBlank(nameBn) ?? name;
    final List<String> words = base
        .split(RegExp(r'\s+'))
        .where((String w) => w.isNotEmpty && w != 'The' && w != 'Daily' && w != 'দৈনিক')
        .toList();
    if (words.isEmpty) return base.isEmpty ? '?' : base.substring(0, 1);
    if (words.length == 1) {
      final String word = words.first;
      return word.length >= 2 ? word.substring(0, 2) : word;
    }
    return '${words[0].substring(0, 1)}${words[1].substring(0, 1)}';
  }

  /// Every normalized string that should match this publication in search.
  List<String> get searchKeys {
    final List<String> raw = <String>[
      name,
      if (nameBn != null) nameBn!,
      ...aliases,
    ];
    final Set<String> keys = <String>{};
    for (final String value in raw) {
      final String normalized = TextUtils.searchNormalize(value);
      if (normalized.isNotEmpty) {
        keys.add(normalized);
        keys.add(normalized.replaceAll(' ', ''));
      }
      if (BengaliText.containsBengali(value)) {
        final String latin = TextUtils.searchNormalize(BengaliText.transliterateToLatin(value));
        if (latin.isNotEmpty) keys.add(latin);
      }
    }
    return keys.toList();
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'name': name,
        'nameBn': nameBn,
        'aliases': aliases,
        'website': website,
        'feedUrl': feedUrl,
        'feedFormat': feedFormat?.name,
        'feedClaim': feedClaim.name,
        'language': language.name,
        'type': type.name,
        'categories': categories.map((SourceCategory c) => c.name).toList(),
        'division': division,
        'district': district,
        'status': status.name,
        'featured': featured,
        'epaperUrl': epaperUrl,
        'notes': notes,
      };

  static NewsSource fromMap(Map<String, dynamic> map) {
    final String? formatKey = map['feedFormat'] as String?;
    return NewsSource(
      id: map['id'] as String,
      name: map['name'] as String,
      nameBn: map['nameBn'] as String?,
      aliases: (map['aliases'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic e) => '$e')
          .toList(),
      website: map['website'] as String,
      feedUrl: TextUtils.nullIfBlank(map['feedUrl'] as String?),
      feedFormat: formatKey == null
          ? null
          : FeedFormat.values.firstWhere(
              (FeedFormat f) => f.name == formatKey,
              orElse: () => FeedFormat.unknown,
            ),
      feedClaim: FeedClaim.values.firstWhere(
        (FeedClaim c) => c.name == map['feedClaim'],
        orElse: () => FeedClaim.none,
      ),
      language: SourceLanguageX.fromKey(map['language'] as String?),
      type: PublicationTypeX.fromKey(map['type'] as String?),
      categories: (map['categories'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic e) => SourceCategoryX.fromKey('$e'))
          .whereType<SourceCategory>()
          .toList(),
      division: TextUtils.nullIfBlank(map['division'] as String?),
      district: TextUtils.nullIfBlank(map['district'] as String?),
      status: SourceStatus.values.firstWhere(
        (SourceStatus s) => s.name == map['status'],
        orElse: () => SourceStatus.active,
      ),
      featured: map['featured'] == true,
      epaperUrl: TextUtils.nullIfBlank(map['epaperUrl'] as String?),
      notes: (map['notes'] as String?) ?? '',
    );
  }
}

/// A publisher-hosted electronic edition.
class EpaperEdition {
  const EpaperEdition({
    required this.id,
    required this.sourceId,
    required this.name,
    this.nameBn,
    required this.url,
    this.access = 'unknown',
    this.notes = '',
  });

  final String id;
  final String sourceId;
  final String name;
  final String? nameBn;
  final String url;

  /// Publisher-stated access model. "unknown" means the app makes no claim.
  final String access;
  final String notes;

  String localizedName({required bool bengali}) {
    if (bengali) {
      final String? bn = TextUtils.nullIfBlank(nameBn);
      if (bn != null) return bn;
    }
    return name;
  }

  static EpaperEdition fromMap(Map<String, dynamic> map) => EpaperEdition(
        id: map['id'] as String,
        sourceId: map['sourceId'] as String,
        name: map['name'] as String,
        nameBn: map['nameBn'] as String?,
        url: map['url'] as String,
        access: (map['access'] as String?) ?? 'unknown',
        notes: (map['notes'] as String?) ?? '',
      );
}

/// Immutable, validated view over `assets/data/sources.json`.
class SourceRegistry {
  SourceRegistry({
    required this.sources,
    required this.epapers,
    required this.updatedAt,
    required this.about,
  })  : _byId = <String, NewsSource>{
          for (final NewsSource source in sources) source.id: source,
        },
        _epapersBySource = <String, List<EpaperEdition>>{};

  final List<NewsSource> sources;
  final List<EpaperEdition> epapers;
  final DateTime updatedAt;
  final String about;
  final Map<String, NewsSource> _byId;
  final Map<String, List<EpaperEdition>> _epapersBySource;

  NewsSource? byId(String? id) => id == null ? null : _byId[id];

  NewsSource requireById(String id) =>
      _byId[id] ??
      (throw StateError('Unknown source id "$id" referenced by the app'));

  String nameOf(String sourceId, {required bool bengali}) =>
      byId(sourceId)?.localizedName(bengali: bengali) ?? sourceId;

  List<NewsSource> byCategory(SourceCategory category) =>
      sources.where((NewsSource s) => s.categories.contains(category)).toList()
        ..sort((NewsSource a, NewsSource b) =>
            a.localizedName(bengali: true).compareTo(b.localizedName(bengali: true)));

  List<NewsSource> get featured =>
      sources.where((NewsSource s) => s.featured && s.isActive).toList();

  List<NewsSource> get withFeeds =>
      sources.where((NewsSource s) => s.hasFeed && s.isActive).toList();

  List<NewsSource> get epaperSources =>
      sources.where((NewsSource s) => s.hasEpaper).toList();

  List<EpaperEdition> epapersFor(String sourceId) {
    final List<EpaperEdition>? cached = _epapersBySource[sourceId];
    if (cached != null) return cached;
    final List<EpaperEdition> result =
        epapers.where((EpaperEdition e) => e.sourceId == sourceId).toList();
    _epapersBySource[sourceId] = result;
    return result;
  }

  /// Divisions that actually have regional publications in the registry.
  List<String> get divisionsWithSources {
    final Set<String> divisions = <String>{
      for (final NewsSource s in sources)
        if (s.division != null && s.isRegional) s.division!,
    };
    return divisions.toList()..sort();
  }

  List<String> districtsIn(String division) {
    final Set<String> districts = <String>{
      for (final NewsSource s in sources)
        if (s.division == division && s.district != null) s.district!,
    };
    return districts.toList()..sort();
  }

  Map<SourceCategory, int> get countsByCategory => <SourceCategory, int>{
        for (final SourceCategory category in SourceCategory.values)
          category: byCategory(category).length,
      };

  List<NewsSource> byLanguage(SourceLanguage language) =>
      sources.where((NewsSource s) => s.language == language).toList();

  List<NewsSource> filter({
    SourceCategory? category,
    SourceLanguage? language,
    String? division,
    bool onlyWithFeeds = false,
  }) {
    return sources.where((NewsSource s) {
      if (category != null && !s.categories.contains(category)) return false;
      if (language != null && s.language != language) return false;
      if (division != null && s.division != division) return false;
      if (onlyWithFeeds && !s.hasFeed) return false;
      return true;
    }).toList();
  }

  /// Ranked publication search that understands Bengali and English names.
  List<NewsSource> search(String rawQuery, {int limit = 40}) {
    final String query = TextUtils.searchNormalize(rawQuery);
    if (query.isEmpty) return const <NewsSource>[];
    final String compact = query.replaceAll(' ', '');
    final bool queryIsBengali = BengaliText.containsBengali(rawQuery);

    final List<_ScoredSource> scored = <_ScoredSource>[];
    for (final NewsSource source in sources) {
      var best = 0;
      for (final String key in source.searchKeys) {
        final String compactKey = key.replaceAll(' ', '');
        if (key == query) {
          best = best < 100 ? 100 : best;
        } else if (compactKey == compact) {
          best = best < 95 ? 95 : best;
        } else if (key.startsWith(query)) {
          best = best < 80 ? 80 : best;
        } else if (key.contains(query)) {
          best = best < 70 ? 70 : best;
        } else {
          final int distance = TextUtils.editDistance(compact, compactKey, cap: 3);
          if (distance <= 2) {
            final int score = 60 - distance * 10;
            if (score > best) best = score;
          }
        }
      }
      // Bengali queries rank Bengali-named publications first, and vice versa.
      if (best > 0) {
        if (queryIsBengali && (source.nameBn ?? '').isNotEmpty) best += 2;
        if (!queryIsBengali && source.language == SourceLanguage.en) best += 2;
        if (source.status == SourceStatus.active) best += 1;
        scored.add(_ScoredSource(source, best));
      }
    }
    scored.sort((_ScoredSource a, _ScoredSource b) {
      final int byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.source.name.compareTo(b.source.name);
    });
    return scored.take(limit).map((_ScoredSource s) => s.source).toList();
  }

  static SourceRegistry fromJsonMap(Map<String, dynamic> map) {
    final List<NewsSource> sources = (map['sources'] as List<dynamic>)
        .map((dynamic e) => NewsSource.fromMap(e as Map<String, dynamic>))
        .toList();
    final List<EpaperEdition> epapers = (map['epapers'] as List<dynamic>? ?? const <dynamic>[])
        .map((dynamic e) => EpaperEdition.fromMap(e as Map<String, dynamic>))
        .toList();
    final String updated = (map['updatedAt'] as String?) ?? '';
    return SourceRegistry(
      sources: List<NewsSource>.unmodifiable(sources),
      epapers: List<EpaperEdition>.unmodifiable(epapers),
      updatedAt: DateTime.tryParse(updated) ?? DateTime.utc(2026, 10, 24),
      about: (map['about'] as String?) ?? '',
    );
  }

  static SourceRegistry fromJsonString(String raw) {
    final dynamic decoded = json.decode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Source registry must be a JSON object');
    }
    return fromJsonMap(decoded);
  }
}

class _ScoredSource {
  _ScoredSource(this.source, this.score);
  final NewsSource source;
  final int score;
}
