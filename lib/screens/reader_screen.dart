import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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
    final bookText = useState<String>('');
    final chapters = useState<List<ReaderChapter>>([]);
    final isLoading = useState(true);
    
    // Lazy Pagination State
    final currentOffset = useState(book.lastOffset); // For lazy mode, this is a char offset, not page index
    final pageCache = useState<Map<int, int>>({0: 0}); // Index -> StartOffset
    final estimatedTotalPages = useState(100);
    
    final pageController = usePageController(initialPage: 0);

    // Initial load
    useEffect(() {
      Future<void> loadBook() async {
        if (book.path == null) return;
        final file = File(book.path!);
        if (!await file.exists()) return;

        final bytes = await file.readAsBytes();
        String text;

        if (settings.encoding == 'auto') {
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
        
        bookText.value = text;
        chapters.value = ReaderEngine.detectChapters(text);
        
        // Estimate total pages (approx 800 chars per page)
        estimatedTotalPages.value = (text.length / 800).ceil().clamp(1, 100000);
        
        // Find starting index for the saved offset
        pageCache.value = {0: book.lastOffset};
        currentOffset.value = book.lastOffset;

        isLoading.value = false;
      }

      loadBook();
      return null;
    }, [settings.encoding]);

    // Theme colors
    final colors = _getThemeColors(settings.theme);

    return Scaffold(
      backgroundColor: colors.background,
      drawer: _buildDrawer(context, ref, bookText.value, chapters.value, pageController, showOverlay, pageCache, currentOffset),
      body: Stack(
        children: [
          if (isLoading.value)
            const Center(child: CircularProgressIndicator())
          else
            GestureDetector(
              onTap: () => showOverlay.value = !showOverlay.value,
              child: PageView.builder(
                controller: pageController,
                itemCount: estimatedTotalPages.value,
                onPageChanged: (index) {
                  final offset = pageCache.value[index] ?? currentOffset.value;
                  currentOffset.value = offset;
                  
                  // Auto bookmark (Save offset)
                  ref.read(libraryProvider.notifier).updateBook(
                        book.copyWith(lastOffset: offset, lastRead: DateTime.now()),
                      );
                },
                itemBuilder: (context, index) {
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final availableWidth = constraints.maxWidth - (settings.horizontalPadding * 2);
                      final availableHeight = constraints.maxHeight - (settings.verticalPadding * 2) - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom;
                      
                      // Get start offset for this index
                      int startOffset = pageCache.value[index] ?? 0;
                      
                      // If we don't have it, and it's the next one, calculate it from the previous one
                      if (!pageCache.value.containsKey(index) && pageCache.value.containsKey(index - 1)) {
                        final prevOffset = pageCache.value[index - 1]!;
                        // Calculate synchronously for smooth flow if possible
                        final prevPage = ReaderEngine.findPageAtOffset(
                          text: bookText.value,
                          startOffset: prevOffset,
                          maxWidth: availableWidth,
                          maxHeight: availableHeight,
                          style: _getStyle(settings),
                        );
                        startOffset = prevPage.endIndex;
                        
                        // Update cache safely in background
                         Future.microtask(() {
                           if (!pageCache.value.containsKey(index)) {
                             final newCache = Map<int, int>.from(pageCache.value);
                             newCache[index] = startOffset;
                             pageCache.value = newCache;
                           }
                         });
                      }

                      final page = ReaderEngine.findPageAtOffset(
                        text: bookText.value,
                        startOffset: startOffset,
                        maxWidth: availableWidth,
                        maxHeight: availableHeight,
                        style: _getStyle(settings),
                      );

                      return Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: settings.horizontalPadding,
                          vertical: settings.verticalPadding,
                        ),
                        child: SafeArea(
                          child: Text(
                            page.content,
                            style: _getStyle(settings).copyWith(color: colors.text),
                            textAlign: TextAlign.justify,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          
          // Overlay UI
          if (showOverlay.value) _buildOverlay(context, ref, settings, colors, bookText.value.length, pageController, showOverlay, currentOffset, pageCache),
        ],
      ),
    );
  }

  Widget _buildOverlay(
    BuildContext context, 
    WidgetRef ref, 
    ReaderSettings settings, 
    _ThemeColors colors,
    int totalChars,
    PageController pageController,
    ValueNotifier<bool> showOverlay,
    ValueNotifier<int> currentOffset,
    ValueNotifier<Map<int, int>> pageCache,
  ) {
    final progress = totalChars > 0 ? currentOffset.value / totalChars : 0.0;
    
    return Column(
      children: [
        // Top Bar
        Container(
          color: const Color(0xCC000000),
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
                  style: GoogleFonts.notoSans(color: Colors.white, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(
                  book.bookmarks.contains(currentOffset.value) ? Icons.bookmark : Icons.bookmark_border,
                  color: Colors.white,
                ),
                onPressed: () {
                  final newBookmarks = List<int>.from(book.bookmarks);
                  if (newBookmarks.contains(currentOffset.value)) {
                    newBookmarks.remove(currentOffset.value);
                  } else {
                    newBookmarks.add(currentOffset.value);
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
          color: const Color(0xCC000000), // black with 0.8 opacity
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   // Progress Slider (Based on Character Offset)
                  Row(
                    children: [
                      Text('${(progress * 100).toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white, fontSize: 12)),
                      Expanded(
                        child: Slider(
                          value: progress.clamp(0.0, 1.0),
                          onChanged: (v) {
                            final target = (v * totalChars).toInt();
                            pageCache.value = {0: target};
                            pageController.jumpToPage(0);
                            currentOffset.value = target;
                          },
                        ),
                      ),
                      Text('${(totalChars / 1024).toInt()}KB', style: const TextStyle(color: Colors.white, fontSize: 12)),
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
                          onChanged: (v) {
                             ref.read(readerSettingsProvider.notifier).updateFontSize(v);
                             // Need to reset cache on font change as it affects pagination
                             pageCache.value = {0: currentOffset.value};
                             pageController.jumpToPage(0);
                          },
                        ),
                      ),
                      Text(settings.fontSize.toInt().toString(), style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Theme & Encoding selectors (already simplified)
                  _buildEncodingAndThemeRows(ref, settings),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEncodingAndThemeRows(WidgetRef ref, ReaderSettings settings) {
     return Column(
       children: [
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
     );
  }

  Widget _buildDrawer(
    BuildContext context, 
    WidgetRef ref, 
    String text, 
    List<ReaderChapter> chapters, 
    PageController pageController,
    ValueNotifier<bool> showOverlay,
    ValueNotifier<Map<int, int>> pageCache,
    ValueNotifier<int> currentOffset,
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
                          pageCache.value = {0: chapter.offset};
                          pageController.jumpToPage(0);
                          currentOffset.value = chapter.offset;
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
                      final bOffset = book.bookmarks[index];
                      return ListTile(
                        leading: const Icon(Icons.bookmark, color: Color(0xFF6B4E3D)),
                        title: Text('위치: ${(bOffset / text.length * 100).toStringAsFixed(1)}%'),
                        subtitle: Text(text.substring(bOffset, (bOffset + 40).clamp(0, text.length)).replaceAll('\n', ' ')),
                        onTap: () {
                          pageCache.value = {0: bOffset};
                          pageController.jumpToPage(0);
                          currentOffset.value = bOffset;
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
