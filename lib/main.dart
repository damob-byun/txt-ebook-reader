import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/library_provider.dart';
import 'providers/app_settings_provider.dart';
import 'providers/webdav_account_provider.dart';
import 'services/storage_service.dart';
import 'screens/library_screen.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();
  
  final prefs = await SharedPreferences.getInstance();
  final storageService = StorageService(prefs);

  runApp(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storageService),
        appSettingsProvider.overrideWith((ref) => AppSettingsNotifier(prefs)),
        webDavAccountProvider.overrideWith((ref) => WebDavAccountNotifier(prefs)),
      ],
      child: const MoonViewerApp(),
    ),
  );
}

class MoonViewerApp extends StatelessWidget {
  const MoonViewerApp({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('App: Building MoonViewerApp...');
    return MaterialApp(
      title: 'MoonViewer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: false, // Disabled for stability
        primaryColor: const Color(0xFF6B4E3D),
        scaffoldBackgroundColor: const Color(0xFFF5F5F0),
      ),
      home: const LibraryScreen(),
    );
  }
}
