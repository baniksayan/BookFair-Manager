import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/book.dart';

enum BookStockFilter {
  all,
  inStock,
  lowStock,
  outOfStock,
  previousStock;

  String get displayName {
    switch (this) {
      case BookStockFilter.all:
        return 'All Titles';
      case BookStockFilter.inStock:
        return 'In Stock';
      case BookStockFilter.lowStock:
        return 'Low Stock (≤5)';
      case BookStockFilter.outOfStock:
        return 'Out of Stock';
      case BookStockFilter.previousStock:
        return 'Previous Stock';
    }
  }
}

class BookCatalogueState {
  const BookCatalogueState({
    this.searchQuery = '',
    this.stockFilter = BookStockFilter.all,
    this.conditionFilter,
    this.genreFilter,
  });

  final String searchQuery;
  final BookStockFilter stockFilter;
  final BookCondition? conditionFilter;
  final String? genreFilter;

  BookCatalogueState copyWith({
    String? searchQuery,
    BookStockFilter? stockFilter,
    BookCondition? conditionFilter,
    String? genreFilter,
    bool clearCondition = false,
    bool clearGenre = false,
  }) {
    return BookCatalogueState(
      searchQuery: searchQuery ?? this.searchQuery,
      stockFilter: stockFilter ?? this.stockFilter,
      conditionFilter: clearCondition
          ? null
          : (conditionFilter ?? this.conditionFilter),
      genreFilter: clearGenre ? null : (genreFilter ?? this.genreFilter),
    );
  }
}

final bookCatalogueViewModelProvider =
    NotifierProvider<BookCatalogueViewModel, BookCatalogueState>(
      BookCatalogueViewModel.new,
    );

class BookCatalogueViewModel extends Notifier<BookCatalogueState> {
  @override
  BookCatalogueState build() => const BookCatalogueState();

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setStockFilter(BookStockFilter filter) {
    state = state.copyWith(stockFilter: filter);
  }

  void setConditionFilter(BookCondition? condition) {
    if (condition == null) {
      state = state.copyWith(clearCondition: true);
    } else {
      state = state.copyWith(conditionFilter: condition);
    }
  }

  void setGenreFilter(String? genre) {
    if (genre == null) {
      state = state.copyWith(clearGenre: true);
    } else {
      state = state.copyWith(genreFilter: genre);
    }
  }

  /// Filters a raw list of books based on current search query, stock status, and condition.
  List<Book> filterBooks({
    required List<Book> books,
    Map<String, int> stockMap = const {},
  }) {
    return books.where((book) {
      final availableStock = stockMap[book.id] ?? book.openingStockQuantity;

      // Filter by stock status
      switch (state.stockFilter) {
        case BookStockFilter.all:
          break;
        case BookStockFilter.inStock:
          if (availableStock <= 0) return false;
          break;
        case BookStockFilter.lowStock:
          if (availableStock <= 0 || availableStock > 5) return false;
          break;
        case BookStockFilter.outOfStock:
          if (availableStock > 0) return false;
          break;
        case BookStockFilter.previousStock:
          if (!book.isPreviousStock) return false;
          break;
      }

      // Filter by condition
      if (state.conditionFilter != null &&
          book.condition != state.conditionFilter) {
        return false;
      }

      // Filter by genre
      if (state.genreFilter != null &&
          state.genreFilter!.isNotEmpty &&
          book.genre.toLowerCase() != state.genreFilter!.toLowerCase()) {
        return false;
      }

      // Search query string filter (title, author, publisher, ISBN)
      if (state.searchQuery.trim().isNotEmpty) {
        final q = state.searchQuery.trim().toLowerCase();
        final matchTitle = book.title.toLowerCase().contains(q);
        final matchAuthor = book.author.toLowerCase().contains(q);
        final matchPublisher = book.publisher.toLowerCase().contains(q);
        final matchGenre = book.genre.toLowerCase().contains(q);
        final matchIsbn =
            (book.isbn10?.toLowerCase().contains(q) ?? false) ||
            (book.isbn13?.toLowerCase().contains(q) ?? false);

        return matchTitle ||
            matchAuthor ||
            matchPublisher ||
            matchGenre ||
            matchIsbn;
      }

      return true;
    }).toList();
  }
}
