import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:charset_converter/charset_converter.dart';
import 'package:cp949_codec/cp949_codec.dart';

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
    
    // Auto-detection or explicit UTF-8
    if (enc == 'auto' || enc == 'utf-8' || enc == 'utf8') {
      try {
        // Native Dart UTF-8 decoding is robust and cross-platform
        return utf8.decode(bytes, allowMalformed: true);
      } catch (e) {
        if (enc != 'auto') {
          debugPrint('ReaderEngine: UTF-8 decode failed: $e');
        }
        // If not auto, fallback to a safe string. If auto, continue to EUC-KR.
        if (enc != 'auto') return String.fromCharCodes(bytes.where((b) => b < 128));
      }
    }

    // EUC-KR / CP949
    if (enc == 'auto' || enc == 'euc-kr' || enc == 'cp949') {
      try {
        // Try cp949_codec first (pure Dart, works on macOS)
        return cp949.decode(bytes);
      } catch (e) {
        debugPrint('ReaderEngine: cp949_codec failed: $e. trying lenient decode...');
        try {
          return _lenientCP949(bytes);
        } catch (e2) {
          debugPrint('ReaderEngine: Lenient CP949 failed: $e2. trying charset_converter...');
          try {
            // Fallback to platform-native if available
            return await CharsetConverter.decode('EUC-KR', bytes);
          } catch (e3) {
            debugPrint('ReaderEngine: EUC-KR decode failed: $e3');
          }
        }
      }
    }
    
    // Other specific encodings
    try {
      return await CharsetConverter.decode(encoding, bytes);
    } catch (e) {
      debugPrint('ReaderEngine: Specific decode ($encoding) failed: $e');
      return String.fromCharCodes(bytes.where((b) => b < 128));
    }
  }

  /// Manually decode CP949 while skipping invalid bytes that cause FormatException
  static String _lenientCP949(Uint8List bytes) {
    try {
      final List<int> sanitized = [];
      int i = 0;
      while (i < bytes.length) {
        final b1 = bytes[i];
        if (b1 <= 0x7F) {
          sanitized.add(b1);
          i++;
        } else if (b1 >= 0x81 && b1 <= 0xFE && i + 1 < bytes.length) {
          final b2 = bytes[i + 1];
          // Valid CP949 trail byte ranges
          if ((b2 >= 0x41 && b2 <= 0x5A) || (b2 >= 0x61 && b2 <= 0x7A) || (b2 >= 0x81 && b2 <= 0xFE)) {
            sanitized.add(b1);
            sanitized.add(b2);
            i += 2;
          } else {
            // Invalid trail byte, skip lead byte
            i++;
          }
        } else {
          // Invalid lead byte (like 0x80 or 0xFF) or hanging lead byte, skip
          i++;
        }
      }
      return cp949.decode(Uint8List.fromList(sanitized));
    } catch (e) {
      // Last resort: just filter ASCII
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
