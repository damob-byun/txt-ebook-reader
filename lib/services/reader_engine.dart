import 'package:flutter/material.dart';

class ReaderPage {
  final int startIndex;
  final int endIndex;
  final String content;

  ReaderPage({
    required this.startIndex,
    required this.endIndex,
    required this.content,
  });
}

class ReaderChapter {
  final String title;
  final int offset;
  ReaderChapter({required this.title, required this.offset});
}

class ReaderEngine {
  static List<ReaderChapter> detectChapters(String text) {
    final List<ReaderChapter> chapters = [];
    final RegExp chapterRegex = RegExp(
      r'^(?:Chapter\s*\d+|제\s*\d+\s*[장회]|[\d\.]+\s+[^\n]+)',
      multiLine: true,
      caseSensitive: false,
    );

    final matches = chapterRegex.allMatches(text);
    for (final match in matches) {
      chapters.add(ReaderChapter(
        title: match.group(0)!.trim(),
        offset: match.start,
      ));
    }
    return chapters;
  }

  static List<ReaderPage> paginate({
    required String text,
    required double maxWidth,
    required double maxHeight,
    required TextStyle style,
    double lineSpacing = 1.5,
  }) {
    final List<ReaderPage> pages = [];
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.justify,
    );

    int start = 0;
    while (start < text.length) {
      int end = _findPageEnd(
        text,
        start,
        maxWidth,
        maxHeight,
        style,
        textPainter,
      );
      
      if (end <= start) break; // Should not happen

      pages.add(ReaderPage(
        startIndex: start,
        endIndex: end,
        content: text.substring(start, end).trim(),
      ));
      
      start = end;
    }

    return pages;
  }

  static int _findPageEnd(
    String text,
    int start,
    double maxWidth,
    double maxHeight,
    TextStyle style,
    TextPainter painter,
  ) {
    // Binary search or incremental search for the best fit
    // For simplicity, we'll use a chunked approach or a simple loop for now.
    // However, binary search on the string length is more efficient.
    
    int low = start;
    int high = text.length;
    int bestEnd = start;

    while (low <= high) {
      int mid = (low + high) ~/ 2;
      String sub = text.substring(start, mid);
      
      painter.text = TextSpan(text: sub, style: style);
      painter.layout(maxWidth: maxWidth);

      if (painter.height <= maxHeight) {
        bestEnd = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    // Try to break at a newline or space if possible for better reading
    if (bestEnd < text.length) {
      int lastNewline = text.lastIndexOf('\n', bestEnd);
      if (lastNewline > start && lastNewline > bestEnd - 100) {
        return lastNewline + 1;
      }
      int lastSpace = text.lastIndexOf(' ', bestEnd);
      if (lastSpace > start && lastSpace > bestEnd - 50) {
        return lastSpace + 1;
      }
    }

    return bestEnd;
  }
}
