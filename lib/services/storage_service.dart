import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/book.dart';
import '../models/reader_settings.dart';

class StorageService {
  static const String _keySettings = 'reader_settings';
  static const String _keyBooks = 'library_books';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  Future<void> saveSettings(ReaderSettings settings) async {
    await _prefs.setString(_keySettings, jsonEncode(settings.toJson()));
  }

  ReaderSettings loadSettings() {
    final str = _prefs.getString(_keySettings);
    if (str == null) return ReaderSettings();
    try {
      return ReaderSettings.fromJson(jsonDecode(str));
    } catch (_) {
      return ReaderSettings();
    }
  }

  Future<void> saveBooks(List<Book> books) async {
    final list = books.map((b) => jsonEncode(b.toJson())).toList();
    await _prefs.setStringList(_keyBooks, list);
  }

  List<Book> loadBooks() {
    final list = _prefs.getStringList(_keyBooks);
    if (list == null) return [];
    return list.map((s) {
      try {
        return Book.fromJson(jsonDecode(s));
      } catch (_) {
        return null;
      }
    }).whereType<Book>().toList();
  }
}
