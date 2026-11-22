import 'dart:async';

import '../../domain/entities/book_fair.dart';
import '../../domain/repositories/book_fair_repository.dart';

/// In-memory mock implementation of [BookFairRepository] for testing and fallback.
class MockBookFairRepository implements BookFairRepository {
  MockBookFairRepository();

  final List<BookFair> _fairs = [];
  final _controller = StreamController<List<BookFair>>.broadcast();
  BookFair? _draft;

  void _notify() {
    _controller.add(List.unmodifiable(_fairs));
  }

  @override
  Future<List<BookFair>> getAllBookFairs() async {
    return List.unmodifiable(_fairs);
  }

  @override
  Future<BookFair?> getBookFairById(String id) async {
    final match = _fairs.where((f) => f.id == id);
    return match.isEmpty ? null : match.first;
  }

  @override
  Future<void> createBookFair(BookFair bookFair) async {
    _fairs.add(bookFair);
    if (_draft?.id == bookFair.id) {
      _draft = null;
    }
    _notify();
  }

  @override
  Future<void> updateBookFair(BookFair bookFair) async {
    final index = _fairs.indexWhere((f) => f.id == bookFair.id);
    if (index != -1) {
      _fairs[index] = bookFair;
      _notify();
    }
  }

  @override
  Future<void> deleteBookFair(String id) async {
    _fairs.removeWhere((f) => f.id == id);
    _notify();
  }

  @override
  Future<void> toggleArchiveBookFair(String id) async {
    final index = _fairs.indexWhere((f) => f.id == id);
    if (index != -1) {
      final fair = _fairs[index];
      _fairs[index] = fair.copyWith(isArchived: !fair.isArchived);
      _notify();
    }
  }

  @override
  Future<void> saveDraft(BookFair bookFair) async {
    _draft = bookFair;
  }

  @override
  Future<BookFair?> getDraft() async {
    return _draft;
  }

  @override
  Future<void> clearDraft() async {
    _draft = null;
  }

  @override
  Stream<List<BookFair>> watchBookFairs() {
    return _controller.stream;
  }
}
