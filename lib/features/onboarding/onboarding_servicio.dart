import 'package:shared_preferences/shared_preferences.dart';

class OnboardingServicio {
  static const _key = 'onboarding_completado';

  static Future<bool> estaCompletado() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_key) ?? false;
    } catch (_) {
      return true;
    }
  }

  static Future<void> marcarCompletado() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, true);
    } catch (_) {}
  }
}
