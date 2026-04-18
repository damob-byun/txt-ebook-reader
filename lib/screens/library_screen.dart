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

            // Main Bookshelf Grid
            filteredBooks.isEmpty
                ? SliverFillRemaining(
                    child: _buildEmptyState(context, isSearching.value),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, rowIndex) {
                          final startIndex = rowIndex * 3;
                          final rowItems = filteredBooks.skip(startIndex).take(3).toList();
                          
                          return Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    for (var i = 0; i < 3; i++)
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 10),
                                          child: i < rowItems.length 
                                              ? _BookItem(book: rowItems[i])
                                              : const SizedBox.shrink(),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              // The Wooden Shelf
                              Container(
                                height: 12,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.brown[400]!,
                                      Colors.brown[600]!,
                                      Colors.brown[800]!,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          );
                        },
                        childCount: (filteredBooks.length / 3).ceil(),
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
                    fontSize: 14, // Slightly smaller for better flow
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.notoSans(
                    fontSize: 11,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 14),
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
          AspectRatio(
            aspectRatio: 0.7,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(4),
                  bottomRight: Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(4, 2),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Book Spine decoration
                  Container(
                    width: 8,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.brown[800]!.withOpacity(0.5),
                          Colors.brown[100]!.withOpacity(0.2),
                        ],
                      ),
                    ),
                  ),
                  Center(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(isRecent ? 12 : 16, 8, 8, 8),
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
                  // Progress Bar at the bottom of the book
                  if (book.totalPages > 0)
                    Positioned(
                      bottom: 4,
                      left: 12,
                      right: 12,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: (book.lastOffset + 1) / book.totalPages,
                          backgroundColor: Colors.brown[50]!,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.brown[400]!),
                          minHeight: 3,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            book.title,
            style: GoogleFonts.notoSans(
              fontSize: isRecent ? 10 : 12,
              fontWeight: FontWeight.w600,
              color: Colors.brown[900],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (isRecent && book.totalPages > 0)
             Text(
              '${((book.lastOffset + 1) / book.totalPages * 100).toInt()}% 읽음',
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
