import '../entities/account_transaction.dart';
import '../entities/cashbook_account.dart';

/// Contract for managing cashbook accounts, transaction ledgers, and account transfers.
abstract class CashbookRepository {
  Future<List<CashbookAccount>> getAccounts({String? fairId});
  Stream<List<CashbookAccount>> watchAccounts({String? fairId});
  Future<CashbookAccount?> getAccountById(String id);
  Future<CashbookAccount> createAccount(CashbookAccount account);
  Future<CashbookAccount> updateAccount(CashbookAccount account);

  Future<List<AccountTransaction>> getTransactions({
    String? accountId,
    String? fairId,
  });
  Stream<List<AccountTransaction>> watchTransactions({
    String? accountId,
    String? fairId,
  });

  /// Executes an atomic funds transfer between two accounts belonging to the same fair.
  ///
  /// Protects against insufficient balance in [fromAccountId].
  /// Produces two balanced ledger transactions sharing a common transfer reference.
  Future<void> transferFunds({
    required String fairId,
    required String fromAccountId,
    required String toAccountId,
    required int amountPaise,
    required DateTime transferDate,
    String? referenceNumber,
    String? notes,
    String? clientRequestId,
  });

  /// Records a direct debit (outflow) or credit (inflow) on an account for business operations.
  Future<AccountTransaction> recordAccountMovement({
    required String fairId,
    required String accountId,
    required String transactionType,
    required String direction,
    required int amountPaise,
    required DateTime transactionDate,
    required String referenceType,
    String? referenceId,
    required String description,
  });

  /// Reverses a previously recorded account movement for compensating rollbacks,
  /// safely restoring the previous account balance and removing the transaction record.
  Future<void> reverseAccountMovement(String transactionId);

  /// Ensures default accounts ('Main Cashbox', 'UPI / QR', 'Bank Account') exist for [fairId].
  Future<List<CashbookAccount>> ensureDefaultAccounts(String fairId);
}
