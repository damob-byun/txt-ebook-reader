import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:charset_converter/charset_converter.dart';

class ReaderPage {
  final int byteStart;
  final int byteEnd;
  final String content;
  const ReaderPage({required this.byteStart, required this.byteEnd, required this.content});
}

class ReaderEngine {
  static const int chunkBytes = 131072; // 128 KB per chunk

  static Future<int> fileSize(String path) async {
    try {
      return await File(path).length();
    } catch (_) {
      return 0;
    }
  }

  /// Reads a text chunk starting at [byteOffset].
  /// Returns (decodedText, bytesConsumed).
  static Future<(String, int)> readChunk(
    String path,
    int byteOffset,
    String encoding,
  ) async {
    final file = File(path);
    if (!await file.exists()) return ('', 0);
    final raf = await file.open(mode: FileMode.read);
    try {
      final fileLen = await raf.length();
      if (byteOffset >= fileLen) return ('', 0);

      final toRead = min(chunkBytes, fileLen - byteOffset);
      await raf.setPosition(byteOffset);
      Uint8List bytes = await raf.read(toRead);

      if (byteOffset + toRead < fileLen) {
        bytes = _trimBoundary(bytes, encoding);
      }

      final decoded = await _decode(bytes, encoding);
      return (decoded, bytes.length);
    } finally {
      await raf.close();
    }
  }

  static Future<String> _decode(Uint8List bytes, String encoding) async {
    if (bytes.isEmpty) return '';
    
    final enc = encoding.toLowerCase();
    if (enc == 'auto') {
      try {
        final r = await CharsetConverter.decode('UTF-8', bytes);
        if (!r.contains('\uFFFD')) return r;
      } catch (e) {
        debugPrint('ReaderEngine: UTF-8 decode failed: $e');
      }
      try {
        return await CharsetConverter.decode('EUC-KR', bytes);
      } catch (e) {
        debugPrint('ReaderEngine: EUC-KR decode failed: $e');
      }
      return String.fromCharCodes(bytes.where((b) => b < 128));
    }
    
    try {
      final targetEnc = enc == 'utf-8' || enc == 'utf8' ? 'UTF-8' : 
                      (enc == 'euc-kr' || enc == 'cp949') ? 'EUC-KR' : encoding;
      return await CharsetConverter.decode(targetEnc, bytes);
    } catch (e) {
      debugPrint('ReaderEngine: Specific decode ($encoding) failed: $e');
      try {
        return await CharsetConverter.decode('UTF-8', bytes);
      } catch (_) {}
      return String.fromCharCodes(bytes.where((b) => b < 128));
    }
  }

  static Uint8List _trimBoundary(Uint8List bytes, String encoding) {
    final enc = encoding.toLowerCase();
    if (enc == 'auto' || enc == 'utf-8' || enc == 'utf8') {
      int end = bytes.length;
      for (int c = 1; c <= 4 && c <= end; c++) {
        final b = bytes[end - c];
        if (b < 0x80) break;
        if ((b & 0xC0) == 0xC0) {
          final seqLen = b >= 0xF0 ? 4 : b >= 0xE0 ? 3 : 2;
          if (c < seqLen) end -= c;
          break;
        }
      }
      return end < bytes.length ? Uint8List.sublistView(bytes, 0, end) : bytes;
    }
    // EUC-KR / CP949: trim at last newline near end
    for (int i = bytes.length - 1; i >= max(0, bytes.length - 10); i--) {
      if (bytes[i] == 0x0A) return Uint8List.sublistView(bytes, 0, i + 1);
    }
    return bytes;
  }

