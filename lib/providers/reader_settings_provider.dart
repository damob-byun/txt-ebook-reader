import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/reader_settings.dart';
import '../services/storage_service.dart';
import 'library_provider.dart';

final readerSettingsProvider = StateNotifierProvider<ReaderSettingsNotifier, ReaderSettings>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return ReaderSettingsNotifier(storage);
});

class ReaderSettingsNotifier extends StateNotifier<ReaderSettings> {
  final StorageService _storage;

  ReaderSettingsNotifier(this._storage) : super(ReaderSettings()) {
    state = _storage.loadSettings();
  }

  Future<void> updateFontSize(double size) async {
    state = state.copyWith(fontSize: size);
    await _storage.saveSettings(state);
  }

  Future<void> updateTheme(ReaderTheme theme) async {
    state = state.copyWith(theme: theme);
    await _storage.saveSettings(state);
  }

  Future<void> updateFontFamily(String family) async {
    state = state.copyWith(fontFamily: family);
    await _storage.saveSettings(state);
  }

  Future<void> updateEncoding(String encoding) async {
    state = state.copyWith(encoding: encoding);
    await _storage.saveSettings(state);
  }
}
