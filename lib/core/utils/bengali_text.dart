import 'text_utils.dart';

/// Bengali-specific helpers: numerals, dates, relative time and a pragmatic
/// Bengali→Latin transliteration used for cross-script publication search.
class BengaliText {
  const BengaliText._();

  static const List<String> _bnDigits = <String>[
    '০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯',
  ];

  static const List<String> monthNamesBn = <String>[
    'জানুয়ারি', 'ফেব্রুয়ারি', 'মার্চ', 'এপ্রিল', 'মে', 'জুন',
    'জুলাই', 'আগস্ট', 'সেপ্টেম্বর', 'অক্টোবর', 'নভেম্বর', 'ডিসেম্বর',
  ];

  static const List<String> monthNamesEn = <String>[
    'January', 'February', 'March', 'April', 'May', 'June', 'July',
    'August', 'September', 'October', 'November', 'December',
  ];

  static const List<String> weekdayNamesBn = <String>[
    'সোমবার', 'মঙ্গলবার', 'বুধবার', 'বৃহস্পতিবার', 'শুক্রবার', 'শনিবার', 'রবিবার',
  ];

  /// Converts ASCII digits to Bengali digits.
  static String toBengaliDigits(Object? value) {
    final String text = '${value ?? ''}';
    final StringBuffer buffer = StringBuffer();
    for (final int rune in text.runes) {
      if (rune >= 0x30 && rune <= 0x39) {
        buffer.write(_bnDigits[rune - 0x30]);
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }

  static String fromBengaliDigits(String input) {
    var out = input;
    for (var i = 0; i < _bnDigits.length; i++) {
      out = out.replaceAll(_bnDigits[i], '$i');
    }
    return out;
  }

  static bool containsBengali(String input) {
    for (final int rune in input.runes) {
      if (rune >= 0x0980 && rune <= 0x09FF) return true;
    }
    return false;
  }

  /// "২ ঘণ্টা আগে" / "2 hours ago". Returns null when [when] is null.
  static String? relative(DateTime? when, {required bool bengali, DateTime? now}) {
    if (when == null) return null;
    final DateTime reference = (now ?? DateTime.now()).toUtc();
    final Duration diff = reference.difference(when.toUtc());
    if (diff.isNegative) {
      return bengali ? 'সদ্য' : 'Just now';
    }
    String value(int amount, String bn, String en) {
      final String number = bengali ? toBengaliDigits(amount) : '$amount';
      return bengali ? '$number $bn আগে' : '$number $en ago';
    }

    if (diff.inMinutes < 1) return bengali ? 'এইমাত্র' : 'Just now';
    if (diff.inMinutes < 60) {
      return value(diff.inMinutes, 'মিনিট', diff.inMinutes == 1 ? 'minute' : 'minutes');
    }
    if (diff.inHours < 24) {
      return value(diff.inHours, 'ঘণ্টা', diff.inHours == 1 ? 'hour' : 'hours');
    }
    if (diff.inDays < 7) {
      return value(diff.inDays, 'দিন', diff.inDays == 1 ? 'day' : 'days');
    }
    return absolute(when, bengali: bengali);
  }

  /// "২৪ অক্টোবর ২০২৬" / "24 October 2026", in Bangladesh time (UTC+6).
  static String absolute(DateTime when, {required bool bengali}) {
    final DateTime local = when.toUtc().add(const Duration(hours: 6));
    final String day = bengali ? toBengaliDigits(local.day) : '${local.day}';
    final String month = (bengali ? monthNamesBn : monthNamesEn)[local.month - 1];
    final String year = bengali ? toBengaliDigits(local.year) : '${local.year}';
    return '$day $month $year';
  }

  /// "২৪ অক্টোবর, ৩:০৫ PM" — used on article detail screens.
  static String dateTime(DateTime when, {required bool bengali}) {
    final DateTime local = when.toUtc().add(const Duration(hours: 6));
    final String day = bengali ? toBengaliDigits(local.day) : '${local.day}';
    final String month = (bengali ? monthNamesBn : monthNamesEn)[local.month - 1];
    final int hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final String hour = bengali ? toBengaliDigits(hour12) : '$hour12';
    final String minute = bengali
        ? toBengaliDigits(local.minute.toString().padLeft(2, '0'))
        : local.minute.toString().padLeft(2, '0');
    final String meridiem = local.hour < 12 ? 'AM' : 'PM';
    return '$day $month, $hour:$minute $meridiem';
  }

  static const Map<String, String> _consonants = <String, String>{
    'ক': 'k', 'খ': 'kh', 'গ': 'g', 'ঘ': 'gh', 'ঙ': 'ng',
    'চ': 'ch', 'ছ': 'chh', 'জ': 'j', 'ঝ': 'jh', 'ঞ': 'n',
    'ট': 't', 'ঠ': 'th', 'ড': 'd', 'ঢ': 'dh', 'ণ': 'n',
    'ত': 't', 'থ': 'th', 'দ': 'd', 'ধ': 'dh', 'ন': 'n',
    'প': 'p', 'ফ': 'ph', 'ব': 'b', 'ভ': 'bh', 'ম': 'm',
    'য': 'j', 'র': 'r', 'ল': 'l', 'শ': 'sh', 'ষ': 'sh',
    'স': 's', 'হ': 'h', 'ড়': 'r', 'ঢ়': 'rh', 'য়': 'y',
    'ৎ': 't', 'ং': 'ng', 'ঃ': 'h', 'ঁ': '',
  };

  static const Map<String, String> _independentVowels = <String, String>{
    'অ': 'o', 'আ': 'a', 'ই': 'i', 'ঈ': 'i', 'উ': 'u', 'ঊ': 'u',
    'ঋ': 'ri', 'এ': 'e', 'ঐ': 'oi', 'ও': 'o', 'ঔ': 'ou',
  };

  static const Map<String, String> _vowelSigns = <String, String>{
    'া': 'a', 'ি': 'i', 'ী': 'i', 'ু': 'u', 'ূ': 'u', 'ৃ': 'ri',
    'ে': 'e', 'ৈ': 'oi', 'ো': 'o', 'ৌ': 'ou', '্': '',
  };

  /// Rough transliteration, good enough to match "প্রথম আলো" ≈ "prothom alo".
  static String transliterateToLatin(String input) {
    final StringBuffer buffer = StringBuffer();
    for (final int rune in input.runes) {
      final String char = String.fromCharCode(rune);
      if (_consonants.containsKey(char)) {
        buffer.write(_consonants[char]);
      } else if (_independentVowels.containsKey(char)) {
        buffer.write(_independentVowels[char]);
      } else if (_vowelSigns.containsKey(char)) {
        buffer.write(_vowelSigns[char]);
      } else if (rune >= 0x30 && rune <= 0x39) {
        buffer.writeCharCode(rune);
      } else if (rune >= 0x09E6 && rune <= 0x09EF) {
        buffer.write(rune - 0x09E6);
      } else if (char == ' ' || char == '।') {
        buffer.write(' ');
      } else if (rune < 128) {
        buffer.write(char);
      }
    }
    return TextUtils.normalizeSpaces(buffer.toString());
  }
}
