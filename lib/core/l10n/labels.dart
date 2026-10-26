import 'package:flutter/material.dart';

import '../../data/models/article.dart';
import '../../data/models/news_source.dart';
import '../../data/models/source_health.dart';

/// Human labels for enums the registry and models expose.
class Labels {
  const Labels._();

  /// Divisions are stored in the registry by their official English names;
  /// the Bengali UI shows the Bengali names for the same eight divisions.
  static String division(String name, {required bool bengali}) {
    if (!bengali) return name;
    const Map<String, String> names = <String, String>{
      'Dhaka': 'ঢাকা',
      'Chattogram': 'চট্টগ্রাম',
      'Rajshahi': 'রাজশাহী',
      'Khulna': 'খুলনা',
      'Barishal': 'বরিশাল',
      'Sylhet': 'সিলেট',
      'Rangpur': 'রংপুর',
      'Mymensingh': 'ময়মনসিংহ',
    };
    return names[name] ?? name;
  }

  static String topic(ArticleTopic topic, {required bool bengali}) {
    if (!bengali) {
      switch (topic) {
        case ArticleTopic.bangladesh:
          return 'Bangladesh';
        case ArticleTopic.editorial:
          return 'Editorial';
        case ArticleTopic.politics:
          return 'Politics';
        case ArticleTopic.economy:
          return 'Economy';
        case ArticleTopic.international:
          return 'International';
        case ArticleTopic.education:
          return 'Education';
        case ArticleTopic.sports:
          return 'Sports';
        case ArticleTopic.entertainment:
          return 'Entertainment';
        case ArticleTopic.technology:
          return 'Technology';
        case ArticleTopic.health:
          return 'Health';
        case ArticleTopic.lifestyle:
          return 'Lifestyle';
        case ArticleTopic.jobs:
          return 'Jobs & Careers';
        case ArticleTopic.learning:
          return 'Learning';
        case ArticleTopic.government:
          return 'Government Notices';
        case ArticleTopic.scholarships:
          return 'Scholarships';
        case ArticleTopic.other:
          return 'More';
      }
    }
    switch (topic) {
      case ArticleTopic.bangladesh:
        return 'বাংলাদেশ';
      case ArticleTopic.editorial:
        return 'সম্পাদকীয়';
      case ArticleTopic.politics:
        return 'রাজনীতি';
      case ArticleTopic.economy:
        return 'অর্থনীতি';
      case ArticleTopic.international:
        return 'আন্তর্জাতিক';
      case ArticleTopic.education:
        return 'শিক্ষা';
      case ArticleTopic.sports:
        return 'খেলা';
      case ArticleTopic.entertainment:
        return 'বিনোদন';
      case ArticleTopic.technology:
        return 'প্রযুক্তি';
      case ArticleTopic.health:
        return 'স্বাস্থ্য';
      case ArticleTopic.lifestyle:
        return 'জীবনযাপন';
      case ArticleTopic.jobs:
        return 'চাকরি ও নিয়োগ';
      case ArticleTopic.learning:
        return 'শিক্ষামূলক ও জ্ঞান';
      case ArticleTopic.government:
        return 'সরকারি বিজ্ঞপ্তি';
      case ArticleTopic.scholarships:
        return 'বৃত্তি ও ফেলোশিপ';
      case ArticleTopic.other:
        return 'অন্যান্য';
    }
  }

  static IconData topicIcon(ArticleTopic topic) {
    switch (topic) {
      case ArticleTopic.bangladesh:
        return Icons.location_city_outlined;
      case ArticleTopic.editorial:
        return Icons.edit_note_rounded;
      case ArticleTopic.politics:
        return Icons.account_balance_outlined;
      case ArticleTopic.economy:
        return Icons.trending_up_rounded;
      case ArticleTopic.international:
        return Icons.public_rounded;
      case ArticleTopic.education:
        return Icons.school_outlined;
      case ArticleTopic.sports:
        return Icons.sports_cricket_outlined;
      case ArticleTopic.entertainment:
        return Icons.movie_outlined;
      case ArticleTopic.technology:
        return Icons.memory_rounded;
      case ArticleTopic.health:
        return Icons.health_and_safety_outlined;
      case ArticleTopic.lifestyle:
        return Icons.spa_outlined;
      case ArticleTopic.jobs:
        return Icons.work_outline_rounded;
      case ArticleTopic.learning:
        return Icons.lightbulb_outline_rounded;
      case ArticleTopic.government:
        return Icons.campaign_outlined;
      case ArticleTopic.scholarships:
        return Icons.workspace_premium_outlined;
      case ArticleTopic.other:
        return Icons.article_outlined;
    }
  }

