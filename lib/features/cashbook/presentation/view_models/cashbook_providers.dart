import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../book_fairs/presentation/view_models/book_fair_providers.dart';
import '../../data/datasources/cashbook_local_datasource.dart';
import '../../data/datasources/financial_operation_local_datasource.dart';
import '../../data/repositories/cashbook_repository_impl.dart';
import '../../domain/entities/account_transaction.dart';
import '../../domain/entities/cashbook_account.dart';
import '../../domain/repositories/cashbook_repository.dart';
import '../../domain/services/financial_operation_coordinator.dart';

// --- Data Source Provider ---
final cashbookLocalDataSourceProvider = Provider<CashbookLocalDataSource>((
  ref,
) {
  final db = ref.watch(appDatabaseProvider);
  return CashbookLocalDataSourceImpl(db);
});

final financialOperationLocalDataSourceProvider =
    Provider<FinancialOperationLocalDataSource>((ref) {
      final db = ref.watch(appDatabaseProvider);
      return FinancialOperationLocalDataSourceImpl(db);
    });

final financialOperationCoordinatorProvider =
    Provider<FinancialOperationCoordinator>((ref) {
      final journalDs = ref.watch(financialOperationLocalDataSourceProvider);
      return FinancialOperationCoordinator(journalDataSource: journalDs);
    });

// --- Repository Provider ---
final cashbookRepositoryProvider = Provider<CashbookRepository>((ref) {
  final ds = ref.watch(cashbookLocalDataSourceProvider);
  final logs = ref.watch(activityLogRepositoryProvider);
  final coordinator = ref.watch(financialOperationCoordinatorProvider);
  return CashbookRepositoryImpl(ds, logs, coordinator: coordinator);
});

// --- Reactive Stream Providers ---

/// Stream of all business cashbook accounts, optionally filtered by [fairId].
final cashbookAccountsStreamProvider =
    StreamProvider.family<List<CashbookAccount>, String?>((ref, fairId) {
      final repo = ref.watch(cashbookRepositoryProvider);
      return repo.watchAccounts(fairId: fairId);
    });

/// Stream of all ledger transactions, optionally filtered by [fairId] and [accountId].
final accountTransactionsStreamProvider =
    StreamProvider.family<
      List<AccountTransaction>,
      ({String? fairId, String? accountId})
    >((ref, filter) {
      final repo = ref.watch(cashbookRepositoryProvider);
      return repo.watchTransactions(
        fairId: filter.fairId,
        accountId: filter.accountId,
      );
    });

/// Stream of a specific cashbook account by ID.
final cashbookAccountDetailsStreamProvider =
    StreamProvider.family<CashbookAccount?, String>((ref, accountId) async* {
      final repo = ref.watch(cashbookRepositoryProvider);
      await for (final accounts in repo.watchAccounts()) {
        yield accounts.cast<CashbookAccount?>().firstWhere(
          (a) => a?.id == accountId,
          orElse: () => null,
        );
      }
    });
