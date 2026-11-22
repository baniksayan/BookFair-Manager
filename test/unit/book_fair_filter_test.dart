import 'package:bookfair_manager/features/book_fairs/domain/entities/book_fair.dart';
import 'package:bookfair_manager/features/book_fairs/presentation/view_models/book_fair_list_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BookFair Filter & Search Logic Unit Tests', () {
    late ProviderContainer container;
    late BookFairListViewModel viewModel;

    final now = DateTime.now();

    // Create a diverse sample of fairs
    final activeFair = BookFair(
      id: 'fair-1',
      name: 'Kolkata International Book Fair',
      location: 'Milan Mela Grounds',
      city: 'Kolkata',
      state: 'West Bengal',
      startDate: now.subtract(const Duration(days: 2)),
      endDate: now.add(const Duration(days: 5)),
      estimatedBudgetPaise: 25000000,
      initialInvestmentPaise: 10000000,
      isArchived: false,
      createdAt: now.subtract(const Duration(days: 10)),
      updatedAt: now.subtract(const Duration(days: 10)),
    );

    final upcomingFair = BookFair(
      id: 'fair-2',
      name: 'New Delhi World Book Fair',
      location: 'Pragati Maidan',
      city: 'New Delhi',
      state: 'Delhi',
      startDate: now.add(const Duration(days: 10)),
      endDate: now.add(const Duration(days: 18)),
      estimatedBudgetPaise: 30000000,
      initialInvestmentPaise: 15000000,
      isArchived: false,
      createdAt: now.subtract(const Duration(days: 5)),
      updatedAt: now.subtract(const Duration(days: 5)),
    );

    final completedFair = BookFair(
      id: 'fair-3',
      name: 'Chennai Book Fair',
      location: 'YMCA Grounds',
      city: 'Chennai',
      state: 'Tamil Nadu',
      startDate: now.subtract(const Duration(days: 30)),
      endDate: now.subtract(const Duration(days: 20)),
      estimatedBudgetPaise: 15000000,
      initialInvestmentPaise: 5000000,
      isArchived: false,
      createdAt: now.subtract(const Duration(days: 40)),
      updatedAt: now.subtract(const Duration(days: 20)),
    );

    final archivedFair = BookFair(
      id: 'fair-4',
      name: 'Old Hyderabad Fair 2024',
      location: 'NTR Grounds',
      city: 'Hyderabad',
      state: 'Telangana',
      startDate: now.subtract(const Duration(days: 100)),
      endDate: now.subtract(const Duration(days: 90)),
      estimatedBudgetPaise: 12000000,
      initialInvestmentPaise: 6000000,
      isArchived: true,
      createdAt: now.subtract(const Duration(days: 120)),
      updatedAt: now.subtract(const Duration(days: 90)),
    );

    final allSampleFairs = [
      activeFair,
      upcomingFair,
      completedFair,
      archivedFair,
    ];

    setUp(() {
      container = ProviderContainer();
      viewModel = container.read(bookFairListViewModelProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    test('Filter "All" returns all non-archived book fairs', () {
      viewModel.setFilter(BookFairFilter.all);
      final results = viewModel.filterFairs(allSampleFairs);

      expect(results.length, equals(3));
      expect(results, contains(activeFair));
      expect(results, contains(upcomingFair));
      expect(results, contains(completedFair));
      expect(results, isNot(contains(archivedFair)));
    });

    test('Filter "Active" returns only currently active fairs', () {
      viewModel.setFilter(BookFairFilter.active);
      final results = viewModel.filterFairs(allSampleFairs);

      expect(results.length, equals(1));
      expect(results.first.id, equals(activeFair.id));
      expect(results.first.status, equals(BookFairStatus.active));
    });

    test('Filter "Upcoming" returns only future fairs', () {
      viewModel.setFilter(BookFairFilter.upcoming);
      final results = viewModel.filterFairs(allSampleFairs);

      expect(results.length, equals(1));
      expect(results.first.id, equals(upcomingFair.id));
      expect(results.first.status, equals(BookFairStatus.upcoming));
    });

    test('Filter "Completed" returns only past fairs', () {
      viewModel.setFilter(BookFairFilter.completed);
      final results = viewModel.filterFairs(allSampleFairs);

      expect(results.length, equals(1));
      expect(results.first.id, equals(completedFair.id));
      expect(results.first.status, equals(BookFairStatus.completed));
    });

    test('Filter "Archived" segregates and returns only archived fairs', () {
      viewModel.setFilter(BookFairFilter.archived);
      final results = viewModel.filterFairs(allSampleFairs);

      expect(results.length, equals(1));
      expect(results.first.id, equals(archivedFair.id));
      expect(results.first.isArchived, isTrue);
    });

    test('Search query string matching by fair name is case-insensitive', () {
      viewModel.setFilter(BookFairFilter.all);
      viewModel.setSearchQuery('kolkata');
      final results = viewModel.filterFairs(allSampleFairs);

      expect(results.length, equals(1));
      expect(results.first.name, equals('Kolkata International Book Fair'));
    });

    test('Search query matches location, city, and state attributes', () {
      viewModel.setFilter(BookFairFilter.all);

      // Match venue location
      viewModel.setSearchQuery('Pragati Maidan');
      expect(viewModel.filterFairs(allSampleFairs).length, equals(1));

      // Match city
      viewModel.setSearchQuery('chennai');
      expect(viewModel.filterFairs(allSampleFairs).length, equals(1));

      // Match state
      viewModel.setSearchQuery('delhi');
      expect(viewModel.filterFairs(allSampleFairs).length, equals(1));
    });

    test(
      'Empty search query and whitespace do not restrict filter results',
      () {
        viewModel.setFilter(BookFairFilter.all);
        viewModel.setSearchQuery('   ');
        final results = viewModel.filterFairs(allSampleFairs);

        expect(results.length, equals(3));
      },
    );

    test('Combined filter and search behaves conjunctively', () {
      // Searching for "Delhi" with "Upcoming" should match
      viewModel.setFilter(BookFairFilter.upcoming);
      viewModel.setSearchQuery('Delhi');
      expect(viewModel.filterFairs(allSampleFairs).length, equals(1));

      // Searching for "Delhi" with "Active" should return empty
      viewModel.setFilter(BookFairFilter.active);
      viewModel.setSearchQuery('Delhi');
      expect(viewModel.filterFairs(allSampleFairs), isEmpty);
    });
  });
}
