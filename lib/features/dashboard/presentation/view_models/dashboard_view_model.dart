import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../book_fairs/domain/entities/activity_log.dart';
import '../../../book_fairs/domain/entities/book_fair.dart';
import '../../../book_fairs/presentation/view_models/book_fair_providers.dart';
import '../../domain/entities/dashboard_summary.dart';

/// State container for the Dashboard screen
class DashboardState {
  const DashboardState({
    this.isLoading = false,
    this.summary,
    this.activities = const [],
    this.errorMessage,
  });

  final bool isLoading;
  final DashboardSummary? summary;
  final List<ActivityLog> activities;
  final String? errorMessage;

  DashboardState copyWith({
    bool? isLoading,
    DashboardSummary? summary,
    List<ActivityLog>? activities,
    String? errorMessage,
  }) {
    return DashboardState(
      isLoading: isLoading ?? this.isLoading,
      summary: summary ?? this.summary,
      activities: activities ?? this.activities,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// View model managing dashboard state backed by real Hive local data
final dashboardViewModelProvider =
    NotifierProvider<DashboardViewModel, DashboardState>(
      DashboardViewModel.new,
    );

class DashboardViewModel extends Notifier<DashboardState> {
  StreamSubscription? _fairsSub;
  StreamSubscription? _logsSub;

  @override
  DashboardState build() {
    // Listen to reactive streams from Hive
    final fairRepo = ref.watch(bookFairRepositoryProvider);
    final logRepo = ref.watch(activityLogRepositoryProvider);

    _fairsSub?.cancel();
    _logsSub?.cancel();

    _fairsSub = fairRepo.watchBookFairs().listen((_) {
      loadDashboardData();
    });

    _logsSub = logRepo.watchRecentLogs().listen((_) {
      loadDashboardData();
    });

    ref.onDispose(() {
      _fairsSub?.cancel();
      _logsSub?.cancel();
    });

    Future.microtask(loadDashboardData);
    return const DashboardState(isLoading: true);
  }

  Future<void> loadDashboardData() async {
    try {
      final fairRepo = ref.read(bookFairRepositoryProvider);
      final investmentRepo = ref.read(investmentRepositoryProvider);
      final logRepo = ref.read(activityLogRepositoryProvider);

      final fairs = await fairRepo.getAllBookFairs();
      final nonArchived = fairs.where((f) => !f.isArchived).toList();

      final activeFairs = nonArchived
          .where((f) => f.status == BookFairStatus.active)
          .length;
      final upcomingFairs = nonArchived
          .where((f) => f.status == BookFairStatus.upcoming)
          .length;

      // Sum total investments across all fairs
      var totalInvestmentPaise = 0;
      for (final fair in fairs) {
        final invs = await investmentRepo.getInvestmentsForFair(fair.id);
        for (final inv in invs) {
          totalInvestmentPaise += inv.amountPaise;
        }
      }

      // Determine featured active or upcoming fair
      BookFair? featuredFair;
      for (final f in nonArchived) {
        if (f.status == BookFairStatus.active) {
          featuredFair = f;
          break;
        }
      }
      featuredFair ??= nonArchived.isNotEmpty ? nonArchived.first : null;

      final summary = DashboardSummary(
        totalFairs: nonArchived.length,
        activeFairs: activeFairs,
        upcomingFairs: upcomingFairs,
        totalRecordedInvestment: totalInvestmentPaise / 100.0,
        activeFair: featuredFair,
        isSampleData: false,
      );

      final activities = await logRepo.getRecentLogs(limit: 6);

      state = state.copyWith(
        isLoading: false,
        summary: summary,
        activities: activities,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }
}
