import '../models/article.dart';
import '../models/news_source.dart';

/// Maps publisher categories, tags and headline keywords onto the app's topic
/// rail. Bengali and English keywords are both supported.
///
/// The classifier is intentionally conservative: when nothing matches, the item
/// lands in [ArticleTopic.other] instead of being forced into a section.
class TopicClassifier {
  const TopicClassifier._();

  static const Map<ArticleTopic, List<String>> _keywords = <ArticleTopic, List<String>>{
    ArticleTopic.politics: <String>[
      'রাজনীতি', 'রাজনৈতিক', 'সরকার', 'সংসদ', 'নির্বাচন', 'আওয়ামী', 'বিএনপি',
      'জামায়াত', 'মন্ত্রী', 'প্রধানমন্ত্রী', 'রাষ্ট্রপতি', 'দলীয়', 'বিরোধী',
      'politics', 'political', 'parliament', 'election', 'government',
      'minister', 'prime minister', 'president', 'party', 'opposition', 'vote',
    ],
    ArticleTopic.economy: <String>[
      'অর্থনীতি', 'অর্থনৈতিক', 'ব্যাংক', 'বাজেট', 'রপ্তানি', 'আমদানি', 'বিনিয়োগ',
      'শেয়ারবাজার', 'ডলার', 'টাকা', 'মূল্যস্ফীতি', 'বাণিজ্য', 'কর',
      'economy', 'economic', 'business', 'bank', 'budget', 'export', 'import',
      'investment', 'stock', 'dollar', 'taka', 'inflation', 'trade', 'tax',
      'market', 'revenue', 'gdp', 'remittance',
    ],
    ArticleTopic.international: <String>[
      'আন্তর্জাতিক', 'বিশ্ব', 'বিদেশ', 'ভারত', 'পাকিস্তান', 'চীন', 'যুক্তরাষ্ট্র',
      'আমেরিকা', 'ইউরোপ', 'মধ্যপ্রাচ্য', 'ফিলিস্তিন', 'ইসরায়েল', 'রাশিয়া',
      'international', 'world', 'global', 'foreign', 'india', 'pakistan',
      'china', 'united states', 'usa', 'europe', 'middle east', 'israel',
      'russia', 'ukraine', 'united nations',
    ],
    ArticleTopic.education: <String>[
      'শিক্ষা', 'শিক্ষার্থী', 'বিশ্ববিদ্যালয়', 'পরীক্ষা', 'কলেজ', 'স্কুল',
      'ভর্তি', 'এসএসসি', 'এইচএসসি', 'শিক্ষক', 'মাদ্রাসা',
      'education', 'student', 'university', 'exam', 'college', 'school',
      'admission', 'teacher', 'academic', 'campus',
    ],
    ArticleTopic.sports: <String>[
      'খেলা', 'ক্রিকেট', 'ফুটবল', 'বাংলাদেশ ক্রিকেট', 'টাইগার', 'ম্যাচ',
      'টুর্নামেন্ট', 'গোল', 'ব্যাটসম্যান', 'বোলার', 'অলিম্পিক', 'শিরোপা',
      'sports', 'cricket', 'football', 'match', 'tournament', 'goal',
      'batsman', 'bowler', 'olympics', 'championship', 'fifa', 'bpl', 'tigers',
    ],
    ArticleTopic.entertainment: <String>[
      'বিনোদন', 'সিনেমা', 'চলচ্চিত্র', 'গান', 'সংগীত', 'নাটক', 'অভিনেতা',
      'অভিনেত্রী', 'টেলিভিশন', 'ঢালিউড', 'মেগা', 'সিরিজ',
      'entertainment', 'cinema', 'movie', 'film', 'music', 'song', 'drama',
      'actor', 'actress', 'television', 'bollywood', 'series', 'concert',
    ],
    ArticleTopic.technology: <String>[
      'প্রযুক্তি', 'টেক', 'মোবাইল', 'ইন্টারনেট', 'কম্পিউটার', 'সফটওয়্যার',
      'কৃত্রিম বুদ্ধিমত্তা', 'এআই', 'রোবট', 'গেমিং', 'স্মার্টফোন',
      'technology', 'tech', 'mobile', 'internet', 'computer', 'software',
      'artificial intelligence', 'ai', 'robot', 'gaming', 'smartphone',
      'app', 'startup', 'digital', 'cyber',
    ],
    ArticleTopic.health: <String>[
      'স্বাস্থ্য', 'চিকিৎসা', 'রোগ', 'হাসপাতাল', 'ডেঙ্গু', 'ভ্যাকসিন', 'ওষুধ',
      'ডাক্তার', 'করোনা',
      'health', 'medical', 'disease', 'hospital', 'dengue', 'vaccine',
      'medicine', 'doctor', 'covid', 'nutrition',
    ],
    ArticleTopic.lifestyle: <String>[
      'জীবনযাপন', 'ফ্যাশন', 'রান্না', 'ভ্রমণ', 'সম্পর্ক', 'পরিবার',
      'lifestyle', 'fashion', 'food', 'recipe', 'travel', 'relationship',
      'family', 'culture', 'art', 'book',
    ],
    ArticleTopic.bangladesh: <String>[
      'বাংলাদেশ', 'ঢাকা', 'চট্টগ্রাম', 'খুলনা', 'রাজশাহী', 'সিলেট', 'বরিশাল',
      'রংপুর', 'ময়মনসিংহ', 'উপজেলা', 'জেলা', 'থানা', 'আবহাওয়া',
      'bangladesh', 'dhaka', 'chattogram', 'khulna', 'rajshahi', 'sylhet',
      'barishal', 'rangpur', 'mymensingh', 'district', 'weather', 'nation',
    ],
  };

