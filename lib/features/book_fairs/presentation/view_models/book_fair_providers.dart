import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/utils/financial_calculator.dart';
import '../../data/datasources/book_fair_local_datasource.dart';
import '../../data/repositories/activity_log_repository_impl.dart';
import '../../data/repositories/book_fair_repository_impl.dart';
import '../../data/repositories/investment_repository_impl.dart';
import '../../data/repositories/partner_repository_impl.dart';
import '../../domain/entities/activity_log.dart';
import '../../domain/entities/book_fair.dart';
import '../../domain/entities/investment.dart';
import '../../domain/entities/partner.dart';
import '../../domain/repositories/activity_log_repository.dart';
import '../../domain/repositories/book_fair_repository.dart';
import '../../domain/repositories/investment_repository.dart';
import '../../domain/repositories/partner_repository.dart';

// --- Data Source Provider ---
final bookFairLocalDataSourceProvider = Provider<BookFairLocalDataSource>((
  ref,
) {
  final db = ref.watch(appDatabaseProvider);
  return BookFairLocalDataSourceImpl(db);
});

// --- Repository Providers ---
final activityLogRepositoryProvider = Provider<ActivityLogRepository>((ref) {
  final ds = ref.watch(bookFairLocalDataSourceProvider);
  return ActivityLogRepositoryImpl(ds);
});

final bookFairRepositoryProvider = Provider<BookFairRepository>((ref) {
  final ds = ref.watch(bookFairLocalDataSourceProvider);
  final logs = ref.watch(activityLogRepositoryProvider);
  return BookFairRepositoryImpl(ds, logs);
});

final partnerRepositoryProvider = Provider<PartnerRepository>((ref) {
  final ds = ref.watch(bookFairLocalDataSourceProvider);
  final logs = ref.watch(activityLogRepositoryProvider);
  return PartnerRepositoryImpl(ds, logs);
});

final investmentRepositoryProvider = Provider<InvestmentRepository>((ref) {
  final ds = ref.watch(bookFairLocalDataSourceProvider);
  final logs = ref.watch(activityLogRepositoryProvider);
  return InvestmentRepositoryImpl(ds, logs);
});

// --- Reactive Stream Providers ---

/// Stream of all book fairs stored in Hive
final bookFairsStreamProvider = StreamProvider<List<BookFair>>((ref) {
  final repo = ref.watch(bookFairRepositoryProvider);
  return repo.watchBookFairs();
});

/// Stream of a specific book fair by [fairId]
final bookFairDetailsStreamProvider = StreamProvider.family<BookFair?, String>((
  ref,
  fairId,
) {
  final repo = ref.watch(bookFairRepositoryProvider);
  return repo.watchBookFairs().map((fairs) {
    for (final f in fairs) {
      if (f.id == fairId) return f;
    }
    return null;
  });
});

/// Stream of all active partners for a given [fairId]
final partnersForFairStreamProvider =
    StreamProvider.family<List<Partner>, String>((ref, fairId) {
      final repo = ref.watch(partnerRepositoryProvider);
      return repo.watchPartnersForFair(fairId);
    });

/// Stream of all recorded investments for a given [fairId]
final investmentsForFairStreamProvider =
    StreamProvider.family<List<Investment>, String>((ref, fairId) {
      final repo = ref.watch(investmentRepositoryProvider);
      return repo.watchInvestmentsForFair(fairId);
    });

/// Stream of recent system activity logs
final recentActivityLogsStreamProvider = StreamProvider<List<ActivityLog>>((
  ref,
) {
  final repo = ref.watch(activityLogRepositoryProvider);
  return repo.watchRecentLogs(limit: 10);
});

/// Financial summary data bundle for a specific Book Fair
class FairFinancialSummary {
  const FairFinancialSummary({
    required this.estimatedBudget,
    required this.estimatedBudgetPaise,
    required this.totalRecordedInvestment,
    required this.totalRecordedInvestmentPaise,
    required this.remainingPlannedBudget,
    required this.remainingPlannedBudgetPaise,
    required this.partnerCount,
    required this.investmentsCount,
  });

  final double estimatedBudget;
  final int estimatedBudgetPaise;
  final double totalRecordedInvestment;
  final int totalRecordedInvestmentPaise;
  final double remainingPlannedBudget;
  final int remainingPlannedBudgetPaise;
  final int partnerCount;
  final int investmentsCount;
}

/// Computes real-time financial stats for a given [fairId]
final fairFinancialSummaryProvider =
    Provider.family<FairFinancialSummary, String>((ref, fairId) {
      final fairAsync = ref.watch(bookFairDetailsStreamProvider(fairId));
      final partnersAsync = ref.watch(partnersForFairStreamProvider(fairId));
      final investmentsAsync = ref.watch(
        investmentsForFairStreamProvider(fairId),
      );

      final fair = fairAsync.value;
      final partners = partnersAsync.value ?? [];
      final investments = investmentsAsync.value ?? [];

      final estimatedBudgetPaise = fair?.estimatedBudgetPaise ?? 0;
      final recordedInvestmentPaise =
          FinancialCalculator.calculateTotalInvestmentPaise(investments);
      final remainingPlannedBudgetPaise =
          FinancialCalculator.calculateRemainingPlannedBudgetPaise(
            estimatedBudgetPaise: estimatedBudgetPaise,
            recordedInvestmentPaise: recordedInvestmentPaise,
          );

      return FairFinancialSummary(
        estimatedBudget: estimatedBudgetPaise / 100.0,
        estimatedBudgetPaise: estimatedBudgetPaise,
        totalRecordedInvestment: recordedInvestmentPaise / 100.0,
        totalRecordedInvestmentPaise: recordedInvestmentPaise,
        remainingPlannedBudget: remainingPlannedBudgetPaise / 100.0,
        remainingPlannedBudgetPaise: remainingPlannedBudgetPaise,
        partnerCount: partners.length,
        investmentsCount: investments.length,
      );
    });
