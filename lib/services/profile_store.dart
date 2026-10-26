import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/author_profile.dart';

/// Local-only storage for the author profile.
///
/// The profile is a preference, not an account: it lives in the app's own
/// preferences file, is never uploaded, and survives upgrades because the key is
/// stable and versioned.
abstract class ProfileStore {
  Future<AuthorProfile> load();
  Future<void> save(AuthorProfile profile);
  Future<void> clear();
}

class SharedPreferencesProfileStore implements ProfileStore {
  SharedPreferencesProfileStore(this._prefs);

  final SharedPreferences _prefs;

  static const String key = 'author_profile_v1';

  static Future<SharedPreferencesProfileStore> create() async =>
      SharedPreferencesProfileStore(await SharedPreferences.getInstance());

  @override
  Future<AuthorProfile> load() async =>
      AuthorProfile.decode(_prefs.getString(key));

  @override
  Future<void> save(AuthorProfile profile) async {
    await _prefs.setString(key, profile.encode());
  }

  @override
  Future<void> clear() async {
    await _prefs.remove(key);
  }
}

class InMemoryProfileStore implements ProfileStore {
  InMemoryProfileStore([this._profile]);

  AuthorProfile? _profile;

  @override
  Future<AuthorProfile> load() async => _profile ?? const AuthorProfile();

  @override
  Future<void> save(AuthorProfile profile) async => _profile = profile;

  @override
  Future<void> clear() async => _profile = null;
}