  /// Publisher category strings that should win over keyword guessing.
  static const Map<String, ArticleTopic> _categoryHints = <String, ArticleTopic>{
    'sports': ArticleTopic.sports,
    'খেলা': ArticleTopic.sports,
    'ক্রীড়া': ArticleTopic.sports,
    'business': ArticleTopic.economy,
    'অর্থনীতি': ArticleTopic.economy,
    'বাণিজ্য': ArticleTopic.economy,
    'politics': ArticleTopic.politics,
    'রাজনীতি': ArticleTopic.politics,
    'international': ArticleTopic.international,
    'আন্তর্জাতিক': ArticleTopic.international,
    'world': ArticleTopic.international,
    'education': ArticleTopic.education,
    'শিক্ষা': ArticleTopic.education,
    'entertainment': ArticleTopic.entertainment,
    'বিনোদন': ArticleTopic.entertainment,
    'technology': ArticleTopic.technology,
    'প্রযুক্তি': ArticleTopic.technology,
    'health': ArticleTopic.health,
    'স্বাস্থ্য': ArticleTopic.health,
    'lifestyle': ArticleTopic.lifestyle,
    'জীবনযাপন': ArticleTopic.lifestyle,
    'bangladesh': ArticleTopic.bangladesh,
    'বাংলাদেশ': ArticleTopic.bangladesh,
  };

  static ArticleTopic classify({
    required String title,
    List<String> categories = const <String>[],
    String? excerpt,
    SourceLanguage language = SourceLanguage.bn,
  }) {
    for (final String category in categories) {
      final String key = category.trim().toLowerCase();
      final ArticleTopic? hint = _categoryHints[key];
      if (hint != null) return hint;
      for (final MapEntry<String, ArticleTopic> entry in _categoryHints.entries) {
        if (key.contains(entry.key)) return entry.value;
      }
    }

    final String haystack = '${title.toLowerCase()} ${(excerpt ?? '').toLowerCase()}';
    ArticleTopic best = ArticleTopic.other;
    var bestScore = 0;
    for (final MapEntry<ArticleTopic, List<String>> entry in _keywords.entries) {
      var score = 0;
      for (final String keyword in entry.value) {
        if (haystack.contains(keyword)) {
          score += keyword.length > 5 ? 2 : 1;
        }
      }
      if (entry.key == ArticleTopic.bangladesh && language != SourceLanguage.bn) {
        score -= 1;
      }
      if (score > bestScore) {
        bestScore = score;
        best = entry.key;
      }
    }
    return bestScore >= 2 ? best : ArticleTopic.other;
  }
}
