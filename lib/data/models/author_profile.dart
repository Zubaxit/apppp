import 'dart:convert';

/// The "about the author" profile shown in the About screen.
///
/// Everything here is editable at runtime and stored only on the device. The
/// starting values contain nothing that was not supplied by the app's author,
/// and nothing that cannot be supported: no awards, books, titles, degrees,
/// employers, dates or family details. The master's study is mentioned as
/// unconfirmed rather than stated as a qualification.
class AuthorProfile {
  const AuthorProfile({
    this.name = 'মোঃ ইমন',
    this.nameEn = 'Md Emon',
    this.role = 'সাহিত্য ও কবিতা',
    this.bio = defaultBio,
    this.longBio = defaultLongBio,
    this.interests = defaultInterests,
    this.links = const <String>[],
  });

  final String name;
  final String nameEn;
  final String role;
  final String bio;
  final String longBio;
  final List<String> interests;

  /// Optional public links, e.g. a personal site. Empty by default: the app
  /// does not invent an address for anyone.
  final List<String> links;

  static const String defaultBio =
      'বাংলা সাহিত্য, কবিতা ও প্রবন্ধ নিয়ে আগ্রহী পাঠক; সরকারি ব্রজলাল কলেজ '
      '(বি. এল. কলেজ), খুলনায় বাংলা অধ্যয়ন করেছেন।';

  static const String defaultLongBio =
      'বাংলা সাহিত্যের চিরায়ত ও আধুনিক ধারা, কবিতা, সমালোচনা এবং দর্শন নিয়ে '
      'আগ্রহ। কবিতা, প্রবন্ধ ও গবেষণামূলক লেখা লিখেন; শামসুর রাহমানের কবিতা '
      'নিয়ে আলাদা আগ্রহ রয়েছে। এই অ্যাপের মতো ব্যবহারিক ডিজিটাল সরঞ্জাম তৈরি '
      'করতেও আগ্রহী।\n\n'
      'উচ্চশিক্ষার বর্তমান অবস্থা (স্নাতকোত্তর পর্যায়) এখনো নিশ্চিত নয়, তাই এখানে '
      'কোনো ডিগ্রি বা প্রতিষ্ঠানের অফিসিয়াল পরিচয় দাবি করা হয়নি।';

  static const List<String> defaultInterests = <String>[
    'বাংলা সাহিত্য',
    'কবিতা',
    'সমালোচনা',
    'দর্শন',
    'চিরায়ত সাহিত্য',
    'শামসুর রাহমানের কবিতা',
    'ডিজিটাল সরঞ্জাম',
  ];

  AuthorProfile copyWith({
    String? name,
    String? nameEn,
    String? role,
    String? bio,
    String? longBio,
    List<String>? interests,
    List<String>? links,
  }) {
    return AuthorProfile(
      name: name ?? this.name,
      nameEn: nameEn ?? this.nameEn,
      role: role ?? this.role,
      bio: bio ?? this.bio,
      longBio: longBio ?? this.longBio,
      interests: interests ?? this.interests,
      links: links ?? this.links,
    );
  }

  /// A monogram for the avatar: the first character of the Bengali name.
  String get initial {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) return 'অ';
    return trimmed.substring(0, 1);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'nameEn': nameEn,
        'role': role,
        'bio': bio,
        'longBio': longBio,
        'interests': interests,
        'links': links,
        'version': 1,
      };

  static AuthorProfile fromJson(Map<String, dynamic> json) {
    List<String> strings(Object? value) => value is List
        ? value
            .whereType<String>()
            .map((String e) => e.trim())
            .where((String e) => e.isNotEmpty)
            .toList()
        : const <String>[];
    String text(Object? value, String fallback) {
      final String trimmed = value is String ? value.trim() : '';
      return trimmed.isEmpty ? fallback : trimmed;
    }

    return AuthorProfile(
      name: text(json['name'], const AuthorProfile().name),
      nameEn: text(json['nameEn'], const AuthorProfile().nameEn),
      role: text(json['role'], const AuthorProfile().role),
      bio: text(json['bio'], defaultBio),
      longBio: text(json['longBio'], defaultLongBio),
      interests: strings(json['interests']),
      links: strings(json['links']),
    );
  }

  String encode() => jsonEncode(toJson());

  static AuthorProfile decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const AuthorProfile();
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return fromJson(decoded);
    } catch (_) {
      // A corrupted or older value must never block the About screen.
    }
    return const AuthorProfile();
  }

  /// Links are only accepted when they are plain web addresses; anything else
  /// would be a broken promise in the UI.
  static bool isSupportedLink(String value) {
    final String lower = value.trim().toLowerCase();
    if (!(lower.startsWith('https://') || lower.startsWith('http://'))) {
      return false;
    }
    return Uri.tryParse(value.trim())?.host.isNotEmpty ?? false;
  }
}
