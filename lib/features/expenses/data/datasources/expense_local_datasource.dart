import '../../../../core/database/app_database.dart';
import '../models/expense_category_model.dart';
import '../models/expense_model.dart';

/// Contract for low-level Hive data operations on expenses and categories.
abstract class ExpenseLocalDataSource {
  List<ExpenseModel> getAllExpenses({String? fairId});
  Stream<List<ExpenseModel>> watchExpenses({String? fairId});
  ExpenseModel? getExpenseById(String id);
  Future<void> saveExpense(ExpenseModel expense);
  Future<void> deleteExpense(String id);

  List<ExpenseCategoryModel> getAllCategories();
  Stream<List<ExpenseCategoryModel>> watchCategories();
  ExpenseCategoryModel? getCategoryById(String id);
  Future<void> saveCategory(ExpenseCategoryModel category);
}

/// Hive implementation of [ExpenseLocalDataSource].
class ExpenseLocalDataSourceImpl implements ExpenseLocalDataSource {
  const ExpenseLocalDataSourceImpl(this._db);

  final AppDatabase _db;

  @override
  List<ExpenseModel> getAllExpenses({String? fairId}) {
    final list = _db.expenses.values.toList();
    if (fairId != null) {
      return list.where((e) => e.fairId == fairId).toList();
    }
    return list;
  }

  @override
  Stream<List<ExpenseModel>> watchExpenses({String? fairId}) async* {
    yield getAllExpenses(fairId: fairId);
    yield* _db.expenses.watch().map((_) => getAllExpenses(fairId: fairId));
  }

  @override
  ExpenseModel? getExpenseById(String id) {
    try {
      return _db.expenses.values.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveExpense(ExpenseModel expense) async {
    await _db.expenses.put(expense.id, expense);
  }

  @override
  Future<void> deleteExpense(String id) async {
    await _db.expenses.delete(id);
  }

  @override
  List<ExpenseCategoryModel> getAllCategories() {
    return _db.expenseCategories.values.toList();
  }

  @override
  Stream<List<ExpenseCategoryModel>> watchCategories() async* {
    yield getAllCategories();
    yield* _db.expenseCategories.watch().map((_) => getAllCategories());
  }

  @override
  ExpenseCategoryModel? getCategoryById(String id) {
    try {
      return _db.expenseCategories.values.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveCategory(ExpenseCategoryModel category) async {
    await _db.expenseCategories.put(category.id, category);
  }
}
