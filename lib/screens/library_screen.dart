import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/library_provider.dart';
import '../models/book.dart';
import 'reader_screen.dart';
import 'webdav_browser_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final books = ref.watch(libraryProvider);
    final recentBooks = books.take(5).toList();

    final filteredBooks = _searchQuery.isEmpty
        ? books
        : books.where((b) => b.title.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '제목 검색...',
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              )
            : const Text(
                'MoonViewer',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Georgia', // Premium system serif
                ),
              ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchQuery = '';
                  _searchController.clear();
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.cloud_download_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WebDavBrowserScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: books.isEmpty
            ? _buildEmptyState(context)
            : CustomScrollView(
                slivers: [
                  if (!_isSearching && recentBooks.isNotEmpty) ...[
                    _buildSliverTitle('최근 읽은 책'),
                    SliverToBoxAdapter(
                      child: _buildRecentList(recentBooks),
                    ),
                  ],
                  if (!_isSearching) ...[
                    SliverToBoxAdapter(
                      child: _buildExploreCard(context),
                    ),
                    _buildSliverTitle('전체 책장'),
                  ],
                  if (filteredBooks.isEmpty && _isSearching)
                    SliverFillRemaining(
                      child: _buildNoResultsState(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.6,
                          crossAxisSpacing: 15,
                          mainAxisSpacing: 20,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            return _BookItem(book: filteredBooks[index]);
                          },
                          childCount: filteredBooks.length,
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 30)),
                ],
              ),
      ),
    );
  }

  Widget _buildSliverTitle(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.brown[800],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentList(List<Book> books) {
    return SizedBox(
      height: 180,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        scrollDirection: Axis.horizontal,
        itemCount: books.length,
        itemBuilder: (context, index) {
          final book = books[index];
          return Container(
            width: 110,
            margin: const EdgeInsets.symmetric(horizontal: 5),
            child: _BookItem(book: book, isSmall: true),
          );
        },
      ),
    );
  }

  Widget _buildExploreCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6B4E3D), Color(0xFF8D6E63)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.brown.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.explore_outlined, size: 40, color: Colors.white70),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'WebDAV 탐색하기',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  '클라우드에서 새로운 책을 가져오세요',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, color: Colors.white),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WebDavBrowserScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.library_books_outlined, size: 80, color: Colors.brown[200]),
          const SizedBox(height: 20),
          Text(
            '책장이 비어있습니다.',
            style: TextStyle(fontSize: 18, color: Colors.brown[400]),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WebDavBrowserScreen()),
              );
            },
            icon: const Icon(Icons.cloud_download),
            label: const Text('WebDAV에서 가져오기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B4E3D),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 60, color: Colors.brown[200]),
          const SizedBox(height: 15),
          Text(
            '검색 결과가 없습니다.',
            style: TextStyle(color: Colors.brown[400]),
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
    final progress = book.totalPages > 0 
        ? ((book.lastOffset + 1) / book.totalPages * 100).toInt() 
        : 0;

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
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 5,
                    offset: const Offset(2, 2),
                  ),
                ],
                border: Border.all(color: Colors.brown[100]!, width: 0.5),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        book.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isSmall ? 10 : 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.brown[800],
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
                    child: Column(
                      children: [
                        if (book.totalPages > 0)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  '$progress%',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.brown[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Container(
                          height: 3,
                          color: Colors.brown[50],
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: (progress / 100).clamp(0.0, 1.0),
                              child: Container(color: Colors.brown[400]),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            book.title,
            style: TextStyle(
              fontSize: isSmall ? 10 : 11,
              fontWeight: FontWeight.w500,
              color: Colors.brown[900],
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
