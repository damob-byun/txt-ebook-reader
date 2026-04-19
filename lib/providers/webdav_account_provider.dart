import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/webdav_account.dart';

final webDavAccountProvider = StateNotifierProvider<WebDavAccountNotifier, WebDavAccount?>((ref) {
  // Initialized in main or with shared_prefs
  throw UnimplementedError();
});

class WebDavAccountNotifier extends StateNotifier<WebDavAccount?> {
  final SharedPreferences _prefs;
  final _secureStorage = const FlutterSecureStorage();
  static const _keyPrefix = 'webdav_';

  WebDavAccountNotifier(this._prefs) : super(null) {
    _load();
  }

  Future<void> _load() async {
    final host = _prefs.getString('${_keyPrefix}host');
    if (host == null) return;

    final port = _prefs.getInt('${_keyPrefix}port') ?? 443;
    final username = _prefs.getString('${_keyPrefix}username') ?? '';
    final useHttps = _prefs.getBool('${_keyPrefix}useHttps') ?? true;
    final password = await _secureStorage.read(key: '${_keyPrefix}password') ?? '';

    state = WebDavAccount(
      host: host,
      port: port,
      username: username,
      password: password,
      useHttps: useHttps,
    );
  }

  Future<void> saveAccount(WebDavAccount account) async {
    await _prefs.setString('${_keyPrefix}host', account.host);
    await _prefs.setInt('${_keyPrefix}port', account.port);
    await _prefs.setString('${_keyPrefix}username', account.username);
    await _prefs.setBool('${_keyPrefix}useHttps', account.useHttps);
    await _secureStorage.write(key: '${_keyPrefix}password', value: account.password);
    
    state = account;
  }

  Future<void> clearAccount() async {
    await _prefs.remove('${_keyPrefix}host');
    await _prefs.remove('${_keyPrefix}port');
    await _prefs.remove('${_keyPrefix}username');
    await _prefs.remove('${_keyPrefix}useHttps');
    await _secureStorage.delete(key: '${_keyPrefix}password');
    
    state = null;
  }
}
