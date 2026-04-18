import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:webdav_client/webdav_client.dart' as dav;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;

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

  Future<String?> downloadFileWithProgress(
    String remotePath,
    String fileName,
    Function(double progress, int downloaded, int total) onProgress,
  ) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final localPath = p.join(dir.path, 'books', fileName);
      final localFile = File(localPath);

      if (!await localFile.parent.exists()) {
        await localFile.parent.create(recursive: true);
      }

      final url = Uri.parse('https://$host:$port$remotePath');
      final request = http.Request('GET', url);
      
      // Basic Auth
      final auth = 'Basic ${base64Encode(utf8.encode('$user:$pass'))}';
      request.headers['Authorization'] = auth;

      final response = await request.send();
      final total = response.contentLength ?? 0;
      int downloaded = 0;

      final sink = localFile.openWrite();
      
      await response.stream.listen((chunk) {
        downloaded += chunk.length;
        sink.add(chunk);
        if (total > 0) {
          onProgress(downloaded / total, downloaded, total);
        }
      }).asFuture();

      await sink.close();
      return localPath;
    } catch (e) {
      debugPrint('Download Progress Error: $e');
      return null;
    }
  }
}
