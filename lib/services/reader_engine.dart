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

  static ReaderPage findPageAtOffset({
    required String text,
    required int startOffset,
    required double maxWidth,
    required double maxHeight,
    required TextStyle style,
  }) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.justify,
    );

    int end = _findPageEnd(
      text,
      startOffset,
      maxWidth,
      maxHeight,
      style,
      textPainter,
    );

    return ReaderPage(
      startIndex: startOffset,
      endIndex: end,
      content: text.substring(startOffset, end),
    );
  }

  static int _findPageEnd(
    String text,
    int start,
    double maxWidth,
    double maxHeight,
    TextStyle style,
    TextPainter painter,
  ) {
    if (start >= text.length) return text.length;

    // Fast path: if the remaining text is small, just take it all
    if (text.length - start < 500) {
      painter.text = TextSpan(text: text.substring(start), style: style);
      painter.layout(maxWidth: maxWidth);
      if (painter.height <= maxHeight) return text.length;
    }

    // Binary search for the page end
    int low = start;
    int high = (start + 3000).clamp(start, text.length); // Assume max 3k chars per page for speed
    int bestEnd = start;

    while (low <= high) {
      int mid = (low + high) ~/ 2;
      if (mid <= start) {
        low = mid + 1;
        continue;
      }
      
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

    // Alignment logic (breaking at newlines or spaces)
    if (bestEnd < text.length) {
      // Find the last newline in the last part of the page
      int lastNewline = text.lastIndexOf('\n', bestEnd);
      if (lastNewline > start && lastNewline > bestEnd - 150) {
        return lastNewline + 1;
      }
      // Or last space
      int lastSpace = text.lastIndexOf(' ', bestEnd);
      if (lastSpace > start && lastSpace > bestEnd - 50) {
        return lastSpace + 1;
      }
    }

    return bestEnd;
  }
}
