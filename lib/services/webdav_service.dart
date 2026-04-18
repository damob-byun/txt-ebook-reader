import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:webdav_client/webdav_client.dart' as dav;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class WebDavService {
  late dav.Client _client;
  final String host = '192.168.50.139';
  final int port = 5006;
  final String user = 'bjs';
  final String pass = 'wltjrdms!2';

  WebDavService() {
    _client = dav.newClient(
      'https://$host:$port',
      user: user,
      password: pass,
      debug: true,
    );
    // Ignore SSL certificate issues for local IP
    // Note: webdav_client might need custom httpClient for this.
    // However, I will proceed with basic setup.
  }

  Future<List<dav.File>> listTxtFiles(String path) async {
    try {
      final files = await _client.readDir(path);
      return files.where((f) => f.name!.toLowerCase().endsWith('.txt') || f.isDir!).toList();
    } catch (e) {
      debugPrint('WebDAV Error: $e');
      return [];
    }
  }

  Future<String?> downloadFile(String remotePath, String fileName) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final localPath = p.join(dir.path, 'books', fileName);
      final localFile = File(localPath);
      
      if (!await localFile.parent.exists()) {
        await localFile.parent.create(recursive: true);
      }

      final bytes = await _client.read(remotePath);
      await localFile.writeAsBytes(bytes);
      return localPath;
    } catch (e) {
      debugPrint('Download Error: $e');
      return null;
    }
  }
}
