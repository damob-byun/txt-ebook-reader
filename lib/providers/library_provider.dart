import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/book.dart';
import '../services/storage_service.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError(); // Initialized in main
});

final libraryProvider = StateNotifierProvider<LibraryNotifier, List<Book>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return LibraryNotifier(storage);
});

class LibraryNotifier extends StateNotifier<List<Book>> {
  final StorageService _storage;

  LibraryNotifier(this._storage) : super([]) {
    _loadBooks();
  }

  void _loadBooks() {
    try {
      debugPrint('LibraryNotifier: Loading books...');
      state = _storage.loadBooks();
      debugPrint('LibraryNotifier: Loaded ${state.length} books.');
      // Sort by last read
      state.sort((a, b) => b.lastRead.compareTo(a.lastRead));
    } catch (e, stack) {
      debugPrint('LibraryNotifier: Error loading books: $e');
      debugPrint('LibraryNotifier: StackTrace: $stack');
    }
  }

  Future<void> addBook(Book book) async {
    // Check if exact same book (ID) already exists
    if (state.any((b) => b.id == book.id)) return;

    // Check if same TITLE exists (different file/path, same name)
    final existingIndex = state.indexWhere((b) => b.title == book.title);

    if (existingIndex != -1) {
      final existing = state[existingIndex];
      // Merge: Keep existing progress (lastOffset, bookmarks, totalBytes), 
      // but update the path to the new one being added.
      final merged = existing.copyWith(
        path: book.path,
        lastRead: DateTime.now(),
      );
      
      // Replace existing with merged and move to top
      state = [
        merged,
        ...state.where((b) => b.id != existing.id),
      ];
    } else {
      state = [book, ...state];
    }
    
    await _storage.saveBooks(state);
  }

  Future<void> updateBook(Book book) async {
    state = [
      for (final b in state)
        if (b.id == book.id) book else b
    ];
    // Re-sort
    state.sort((a, b) => b.lastRead.compareTo(a.lastRead));
    await _storage.saveBooks(state);
  }

  Future<void> removeBook(String id) async {
    state = state.where((b) => b.id != id).toList();
    await _storage.saveBooks(state);
  }
}
