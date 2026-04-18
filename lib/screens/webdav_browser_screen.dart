import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webdav_client/webdav_client.dart' as dav;
import '../services/webdav_service.dart';
import '../models/book.dart';
import '../providers/library_provider.dart';

final webDavServiceProvider = Provider((ref) => WebDavService());

class WebDavBrowserScreen extends ConsumerStatefulWidget {
  const WebDavBrowserScreen({super.key});

  @override
  ConsumerState<WebDavBrowserScreen> createState() => _WebDavBrowserScreenState();
}

class _WebDavBrowserScreenState extends ConsumerState<WebDavBrowserScreen> {
  String _currentPath = '/';
  List<dav.File> _files = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() => _isLoading = true);
    final service = ref.read(webDavServiceProvider);
    final files = await service.listTxtFiles(_currentPath);
    setState(() {
      _files = files;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentPath),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFiles,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _files.length,
              itemBuilder: (context, index) {
                final file = _files[index];
                if (file.isDir!) {
                  return ListTile(
                    leading: const Icon(Icons.folder, color: Colors.amber),
                    title: Text(file.name!),
                    onTap: () {
                      setState(() => _currentPath = file.path!);
                      _loadFiles();
                    },
                  );
                } else {
                  return ListTile(
                    leading: const Icon(Icons.description, color: Colors.blue),
                    title: Text(file.name!),
                    subtitle: Text('${(file.size! / 1024).toStringAsFixed(1)} KB'),
                    trailing: const Icon(Icons.download),
                    onTap: () => _downloadAndAddBook(file),
                  );
                }
              },
            ),
    );
  }

  Future<void> _downloadAndAddBook(dav.File file) async {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final service = ref.read(webDavServiceProvider);
      final localPath = await service.downloadFile(file.path!, file.name!);

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      if (localPath != null) {
        final book = Book.fromRemote(file.name!, file.path!);
        final bookWithLocal = book.copyWith(path: localPath);
        
        await ref.read(libraryProvider.notifier).addBook(bookWithLocal);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('책장에 추가되었습니다.')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('다운로드 실패')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close dialog on error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류 발생: $e')),
        );
      }
    }
  }
}
