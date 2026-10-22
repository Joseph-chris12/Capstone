import 'package:shared_preferences/shared_preferences.dart';

/// Remembers whether the visitor has already seen the tutorial, so a first
/// launch opens on it and every later launch goes straight to the camera.
class OnboardingStore {
  OnboardingStore(this._prefs);

  static const _key = 'tutorial_seen';

  final SharedPreferences? _prefs;

  /// Never throws: if storage is unavailable the tutorial simply shows again.
  static Future<OnboardingStore> load() async {
    try {
      return OnboardingStore(await SharedPreferences.getInstance());
    } catch (_) {
      return OnboardingStore(null);
    }
  }

  bool get tutorialSeen => _prefs?.getBool(_key) ?? false;

  Future<void> markTutorialSeen() async {
    try {
      await _prefs?.setBool(_key, true);
    } catch (_) {
      // Worst case the tutorial opens once more next launch.
    }
  }
}
