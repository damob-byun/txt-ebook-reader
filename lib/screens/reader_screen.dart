import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:charset_converter/charset_converter.dart';
import '../models/book.dart';
import '../models/reader_settings.dart';
import '../providers/reader_settings_provider.dart';
import '../providers/library_provider.dart';
import '../services/reader_engine.dart';

class ReaderScreen extends HookConsumerWidget {
  final Book book;

  const ReaderScreen({super.key, required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(readerSettingsProvider);
    final showOverlay = useState(false);
    final pages = useState<List<ReaderPage>>([]);
    final chapters = useState<List<ReaderChapter>>([]);
    final isLoading = useState(true);
    final pageController = usePageController(initialPage: book.lastOffset);
    final currentPage = useState(book.lastOffset);

    // Initial load and pagination
    useEffect(() {
      Future<void> loadBook() async {
        if (book.path == null) return;
        final file = File(book.path!);
        if (!await file.exists()) return;

        final bytes = await file.readAsBytes();
        String text;

        if (settings.encoding == 'auto') {
          // Auto detection: try UTF-8 first, then CP949
          try {
            text = utf8.decode(bytes);
          } catch (_) {
            try {
              text = await CharsetConverter.decode('cp949', bytes);
            } catch (e) {
              text = 'Decoding Error: $e';
            }
          }
        } else {
          try {
            text = await CharsetConverter.decode(settings.encoding, bytes);
          } catch (e) {
            text = 'Decoding Error ($settings.encoding): $e';
          }
        }
        
        // Measure constraints for pagination
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final size = MediaQuery.of(context).size;
          final padding = MediaQuery.of(context).padding;
          final availableWidth = size.width - (settings.horizontalPadding * 2);
          final availableHeight = size.height - (settings.verticalPadding * 2) - padding.top - padding.bottom;

          final paginatedPages = ReaderEngine.paginate(
            text: text,
            maxWidth: availableWidth,
            maxHeight: availableHeight,
            style: _getStyle(settings),
          );

          pages.value = paginatedPages;
          chapters.value = ReaderEngine.detectChapters(text);
          isLoading.value = false;
          
          // Update total pages in library
          ref.read(libraryProvider.notifier).updateBook(
                book.copyWith(totalPages: paginatedPages.length),
              );

          // Jump to last saved page if valid
          if (book.lastOffset < paginatedPages.length) {
            pageController.jumpToPage(book.lastOffset);
            currentPage.value = book.lastOffset;
          }
        });
      }

      loadBook();
      return null;
    }, [settings.fontSize, settings.fontFamily]);

    // Theme colors
    final colors = _getThemeColors(settings.theme);

