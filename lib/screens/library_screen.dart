import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/library_provider.dart';
import '../providers/webdav_account_provider.dart';
import '../models/book.dart';
import 'reader_screen.dart';
import 'webdav_browser_screen.dart';
import 'webdav_login_screen.dart';
import 'settings_screen.dart';
import 'dart:io';
import 'package:path/path.dart' as p;

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showCloudSelection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                '클라우드 서비스 선택',
                style: TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dns_outlined, color: Colors.blue),
              title: Text('WebDAV', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
              subtitle: const Text('개인 NAS 또는 서버 연결'),
              onTap: () {
                Navigator.pop(context);
                final account = ref.read(webDavAccountProvider);
                if (account == null || !account.isValid) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const WebDavLoginScreen()),
                  );
                } else {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const WebDavBrowserScreen()),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_to_drive, color: Colors.green),
              title: Text('Google Drive', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
              subtitle: const Text('준비 중입니다'),
              enabled: false,
            ),
            ListTile(
              leading: const Icon(Icons.cloud_outlined, color: Colors.blueAccent),
              title: Text('Dropbox', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
              subtitle: const Text('준비 중입니다'),
              enabled: false,
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final books = ref.watch(libraryProvider);
    final filteredBooks = _searchQuery.isEmpty
        ? books
        : books.where((b) => b.title.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: '책 제목 검색...',
                  hintStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                  border: InputBorder.none,
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              )
            : Text(
                'MoonViewer',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchQuery = '';
                  _searchController.clear();
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.cloud_download_outlined),
            onPressed: () => _showCloudSelection(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      drawer: _buildDrawer(context, isDark),
      body: books.isEmpty 
          ? _buildEmptyState(context, isDark) 
          : ListView(
              padding: EdgeInsets.zero,
              children: [
                if (!_isSearching) ...[
                  _buildSectionTitle('최근 읽은 책', isDark),
                  _buildRecentList(books.take(5).toList()),
                  _buildFilePickerCard(context),
                  _buildSectionTitle('전체 책장', isDark),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.65,
                      crossAxisSpacing: 15,
                      mainAxisSpacing: 20,
                    ),
                    itemCount: filteredBooks.length,
                    itemBuilder: (context, index) {
                      return _BookItem(book: filteredBooks[index]);
                    },
                  ),
                ),
                const SizedBox(height: 50),
              ],
            ),
    );
  }

  Widget _buildDrawer(BuildContext context, bool isDark) {
    return Drawer(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: isDark ? Colors.black26 : const Color(0xFF6B4E3D)),
            child: const Center(
              child: Text(
                'MoonViewer',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.settings, color: isDark ? Colors.white70 : Colors.black87),
            title: Text('전체 설정', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.cloud_sync, color: isDark ? Colors.white70 : Colors.black87),
            title: Text('WebDAV 계정 설정', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WebDavLoginScreen()),
              );
            },
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'v1.0.0',
              style: TextStyle(color: isDark ? Colors.white24 : Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.brown[200] : Colors.brown[800],
        ),
      ),
    );
  }

  Widget _buildRecentList(List<Book> books) {
    if (books.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 160,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        scrollDirection: Axis.horizontal,
        itemCount: books.length,
        itemBuilder: (context, index) {
          final book = books[index];
          return Container(
            width: 100,
            margin: const EdgeInsets.symmetric(horizontal: 5),
            child: _BookItem(book: book, isSmall: true),
          );
        },
      ),
    );
  }

  Widget _buildFilePickerCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A6572), Color(0xFF344955)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _pickLocalFile(context),
        child: const Row(
          children: [
            Icon(Icons.folder_open_outlined, size: 36, color: Colors.white70),
            SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '기기에서 탐색하기',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '내 기기의 .txt 파일 가져오기',
                    style: TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ],
              ),
            ),
            Icon(Icons.add_circle_outline, size: 24, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  Future<void> _pickLocalFile(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final name = result.files.single.name;
        
        // Add to library
        final book = Book(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: p.basenameWithoutExtension(name),
          path: path,
          lastRead: DateTime.now(),
        );
        
        await ref.read(libraryProvider.notifier).addBook(book);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"${book.title}"이(가) 책장에 추가되었습니다.')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('파일을 가져오는 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.library_books_outlined, size: 60, color: isDark ? Colors.brown[300] : Colors.brown[200]),
          const SizedBox(height: 20),
          Text(
            '책장이 비어있습니다.',
            style: TextStyle(fontSize: 16, color: isDark ? Colors.brown[100] : Colors.brown),
          ),
          const SizedBox(height: 15),
          ElevatedButton.icon(
            onPressed: () => _pickLocalFile(context),
            icon: const Icon(Icons.folder_open),
            label: const Text('기기에서 탐색하기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? const Color(0xFF6B4E3D) : const Color(0xFF4A6572),
              foregroundColor: Colors.white,
            ),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WebDavBrowserScreen()),
              );
            },
            icon: const Icon(Icons.cloud_download, size: 16),
            label: const Text('WebDAV 가기'),
            style: TextButton.styleFrom(
              foregroundColor: isDark ? Colors.brown[200] : Colors.brown,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 60, color: isDark ? Colors.white24 : Colors.brown[200]),
          const SizedBox(height: 15),
          Text(
            '검색 결과가 없습니다.',
            style: TextStyle(color: isDark ? Colors.white54 : Colors.brown),
          ),
        ],
      ),
    );
  }
}

class _BookItem extends ConsumerWidget {
  final Book book;
  final bool isSmall;

  const _BookItem({required this.book, this.isSmall = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = book.totalBytes > 0 
        ? ((book.lastOffset) / book.totalBytes * 100).toInt() 
        : 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ReaderScreen(book: book)),
        );
      },
      onLongPress: () => _showDeleteDialog(context, ref),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                    blurRadius: 4,
                    offset: const Offset(1, 1),
                  ),
                ],
                border: Border.all(color: isDark ? Colors.white12 : Colors.brown[100]!, width: 0.5),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(6.0),
                      child: Text(
                        book.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isSmall ? 9 : 10,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : Colors.brown[800],
                          fontFamily: 'Georgia',
                        ),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 2,
                      color: isDark ? Colors.white10 : Colors.brown[50],
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: (progress / 100).clamp(0.0, 1.0),
                        child: Container(color: isDark ? Colors.amber[700] : Colors.brown[400]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            book.title,
            style: TextStyle(
              fontSize: isSmall ? 9 : 10,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white60 : Colors.brown[900],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('책 삭제'),
        content: Text('"${book.title}"을(를) 책장에서 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              ref.read(libraryProvider.notifier).removeBook(book.id);
              Navigator.pop(context);
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
