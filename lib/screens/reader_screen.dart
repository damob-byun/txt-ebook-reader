import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../models/book.dart';
import '../models/reader_settings.dart';
import '../providers/reader_settings_provider.dart';
import '../providers/library_provider.dart';
import '../services/reader_engine.dart';

// ---------------------------------------------------------------------------
// Theme helpers
// ---------------------------------------------------------------------------

class _TC {
  final Color bg, text, bar;
  const _TC(this.bg, this.text, this.bar);
}

_TC _tc(ReaderTheme t) {
  switch (t) {
    case ReaderTheme.night:
      return const _TC(Color(0xFF1A1A1A), Color(0xFFBBBBBB), Color(0xEE111111));
    case ReaderTheme.sepia:
      return const _TC(Color(0xFFF4ECD8), Color(0xFF5B4636), Color(0xEE3D2B1F));
    case ReaderTheme.soft:
      return const _TC(Color(0xFFEEF3E8), Color(0xFF2D3B28), Color(0xEE2D3B28));
    case ReaderTheme.classic:
      return const _TC(Color(0xFFF8F7F2), Color(0xFF2C1E14), Color(0xEE2C1E14));
  }
}

TextStyle _ts(ReaderSettings s) => TextStyle(
  fontFamily: s.fontFamily == 'Georgia' ? 'Georgia' : null,
  fontSize: s.fontSize,
  height: s.lineSpacing,
);

// ---------------------------------------------------------------------------
// ReaderScreen
// ---------------------------------------------------------------------------

