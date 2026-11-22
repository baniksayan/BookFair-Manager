import '../entities/expense.dart';
import '../entities/expense_category.dart';

/// Contract for business operations on stall operational expenses.
abstract class ExpenseRepository {
  Future<List<Expense>> getExpenses({String? fairId});
  Stream<List<Expense>> watchExpenses({String? fairId});
  Future<Expense?> getExpenseById(String id);
  Future<Expense> createExpense(
    Expense expense, {
    int? initialPaymentAmountPaise,
    String? paymentMethod,
    String? paidByPartnerId,
    String? paidFromAccountId,
    String? referenceNumber,
    String? clientRequestId,
  });
  Future<Expense> updateExpense(Expense expense);
  Future<void> cancelExpense(
    String id,
    String reason, {
    String? refundToAccountId,
    int? refundAmountPaise,
    String? clientRequestId,
  });

  /// Records a partial or complete refund for disbursed expense payments.
  ///
  /// Cumulative refunds are strictly checked and cannot exceed previously disbursed funds.
  Future<void> recordExpenseRefund({
    required String expenseId,
    required String toAccountId,
    required int amountPaise,
    required String reason,
    String? clientRequestId,
  });

  /// Explicitly writes off the remaining outstanding obligations of an expense with an audit trail.
  Future<Expense> writeOffExpenseOutstanding({
    required String expenseId,
    required String reason,
    String? clientRequestId,
  });

  /// Returns the sum of all valid, non-voided refunds committed for this expense.
  Future<int> getCumulativeRefundsPaise(String expenseId);

  Future<List<ExpenseCategory>> getCategories();
  Stream<List<ExpenseCategory>> watchCategories();
  Future<ExpenseCategory> addCategory(String name, {String? iconName});
}
