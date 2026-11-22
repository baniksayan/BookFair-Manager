import '../entities/book_fair.dart';

/// Abstract domain repository interface for book fair entity lifecycle operations.
abstract interface class BookFairRepository {
  Future<List<BookFair>> getAllBookFairs();
  Future<BookFair?> getBookFairById(String id);
  Future<void> createBookFair(BookFair bookFair);
  Future<void> updateBookFair(BookFair bookFair);
  Future<void> deleteBookFair(String id);
  Future<void> toggleArchiveBookFair(String id);
  Future<void> saveDraft(BookFair bookFair);
  Future<BookFair?> getDraft();
  Future<void> clearDraft();
  Stream<List<BookFair>> watchBookFairs();
}
