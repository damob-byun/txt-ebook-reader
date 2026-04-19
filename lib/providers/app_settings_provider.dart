import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';

final appSettingsProvider = StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) {
  // Initialized in main
  throw UnimplementedError();
});

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  final SharedPreferences _prefs;
  static const _key = 'app_settings';

  AppSettingsNotifier(this._prefs) : super(AppSettings()) {
    _load();
  }

  void _load() {
    final str = _prefs.getString(_key);
    if (str != null) {
      try {
        state = AppSettings.fromJson(jsonDecode(str));
      } catch (_) {}
    }
  }

  Future<void> updateVolumeKeys(bool val) async {
    state = state.copyWith(useVolumeKeys: val);
    await _prefs.setString(_key, jsonEncode(state.toJson()));
  }

  Future<void> updateTouchTurn(bool val) async {
    state = state.copyWith(useTouchTurn: val);
    await _prefs.setString(_key, jsonEncode(state.toJson()));
  }

  Future<void> updateScrollMode(bool val) async {
    state = state.copyWith(useScrollMode: val);
    await _prefs.setString(_key, jsonEncode(state.toJson()));
  }
}
