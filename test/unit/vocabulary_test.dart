import 'package:bangladesh_newspaper_hub/data/models/vocabulary_entry.dart';
import 'package:bangladesh_newspaper_hub/data/services/stores.dart';
import 'package:bangladesh_newspaper_hub/services/vocabulary_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/test_app.dart';

VocabularyEntry entry(String word, [String meaning = 'অর্থ']) =>
    VocabularyEntry(
      word: word,
      meaningBn: meaning,
      savedAt: DateTime.utc(2026, 10, 26),
    );

void main() {
  test('whole-word matching is case-insensitive and handles punctuation', () {
    final VocabularyMatcher matcher =
        VocabularyMatcher(<VocabularyEntry>[entry('impose')]);
    final List<VocabularyMatch> matches =
        matcher.find('IMPOSE, then impose; do not decompose.');
    expect(matches, hasLength(2));
    expect(matches.map((VocabularyMatch item) => item.entry.word),
        everyElement('impose'));
  });

  test('matches conservative common forms and avoids substring false positives',
      () {
    final VocabularyMatcher matcher = VocabularyMatcher(<VocabularyEntry>[
      entry('impose'),
      entry('president'),
    ]);
    final List<VocabularyMatch> matches = matcher.find(
      'They imposed rules, impose fines, and are imposing limits. Presidential offices differ.',
    );
    expect(matches.where((VocabularyMatch item) => item.entry.word == 'impose'),
        hasLength(3));
    expect(
        matches.where((VocabularyMatch item) => item.entry.word == 'president'),
        isEmpty);
  });

  test('finds multiple occurrences efficiently in a larger vocabulary', () {
    final List<VocabularyEntry> entries = <VocabularyEntry>[
      for (int i = 0; i < 1000; i++) entry('term$i'),
      entry('policy'),
    ];
    final VocabularyMatcher matcher = VocabularyMatcher(entries);
    expect(matcher.find('Policy changes require policy debate.'), hasLength(2));
  });

  test('controller creates, edits, retrieves and deletes without duplicates',
      () async {
    final TestHarness harness = TestHarness(stores: fakeStores());
    await harness.saved.load();
    await harness.saved.saveVocabulary(entry('Policy', 'নীতি'));
    expect(harness.saved.vocabularyFor('policy')?.meaningBn, 'নীতি');
    await harness.saved.saveVocabulary(entry('policy', 'নীতিমালা'));
    expect(harness.saved.vocabulary, hasLength(1));
    expect(harness.saved.vocabularyFor('POLICY')?.meaningBn, 'নীতিমালা');
    await harness.saved.removeVocabulary('policy');
    expect(harness.saved.vocabulary, isEmpty);
  });

  test('import and repository retrieval preserve exact Bengali Unicode',
      () async {
    const String meaning =
        'রাষ্ট্রের আইনসভা—যুক্তাক্ষর ক্ষ, জ্ঞ; mixed Legislature অর্থ।';
    final TestHarness harness = TestHarness(stores: fakeStores());
    await harness.saved.load();
    await harness.saved.importVocabulary(
      <VocabularyEntry>[entry('legislature', meaning)],
      replaceConflicts: false,
    );
    expect(harness.saved.vocabularyFor('LEGISLATURE')?.meaningBn, meaning);
    expect(
      (await harness.repository.vocabulary()).single.meaningBn,
      meaning,
    );
  });

  test('import preserves or replaces conflicts only when requested', () async {
    final TestHarness harness = TestHarness(stores: fakeStores());
    await harness.saved.load();
    await harness.saved.saveVocabulary(entry('Policy', 'স্থানীয়'));
    expect(
      await harness.saved.importVocabulary(
        <VocabularyEntry>[entry('policy', 'আমদানি'), entry('budget', 'বাজেট')],
        replaceConflicts: false,
      ),
      1,
    );
    expect(harness.saved.vocabularyFor('policy')?.meaningBn, 'স্থানীয়');
    await harness.saved.importVocabulary(
      <VocabularyEntry>[entry('POLICY', 'আমদানি')],
      replaceConflicts: true,
    );
    expect(harness.saved.vocabularyFor('policy')?.meaningBn, 'আমদানি');
  });

  test('failed atomic import leaves controller and storage unchanged',
      () async {
    final _FailingVocabularyStore store = _FailingVocabularyStore();
    final TestHarness harness = TestHarness(
      stores: fakeStores(vocabulary: store),
    );
    await harness.saved.load();
    await harness.saved.saveVocabulary(entry('local', 'স্থানীয়'));
    await expectLater(
      harness.saved.importVocabulary(
        <VocabularyEntry>[entry('new', 'নতুন')],
        replaceConflicts: true,
      ),
      throwsStateError,
    );
    expect(harness.saved.vocabularyFor('local'), isNotNull);
    expect(harness.saved.vocabularyFor('new'), isNull);
    expect(await store.all(), hasLength(1));
  });
}

class _FailingVocabularyStore extends FakeVocabularyStore
    implements VocabularyStore {
  @override
  Future<void> saveAllAtomic(Iterable<VocabularyEntry> entries) async {
    throw StateError('simulated transaction failure');
  }
}
