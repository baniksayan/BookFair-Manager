import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/book_fair.dart';
import 'book_fair_providers.dart';

enum BookFairFilter {
  all,
  active,
  upcoming,
  completed,
  archived;

  String get displayName {
    switch (this) {
      case BookFairFilter.all:
        return 'All';
      case BookFairFilter.active:
        return 'Active';
      case BookFairFilter.upcoming:
        return 'Upcoming';
      case BookFairFilter.completed:
        return 'Completed';
      case BookFairFilter.archived:
        return 'Archived';
    }
  }
}

/// State container for the Book Fair listing screen
class BookFairListState {
  const BookFairListState({
    this.searchQuery = '',
    this.activeFilter = BookFairFilter.all,
    this.errorMessage,
  });

  final String searchQuery;
  final BookFairFilter activeFilter;
  final String? errorMessage;

  BookFairListState copyWith({
    String? searchQuery,
    BookFairFilter? activeFilter,
    String? errorMessage,
  }) {
    return BookFairListState(
      searchQuery: searchQuery ?? this.searchQuery,
      activeFilter: activeFilter ?? this.activeFilter,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final bookFairListViewModelProvider =
    NotifierProvider<BookFairListViewModel, BookFairListState>(
      BookFairListViewModel.new,
    );

class BookFairListViewModel extends Notifier<BookFairListState> {
  @override
  BookFairListState build() => const BookFairListState();

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setFilter(BookFairFilter filter) {
    state = state.copyWith(activeFilter: filter);
  }

  Future<void> deleteFair(String id) async {
    try {
      final repo = ref.read(bookFairRepositoryProvider);
      await repo.deleteBookFair(id);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> toggleArchive(String id) async {
    try {
      final repo = ref.read(bookFairRepositoryProvider);
      await repo.toggleArchiveBookFair(id);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  /// Filters and searches the raw list of fairs
  List<BookFair> filterFairs(List<BookFair> rawFairs) {
    return rawFairs.where((fair) {
      // Filter by status tab
      switch (state.activeFilter) {
        case BookFairFilter.all:
          if (fair.isArchived) return false; // Archived are segregated
          break;
        case BookFairFilter.active:
          if (fair.isArchived || fair.status != BookFairStatus.active) {
            return false;
          }
          break;
        case BookFairFilter.upcoming:
          if (fair.isArchived || fair.status != BookFairStatus.upcoming) {
            return false;
          }
          break;
        case BookFairFilter.completed:
          if (fair.isArchived || fair.status != BookFairStatus.completed) {
            return false;
          }
          break;
        case BookFairFilter.archived:
          if (!fair.isArchived) return false;
          break;
      }

      // Search query filter (matches name, location, city, state)
      if (state.searchQuery.trim().isNotEmpty) {
        final q = state.searchQuery.trim().toLowerCase();
        final matchName = fair.name.toLowerCase().contains(q);
        final matchLocation = fair.location.toLowerCase().contains(q);
        final matchCity = fair.city.toLowerCase().contains(q);
        final matchState = fair.state.toLowerCase().contains(q);
        return matchName || matchLocation || matchCity || matchState;
      }

      return true;
    }).toList();
  }
}
