import '../../../../core/database/app_database.dart';
import '../models/account_transaction_model.dart';
import '../models/cashbook_account_model.dart';

/// Contract for low-level Hive operations on liquid holding accounts and ledger transactions.
abstract class CashbookLocalDataSource {
  List<CashbookAccountModel> getAccounts({String? fairId});
  Stream<List<CashbookAccountModel>> watchAccounts({String? fairId});
  CashbookAccountModel? getAccountById(String id);
  Future<void> saveAccount(CashbookAccountModel account);
  Future<void> deleteAccount(String id);

  List<AccountTransactionModel> getTransactions({
    String? accountId,
    String? fairId,
  });
  Stream<List<AccountTransactionModel>> watchTransactions({
    String? accountId,
    String? fairId,
  });
  Future<void> saveTransaction(AccountTransactionModel transaction);
  Future<void> deleteTransaction(String id);
  AccountTransactionModel? getTransactionById(String id);
}

/// Hive implementation of [CashbookLocalDataSource].
class CashbookLocalDataSourceImpl implements CashbookLocalDataSource {
  const CashbookLocalDataSourceImpl(this._db);

  final AppDatabase _db;

  @override
  List<CashbookAccountModel> getAccounts({String? fairId}) {
    final list = _db.cashbookAccounts.values.toList();
    if (fairId != null) {
      return list.where((a) => a.fairId == fairId).toList();
    }
    return list;
  }

  @override
  Stream<List<CashbookAccountModel>> watchAccounts({String? fairId}) async* {
    yield getAccounts(fairId: fairId);
    yield* _db.cashbookAccounts.watch().map((_) => getAccounts(fairId: fairId));
  }

  @override
  CashbookAccountModel? getAccountById(String id) {
    try {
      return _db.cashbookAccounts.values.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveAccount(CashbookAccountModel account) async {
    await _db.cashbookAccounts.put(account.id, account);
  }

  @override
  Future<void> deleteAccount(String id) async {
    await _db.cashbookAccounts.delete(id);
  }

  @override
  List<AccountTransactionModel> getTransactions({
    String? accountId,
    String? fairId,
  }) {
    var list = _db.accountTransactions.values.toList();
    if (fairId != null) {
      list = list.where((t) => t.fairId == fairId).toList();
    }
    if (accountId != null) {
      list = list.where((t) => t.accountId == accountId).toList();
    }
    // Sort newest first
    list.sort(
      (a, b) => b.transactionDateEpoch.compareTo(a.transactionDateEpoch),
    );
    return list;
  }

  @override
  Stream<List<AccountTransactionModel>> watchTransactions({
    String? accountId,
    String? fairId,
  }) async* {
    yield getTransactions(accountId: accountId, fairId: fairId);
    yield* _db.accountTransactions.watch().map(
      (_) => getTransactions(accountId: accountId, fairId: fairId),
    );
  }

  @override
  Future<void> saveTransaction(AccountTransactionModel transaction) async {
    await _db.accountTransactions.put(transaction.id, transaction);
  }

  @override
  Future<void> deleteTransaction(String id) async {
    await _db.accountTransactions.delete(id);
  }

  @override
  AccountTransactionModel? getTransactionById(String id) {
    try {
      return _db.accountTransactions.get(id);
    } catch (_) {
      return null;
    }
  }
}
