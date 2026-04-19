import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:webdav_client/webdav_client.dart' as dav;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;

class WebDavService {
  late dav.Client _client;
  final String host;
  final int port;
  final String user;
  final String pass;
  final bool useHttps;

  WebDavService({
    required this.host,
    required this.port,
    required this.user,
    required this.pass,
    this.useHttps = true,
  }) {
    final protocol = useHttps ? 'https' : 'http';
    _client = dav.newClient(
      '$protocol://$host:$port',
      user: user,
      password: pass,
      debug: true,
    );
  }

  Future<List<dav.File>> listTxtFiles(String path) async {
    try {
      debugPrint('WebDAV: Listing files in $path');
      final files = await _client.readDir(path);
      debugPrint('WebDAV: Found ${files.length} files');
      return files
          .where((f) => f.name!.toLowerCase().endsWith('.txt') || f.isDir!)
          .toList();
    } catch (e) {
      debugPrint('WebDAV Listing Error: $e');
      return [];
    }
  }

  Future<String?> downloadFileWithProgress(
    String remotePath,
    String fileName,
    Function(double) onProgress,
  ) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final localPath = p.join(dir.path, 'books', fileName);
      final localFile = File(localPath);

      if (!await localFile.parent.exists()) {
        await localFile.parent.create(recursive: true);
      }

      // Using http for progress tracking
      final auth = 'Basic ${base64Encode(utf8.encode('$user:$pass'))}';
      final url =
          'https://$host:$port${remotePath.startsWith('/') ? '' : '/'}$remotePath';

      final request = http.Request('GET', Uri.parse(url));
      request.headers['Authorization'] = auth;

      final response = await http.Client().send(request);
      final contentLength = response.contentLength ?? 0;
      int downloaded = 0;

      final List<int> bytes = [];
      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        downloaded += chunk.length;
        if (contentLength > 0) {
          onProgress(downloaded / contentLength);
        }
      }

      await localFile.writeAsBytes(bytes);
      return localPath;
    } catch (e) {
      debugPrint('Download Progress Error: $e');
      return null;
    }
  }

  Future<String?> downloadFile(String remotePath, String fileName) async {
    return downloadFileWithProgress(remotePath, fileName, (p) {});
  }
}
