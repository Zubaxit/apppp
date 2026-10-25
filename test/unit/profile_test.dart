import 'dart:convert';

import 'package:bangladesh_newspaper_hub/data/models/author_profile.dart';
import 'package:bangladesh_newspaper_hub/services/profile_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthorProfile', () {
    test('the starting profile contains only supplied, supportable facts', () {
      const AuthorProfile profile = AuthorProfile();
      expect(profile.name, 'মোঃ ইমন');
      expect(profile.nameEn, 'Md Emon');
      expect(profile.bio, contains('ব্রজলাল কলেজ'));
      expect(profile.bio, contains('খুলনা'));
      expect(profile.interests, contains('কবিতা'));
      expect(profile.links, isEmpty);
      // The master's-level study is explicitly unconfirmed rather than claimed.
      expect(profile.longBio, contains('নিশ্চিত নয়'));
      expect(profile.longBio, isNot(contains('স্নাতকোত্তর ডিগ্রি')));
    });

    test('an edited profile survives an encode/decode round trip', () {
      final AuthorProfile edited = const AuthorProfile().copyWith(
        name: 'ইমন',
        bio: 'নিজের লেখা পরিচিতি',
        interests: const <String>['কবিতা', 'দর্শন'],
        links: const <String>['https://example.org/emon'],
      );
      final AuthorProfile restored = AuthorProfile.decode(edited.encode());
      expect(restored.name, 'ইমন');
      expect(restored.bio, 'নিজের লেখা পরিচিতি');
      expect(restored.interests, <String>['কবিতা', 'দর্শন']);
      expect(restored.links, <String>['https://example.org/emon']);
      expect(restored.nameEn, edited.nameEn);
    });

    test('blank fields fall back to the starting profile', () {
      final AuthorProfile restored = AuthorProfile.decode(
        jsonEncode(<String, dynamic>{'name': '   ', 'bio': '', 'interests': <String>[]}),
      );
      expect(restored.name, 'মোঃ ইমন');
      expect(restored.bio, AuthorProfile.defaultBio);
      expect(restored.interests, isEmpty);
    });

    test('corrupt stored data never blocks the About screen', () {
      expect(AuthorProfile.decode('{not json').name, 'মোঃ ইমন');
      expect(AuthorProfile.decode('').name, 'মোঃ ইমন');
      expect(AuthorProfile.decode(null).nameEn, 'Md Emon');
    });

    test('only plain web addresses are accepted as profile links', () {
      expect(AuthorProfile.isSupportedLink('https://example.org'), isTrue);
      expect(AuthorProfile.isSupportedLink('http://example.org/x'), isTrue);
      expect(AuthorProfile.isSupportedLink('example.org'), isFalse);
      expect(AuthorProfile.isSupportedLink('javascript:alert(1)'), isFalse);
      expect(AuthorProfile.isSupportedLink('https://'), isFalse);
    });

    test('the monogram falls back to a Bengali letter when the name is empty', () {
      expect(const AuthorProfile().initial, 'ম');
      expect(const AuthorProfile(name: '').initial, 'অ');
    });
  });

  group('InMemoryProfileStore', () {
    test('starts at the default profile, saves and clears', () async {
      final InMemoryProfileStore store = InMemoryProfileStore();
      expect((await store.load()).name, 'মোঃ ইমন');

      await store.save(const AuthorProfile(name: 'পরীক্ষা'));
      expect((await store.load()).name, 'পরীক্ষা');

      await store.clear();
      expect((await store.load()).name, 'মোঃ ইমন');
    });
  });
}
