import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/library_provider.dart';
import '../models/book.dart';
import 'reader_screen.dart';
import 'webdav_browser_screen.dart';

class LibraryScreen extends HookConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(libraryProvider);
    final isSearching = useState(false);
    final searchQuery = useState('');

    final filteredBooks = searchQuery.value.isEmpty
        ? books
        : books.where((b) => b.title.toLowerCase().contains(searchQuery.value.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      appBar: AppBar(
        title: isSearching.value
            ? TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '제목 검색...',
                  border: InputBorder.none,
                ),
                onChanged: (v) => searchQuery.value = v,
              )
            : Text(
                'MoonViewer',
                style: GoogleFonts.lora(fontWeight: FontWeight.bold),
              ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(isSearching.value ? Icons.close : Icons.search),
            onPressed: () {
              isSearching.value = !isSearching.value;
              if (!isSearching.value) searchQuery.value = '';
            },
          ),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            if (!isSearching.value) ...[
              // Explore & Quick Actions
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildActionCard(
                          context,
                          title: 'WebDAV 탐색',
                          subtitle: '원격 서버에서 책 가져오기',
                          icon: Icons.cloud_outlined,
                          color: const Color(0xFF6B4E3D),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const WebDavBrowserScreen()),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Recent Books Section
              if (books.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                    child: Text(
                      '최근 읽은 책',
                      style: GoogleFonts.notoSans(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.brown[900],
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 180,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      scrollDirection: Axis.horizontal,
                      itemCount: books.take(5).length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: SizedBox(
                            width: 100,
                            child: _BookItem(book: books[index], isRecent: true),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],

              // All Books Section Title
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 30, 20, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '나의 서재',
                        style: GoogleFonts.notoSans(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.brown[900],
                        ),
                      ),
                      Text(
                        '총 ${books.length}권',
                        style: GoogleFonts.notoSans(fontSize: 12, color: Colors.brown[400]),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Main Grid
            filteredBooks.isEmpty
                ? SliverFillRemaining(
                    child: _buildEmptyState(context, isSearching.value),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.all(20),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.65,
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 30,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _BookItem(book: filteredBooks[index]),
                        childCount: filteredBooks.length,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.notoSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.notoSans(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isSearching) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearching ? Icons.search_off : Icons.library_books_outlined,
            size: 80,
            color: Colors.brown[200],
          ),
          const SizedBox(height: 20),
          Text(
            isSearching ? '검색 결과가 없습니다.' : '책장이 비어있습니다.',
            style: GoogleFonts.notoSans(fontSize: 18, color: Colors.brown[400]),
          ),
          if (!isSearching) ...[
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
        ],
      ),
    );
  }
}

class _BookItem extends ConsumerWidget {
  final Book book;
  final bool isRecent;

  const _BookItem({required this.book, this.isRecent = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ReaderScreen(book: book)),
        );
      },
      onLongPress: isRecent ? null : () => _showDeleteDialog(context, ref),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(4, 4),
                  ),
                ],
                border: Border.all(color: Colors.brown[100]!, width: 0.5),
              ),
              child: Stack(
                children: [
                   Center(
                    child: Padding(
                      padding: EdgeInsets.all(isRecent ? 8.0 : 12.0),
                      child: Text(
                        book.title,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.notoSans(
                          fontSize: isRecent ? 10 : 12,
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
                    child: Container(
                      height: 4,
                      color: Colors.brown[100],
                    ),
                  ),
                  if (book.totalPages > 0)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final progress = (book.lastOffset + 1) / book.totalPages;
                          return Container(
                            height: 4,
                            width: constraints.maxWidth * progress.clamp(0.0, 1.0),
                            color: Colors.brown[400],
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            book.title,
            style: GoogleFonts.notoSans(
              fontSize: isRecent ? 10 : 12,
              fontWeight: FontWeight.w500,
              color: Colors.brown[900],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (isRecent && book.totalPages > 0)
             Text(
              '${((book.lastOffset + 1) / book.totalPages * 100).toInt()}%',
              style: GoogleFonts.notoSans(
                fontSize: 9,
                color: Colors.brown[400],
              ),
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
