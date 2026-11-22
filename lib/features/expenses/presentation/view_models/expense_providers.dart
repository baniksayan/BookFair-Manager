import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../book_fairs/presentation/view_models/book_fair_providers.dart';
import '../../../cashbook/presentation/view_models/cashbook_providers.dart';
import '../../../payments/presentation/view_models/payment_providers.dart';
import '../../data/repositories/expense_repository_impl.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_category.dart';
import '../../domain/repositories/expense_repository.dart';

// --- Repository Provider ---
final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  final ds = ref.watch(expenseLocalDataSourceProvider);
  final paymentRepo = ref.watch(paymentRepositoryProvider);
  final logs = ref.watch(activityLogRepositoryProvider);
  final cashbookRepo = ref.watch(cashbookRepositoryProvider);
  final coordinator = ref.watch(financialOperationCoordinatorProvider);

  return ExpenseRepositoryImpl(
    expenseDataSource: ds,
    paymentRepository: paymentRepo,
    activityLogs: logs,
    cashbookRepository: cashbookRepo,
    coordinator: coordinator,
  );
});

// --- Reactive Stream Providers ---

/// Stream of all expenses, optionally filtered by [fairId].
final expensesStreamProvider = StreamProvider.family<List<Expense>, String?>((
  ref,
  fairId,
) {
  final repo = ref.watch(expenseRepositoryProvider);
  return repo.watchExpenses(fairId: fairId);
});

/// Stream of a specific expense by [id].
final expenseDetailsStreamProvider = StreamProvider.family<Expense?, String>((
  ref,
  expenseId,
) async* {
  final repo = ref.watch(expenseRepositoryProvider);
  await for (final expenses in repo.watchExpenses()) {
    yield expenses.cast<Expense?>().firstWhere(
      (e) => e?.id == expenseId,
      orElse: () => null,
    );
  }
});

/// Stream of all expense categories.
final expenseCategoriesStreamProvider = StreamProvider<List<ExpenseCategory>>((
  ref,
) {
  final repo = ref.watch(expenseRepositoryProvider);
  return repo.watchCategories();
});
