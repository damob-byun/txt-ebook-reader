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
    state = _storage.loadBooks();
    // Sort by last read
    state.sort((a, b) => b.lastRead.compareTo(a.lastRead));
  }

  Future<void> addBook(Book book) async {
    if (state.any((b) => b.id == book.id)) return;
    state = [book, ...state];
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