    return Scaffold(
      backgroundColor: colors.background,
      drawer: _buildDrawer(context, ref, pages.value, chapters.value, pageController, showOverlay),
      body: Stack(
        children: [
          if (isLoading.value)
            const Center(child: CircularProgressIndicator())
          else
            GestureDetector(
              onTap: () => showOverlay.value = !showOverlay.value,
              child: PageView.builder(
                controller: pageController,
                itemCount: pages.value.length,
                onPageChanged: (index) {
                  currentPage.value = index;
                  // Auto bookmark
                  ref.read(libraryProvider.notifier).updateBook(
                        book.copyWith(lastOffset: index, lastRead: DateTime.now()),
                      );
                },
                itemBuilder: (context, index) {
                  return Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: settings.horizontalPadding,
                      vertical: settings.verticalPadding,
                    ),
                    child: SafeArea(
                      child: Text(
                        pages.value[index].content,
                        style: _getStyle(settings).copyWith(color: colors.text),
                        textAlign: TextAlign.justify,
                      ),
                    ),
                  );
                },
              ),
            ),
          
          // Overlay UI
          if (showOverlay.value) _buildOverlay(context, ref, settings, colors, pages.value.length, pageController, showOverlay, currentPage),
        ],
      ),
    );
  }

  Widget _buildOverlay(
    BuildContext context, 
    WidgetRef ref, 
    ReaderSettings settings, 
    _ThemeColors colors,
    int totalPages,
    PageController pageController,
    ValueNotifier<bool> showOverlay,
    ValueNotifier<int> currentPage,
  ) {
    return Column(
      children: [
        // Top Bar
        Container(
          color: Colors.black.withOpacity(0.8),
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top, left: 16, right: 16, bottom: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
              Expanded(
                child: Text(
                  book.title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(
                  book.bookmarks.contains(currentPage.value) ? Icons.bookmark : Icons.bookmark_border,
                  color: Colors.white,
                ),
                onPressed: () {
                  final newBookmarks = List<int>.from(book.bookmarks);
                  if (newBookmarks.contains(currentPage.value)) {
                    newBookmarks.remove(currentPage.value);
                  } else {
                    newBookmarks.add(currentPage.value);
                  }
                  ref.read(libraryProvider.notifier).updateBook(book.copyWith(bookmarks: newBookmarks));
                },
              ),
            ],
          ),
        ),
        const Spacer(),
        // Bottom Bar
        Container(
          color: Colors.black.withOpacity(0.8),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   // Progress Slider
                  Row(
                    children: [
                      Text('${currentPage.value + 1}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                      Expanded(
                        child: Slider(
                          value: currentPage.value.toDouble(),
                          min: 0,
                          max: (totalPages - 1).toDouble().clamp(0, double.infinity),
                          onChanged: (v) {
                            pageController.jumpToPage(v.toInt());
                            currentPage.value = v.toInt();
                          },
                        ),
                      ),
                      Text('$totalPages', style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Font Size Slider
                  Row(
                    children: [
                      const Icon(Icons.text_fields, color: Colors.white, size: 20),
                      Expanded(
                        child: Slider(
                          value: settings.fontSize,
                          min: 12,
                          max: 40,
                          onChanged: (v) => ref.read(readerSettingsProvider.notifier).updateFontSize(v),
                        ),
                      ),
                      Text(settings.fontSize.toInt().toString(), style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Encoding Selector
                  Row(
                    children: [
                       const Text('인코딩: ', style: TextStyle(color: Colors.white, fontSize: 12)),
                       const SizedBox(width: 8),
                       Expanded(
                         child: SingleChildScrollView(
                           scrollDirection: Axis.horizontal,
                           child: Row(
                             children: [
                               _buildEncodingChip(ref, settings, 'auto', '자동 감지'),
                               _buildEncodingChip(ref, settings, 'utf-8', 'UTF-8'),
                               _buildEncodingChip(ref, settings, 'cp949', 'CP949'),
                             ],
                           ),
                         ),
                       ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Theme Switcher
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: ReaderTheme.values.map((t) {
                      final themeColor = _getThemeColors(t);
                      return GestureDetector(
                        onTap: () => ref.read(readerSettingsProvider.notifier).updateTheme(t),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: themeColor.background,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: settings.theme == t ? Colors.blue : Colors.grey,
                              width: settings.theme == t ? 3 : 1,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDrawer(
    BuildContext context, 
    WidgetRef ref, 
    List<ReaderPage> pages, 
    List<ReaderChapter> chapters, 
    PageController pageController,
    ValueNotifier<bool> showOverlay,
  ) {
    return DefaultTabController(
      length: 2,
      child: Drawer(
        backgroundColor: const Color(0xFFF5F5ED),
        child: Column(
          children: [
            Container(
              height: 150,
              color: const Color(0xFF6B4E3D),
              alignment: Alignment.bottomLeft,
              padding: const EdgeInsets.all(20),
              child: Text(
                book.title,
                style: GoogleFonts.lora(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const TabBar(
              labelColor: Color(0xFF6B4E3D),
              indicatorColor: Color(0xFF6B4E3D),
              tabs: [
                Tab(text: '목차'),
                Tab(text: '책갈피'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // Chapter List
                  ListView.builder(
                    itemCount: chapters.length,
                    itemBuilder: (context, index) {
                      final chapter = chapters[index];
                      return ListTile(
                        title: Text(chapter.title, style: const TextStyle(fontSize: 14)),
                        onTap: () {
                          final pageIdx = _getPageForOffset(pages, chapter.offset);
                          pageController.jumpToPage(pageIdx);
                          Navigator.pop(context);
                          showOverlay.value = false;
                        },
                      );
                    },
                  ),
                  // Bookmark List
                  ListView.builder(
                    itemCount: book.bookmarks.length,
                    itemBuilder: (context, index) {
                      final bPageIdx = book.bookmarks[index];
                      return ListTile(
                        leading: const Icon(Icons.bookmark, color: Color(0xFF6B4E3D)),
                        title: Text('페이지 ${bPageIdx + 1}'),
                        subtitle: Text('${pages[bPageIdx].content.substring(0, 30).replaceAll('\n', ' ')}...'),
                        onTap: () {
                          pageController.jumpToPage(bPageIdx);
                          Navigator.pop(context);
                          showOverlay.value = false;
                        },
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () {
                            final newBookmarks = List<int>.from(book.bookmarks);
                            newBookmarks.removeAt(index);
                            ref.read(libraryProvider.notifier).updateBook(book.copyWith(bookmarks: newBookmarks));
                            Navigator.pop(context);
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _getPageForOffset(List<ReaderPage> pages, int offset) {
    for (int i = 0; i < pages.length; i++) {
      if (offset >= pages[i].startIndex && offset < pages[i].endIndex) {
        return i;
      }
    }
    return 0;
  }

  Widget _buildEncodingChip(WidgetRef ref, ReaderSettings settings, String value, String label) {
    final isSelected = settings.encoding == value;
    return GestureDetector(
      onTap: () => ref.read(readerSettingsProvider.notifier).updateEncoding(value),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey[800],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  TextStyle _getStyle(ReaderSettings settings) {
    return GoogleFonts.getFont(
      settings.fontFamily,
      fontSize: settings.fontSize,
      height: settings.lineSpacing,
    );
  }

  _ThemeColors _getThemeColors(ReaderTheme theme) {
    switch (theme) {
      case ReaderTheme.classic:
        return _ThemeColors(background: const Color(0xFFF5F5ED), text: const Color(0xFF2C1E14));
      case ReaderTheme.night:
        return _ThemeColors(background: const Color(0xFF1A1A1A), text: const Color(0xFFB0B0B0));
      case ReaderTheme.sepia:
        return _ThemeColors(background: const Color(0xFFF4ECD8), text: const Color(0xFF5B4636));
      case ReaderTheme.soft:
        return _ThemeColors(background: const Color(0xFFE8F5E9), text: const Color(0xFF2E4D2E));
    }
  }
}

class _ThemeColors {
  final Color background;
  final Color text;
  _ThemeColors({required this.background, required this.text});
}
