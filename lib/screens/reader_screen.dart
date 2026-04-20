import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../models/book.dart';
import '../models/reader_settings.dart';
import '../providers/reader_settings_provider.dart';
import '../providers/library_provider.dart';
import '../services/reader_engine.dart';
import '../providers/app_settings_provider.dart';
import '../models/app_settings.dart';
import 'package:perfect_volume_control/perfect_volume_control.dart';

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

  Widget _buildPage(ReaderPage page, ReaderSettings settings, _TC colors, TextStyle style) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: settings.horizontalPadding,
        vertical: settings.verticalPadding,
      ),
      child: Text(
        page.content,
        style: style.copyWith(color: colors.text),
        textAlign: TextAlign.justify,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(readerSettingsProvider);
    final appSettings = ref.watch(appSettingsProvider);
    final mq = MediaQuery.of(context);
    final scaffoldKey = useMemoized(() => GlobalKey<ScaffoldState>());

    // Always use the latest book state from library for bookmarks
    final library = ref.watch(libraryProvider);
    final latestBook = library.firstWhere(
      (b) => b.id == book.id,
      orElse: () => book,
    );

    final isLoading = useState(true);
    final isLoadingMore = useState(false);
    final allPages = useState<List<ReaderPage>>([]);
    final totalBytes = useState(0);
    final loadedEnd = useState(0);
    final pageCtrl = usePageController();
    final scrollCtrl = useScrollController();
    final pageIdx = useState(0);
    final showOverlay = useState(false);
    final sliderVal = useState(0.0);
    final isDragging = useState(false);

    // Tracks current reading byte without triggering re-renders
    final readByte = useRef(book.lastOffset);
    final jumpTimer = useRef<Timer?>(null);
    final curIdxRef = useRef(0);
    final lastSafePagesRef = useRef<List<ReaderPage>>([]);

    // Automatic Two-Page Mode detection (First time only)
    useEffect(() {
      if (settings.useTwoPageMode == null) {
        if (mq.size.width > 900) {
          ref.read(readerSettingsProvider.notifier).updateTwoPageMode(true);
        } else {
          ref.read(readerSettingsProvider.notifier).updateTwoPageMode(false);
        }
      }
      return null;
    }, []);

    final isTwoPage = settings.useTwoPageMode ?? (mq.size.width > 900);

    final colors = _tc(settings.theme);
    final style = _ts(settings);


    // Page dimensions
    // In two-page mode, each logical page has half the width (minus a small gap)
    final safeAreaH = max(100.0, mq.size.height - mq.padding.top - mq.padding.bottom);
    final totalW = max(100.0, mq.size.width - settings.horizontalPadding * 2);
    final pageW = isTwoPage ? (totalW / 2) - 10 : totalW;
    
    final pageH = max(
      100.0,
      mq.size.height -
          mq.padding.top -
          mq.padding.bottom -
          settings.verticalPadding * 2,
    );

    // -----------------------------------------------------------------------
    // Load / reload (runs when font or encoding settings change)
    // -----------------------------------------------------------------------
    useEffect(
      () {
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
                ? (targetByte ~/ ReaderEngine.chunkBytes) *
                      ReaderEngine.chunkBytes
                : 0;

            final (text, consumed) = await ReaderEngine.readChunk(
              book.path!,
              chunkStart,
              settings.encoding,
            );

            if (!context.mounted) return;
            if (text.isEmpty) {
              isLoading.value = false;
              return;
            }

            final pages = ReaderEngine.paginate(
              text: text,
              maxWidth: pageW,
              maxHeight: pageH,
              style: style,
              byteStart: chunkStart,
              byteEnd: chunkStart + consumed,
            );

            allPages.value = pages;
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
              int displayIdx = isTwoPage ? savedIdx ~/ 2 : savedIdx;
              if (appSettings.useScrollMode) {
                if (scrollCtrl.hasClients) {
                  scrollCtrl.jumpTo(displayIdx * safeAreaH);
                }
              } else {
                if (pageCtrl.hasClients) {
                  pageCtrl.jumpToPage(displayIdx);
                }
              }
              pageIdx.value = savedIdx;
            });
          } catch (e) {
            debugPrint('ReaderScreen: load error: $e');
          } finally {
            if (context.mounted) isLoading.value = false;
          }
        }

        load();
        return null;
      },
      [
        settings.fontSize,
        settings.fontFamily,
        settings.lineSpacing,
        settings.encoding,
        pageW,
        pageH,
        appSettings.useScrollMode, // Re-paginate if scroll mode changes layout needs
      ],
    );

    final safePages = allPages.value;
    lastSafePagesRef.value = safePages;
    final curIdx = pageIdx.value.clamp(0, max(0, safePages.length - 1)).toInt();
    curIdxRef.value = curIdx;


    void triggerPageTurn(bool isNext) {
      final currentIdx = curIdxRef.value;
      final pages = lastSafePagesRef.value;
      
      if (!isNext) {
        if (appSettings.useScrollMode) {
          if (scrollCtrl.hasClients) {
            final target = max(0.0, scrollCtrl.offset - safeAreaH);
            scrollCtrl.animateTo(target,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut);
          }
        } else {
          if (currentIdx > 0) {
            pageCtrl.previousPage(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut);
          }
        }
      } else {
        if (appSettings.useScrollMode) {
          if (scrollCtrl.hasClients) {
            final target = min(scrollCtrl.position.maxScrollExtent, scrollCtrl.offset + safeAreaH);
            scrollCtrl.animateTo(target,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut);
          }
        } else {
          if (currentIdx < pages.length - 1) {
            pageCtrl.nextPage(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut);
          }
        }
      }
    }

    // -----------------------------------------------------------------------
    // Volume Buttons Listener
    // -----------------------------------------------------------------------
    useEffect(() {
      if (!appSettings.useVolumeKeys) return null;

      bool isDisposed = false;
      StreamSubscription<double>? subscription;
      double lastVolume = -1.0; // Force first event to trigger
      bool isResetting = false;
      
      void startListening() async {
        try {
          // Initial delay to avoid conflicts during screen transition
          await Future.delayed(const Duration(milliseconds: 600));
          if (isDisposed) return;

          PerfectVolumeControl.hideUI = true;
          lastVolume = await PerfectVolumeControl.getVolume();

          subscription = PerfectVolumeControl.stream.listen((volume) async {
            if (isDisposed || isResetting) return;
            
            // Ignore tiny fluctuations (noise)
            if (lastVolume != -1.0 && (volume - lastVolume).abs() < 0.001) return;

            final isUp = volume > lastVolume;
            lastVolume = volume;

            triggerPageTurn(!isUp); // isUp means Volume Up, which is previous page (isNext = false)

            // Hack: Reset volume if it gets too close to the edges to allow infinite scrolling
            // We use a wider margin to be safe and ensure the system UI doesn't pop up
            if (volume <= 0.15 || volume >= 0.85) {
              isResetting = true;
              await PerfectVolumeControl.setVolume(0.5);
              lastVolume = 0.5;
              // Small delay to let the system stabilize after programmatic volume change
              await Future.delayed(const Duration(milliseconds: 300));
              isResetting = false;
            }
          });
        } catch (e) {
          debugPrint('ReaderScreen: PerfectVolumeControl initialization failed: $e');
        }
      }

      startListening();

      return () {
        isDisposed = true;
        subscription?.cancel();
        // Restore system UI on exit
        PerfectVolumeControl.hideUI = false;
      };
    }, [appSettings.useVolumeKeys]);

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
        book.path!,
        startByte,
        settings.encoding,
      );

      if (!context.mounted || text.isEmpty) {
        isLoadingMore.value = false;
        return;
      }

      final newPages = ReaderEngine.paginate(
        text: text,
        maxWidth: pageW,
        maxHeight: pageH,
        style: style,
        byteStart: startByte,
        byteEnd: startByte + consumed,
      );

      allPages.value = [...allPages.value, ...newPages];
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
          int displayIdx = isTwoPage ? i ~/ 2 : i;
          if (appSettings.useScrollMode) {
             if (scrollCtrl.hasClients) scrollCtrl.jumpTo(displayIdx * safeAreaH);
          } else {
             pageCtrl.jumpToPage(displayIdx);
          }
          pageIdx.value = i;
          readByte.value = targetByte;
          if (totalBytes.value > 0)
            sliderVal.value = targetByte / totalBytes.value;
          return;
        }
      }

      isLoading.value = true;
      final chunkStart =
          (targetByte ~/ ReaderEngine.chunkBytes) * ReaderEngine.chunkBytes;
      final (text, consumed) = await ReaderEngine.readChunk(
        book.path!,
        chunkStart,
        settings.encoding,
      );

      if (!context.mounted || text.isEmpty) {
        isLoading.value = false;
        return;
      }

      final newPages = ReaderEngine.paginate(
        text: text,
        maxWidth: pageW,
        maxHeight: pageH,
        style: style,
        byteStart: chunkStart,
        byteEnd: chunkStart + consumed,
      );

      allPages.value = newPages;
      loadedEnd.value = chunkStart + consumed;
      readByte.value = targetByte;

      int jumpIdx = 0;
      for (int i = 0; i < newPages.length; i++) {
        if (newPages[i].byteStart <= targetByte) {
          jumpIdx = i;
        } else {
          break;
        }
      }

      isLoading.value = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (pageCtrl.hasClients) {
          int displayIdx = isTwoPage ? jumpIdx ~/ 2 : jumpIdx;
          pageCtrl.jumpToPage(displayIdx);
          pageIdx.value = jumpIdx;
        }
      });
    }

    // -----------------------------------------------------------------------
    // Page changed (takes the display index from PageView)
    // -----------------------------------------------------------------------
    void onPageChanged(int displayIdx) {
      final actualIdx = isTwoPage ? displayIdx * 2 : displayIdx;
      pageIdx.value = actualIdx;
      curIdxRef.value = actualIdx;
      
      final pages = allPages.value;
      if (actualIdx >= pages.length) return;

      final page = pages[actualIdx];
      readByte.value = page.byteStart;
      if (totalBytes.value > 0)
        sliderVal.value = page.byteStart / totalBytes.value;

      final estimated = loadedEnd.value > 0 && pages.isNotEmpty
          ? (totalBytes.value * pages.length ~/ loadedEnd.value)
          : 0;

      ref
          .read(libraryProvider.notifier)
          .updateBook(
            latestBook.copyWith(
              lastOffset: page.byteStart,
              lastRead: DateTime.now(),
              totalPages: estimated,
            ),
          );

      if (actualIdx >= pages.length - 10) loadNext();
    }

    // -----------------------------------------------------------------------
    // UI
    // -----------------------------------------------------------------------
    final progress = totalBytes.value > 0 ? (sliderVal.value * 100).toStringAsFixed(2) : '0.00';

    final isBookmarked =
        safePages.isNotEmpty &&
        curIdx < safePages.length &&
        latestBook.bookmarks.contains(safePages[curIdx].byteStart);

    return Scaffold(
      key: scaffoldKey,
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
                ? Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.text.withOpacity(0.4),
                    ),
                  )
                : safePages.isEmpty
                ? Center(
                    child: Text(
                      '텍스트를 읽을 수 없습니다.',
                      style: TextStyle(color: colors.text),
                    ),
                  )
                : GestureDetector(
                    onTapUp: (d) {
                      if (!appSettings.useTouchTurn) {
                        // Only allow center tap for overlay
                        showOverlay.value = !showOverlay.value;
                        return;
                      }
                      final w = mq.size.width;
                      final h = mq.size.height;
                      final x = d.globalPosition.dx;
                      final y = d.globalPosition.dy;

                      bool isNext = false;
                      bool isPrev = false;
                      
                      // Absolute center override (middle third)
                      bool isCenter = (x > w * 0.33 && x < w * 0.67) && (y > h * 0.33 && y < h * 0.67);

                      if (!isCenter) {
                        switch (appSettings.touchZoneStyle) {
                          case TouchZoneStyle.leftRight:
                            if (x < w * 0.25) isPrev = true;
                            else if (x > w * 0.75) isNext = true;
                            break;
                          case TouchZoneStyle.anywhereNext:
                            if (y > h * 0.2) isNext = true;
                            break;
                          case TouchZoneStyle.bottomNext:
                            if (y > h * 0.7) {
                              isNext = true;
                            } else if (y > h * 0.3) {
                              if (x < w * 0.5) isPrev = true;
                              else isNext = true;
                            }
                            break;
                          case TouchZoneStyle.lShape:
                            if (x > w * 0.7 || y > h * 0.7) {
                              isNext = true;
                            } else if (x < w * 0.3 && y < h * 0.3) {
                              isPrev = true;
                            }
                            break;
                        }
                      }

                      if (isPrev) {
                        triggerPageTurn(false);
                      } else if (isNext) {
                        triggerPageTurn(true);
                      } else {
                        showOverlay.value = !showOverlay.value;
                      }
                    },
                    child: appSettings.useScrollMode 
                    ? NotificationListener<ScrollUpdateNotification>(
                        onNotification: (notif) {
                           if (!scrollCtrl.hasClients) return false;
                           final idx = (scrollCtrl.offset / safeAreaH).round();
                           final pagesCount = isTwoPage ? (safePages.length / 2).ceil() : safePages.length;
                           if (idx != (isTwoPage ? pageIdx.value ~/ 2 : pageIdx.value) && idx >= 0 && idx < pagesCount) {
                               onPageChanged(idx);
                           }
                           if (scrollCtrl.position.extentAfter < safeAreaH * 2) {
                               loadNext();
                           }
                           return false;
                        },
                        child: ListView.builder(
                          controller: scrollCtrl,
                          itemExtent: safeAreaH,
                          physics: const BouncingScrollPhysics(),
                          itemCount: isTwoPage 
                              ? (safePages.length / 2).ceil() + (isLoadingMore.value ? 1 : 0)
                              : safePages.length + (isLoadingMore.value ? 1 : 0),
                          itemBuilder: (ctx, i) {
                            if (isTwoPage) {
                              final leftIdx = i * 2;
                              final rightIdx = i * 2 + 1;
                              if (leftIdx >= safePages.length) {
                                return Center(child: CircularProgressIndicator(color: colors.text.withOpacity(0.3)));
                              }
                              return SizedBox(
                                height: safeAreaH,
                                child: Row(
                                  children: [
                                    Expanded(child: _buildPage(safePages[leftIdx], settings, colors, style)),
                                    const VerticalDivider(width: 1, thickness: 0.1, color: Colors.black12),
                                    Expanded(child: rightIdx < safePages.length ? _buildPage(safePages[rightIdx], settings, colors, style) : Container()),
                                  ],
                                ),
                              );
                            }
                            if (i >= safePages.length) {
                              return Center(child: CircularProgressIndicator(strokeWidth: 2, color: colors.text.withOpacity(0.3)));
                            }
                            return SizedBox(
                              height: safeAreaH,
                              child: _buildPage(safePages[i], settings, colors, style),
                            );
                          },
                        ),
                      )
                    : PageView.builder(
                      controller: pageCtrl,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: isTwoPage 
                          ? (safePages.length / 2).ceil() + (isLoadingMore.value ? 1 : 0)
                          : safePages.length + (isLoadingMore.value ? 1 : 0),
                      onPageChanged: onPageChanged,
                      itemBuilder: (ctx, i) {
                        if (isTwoPage) {
                          final leftIdx = i * 2;
                          final rightIdx = i * 2 + 1;
                          
                          if (leftIdx >= safePages.length) {
                            return Center(child: CircularProgressIndicator(color: colors.text.withOpacity(0.3)));
                          }

                          return Row(
                            children: [
                              Expanded(
                                child: _buildPage(safePages[leftIdx], settings, colors, style),
                              ),
                              const VerticalDivider(width: 1, thickness: 0.1, color: Colors.black12),
                              Expanded(
                                child: rightIdx < safePages.length 
                                  ? _buildPage(safePages[rightIdx], settings, colors, style)
                                  : Container(),
                              ),
                            ],
                          );
                        }
                        
                        // Single Page Mode
                        if (i >= safePages.length) {
                          return Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.text.withOpacity(0.3),
                            ),
                          );
                        }
                        return _buildPage(safePages[i], settings, colors, style);
                      },
                    ),
                  ),
          ),

          // ---- Bottom Footer (Progress & Time) ----
          Positioned(
            bottom: mq.padding.bottom + 5,
            left: 0,
            right: 0,
            child: _ReaderFooter(progress: progress, colors: colors),
          ),

          // ---- Overlay ----
          if (showOverlay.value && safePages.isNotEmpty)
            _buildOverlay(
              context: context,
              ref: ref,
              colors: colors,
              settings: settings,
              latestBook: latestBook,
              safePages: safePages,
              pageIdx: pageIdx,
              progress: progress,
              sliderVal: sliderVal,
              isDragging: isDragging,
              totalBytes: totalBytes.value,
              jumpTimer: jumpTimer,
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
              onOpenDrawer: () {
                scaffoldKey.currentState?.openDrawer();
              },
              jumpToByte: jumpToByte,
            ),
        ],
      ),
    );
  }

  Widget _buildOverlay({
    required BuildContext context,
    required WidgetRef ref,
    required _TC colors,
    required ReaderSettings settings,
    required Book latestBook,
    required List<ReaderPage> safePages,
    required ValueNotifier<int> pageIdx,
    required String progress,
    required ValueNotifier<double> sliderVal,
    required ValueNotifier<bool> isDragging,
    required int totalBytes,
    required ObjectRef<Timer?> jumpTimer,
    required ValueNotifier<bool> showOverlay,
    required bool isBookmarked,
    required PageController pageCtrl,
    required VoidCallback onSettings,
    required VoidCallback onOpenDrawer,
    required Function(int) jumpToByte,
  }) {
    final mq = MediaQuery.of(context);
    final curIdx = pageIdx.value.clamp(0, safePages.length - 1);
    final curPage = safePages[curIdx];

    return Column(
      children: [
        // Top bar
        Container(
          color: colors.bar,
          padding: EdgeInsets.only(
            top: mq.padding.top + 2,
            left: 4,
            right: 4,
            bottom: 4,
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
                  onOpenDrawer();
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
              // Options Menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white, size: 24),
                color: colors.bar,
                offset: const Offset(0, 40),
                onSelected: (val) {
                  if (val != 'bookmark_toggle') showOverlay.value = false;
                  
                  if (val == 'search') {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => _SearchSheet(
                        book: latestBook,
                        encoding: settings.encoding,
                        onJump: (offset) => jumpToByte(offset),
                      ),
                    );
                  } else if (val == 'bookmark_list') {
                    onOpenDrawer();
                  } else if (val == 'bookmark_toggle') {
                    final curPage = safePages[pageIdx.value.clamp(0, safePages.length - 1)];
                    final bm = List<int>.from(latestBook.bookmarks);
                    if (bm.contains(curPage.byteStart)) {
                      bm.remove(curPage.byteStart);
                    } else {
                      bm.add(curPage.byteStart);
                    }
                    ref.read(libraryProvider.notifier).updateBook(latestBook.copyWith(bookmarks: bm));
                  } else if (val == 'settings') {
                    onSettings();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'search',
                    child: ListTile(
                      leading: Icon(Icons.search, color: Colors.white, size: 20),
                      title: Text('검색', style: TextStyle(color: Colors.white, fontSize: 14)),
                      dense: true,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'bookmark_toggle',
                    child: ListTile(
                      leading: Icon(
                        isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                        color: isBookmarked ? Colors.amber : Colors.white,
                        size: 20,
                      ),
                      title: Text(isBookmarked ? '북마크 해제' : '북마크 추가', 
                        style: const TextStyle(color: Colors.white, fontSize: 14)),
                      dense: true,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'bookmark_list',
                    child: ListTile(
                      leading: Icon(Icons.list, color: Colors.white, size: 20),
                      title: Text('북마크 목록', style: TextStyle(color: Colors.white, fontSize: 14)),
                      dense: true,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'settings',
                    child: ListTile(
                      leading: Icon(Icons.tune, color: Colors.white, size: 20),
                      title: Text('보기 옵션', style: TextStyle(color: Colors.white, fontSize: 14)),
                      dense: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        if (isDragging.value)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$progress%',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),

        const Spacer(),

        // Bottom bar
        Container(
          color: colors.bar,
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 10,
            bottom: mq.padding.bottom + 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SliderTheme(
                data: SliderThemeData(
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 12,
                  ),
                  trackHeight: 3,
                  activeTrackColor: Colors.white70,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Colors.white,
                  overlayColor: Colors.white24,
                ),
                child: Slider(
                  value: sliderVal.value.clamp(0.0, 1.0),
                  onChanged: (v) {
                    isDragging.value = true;
                    sliderVal.value = v;
                    final targetByte = (v * totalBytes).round();
                    
                    // Try synchronous jump if within loaded pages
                    int closest = -1;
                    for (int i = 0; i < safePages.length; i++) {
                      if (safePages[i].byteStart <= targetByte && targetByte < safePages[i].byteEnd) {
                        closest = i;
                        break;
                      } else if (safePages[i].byteStart <= targetByte) {
                        closest = i;
                      }
                    }

                    if (closest != -1) {
                      final isTwo = mq.size.width > 900 && (settings.useTwoPageMode ?? true);
                      int displayIdx = isTwo ? closest ~/ 2 : closest;
                      if (pageCtrl.hasClients && pageIdx.value != closest) {
                        pageCtrl.jumpToPage(displayIdx);
                        pageIdx.value = closest;
                      }
                    }

                    // Debounced full jump (for unloaded chunks)
                    jumpTimer.value?.cancel();
                    jumpTimer.value = Timer(const Duration(milliseconds: 100), () {
                      if (closest == -1 || targetByte < safePages.first.byteStart || targetByte >= safePages.last.byteEnd) {
                        jumpToByte(targetByte);
                      }
                    });
                  },
                  onChangeEnd: (v) {
                    isDragging.value = false;
                    jumpTimer.value?.cancel();
                    jumpToByte((v * totalBytes).round());
                  },
                ),
              ),
              Text(
                '${pageIdx.value + 1}페이지  ·  $progress%',
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
    if (bookIdx < 0)
      return const Drawer(child: Center(child: CircularProgressIndicator()));
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
                    Icon(
                      Icons.bookmark_border,
                      size: 48,
                      color: Colors.brown[200],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '북마크가 없습니다.',
                      style: TextStyle(color: Colors.brown),
                    ),
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
                  final pct = totalBytes > 0 ? (offset * 100 ~/ totalBytes) : 0;
                  return ListTile(
                    leading: const Icon(
                      Icons.bookmark,
                      color: Color(0xFF6B4E3D),
                    ),
                    title: Text(
                      '$pct% 위치',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      color: Colors.red[300],
                      onPressed: () {
                        final updated = List<int>.from(bm)..remove(offset);
                        ref
                            .read(libraryProvider.notifier)
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
      (ReaderTheme.sepia, const Color(0xFFF4ECD8), '세피아'),
      (ReaderTheme.soft, const Color(0xFFEEF3E8), '녹색'),
      (ReaderTheme.night, const Color(0xFF1A1A1A), '야간'),
    ];
    const encodings = ['auto', 'UTF-8', 'EUC-KR'];
    const encLabels = ['자동', 'UTF-8', 'EUC-KR'];
    const fonts = ['Georgia', 'system'];
    const fontLabels = ['Georgia', '기본 폰트'];

    return Container(
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: mq.viewInsets.bottom + mq.padding.bottom + 20,
        top: 12,
        left: 24,
        right: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
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
                _IconBtn(
                  icon: Icons.remove,
                  colors: colors,
                  onTap: () => n.updateFontSize(s.fontSize - 1),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    '${s.fontSize.round()}',
                    style: TextStyle(
                      color: colors.text,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                _IconBtn(
                  icon: Icons.add,
                  colors: colors,
                  onTap: () => n.updateFontSize(s.fontSize + 1),
                ),
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
                Text(
                  s.lineSpacing.toStringAsFixed(1),
                  style: TextStyle(
                    color: colors.text.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      trackHeight: 3,
                      activeTrackColor: colors.text.withOpacity(0.6),
                      inactiveTrackColor: colors.text.withOpacity(0.2),
                      thumbColor: colors.text,
                    ),
                    child: Slider(
                      value: s.lineSpacing,
                      min: 1.0,
                      max: 3.0,
                      divisions: 20,
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
              children: List.generate(
                fonts.length,
                (i) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _Chip(
                    label: fontLabels[i],
                    selected: s.fontFamily == fonts[i],
                    colors: colors,
                    onTap: () => n.updateFontFamily(fonts[i]),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Encoding
          _Row(
            label: '인코딩',
            colors: colors,
            child: Row(
              children: List.generate(
                encodings.length,
                (i) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _Chip(
                    label: encLabels[i],
                    selected: s.encoding == encodings[i],
                    colors: colors,
                    onTap: () => n.updateEncoding(encodings[i]),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 22),

          // Themes
          Row(
            children: [
              Text(
                '테마',
                style: TextStyle(
                  color: colors.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 20),
              ...themeData.map(
                (td) => GestureDetector(
                  onTap: () => n.updateTheme(td.$1),
                  child: Tooltip(
                    message: td.$3,
                    child: Container(
                      width: 32,
                      height: 32,
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
                            ? [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.3),
                                  blurRadius: 4,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Touch Zones
          _Row(
            label: '터치 제어',
            colors: colors,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(
                      TouchZoneStyle.values.length,
                      (i) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _Chip(
                          label: const ['기본 (좌우)', '어디든 다음', '하단 위주', 'ㄱ자 영역'][i],
                          selected: ref.watch(appSettingsProvider).touchZoneStyle == TouchZoneStyle.values[i],
                          colors: colors,
                          onTap: () => ref.read(appSettingsProvider.notifier).updateTouchZoneStyle(TouchZoneStyle.values[i]),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _TouchZoneVisualizer(
                   style: ref.watch(appSettingsProvider).touchZoneStyle,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 18),
          
          // Two-Page Mode
          _Row(
            label: '두 쪽 보기',
            colors: colors,
            child: Row(
              children: [
                Switch(
                  value: s.useTwoPageMode ?? false,
                  activeColor: Colors.blue,
                  onChanged: (val) => n.updateTwoPageMode(val),
                ),
                const SizedBox(width: 8),
                Text(
                  (s.useTwoPageMode == null) ? '(자동 감지됨)' : '',
                  style: TextStyle(color: colors.text.withOpacity(0.5), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TouchZoneVisualizer extends StatelessWidget {
  final TouchZoneStyle style;
  const _TouchZoneVisualizer({required this.style});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 160,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          Positioned.fill(child: _ZoneBox('메뉴', Colors.grey.withOpacity(0.2))),
          
          if (style == TouchZoneStyle.leftRight) ...[
            Positioned(left: 0, top: 0, bottom: 0, width: 30, child: _ZoneBox('이전', Colors.red.withOpacity(0.25))),
            Positioned(right: 0, top: 0, bottom: 0, width: 30, child: _ZoneBox('다음', Colors.green.withOpacity(0.25))),
          ] else if (style == TouchZoneStyle.anywhereNext) ...[
            Positioned(left: 0, right: 0, top: 32, bottom: 0, child: _ZoneBox('다음', Colors.green.withOpacity(0.25))),
          ] else if (style == TouchZoneStyle.bottomNext) ...[
            Positioned(left: 0, width: 60, top: 48, bottom: 48, child: _ZoneBox('이전', Colors.red.withOpacity(0.25))),
            Positioned(right: 0, width: 60, top: 48, bottom: 48, child: _ZoneBox('다음', Colors.green.withOpacity(0.25))),
            Positioned(left: 0, right: 0, bottom: 0, height: 48, child: _ZoneBox('다음', Colors.green.withOpacity(0.25))),
          ] else if (style == TouchZoneStyle.lShape) ...[
            Positioned(right: 0, top: 0, bottom: 0, width: 36, child: _ZoneBox('다음', Colors.green.withOpacity(0.25))),
            Positioned(left: 0, right: 0, bottom: 0, height: 48, child: _ZoneBox('다음', Colors.green.withOpacity(0.25))),
            Positioned(left: 0, top: 0, width: 36, height: 48, child: _ZoneBox('이전', Colors.red.withOpacity(0.25))),
          ],
          
          // Absolute Center override for Menu
          Positioned(
            left: 120 * 0.33, right: 120 * 0.33,
            top: 160 * 0.33, bottom: 160 * 0.33,
            child: _ZoneBox('중앙\n메뉴', Colors.grey.withOpacity(0.65)),
          ),
        ],
      ),
    );
  }
}

class _ZoneBox extends StatelessWidget {
  final String label;
  final Color color;
  const _ZoneBox(this.label, this.color);
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: Colors.black12, width: 0.5),
      ),
      child: Center(
        child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small UI helpers
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Reader Footer (Status Bar)
// ---------------------------------------------------------------------------

class _ReaderFooter extends HookWidget {
  final String progress;
  final _TC colors;

  const _ReaderFooter({required this.progress, required this.colors});

  @override
  Widget build(BuildContext context) {
    final timeStr = useState(_formatTime());

    useEffect(() {
      final timer = Stream.periodic(const Duration(seconds: 10)).listen((_) {
        timeStr.value = _formatTime();
      });
      return timer.cancel;
    }, []);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Center(
        child: Text(
          '$progress%  ·  ${timeStr.value}',
          style: TextStyle(
            fontSize: 10,
            color: colors.text.withOpacity(0.4),
            fontWeight: FontWeight.w400,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  String _formatTime() {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

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
          child: Text(
            label,
            style: TextStyle(color: colors.text, fontWeight: FontWeight.w600),
          ),
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
  const _IconBtn({
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
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
    required this.label,
    required this.selected,
    required this.colors,
    required this.onTap,
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
            color: colors.text,
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _SearchSheet extends StatefulWidget {
  final Book book;
  final String encoding;
  final Function(int) onJump;
  const _SearchSheet({
    required this.book,
    required this.encoding,
    required this.onJump,
  });

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  final _searchCtrl = TextEditingController();
  List<SearchResult> _results = [];
  bool _isSearching = false;

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;
    if (widget.book.path == null) return;

    setState(() {
      _isSearching = true;
      _results = [];
    });

    try {
      final res = await ReaderEngine.fullTextSearch(
        path: widget.book.path!,
        query: query.trim(),
        encoding: widget.encoding,
      );
      if (mounted) {
        setState(() {
          _results = res;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      height: mq.size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: mq.viewInsets.bottom + 20,
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text('본문 검색',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchCtrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: '검색어를 입력하세요',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.send),
                onPressed: () => _performSearch(_searchCtrl.text),
              ),
            ),
            onSubmitted: _performSearch,
          ),
          const SizedBox(height: 10),
          if (_isSearching)
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, i) {
                final r = _results[i];
                return ListTile(
                  title: Text(r.snippet, style: const TextStyle(fontSize: 13)),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onJump(r.byteOffset);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
