import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webdav_client/webdav_client.dart' as dav;
import 'dart:async';
import '../services/webdav_service.dart';
import '../models/book.dart';
import '../providers/library_provider.dart';
import '../providers/webdav_account_provider.dart';

final webDavServiceProvider = Provider<WebDavService?>((ref) {
  final account = ref.watch(webDavAccountProvider);
  if (account == null || !account.isValid) return null;
  
  return WebDavService(
    host: account.host,
    port: account.port,
    user: account.username,
    pass: account.password,
    useHttps: account.useHttps,
  );
});

class WebDavBrowserScreen extends ConsumerStatefulWidget {
  const WebDavBrowserScreen({super.key});

  @override
  ConsumerState<WebDavBrowserScreen> createState() => _WebDavBrowserScreenState();
}

class _WebDavBrowserScreenState extends ConsumerState<WebDavBrowserScreen> {
  String _currentPath = '/';
  List<dav.File> _files = [];
  Map<dav.File, String> _lowercaseNames = {}; // Cache for search optimization
  bool _isLoading = true;
  String? _errorMessage;
  
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadFiles();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text.toLowerCase();
        });
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  List<dav.File> get _filteredFiles {
    if (_searchQuery.isEmpty) return _files;
    return _files.where((f) {
      final name = _lowercaseNames[f] ?? '';
      return name.contains(_searchQuery);
    }).toList();
  }

  Future<void> _loadFiles() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final service = ref.read(webDavServiceProvider);
      if (service == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = "WebDAV 설정 정보가 없습니다.";
        });
        return;
      }
      final files = await service.listTxtFiles(_currentPath);
      
      if (!mounted) return;
      setState(() {
        _files = files;
        _lowercaseNames = {
          for (var f in files) f: f.name?.toLowerCase() ?? ''
        };
        _isLoading = false;
        if (files.isEmpty && _currentPath != '/') {
          _errorMessage = "이 폴더에는 표시할 파일이 없습니다.";
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = "연결 오류: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      appBar: AppBar(
        title: _isSearching 
          ? _buildSearchField() 
          : Text(_currentPath, style: const TextStyle(fontSize: 14, color: Colors.black87)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        leading: _isSearching 
          ? null 
          : _currentPath != '/' ? IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Simple up directory logic
            final parts = _currentPath.split('/');
            parts.removeLast();
            setState(() => _currentPath = parts.join('/') == '' ? '/' : parts.join('/'));
            _loadFiles();
          },
        ) : null,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchController.clear();
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFiles,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6B4E3D)))
          : _errorMessage != null
              ? _buildErrorPlaceholder()
              : _filteredFiles.isEmpty
                  ? _buildEmptyPlaceholder()
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      itemCount: _filteredFiles.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 70),
                      itemBuilder: (context, index) {
                        final file = _filteredFiles[index];
                        final isDir = file.isDir ?? false;
                        
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDir ? Colors.amber.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isDir ? Icons.folder : Icons.description,
                              color: isDir ? Colors.amber[700] : Colors.blue[700],
                            ),
                          ),
                          title: Text(
                            file.name ?? 'Unknown',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: isDir 
                              ? const Text('폴더', style: TextStyle(fontSize: 12))
                              : Text('${( (file.size ?? 0) / 1024).toStringAsFixed(1)} KB', style: const TextStyle(fontSize: 12)),
                          trailing: isDir ? const Icon(Icons.chevron_right) : const Icon(Icons.download_rounded),
                          onTap: () {
                            if (isDir) {
                              setState(() => _currentPath = file.path!);
                              _loadFiles();
                            } else {
                              _downloadWithProgress(file);
                            }
                          },
                        );
                      },
                    ),
    );
  }

  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      autofocus: true,
      decoration: const InputDecoration(
        hintText: '파일 또는 폴더 검색...',
        border: InputBorder.none,
        hintStyle: TextStyle(color: Colors.black45, fontSize: 14),
      ),
      style: const TextStyle(color: Colors.black87, fontSize: 14),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 60, color: Colors.redAccent),
          const SizedBox(height: 20),
          Text(_errorMessage!, textAlign: TextAlign.center),
          TextButton(onPressed: _loadFiles, child: const Text('다시 시도'))
        ],
      ),
    );
  }

  Widget _buildEmptyPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _isSearching ? Icons.search_off : Icons.folder_open,
            size: 60,
            color: Colors.brown[200],
          ),
          const SizedBox(height: 20),
          Text(
            _isSearching ? '검색 결과가 없습니다.' : '파일이 없습니다.',
            style: const TextStyle(color: Colors.brown),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadWithProgress(dav.File file) async {
    double progress = 0;
    
    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('다운로드 중'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(file.name!, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 20),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.brown[50],
                  color: const Color(0xFF6B4E3D),
                ),
                const SizedBox(height: 10),
                Text('${(progress * 100).toInt()}%'),
              ],
            ),
          );
        }
      ),
    );

    final service = ref.read(webDavServiceProvider);
    if (service == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WebDAV 계정 설정이 필요합니다.')),
      );
      return;
    }
    
    final localPath = await service.downloadFileWithProgress(
      file.path!, 
      file.name!,
      (p) {
        // This won't directly update the dialog unless we have a logic to communicate.
        // In a real app, you might use a Provider or a more complex dialog state.
        // For simplicity, we'll try to use a ValueNotifier.
      }
    );

    // Re-implementation with ValueNotifier for dialog
    final progressNotifier = ValueNotifier<double>(0);
    
    // Replace the previous showDialog with one that uses the notifier
    Navigator.pop(context); // Close the placeholder dialog
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ValueListenableBuilder<double>(
        valueListenable: progressNotifier,
        builder: (context, value, _) {
          return AlertDialog(
            title: const Text('다운로드 중'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(file.name!, style: const TextStyle(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 20),
                LinearProgressIndicator(
                  value: value,
                  backgroundColor: Colors.brown[50],
                  color: const Color(0xFF6B4E3D),
                ),
                const SizedBox(height: 10),
                Text('${(value * 100).toInt()}%'),
              ],
            ),
          );
        }
      ),
    );

    final resultPath = await service.downloadFileWithProgress(
      file.path!, 
      file.name!,
      (p) => progressNotifier.value = p,
    );

    if (!mounted) return;
    Navigator.pop(context); // Close progress dialog

    if (resultPath != null) {
      final book = Book.fromRemote(file.name!, file.path!);
      final bookWithLocal = book.copyWith(path: resultPath);
      await ref.read(libraryProvider.notifier).addBook(bookWithLocal);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${file.name}" 책장에 추가되었습니다.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('다운로드 실패')),
      );
    }
  }
}