  /// Paginate decoded text into pages.
  /// [byteStart]/[byteEnd] are the file byte offsets of this text chunk.
  static List<ReaderPage> paginate({
    required String text,
    required double maxWidth,
    required double maxHeight,
    required TextStyle style,
    required int byteStart,
    required int byteEnd,
  }) {
    if (text.isEmpty) return [];
    if (maxWidth <= 0 || maxHeight <= 0) {
      debugPrint('ReaderEngine: Invalid dimensions ($maxWidth x $maxHeight)');
      return [];
    }

    final lineH = _lineHeight(style, maxWidth);
    if (lineH <= 0) return [];
    
    final linesPerPage = (maxHeight / lineH).floor().clamp(1, 100);
    final charsPerLine = _charsPerLine(style, maxWidth);
    final target = (linesPerPage * charsPerLine).clamp(200, 8000);

    final pages = <ReaderPage>[];
    int start = 0;
    final total = text.length;
    final byteRange = byteEnd - byteStart;

    while (start < total) {
      int end = min(start + target, total);
      if (end < total) end = _snap(text, start, end, target);
      end = _fitPage(text, start, end, maxWidth, maxHeight, style, target);
      if (end <= start) end = min(start + 10, total);

      final content = text.substring(start, end).trim();
      if (content.isNotEmpty) {
        final s = total > 0 ? byteStart + (byteRange * start ~/ total) : byteStart;
        final e = end >= total ? byteEnd : byteStart + (byteRange * end ~/ total);
        pages.add(ReaderPage(byteStart: s, byteEnd: e, content: content));
      }
      start = end;
    }
    return pages;
  }

  static double _lineHeight(TextStyle style, double maxWidth) {
    if (maxWidth <= 0) return (style.fontSize ?? 18) * (style.height ?? 1.6);
    try {
      final p = TextPainter(
        text: TextSpan(text: '가나다라마바사\nABC 123', style: style),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxWidth);
      final m = p.computeLineMetrics();
      if (m.isNotEmpty) {
        return m.map((l) => l.height).reduce((a, b) => a + b) / m.length;
      }
    } catch (e) {
      debugPrint('ReaderEngine: _lineHeight error: $e');
    }
    return (style.fontSize ?? 18) * (style.height ?? 1.6);
  }

  static int _charsPerLine(TextStyle style, double maxWidth) {
    const sample = '가나다라마바사아자차카타파하이그리';
    final p = TextPainter(
      text: TextSpan(text: sample, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final avgW = p.width / sample.length;
    return max(10, (maxWidth / avgW).round());
  }

  static int _snap(String text, int start, int end, int target) {
    final para = text.lastIndexOf('\n\n', end);
    if (para > start && end - para < target ~/ 3) return para + 2;
    final nl = text.lastIndexOf('\n', end);
    if (nl > start && end - nl < 300) return nl + 1;
    final sp = text.lastIndexOf(' ', end);
    if (sp > start && end - sp < 50) return sp + 1;
    return end;
  }

  static int _fitPage(
    String text, int start, int end,
    double maxWidth, double maxHeight, TextStyle style, int target,
  ) {
    if (maxWidth <= 0 || maxHeight <= 0) return end;
    
    try {
      final sub = text.substring(start, end);
      final p = TextPainter(
        text: TextSpan(text: sub, style: style),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.justify,
      )..layout(maxWidth: maxWidth);
      if (p.height <= maxHeight) return end;
    } catch (e) {
      debugPrint('ReaderEngine: _fitPage initial layout error: $e');
      return min(start + 100, end); // Fallback to a small increment
    }

    // Binary search for fitting end
    int lo = start, hi = end, best = start + 1;
    while (lo <= hi) {
      final mid = (lo + hi) ~/ 2;
      if (mid <= start) { lo = mid + 1; continue; }
      try {
        final mp = TextPainter(
          text: TextSpan(text: text.substring(start, mid), style: style),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.justify,
        )..layout(maxWidth: maxWidth);
        if (mp.height <= maxHeight) {
          best = mid;
          lo = mid + 1;
        } else {
          hi = mid - 1;
        }
      } catch (e) {
        hi = mid - 1;
      }
    }
    return _snap(text, start, best, target);
  }
}