  /// Short labels for chips, cards and rails — the same topics, fewer words.
  static String topicShort(ArticleTopic topic, {required bool bengali}) {
    if (!bengali) {
      return switch (topic) {
        ArticleTopic.bangladesh => 'Bangladesh',
        ArticleTopic.editorial => 'Editorial',
        ArticleTopic.politics => 'Politics',
        ArticleTopic.economy => 'Economy',
        ArticleTopic.international => 'World',
        ArticleTopic.education => 'Education',
        ArticleTopic.sports => 'Sport',
        ArticleTopic.entertainment => 'Culture',
        ArticleTopic.technology => 'Technology',
        ArticleTopic.health => 'Health',
        ArticleTopic.lifestyle => 'Lifestyle',
        ArticleTopic.jobs => 'Jobs',
        ArticleTopic.learning => 'Knowledge',
        ArticleTopic.government => 'Notices',
        ArticleTopic.scholarships => 'Scholarships',
        ArticleTopic.other => 'More',
      };
    }
    return switch (topic) {
      ArticleTopic.bangladesh => 'বাংলাদেশ',
      ArticleTopic.editorial => 'সম্পাদকীয়',
      ArticleTopic.politics => 'রাজনীতি',
      ArticleTopic.economy => 'অর্থনীতি',
      ArticleTopic.international => 'বিশ্ব',
      ArticleTopic.education => 'শিক্ষা',
      ArticleTopic.sports => 'খেলা',
      ArticleTopic.entertainment => 'সংস্কৃতি',
      ArticleTopic.technology => 'প্রযুক্তি',
      ArticleTopic.health => 'স্বাস্থ্য',
      ArticleTopic.lifestyle => 'জীবনযাপন',
      ArticleTopic.jobs => 'চাকরি',
      ArticleTopic.learning => 'জ্ঞান',
      ArticleTopic.government => 'বিজ্ঞপ্তি',
      ArticleTopic.scholarships => 'বৃত্তি',
      ArticleTopic.other => 'অন্যান্য',
    };
  }

  static String category(SourceCategory category, {required bool bengali}) {
    if (!bengali) {
      switch (category) {
        case SourceCategory.national:
          return 'National';
        case SourceCategory.english:
          return 'English';
        case SourceCategory.online:
          return 'Online';
        case SourceCategory.business:
          return 'Business';
        case SourceCategory.regional:
          return 'Regional';
        case SourceCategory.broadcast:
          return 'Agencies & broadcasters';
      }
    }
    switch (category) {
      case SourceCategory.national:
        return 'জাতীয়';
      case SourceCategory.english:
        return 'ইংরেজি';
      case SourceCategory.online:
        return 'অনলাইন';
      case SourceCategory.business:
        return 'অর্থনীতি';
      case SourceCategory.regional:
        return 'আঞ্চলিক';
      case SourceCategory.broadcast:
        return 'সংস্থা ও সম্প্রচার';
    }
  }

  static IconData categoryIcon(SourceCategory category) {
    switch (category) {
      case SourceCategory.national:
        return Icons.newspaper_rounded;
      case SourceCategory.english:
        return Icons.translate_rounded;
      case SourceCategory.online:
        return Icons.language_rounded;
      case SourceCategory.business:
        return Icons.show_chart_rounded;
      case SourceCategory.regional:
        return Icons.map_outlined;
      case SourceCategory.broadcast:
        return Icons.podcasts_rounded;
    }
  }

  static String type(PublicationType type, {required bool bengali}) {
    if (!bengali) {
      switch (type) {
        case PublicationType.dailyNewspaper:
          return 'Daily newspaper';
        case PublicationType.onlinePortal:
          return 'Online portal';
        case PublicationType.weekly:
          return 'Weekly';
        case PublicationType.magazine:
          return 'Magazine';
        case PublicationType.newsAgency:
          return 'News agency';
        case PublicationType.broadcaster:
          return 'Broadcaster';
        case PublicationType.unknown:
          return 'Publication';
      }
    }
    switch (type) {
      case PublicationType.dailyNewspaper:
        return 'দৈনিক পত্রিকা';
      case PublicationType.onlinePortal:
        return 'অনলাইন পোর্টাল';
      case PublicationType.weekly:
        return 'সাপ্তাহিক';
      case PublicationType.magazine:
        return 'ম্যাগাজিন';
      case PublicationType.newsAgency:
        return 'সংবাদ সংস্থা';
      case PublicationType.broadcaster:
        return 'সম্প্রচারমাধ্যম';
      case PublicationType.unknown:
        return 'প্রকাশনা';
    }
  }

  static String language(SourceLanguage language, {required bool bengali}) {
    if (language == SourceLanguage.bn) return bengali ? 'বাংলা' : 'Bengali';
    return bengali ? 'ইংরেজি' : 'English';
  }

  static String sourceStatus(SourceStatus status, {required bool bengali}) {
    switch (status) {
      case SourceStatus.active:
        return bengali ? 'সক্রিয়' : 'Active';
      case SourceStatus.needsReview:
        return bengali ? 'পুনরায় যাচাই প্রয়োজন' : 'Needs review';
      case SourceStatus.inactive:
        return bengali ? 'নিষ্ক্রিয়' : 'Inactive';
    }
  }

  /// Registry-level statement about how the feed URL is known.
  static String feedClaim(FeedClaim claim, {required bool bengali}) {
    switch (claim) {
      case FeedClaim.officialDocumented:
        return bengali
            ? 'প্রকাশকের নিজস্ব ডকুমেন্টেড ফিড'
            : 'Documented by the publisher';
      case FeedClaim.verifiedWorking:
        return bengali ? 'যাচাই করা সচল ফিড' : 'Verified working feed';
      case FeedClaim.candidate:
        return bengali ? 'যাচাই হয়নি (সম্ভাব্য)' : 'Unverified (candidate)';
      case FeedClaim.none:
        return bengali ? 'ফিড নেই' : 'No feed';
    }
  }

  static String feedHealth(SourceHealthStatus status, {required bool bengali}) {
    switch (status) {
      case SourceHealthStatus.ok:
        return bengali ? 'ফিড সচল' : 'Feed working';
      case SourceHealthStatus.failing:
        return bengali ? 'ফিড বন্ধ' : 'Feed failing';
      case SourceHealthStatus.disabled:
        return bengali ? 'ফিড নেই' : 'No feed';
      case SourceHealthStatus.unknown:
        return bengali ? 'যাচাই হয়নি' : 'Not checked';
    }
  }
}
