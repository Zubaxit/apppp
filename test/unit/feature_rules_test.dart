import 'dart:io';

import 'package:bangladesh_newspaper_hub/core/utils/language_detect.dart';
import 'package:bangladesh_newspaper_hub/core/utils/story_matcher.dart';
import 'package:bangladesh_newspaper_hub/data/feeds/topic_classifier.dart';
import 'package:bangladesh_newspaper_hub/data/models/article.dart';
import 'package:bangladesh_newspaper_hub/services/news_shield.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final Uint8List bytes = File(key).readAsBytesSync();
    return ByteData.sublistView(bytes);
  }
}

Article story({
  required String source,
  required String title,
  required String link,
  String? excerpt,
  DateTime? published,
}) =>
    Article.create(
      sourceId: source,
      title: title,
      link: link,
      excerpt: excerpt,
      publishedAt: published ?? DateTime.utc(2026, 10, 25, 8),
      fetchedAt: DateTime.utc(2026, 10, 25, 9),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('article language detection', () {
    test('uses enough body text and recognizes Bengali', () {
      expect(
        LanguageDetect.ofArticle(
          title: 'A misleading English title',
          body: 'বাংলা ভাষায় লেখা এই দীর্ঘ প্রতিবেদনে দেশের অর্থনীতি, মানুষ এবং '
              'জনজীবনের বিভিন্ন দিক নিয়ে বিস্তারিত আলোচনা করা হয়েছে। ' *
              3,
        ),
        TextLanguage.bengali,
      );
    });

    test('short text is unknown and mixed prose stays translatable', () {
      expect(LanguageDetect.detect('Dhaka election'), TextLanguage.unknown);
      expect(
        LanguageDetect.detect(
          ('বাংলা অংশে ঘটনার ব্যাখ্যা আছে, while this English section carries '
                  'substantial additional reporting and useful context. ') *
              3,
        ),
        TextLanguage.mixed,
      );
      expect(LanguageDetect.offersTranslation(TextLanguage.unknown), isFalse);
    });
  });

  group('new topic rules', () {
    test('classifies each new section without duplicating Education', () {
      expect(
        TopicClassifier.classify(title: '৪৭তম বিসিএস নিয়োগ পরীক্ষার সময়সূচি'),
        ArticleTopic.jobs,
      );
      expect(
        TopicClassifier.classify(title: 'নতুন আবিষ্কার বদলে দিচ্ছে মহাবিশ্বের ইতিহাস'),
        ArticleTopic.learning,
      );
      expect(
        TopicClassifier.classify(title: 'মন্ত্রণালয়ের নতুন সরকারি প্রজ্ঞাপন প্রকাশ'),
        ArticleTopic.government,
      );
      expect(
        TopicClassifier.classify(title: 'Chevening scholarship applications open'),
        ArticleTopic.scholarships,
      );
      expect(
        TopicClassifier.classify(title: 'বিশ্ববিদ্যালয় ভর্তি পরীক্ষার ফলাফল প্রকাশ'),
        ArticleTopic.education,
      );
    });
  });

  group('same-story matcher', () {
    test('matches strong same-event coverage but rejects a broad shared entity', () {
      final Article a = story(
        source: 'one',
        title: 'Supreme Court suspends election order after emergency hearing',
        link: 'https://one.example/court-election-order',
        excerpt: 'Judges suspended the election order after an emergency hearing.',
      );
      final Article b = story(
        source: 'two',
        title: 'Election order suspended by Supreme Court following emergency hearing',
        link: 'https://two.example/supreme-court-ruling',
        excerpt: 'The Supreme Court ruling came after the same emergency hearing.',
      );
      final Article unrelated = story(
        source: 'three',
        title: 'Supreme Court opens legal history exhibition for students',
        link: 'https://three.example/exhibition',
      );
      expect(StoryMatcher.matches(a, b), isTrue);
      expect(StoryMatcher.matches(a, unrelated), isFalse);
    });

    test('deduplicates canonical URLs and handles late arriving reports', () {
      final Article first = story(
        source: 'one',
        title: 'Cyclone forces coastal evacuation before landfall tonight',
        link: 'https://example.org/story?utm_source=feed',
        excerpt: 'Coastal districts begin evacuation before the cyclone landfall.',
      );
      final Article duplicate = story(
        source: 'two',
        title: 'Cyclone forces coastal evacuation before landfall tonight',
        link: 'https://example.org/story?fbclid=abc',
        excerpt: first.excerpt,
      );
      final Article late = story(
        source: 'three',
        title: 'Coastal evacuation begins as cyclone nears landfall tonight',
        link: 'https://three.example/cyclone',
        excerpt: 'Officials ordered coastal evacuation as the cyclone nears landfall.',
      );
      expect(StoryMatcher.index(<Article>[first, duplicate])[first.id], isNull);
      expect(StoryMatcher.index(<Article>[first, late])[first.id], contains(late));
    });

    test('bridges clear Bangla and English event concepts conservatively', () {
      final Article en = story(
        source: 'one',
        title: 'Bank recruitment exam results published after written test',
        link: 'https://one.example/jobs',
        excerpt: 'The bank published recruitment results for the written exam.',
      );
      final Article bn = story(
        source: 'two',
        title: 'ব্যাংক নিয়োগ লিখিত পরীক্ষার ফলাফল প্রকাশ',
        link: 'https://two.example/jobs',
        excerpt: 'চাকরির নিয়োগ পরীক্ষার ফলাফল আজ প্রকাশ করেছে ব্যাংক।',
      );
      expect(StoryMatcher.matches(en, bn), isTrue);
    });
  });

  group('News Shield fallback', () {
    test('loads real rules and never blocks first-party content', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await NewsShield.load(bundle: _DiskBundle());
      expect(NewsShield.hosts.length, greaterThan(1000));
      expect(
        NewsShield.blocks(
          'https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js',
          pageUrl: 'https://www.thedailystar.net/story',
        ),
        isTrue,
      );
      expect(
        NewsShield.blocks(
          'https://media.thedailystar.net/photo.jpg',
          pageUrl: 'https://www.thedailystar.net/story',
        ),
        isFalse,
      );
    });

    test('OFF script leaves requests alone and removes cosmetic rules', () {
      final String off = NewsShield.script(enabled: false);
      expect(off, contains('shield.active = false'));
      expect(off, contains("style.remove()"));
    });
  });
}