class ReaderScreen extends HookConsumerWidget {
  final Book book;
  const ReaderScreen({super.key, required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(readerSettingsProvider);
    final mq       = MediaQuery.of(context);

    // Always use the latest book state from library for bookmarks
    final library   = ref.watch(libraryProvider);
    final latestBook = library.firstWhere((b) => b.id == book.id, orElse: () => book);

    final isLoading     = useState(true);
    final isLoadingMore = useState(false);
    final allPages      = useState<List<ReaderPage>>([]);
    final totalBytes    = useState(0);
    final loadedEnd     = useState(0);
    final pageCtrl      = usePageController();
    final pageIdx       = useState(0);
    final showOverlay   = useState(false);
    final sliderVal     = useState(0.0);

    // Tracks current reading byte without triggering re-renders
    final readByte = useRef(book.lastOffset);

    final colors = _tc(settings.theme);
    final style  = _ts(settings);

    final pageW = max(100.0, mq.size.width - settings.horizontalPadding * 2);
    final pageH = max(100.0, mq.size.height - mq.padding.top - mq.padding.bottom - settings.verticalPadding * 2);

    // -----------------------------------------------------------------------
    // Load / reload (runs when font or encoding settings change)
    // -----------------------------------------------------------------------
    useEffect(() {
      final targetByte = readByte.value;

      Future<void> load() async {
        if (book.path == null || book.path!.isEmpty) {
          isLoading.value = false;
          return;
        }
        isLoading.value = true;
        try {
          final fileSz = await ReaderEngine.fileSize(book.path!);
          totalBytes.value = fileSz;

          final chunkStart = fileSz > 0
              ? (targetByte ~/ ReaderEngine.chunkBytes) * ReaderEngine.chunkBytes
              : 0;

          final (text, consumed) = await ReaderEngine.readChunk(
            book.path!, chunkStart, settings.encoding,
          );

          if (!context.mounted) return;
          if (text.isEmpty) { isLoading.value = false; return; }

          final pages = ReaderEngine.paginate(
            text: text, maxWidth: pageW, maxHeight: pageH,
            style: style,
            byteStart: chunkStart, byteEnd: chunkStart + consumed,
          );

          allPages.value  = pages;
          loadedEnd.value = chunkStart + consumed;

          int savedIdx = 0;
          if (pages.isNotEmpty) {
            for (int i = 0; i < pages.length; i++) {
              if (pages[i].byteStart <= targetByte) {
                savedIdx = i;
              } else {
                break;
              }
            }
          }

          if (fileSz > 0 && pages.isNotEmpty) {
            sliderVal.value = pages[savedIdx].byteStart / fileSz;
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (pageCtrl.hasClients && savedIdx < pages.length) {
              pageCtrl.jumpToPage(savedIdx);
              pageIdx.value = savedIdx;
            }
          });
        } catch (e) {
          debugPrint('ReaderScreen: load error: $e');
        } finally {
          if (context.mounted) isLoading.value = false;
        }
      }

      load();
      return null;
    }, [settings.fontSize, settings.fontFamily, settings.lineSpacing, settings.encoding, pageW, pageH]);

    // -----------------------------------------------------------------------
    // Load next chunk
    // -----------------------------------------------------------------------
    Future<void> loadNext() async {
      if (isLoadingMore.value) return;
      if (book.path == null) return;
      if (loadedEnd.value >= totalBytes.value) return;

      isLoadingMore.value = true;
      final startByte = loadedEnd.value;

      final (text, consumed) = await ReaderEngine.readChunk(
        book.path!, startByte, settings.encoding,
      );

      if (!context.mounted || text.isEmpty) {
        isLoadingMore.value = false;
        return;
      }

      final newPages = ReaderEngine.paginate(
        text: text, maxWidth: pageW, maxHeight: pageH,
        style: style,
        byteStart: startByte, byteEnd: startByte + consumed,
      );

      allPages.value  = [...allPages.value, ...newPages];
      loadedEnd.value = startByte + consumed;
      isLoadingMore.value = false;
    }

    // -----------------------------------------------------------------------
    // Jump to byte offset (slider or bookmark)
    // -----------------------------------------------------------------------
    Future<void> jumpToByte(int targetByte) async {
      if (book.path == null) return;

      final pages = allPages.value;
      for (int i = 0; i < pages.length; i++) {
        if (pages[i].byteStart <= targetByte && targetByte < pages[i].byteEnd) {
          pageCtrl.jumpToPage(i);
          pageIdx.value = i;
          readByte.value = targetByte;
          if (totalBytes.value > 0) sliderVal.value = targetByte / totalBytes.value;
          return;
        }
      }

      isLoading.value = true;
      final chunkStart =
          (targetByte ~/ ReaderEngine.chunkBytes) * ReaderEngine.chunkBytes;
      final (text, consumed) = await ReaderEngine.readChunk(
        book.path!, chunkStart, settings.encoding,
      );

      if (!context.mounted || text.isEmpty) {
        isLoading.value = false;
        return;
      }

      final newPages = ReaderEngine.paginate(
        text: text, maxWidth: pageW, maxHeight: pageH,
        style: style,
        byteStart: chunkStart, byteEnd: chunkStart + consumed,
      );

      allPages.value  = newPages;
      loadedEnd.value = chunkStart + consumed;
      readByte.value  = targetByte;

      int jumpIdx = 0;
      for (int i = 0; i < newPages.length; i++) {
        if (newPages[i].byteStart <= targetByte) { jumpIdx = i; }
        else { break; }
      }

      isLoading.value = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (pageCtrl.hasClients) {
          pageCtrl.jumpToPage(jumpIdx);
          pageIdx.value = jumpIdx;
        }
      });
    }

    // -----------------------------------------------------------------------
    // Page changed
    // -----------------------------------------------------------------------
    void onPageChanged(int i) {
      pageIdx.value = i;
      final pages = allPages.value;
      if (i >= pages.length) return;

      final page = pages[i];
      readByte.value = page.byteStart;
      if (totalBytes.value > 0) sliderVal.value = page.byteStart / totalBytes.value;

      final estimated = loadedEnd.value > 0 && pages.isNotEmpty
          ? (totalBytes.value * pages.length ~/ loadedEnd.value)
          : 0;

      ref.read(libraryProvider.notifier).updateBook(latestBook.copyWith(
        lastOffset: page.byteStart,
        lastRead: DateTime.now(),
        totalPages: estimated,
      ));

      if (i >= pages.length - 5) loadNext();
    }

    // -----------------------------------------------------------------------
    // UI
    // -----------------------------------------------------------------------
    final safePages = allPages.value;
    final curIdx    = pageIdx.value.clamp(0, safePages.isEmpty ? 0 : safePages.length - 1);
    final progress  = totalBytes.value > 0 ? (sliderVal.value * 100).round() : 0;

    final isBookmarked = safePages.isNotEmpty && curIdx < safePages.length &&
        latestBook.bookmarks.contains(safePages[curIdx].byteStart);

    return Scaffold(
      backgroundColor: colors.bg,
      drawer: _BookmarkDrawer(
        bookId: book.id,
        totalBytes: totalBytes.value,
        onJump: (byte) {
          Navigator.pop(context);
          jumpToByte(byte);
        },
      ),
      body: Stack(
        children: [
          // ---- Reader content ----
          SafeArea(
            child: isLoading.value
                ? Center(child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.text.withOpacity(0.4),
                  ))
                : safePages.isEmpty
                    ? Center(child: Text('텍스트를 읽을 수 없습니다.',
                        style: TextStyle(color: colors.text)))
                    : GestureDetector(
                        onTapUp: (d) {
                          final w = mq.size.width;
                          final x = d.globalPosition.dx;
                          if (x < w * 0.25) {
                            if (curIdx > 0) {
                              pageCtrl.previousPage(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOut,
                              );
                            }
                          } else if (x > w * 0.75) {
                            pageCtrl.nextPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                            );
                          } else {
                            showOverlay.value = !showOverlay.value;
                          }
                        },
                        child: PageView.builder(
                          controller: pageCtrl,
                          physics: const BouncingScrollPhysics(),
                          itemCount: safePages.length + (isLoadingMore.value ? 1 : 0),
                          onPageChanged: onPageChanged,
                          itemBuilder: (ctx, i) {
                            if (i >= safePages.length) {
                              return Center(child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colors.text.withOpacity(0.3),
                              ));
                            }
                            return Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: settings.horizontalPadding,
                                vertical: settings.verticalPadding,
                              ),
                              child: Text(
                                safePages[i].content,
                                style: style.copyWith(color: colors.text),
                                textAlign: TextAlign.justify,
                              ),
                            );
                          },
                        ),
                      ),
          ),

          // ---- Overlay ----
          if (showOverlay.value && safePages.isNotEmpty)
            _buildOverlay(
              context: context,
              ref: ref,
              colors: colors,
              latestBook: latestBook,
              safePages: safePages,
              curIdx: curIdx,
              progress: progress,
              sliderVal: sliderVal,
              totalBytes: totalBytes.value,
              showOverlay: showOverlay,
              isBookmarked: isBookmarked,
              pageCtrl: pageCtrl,
              onSettings: () {
                showOverlay.value = false;
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const _SettingsSheet(),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildOverlay({
    required BuildContext context,
    required WidgetRef ref,
    required _TC colors,
    required Book latestBook,
    required List<ReaderPage> safePages,
    required int curIdx,
    required int progress,
    required ValueNotifier<double> sliderVal,
    required int totalBytes,
    required ValueNotifier<bool> showOverlay,
    required bool isBookmarked,
    required PageController pageCtrl,
    required VoidCallback onSettings,
  }) {
    final mq      = MediaQuery.of(context);
    final curPage = safePages[curIdx];

    return Column(
      children: [
        // Top bar
        Container(
          color: colors.bar,
          padding: EdgeInsets.only(
            top: mq.padding.top + 2,
            left: 4, right: 4, bottom: 4,
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                color: Colors.white,
                onPressed: () => Navigator.of(context).pop(),
              ),
              IconButton(
                icon: const Icon(Icons.menu, size: 22),
                color: Colors.white,
                onPressed: () {
                  showOverlay.value = false;
                  Scaffold.of(context).openDrawer();
                },
              ),
              Expanded(
                child: Text(
                  latestBook.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              // Bookmark toggle
              IconButton(
                icon: Icon(
                  isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  size: 22,
                ),
                color: isBookmarked ? Colors.amber : Colors.white,
                onPressed: () {
                  final bm = List<int>.from(latestBook.bookmarks);
                  if (bm.contains(curPage.byteStart)) {
                    bm.remove(curPage.byteStart);
                  } else {
                    bm.add(curPage.byteStart);
                  }
                  ref.read(libraryProvider.notifier)
                      .updateBook(latestBook.copyWith(bookmarks: bm));
                },
              ),
              // Settings
              IconButton(
                icon: const Icon(Icons.tune, size: 22),
                color: Colors.white,
                onPressed: onSettings,
              ),
            ],
          ),
        ),

        const Spacer(),

        // Bottom bar
        Container(
          color: colors.bar,
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 10,
            bottom: mq.padding.bottom + 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SliderTheme(
                data: SliderThemeData(
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                  trackHeight: 3,
                  activeTrackColor: Colors.white70,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Colors.white,
                  overlayColor: Colors.white24,
                ),
                child: Slider(
                  value: sliderVal.value.clamp(0.0, 1.0),
                  onChanged: (v) => sliderVal.value = v,
                  onChangeEnd: (v) {
                    // Find closest loaded page
                    final targetByte = (v * totalBytes).round();
                    int closest = 0;
                    for (int i = 0; i < safePages.length; i++) {
                      if (safePages[i].byteStart <= targetByte) { closest = i; }
                      else { break; }
                    }
                    pageCtrl.jumpToPage(closest);
                  },
                ),
              ),
              Text(
                '${curIdx + 1}페이지  ·  $progress%',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Bookmark Drawer
// ---------------------------------------------------------------------------

class _BookmarkDrawer extends ConsumerWidget {
  final String bookId;
  final int totalBytes;
  final void Function(int byteOffset) onJump;

  const _BookmarkDrawer({
    required this.bookId,
    required this.totalBytes,
    required this.onJump,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    final bookIdx = library.indexWhere((b) => b.id == bookId);
    if (bookIdx < 0) return const Drawer(child: Center(child: CircularProgressIndicator()));
    final book = library[bookIdx];
    final bm = book.bookmarks;

    return Drawer(
      backgroundColor: const Color(0xFFF5F5ED),
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF6B4E3D)),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.bookmark, color: Colors.white70, size: 28),
                  const SizedBox(height: 8),
                  Text(
                    book.title,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          if (bm.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bookmark_border, size: 48, color: Colors.brown[200]),
                    const SizedBox(height: 12),
                    const Text('북마크가 없습니다.',
                        style: TextStyle(color: Colors.brown)),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: bm.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, indent: 16, endIndent: 16),
                itemBuilder: (ctx, i) {
                  final offset = bm[i];
                  final pct    = totalBytes > 0 ? (offset * 100 ~/ totalBytes) : 0;
                  return ListTile(
                    leading: const Icon(Icons.bookmark, color: Color(0xFF6B4E3D)),
                    title: Text('$pct% 위치',
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      color: Colors.red[300],
                      onPressed: () {
                        final updated = List<int>.from(bm)..remove(offset);
                        ref.read(libraryProvider.notifier)
                            .updateBook(book.copyWith(bookmarks: updated));
                      },
                    ),
                    onTap: () => onJump(offset),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Settings Bottom Sheet
// ---------------------------------------------------------------------------

class _SettingsSheet extends ConsumerWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(readerSettingsProvider);
    final n = ref.read(readerSettingsProvider.notifier);
    final mq = MediaQuery.of(context);
    final colors = _tc(s.theme); // live-update when theme changes

    final themeData = [
      (ReaderTheme.classic, const Color(0xFFF8F7F2), '클래식'),
      (ReaderTheme.sepia,   const Color(0xFFF4ECD8), '세피아'),
      (ReaderTheme.soft,    const Color(0xFFEEF3E8), '녹색'),
      (ReaderTheme.night,   const Color(0xFF1A1A1A), '야간'),
    ];
    const encodings  = ['auto', 'UTF-8', 'EUC-KR'];
    const encLabels  = ['자동',  'UTF-8', 'EUC-KR'];
    const fonts      = ['Georgia', 'system'];
    const fontLabels = ['Georgia', '기본 폰트'];

    return Container(
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: mq.viewInsets.bottom + mq.padding.bottom + 20,
        top: 12, left: 24, right: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: colors.text.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Font size
          _Row(
            label: '글자 크기',
            colors: colors,
            child: Row(
              children: [
                _IconBtn(icon: Icons.remove, colors: colors,
                    onTap: () => n.updateFontSize(s.fontSize - 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text('${s.fontSize.round()}',
                      style: TextStyle(color: colors.text,
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                _IconBtn(icon: Icons.add, colors: colors,
                    onTap: () => n.updateFontSize(s.fontSize + 1)),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Line spacing
          _Row(
            label: '줄 간격',
            colors: colors,
            child: Row(
              children: [
                Text(s.lineSpacing.toStringAsFixed(1),
                    style: TextStyle(
                        color: colors.text.withOpacity(0.7), fontSize: 12)),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 6),
                      trackHeight: 3,
                      activeTrackColor: colors.text.withOpacity(0.6),
                      inactiveTrackColor: colors.text.withOpacity(0.2),
                      thumbColor: colors.text,
                    ),
                    child: Slider(
                      value: s.lineSpacing,
                      min: 1.0, max: 3.0, divisions: 20,
                      onChanged: (v) => n.updateLineSpacing(v),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Font family
          _Row(
            label: '글꼴',
            colors: colors,
            child: Row(
              children: List.generate(fonts.length, (i) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _Chip(
                  label: fontLabels[i],
                  selected: s.fontFamily == fonts[i],
                  colors: colors,
                  onTap: () => n.updateFontFamily(fonts[i]),
                ),
              )),
            ),
          ),

          const SizedBox(height: 18),

          // Encoding
          _Row(
            label: '인코딩',
            colors: colors,
            child: Row(
              children: List.generate(encodings.length, (i) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _Chip(
                  label: encLabels[i],
                  selected: s.encoding == encodings[i],
                  colors: colors,
                  onTap: () => n.updateEncoding(encodings[i]),
                ),
              )),
            ),
          ),

          const SizedBox(height: 22),

          // Themes
          Row(
            children: [
              Text('테마',
                  style: TextStyle(
                      color: colors.text, fontWeight: FontWeight.w600)),
              const SizedBox(width: 20),
              ...themeData.map((td) => GestureDetector(
                onTap: () => n.updateTheme(td.$1),
                child: Tooltip(
                  message: td.$3,
                  child: Container(
                    width: 32, height: 32,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: td.$2,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: s.theme == td.$1
                            ? Colors.blue
                            : colors.text.withOpacity(0.3),
                        width: s.theme == td.$1 ? 2.5 : 1,
                      ),
                      boxShadow: s.theme == td.$1
                          ? [BoxShadow(
                              color: Colors.blue.withOpacity(0.3),
                              blurRadius: 4,
                            )]
                          : null,
                    ),
                  ),
                ),
              )),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small UI helpers
// ---------------------------------------------------------------------------

class _Row extends StatelessWidget {
  final String label;
  final _TC colors;
  final Widget child;
  const _Row({required this.label, required this.colors, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(label,
              style: TextStyle(
                  color: colors.text, fontWeight: FontWeight.w600)),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final _TC colors;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          border: Border.all(color: colors.text.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: colors.text),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final _TC colors;
  final VoidCallback onTap;
  const _Chip({
    required this.label, required this.selected,
    required this.colors, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? colors.text.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? colors.text : colors.text.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: colors.text, fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
