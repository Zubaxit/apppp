import 'package:shared_preferences/shared_preferences.dart';

/// Thin abstraction so preference persistence can be faked in tests.
abstract class PreferencesStore {
  Future<String?> read();
  Future<void> write(String value);
}

class SharedPreferencesStore implements PreferencesStore {
  SharedPreferencesStore(this._prefs);

  final SharedPreferences _prefs;
  static const String key = 'app_preferences_v1';

  static Future<SharedPreferencesStore> create() async =>
      SharedPreferencesStore(await SharedPreferences.getInstance());

  @override
  Future<String?> read() async => _prefs.getString(key);

  @override
  Future<void> write(String value) async {
    await _prefs.setString(key, value);
  }
}

class InMemoryPreferencesStore implements PreferencesStore {
  InMemoryPreferencesStore([this._value]);
  String? _value;

  @override
  Future<String?> read() async => _value;

  @override
  Future<void> write(String value) async => _value = value;
}
