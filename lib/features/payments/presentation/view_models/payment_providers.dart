import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../book_fairs/presentation/view_models/book_fair_providers.dart';
import '../../../cashbook/presentation/view_models/cashbook_providers.dart';
import '../../../expenses/data/datasources/expense_local_datasource.dart';
import '../../data/datasources/payment_local_datasource.dart';
import '../../data/repositories/payment_repository_impl.dart';
import '../../domain/entities/payment_record.dart';
import '../../domain/repositories/payment_repository.dart';

// --- Data Source Provider ---
final paymentLocalDataSourceProvider = Provider<PaymentLocalDataSource>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return PaymentLocalDataSourceImpl(db);
});

final expenseLocalDataSourceProvider = Provider<ExpenseLocalDataSource>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ExpenseLocalDataSourceImpl(db);
});

// --- Repository Provider ---
final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  final paymentDs = ref.watch(paymentLocalDataSourceProvider);
  final expenseDs = ref.watch(expenseLocalDataSourceProvider);
  final cashbookRepo = ref.watch(cashbookRepositoryProvider);
  final db = ref.watch(appDatabaseProvider);
  final logs = ref.watch(activityLogRepositoryProvider);
  final coordinator = ref.watch(financialOperationCoordinatorProvider);

  return PaymentRepositoryImpl(
    paymentDataSource: paymentDs,
    cashbookRepository: cashbookRepo,
    expenseDataSource: expenseDs,
    database: db,
    activityLogs: logs,
    coordinator: coordinator,
  );
});

// --- Reactive Stream Providers ---

/// Stream of all payment records with optional filters.
final paymentsStreamProvider =
    StreamProvider.family<
      List<PaymentRecord>,
      ({String? fairId, String? relatedEntityType, String? relatedEntityId})
    >((ref, filter) {
      final repo = ref.watch(paymentRepositoryProvider);
      return repo.watchPayments(
        fairId: filter.fairId,
        relatedEntityType: filter.relatedEntityType,
        relatedEntityId: filter.relatedEntityId,
      );
    });
