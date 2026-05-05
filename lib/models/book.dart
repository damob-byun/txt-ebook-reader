import 'dart:convert';
import 'package:crypto/crypto.dart';

class Book {
  final String id;
  final String title;
  final String? path; // Local path or remote URL identifier
  final String? remotePath;
  final DateTime lastRead;
  final int lastOffset;
  final int totalPages;
  final int totalBytes;
  final List<int> bookmarks;
  final String? coverUrl;

  Book({
    required this.id,
    required this.title,
    this.path,
    this.remotePath,
    required this.lastRead,
    this.lastOffset = 0,
    this.totalPages = 0,
    this.totalBytes = 0,
    this.bookmarks = const [],
    this.coverUrl,
  });

  factory Book.fromRemote(String name, String remotePath) {
    final id = sha256.convert(utf8.encode(remotePath)).toString();
    return Book(
      id: id,
      title: name,
      remotePath: remotePath,
      lastRead: DateTime.now(),
    );
  }

  Book copyWith({
    String? path,
    DateTime? lastRead,
    int? lastOffset,
    int? totalPages,
    int? totalBytes,
    List<int>? bookmarks,
  }) {
    return Book(
      id: id,
      title: title,
      path: path ?? this.path,
      remotePath: remotePath,
      lastRead: lastRead ?? this.lastRead,
      lastOffset: lastOffset ?? this.lastOffset,
      totalPages: totalPages ?? this.totalPages,
      totalBytes: totalBytes ?? this.totalBytes,
      bookmarks: bookmarks ?? this.bookmarks,
      coverUrl: coverUrl,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'path': path,
        'remotePath': remotePath,
        'lastRead': lastRead.toIso8601String(),
        'lastOffset': lastOffset,
        'totalPages': totalPages,
        'totalBytes': totalBytes,
        'bookmarks': bookmarks,
        'coverUrl': coverUrl,
      };

  factory Book.fromJson(Map<String, dynamic> json) => Book(
        id: json['id'],
        title: json['title'],
        path: json['path'],
        remotePath: json['remotePath'],
        lastRead: DateTime.parse(json['lastRead']),
        lastOffset: json['lastOffset'] ?? 0,
        totalPages: json['totalPages'] ?? 0,
        totalBytes: json['totalBytes'] ?? 0,
        bookmarks: List<int>.from(json['bookmarks'] ?? []),
        coverUrl: json['coverUrl'],
      );
}
