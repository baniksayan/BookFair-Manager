import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_exceptions.dart';
import '../../../book_fairs/domain/entities/activity_log.dart';
import '../../../book_fairs/domain/repositories/activity_log_repository.dart';
import '../../domain/entities/account_transaction.dart';
import '../../domain/entities/cashbook_account.dart';
import '../../domain/repositories/cashbook_repository.dart';
import '../../domain/services/financial_operation_coordinator.dart';
import '../datasources/cashbook_local_datasource.dart';
import '../datasources/financial_operation_local_datasource.dart';
import '../models/account_transaction_model.dart';
import '../models/cashbook_account_model.dart';

/// Concrete Hive implementation of [CashbookRepository].
class CashbookRepositoryImpl implements CashbookRepository {
  CashbookRepositoryImpl(
    this._dataSource,
    this._activityLogs, {
    FinancialOperationCoordinator? coordinator,
    Uuid? uuid,
  }) : _coordinator =
           coordinator ??
           FinancialOperationCoordinator(
             journalDataSource: const FinancialOperationLocalDataSourceImpl(
               AppDatabase(),
             ),
             uuid: uuid,
           ),
       _uuid = uuid ?? const Uuid();

  final CashbookLocalDataSource _dataSource;
  final ActivityLogRepository _activityLogs;
  final FinancialOperationCoordinator _coordinator;
  final Uuid _uuid;

  @override
  Future<List<CashbookAccount>> getAccounts({String? fairId}) async {
    return _dataSource
        .getAccounts(fairId: fairId)
        .map((m) => m.toEntity())
        .toList();
  }

  @override
  Stream<List<CashbookAccount>> watchAccounts({String? fairId}) {
    return _dataSource
        .watchAccounts(fairId: fairId)
        .map((list) => list.map((m) => m.toEntity()).toList());
  }

  @override
  Future<CashbookAccount?> getAccountById(String id) async {
    return _dataSource.getAccountById(id)?.toEntity();
  }

  @override
  Future<CashbookAccount> createAccount(CashbookAccount account) async {
    final model = CashbookAccountModel.fromEntity(account);
    await _dataSource.saveAccount(model);

    // Establish v5 baseline snapshot in metadataBox for the newly created account
    const db = AppDatabase();
    final baselineKey = 'account_baseline_v5_${account.id}';
    final cutoverKey = 'account_cutover_epoch_v5_${account.id}';
    if (!db.metadata.containsKey(baselineKey)) {
      await db.metadata.put(baselineKey, account.openingBalancePaise);
      await db.metadata.put(
        cutoverKey,
        account.createdAt.millisecondsSinceEpoch,
      );
      await db.metadata.flush();
    }

    // If opening balance > 0, generate opening balance transaction
    if (account.openingBalancePaise > 0) {
      final tx = AccountTransaction(
        id: _uuid.v4(),
        fairId: account.fairId,
        accountId: account.id,
        transactionType: 'opening_balance',
        direction: 'inflow',
        amountPaise: account.openingBalancePaise,
        transactionDate: account.createdAt,
        referenceType: 'manual',
        description: 'Initial opening balance for ${account.accountName}',
        createdAt: account.createdAt,
      );
      await _dataSource.saveTransaction(AccountTransactionModel.fromEntity(tx));
    }

    await _activityLogs.logEvent(
      ActivityLog(
        id: _uuid.v4(),
        fairId: account.fairId,
        title: 'Payment Account Created',
        subtitle:
            'Established ${account.accountName} (${account.accountType.toUpperCase()})',
        amount: '₹${(account.openingBalancePaise / 100.0).toStringAsFixed(2)}',
        type: ActivityLogType.fairUpdated,
        timestamp: DateTime.now(),
      ),
    );

    return account;
  }

  @override
  Future<CashbookAccount> updateAccount(CashbookAccount account) async {
    final existing = _dataSource.getAccountById(account.id);
    if (existing == null) {
      throw RecordNotFoundException('CashbookAccount', account.id);
    }
    // Invariant: Account balances cannot be modified via updateAccount.
    // Balances must only change via coordinated ledger operations.
    final sanitized = account.copyWith(
      openingBalancePaise: existing.openingBalancePaise,
      currentBalancePaise: existing.currentBalancePaise,
      updatedAt: DateTime.now(),
    );
    final model = CashbookAccountModel.fromEntity(sanitized);
    await _dataSource.saveAccount(model);
    return sanitized;
  }

  @override
  Future<List<AccountTransaction>> getTransactions({
    String? accountId,
    String? fairId,
  }) async {
    return _dataSource
        .getTransactions(accountId: accountId, fairId: fairId)
        .where(
          (m) =>
              m.transactionType != 'void_abandoned' &&
              m.referenceType != 'void_abandoned',
        )
        .map((m) => m.toEntity())
        .toList();
  }

  @override
  Stream<List<AccountTransaction>> watchTransactions({
    String? accountId,
    String? fairId,
  }) {
    return _dataSource
        .watchTransactions(accountId: accountId, fairId: fairId)
        .map(
          (list) => list
              .where(
                (m) =>
                    m.transactionType != 'void_abandoned' &&
                    m.referenceType != 'void_abandoned',
              )
              .map((m) => m.toEntity())
              .toList(),
        );
  }

  @override
  Future<void> transferFunds({
    required String fairId,
    required String fromAccountId,
    required String toAccountId,
    required int amountPaise,
    required DateTime transferDate,
    String? referenceNumber,
    String? notes,
    String? clientRequestId,
  }) async {
    if (amountPaise <= 0) {
      throw const ValidationException(
        'Transfer amount must be strictly positive',
      );
    }
    if (fromAccountId == toAccountId) {
      throw const ValidationException(
        'Cannot transfer funds to the exact same account',
      );
    }

    if (FinancialOperationCoordinator.isAccountQuarantined(fromAccountId) ||
        FinancialOperationCoordinator.isAccountQuarantined(toAccountId)) {
      throw AccountQuarantinedException(
        'Account is quarantined due to an unresolved financial recovery failure.',
      );
    }

    final fromModel = _dataSource.getAccountById(fromAccountId);
    final toModel = _dataSource.getAccountById(toAccountId);

    if (fromModel == null || toModel == null) {
      throw RecordNotFoundException(
        'CashbookAccount',
        fromModel == null ? fromAccountId : toAccountId,
      );
    }

    if (!fromModel.isActive || !toModel.isActive) {
      throw ValidationException(
        'Cannot transfer funds involving inactive account ("${!fromModel.isActive ? fromModel.accountName : toModel.accountName}")',
      );
    }

    if (fromModel.currentBalancePaise < amountPaise) {
      throw ValidationException(
        'Insufficient balance in ${fromModel.accountName}. '
        'Available: ₹${(fromModel.currentBalancePaise / 100.0).toStringAsFixed(2)}, '
        'Required: ₹${(amountPaise / 100.0).toStringAsFixed(2)}',
      );
    }

    final effectiveRequestId = clientRequestId ?? _uuid.v4();
    final transferRefId = effectiveRequestId;
    final idempotencyKey =
        'transfer_${fairId}_${fromAccountId}_${toAccountId}_$effectiveRequestId';
    final now = DateTime.now();

    final debitTxId = 'tx_debit_$effectiveRequestId';
    final creditTxId = 'tx_credit_$effectiveRequestId';

    final debitTx = AccountTransaction(
      id: debitTxId,
      fairId: fairId,
      accountId: fromAccountId,
      transactionType: 'transfer_out',
      direction: 'outflow',
      amountPaise: amountPaise,
      transactionDate: transferDate,
      referenceType: 'transfer',
      referenceId: transferRefId,
      description:
          'Transfer to ${toModel.accountName}${referenceNumber != null && referenceNumber.isNotEmpty ? ' (Ref: $referenceNumber)' : ''}${notes != null && notes.isNotEmpty ? ' • $notes' : ''}',
      createdAt: now,
    );

    final creditTx = AccountTransaction(
      id: creditTxId,
      fairId: fairId,
      accountId: toAccountId,
      transactionType: 'transfer_in',
      direction: 'inflow',
      amountPaise: amountPaise,
      transactionDate: transferDate,
      referenceType: 'transfer',
      referenceId: transferRefId,
      description:
          'Transfer from ${fromModel.accountName}${referenceNumber != null && referenceNumber.isNotEmpty ? ' (Ref: $referenceNumber)' : ''}${notes != null && notes.isNotEmpty ? ' • $notes' : ''}',
      createdAt: now,
    );

    final payload = {
      'fromAccountId': fromAccountId,
      'toAccountId': toAccountId,
      'amountPaise': amountPaise,
      'debitTxId': debitTxId,
      'creditTxId': creditTxId,
      'transferRefId': transferRefId,
      'transferDateEpoch': transferDate.millisecondsSinceEpoch,
      'originalRecords': {
        'debitTx': {
          'id': debitTx.id,
          'fairId': debitTx.fairId,
          'accountId': debitTx.accountId,
          'transactionType': debitTx.transactionType,
          'direction': debitTx.direction,
          'amountPaise': debitTx.amountPaise,
          'transactionDateEpoch':
              debitTx.transactionDate.millisecondsSinceEpoch,
          'referenceType': debitTx.referenceType,
          'referenceId': debitTx.referenceId,
          'description': debitTx.description,
        },
        'creditTx': {
          'id': creditTx.id,
          'fairId': creditTx.fairId,
          'accountId': creditTx.accountId,
          'transactionType': creditTx.transactionType,
          'direction': creditTx.direction,
          'amountPaise': creditTx.amountPaise,
          'transactionDateEpoch':
              creditTx.transactionDate.millisecondsSinceEpoch,
          'referenceType': creditTx.referenceType,
          'referenceId': creditTx.referenceId,
          'description': creditTx.description,
        },
      },
    };

    bool fromDebited = false;
    bool toCredited = false;

    const db = AppDatabase();
    final affectedBoxes = [db.accountTransactions, db.cashbookAccounts];

    await _coordinator.runCoordinatedOperation<void>(
      fairId: fairId,
      operationType: 'account_transfer',
      idempotencyKey: idempotencyKey,
      amountPaise: amountPaise,
      primaryEntityId: transferRefId,
      sourceAccountId: fromAccountId,
      targetAccountId: toAccountId,
      payload: payload,
      affectedBoxes: affectedBoxes,
      executeWrites: (opId) async {
        final freshFrom = _dataSource.getAccountById(fromAccountId);
        final freshTo = _dataSource.getAccountById(toAccountId);
        if (freshFrom == null || freshTo == null) {
          throw RecordNotFoundException(
            'CashbookAccount',
            freshFrom == null ? fromAccountId : toAccountId,
          );
        }

        if (freshFrom.currentBalancePaise < amountPaise) {
          throw ValidationException(
            'Insufficient balance in ${freshFrom.accountName}. '
            'Available: ₹${(freshFrom.currentBalancePaise / 100.0).toStringAsFixed(2)}, '
            'Required: ₹${(amountPaise / 100.0).toStringAsFixed(2)}',
          );
        }

        await _dataSource.saveTransaction(
          AccountTransactionModel.fromEntity(debitTx),
        );
        await _dataSource.saveTransaction(
          AccountTransactionModel.fromEntity(creditTx),
        );

        final updatedFrom = freshFrom.toEntity().copyWith(
          currentBalancePaise: freshFrom.currentBalancePaise - amountPaise,
          updatedAt: DateTime.now(),
        );
        await _dataSource.saveAccount(
          CashbookAccountModel.fromEntity(updatedFrom),
        );
        fromDebited = true;

        final updatedTo = freshTo.toEntity().copyWith(
          currentBalancePaise: freshTo.currentBalancePaise + amountPaise,
          updatedAt: DateTime.now(),
        );
        await _dataSource.saveAccount(
          CashbookAccountModel.fromEntity(updatedTo),
        );
        toCredited = true;

        try {
          await _activityLogs.logEvent(
            ActivityLog(
              id: _uuid.v4(),
              fairId: fairId,
              title: 'Account Funds Transferred',
              subtitle:
                  'From ${freshFrom.accountName} to ${freshTo.accountName}',
              amount: '₹${(amountPaise / 100.0).toStringAsFixed(2)}',
              type: ActivityLogType.fundsTransferred,
              timestamp: now,
            ),
          );
        } catch (_) {}
      },
      rollbackWrites: (opId) async {
        // Tag transactions as void_abandoned to preserve forensic evidence without deletion
        try {
          final voidedDebit = AccountTransactionModel(
            id: debitTx.id,
            fairId: debitTx.fairId,
            accountId: debitTx.accountId,
            transactionType: 'void_abandoned',
            direction: debitTx.direction,
            amountPaise: debitTx.amountPaise,
            transactionDateEpoch:
                debitTx.transactionDate.millisecondsSinceEpoch,
            referenceType: 'void_abandoned',
            referenceId: debitTx.referenceId,
            description:
                '[VOID_ABANDONED: origTxType=${debitTx.transactionType}, origRefType=${debitTx.referenceType}, op=$opId] ${debitTx.description}',
            createdAtEpoch: debitTx.createdAt.millisecondsSinceEpoch,
          );
          await _dataSource.saveTransaction(voidedDebit);
        } catch (_) {}

        try {
          final voidedCredit = AccountTransactionModel(
            id: creditTx.id,
            fairId: creditTx.fairId,
            accountId: creditTx.accountId,
            transactionType: 'void_abandoned',
            direction: creditTx.direction,
            amountPaise: creditTx.amountPaise,
            transactionDateEpoch:
                creditTx.transactionDate.millisecondsSinceEpoch,
            referenceType: 'void_abandoned',
            referenceId: creditTx.referenceId,
            description:
                '[VOID_ABANDONED: origTxType=${creditTx.transactionType}, origRefType=${creditTx.referenceType}, op=$opId] ${creditTx.description}',
            createdAtEpoch: creditTx.createdAt.millisecondsSinceEpoch,
          );
          await _dataSource.saveTransaction(voidedCredit);
        } catch (_) {}

        if (fromDebited) {
          try {
            final curFrom = _dataSource.getAccountById(fromAccountId);
            if (curFrom != null) {
              final restored = curFrom.toEntity().copyWith(
                currentBalancePaise: curFrom.currentBalancePaise + amountPaise,
                updatedAt: DateTime.now(),
              );
              await _dataSource.saveAccount(
                CashbookAccountModel.fromEntity(restored),
              );
            }
          } catch (_) {}
        }

        if (toCredited) {
          try {
            final curTo = _dataSource.getAccountById(toAccountId);
            if (curTo != null) {
              final restored = curTo.toEntity().copyWith(
                currentBalancePaise: curTo.currentBalancePaise - amountPaise,
                updatedAt: DateTime.now(),
              );
              await _dataSource.saveAccount(
                CashbookAccountModel.fromEntity(restored),
              );
            }
          } catch (_) {}
        }
      },
      validateInvariants: () {
        final f = _dataSource.getAccountById(fromAccountId);
        final t = _dataSource.getAccountById(toAccountId);
        if (f == null || t == null) {
          throw const ValidationException(
            'Transfer accounts missing on disk after write',
          );
        }
      },
      onAlreadyCommitted: (existing) async {
        return;
      },
    );
  }

  @override
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
  }) async {
    if (FinancialOperationCoordinator.isAccountQuarantined(accountId)) {
      throw AccountQuarantinedException(
        'Account is quarantined due to an unresolved financial recovery failure.',
      );
    }

    if (amountPaise <= 0) {
      throw const ValidationException(
        'Transaction amount must be strictly positive',
      );
    }

    final accountModel = _dataSource.getAccountById(accountId);
    if (accountModel == null) {
      throw RecordNotFoundException('CashbookAccount', accountId);
    }

    if (!accountModel.isActive) {
      throw ValidationException(
        'Cannot record transactions on inactive account "${accountModel.accountName}"',
      );
    }

    final isOutflow = direction.toLowerCase() == 'outflow';
    if (isOutflow && accountModel.currentBalancePaise < amountPaise) {
      throw ValidationException(
        'Insufficient balance in ${accountModel.accountName}. '
        'Available: ₹${(accountModel.currentBalancePaise / 100.0).toStringAsFixed(2)}, '
        'Required: ₹${(amountPaise / 100.0).toStringAsFixed(2)}',
      );
    }

    final tx = AccountTransaction(
      id: _uuid.v4(),
      fairId: fairId,
      accountId: accountId,
      transactionType: transactionType,
      direction: direction,
      amountPaise: amountPaise,
      transactionDate: transactionDate,
      referenceType: referenceType,
      referenceId: referenceId,
      description: description,
      createdAt: DateTime.now(),
    );

    final newBalance = tx.isInflow
        ? accountModel.currentBalancePaise + amountPaise
        : accountModel.currentBalancePaise - amountPaise;

    final updatedAccount = accountModel.toEntity().copyWith(
      currentBalancePaise: newBalance,
      updatedAt: DateTime.now(),
    );

    // Persist transaction and updated balance with compensating rollback protection
    bool txSaved = false;
    try {
      await _dataSource.saveTransaction(AccountTransactionModel.fromEntity(tx));
      txSaved = true;
      await _dataSource.saveAccount(
        CashbookAccountModel.fromEntity(updatedAccount),
      );
      return tx;
    } catch (e) {
      if (txSaved) {
        try {
          await _dataSource.deleteTransaction(tx.id);
        } catch (_) {}
      }
      rethrow;
    }
  }

  @override
  Future<void> reverseAccountMovement(String transactionId) async {
    final transactions = _dataSource.getTransactions();
    AccountTransactionModel? txModel;
    for (final t in transactions) {
      if (t.id == transactionId) {
        txModel = t;
        break;
      }
    }
    if (txModel == null) return;

    if (FinancialOperationCoordinator.isAccountQuarantined(txModel.accountId)) {
      throw AccountQuarantinedException(
        'Account is quarantined due to an unresolved financial recovery failure.',
      );
    }

    final accountModel = _dataSource.getAccountById(txModel.accountId);
    if (accountModel != null) {
      final isOutflow = txModel.direction.toLowerCase() == 'outflow';
      final restoredBalance = isOutflow
          ? accountModel.currentBalancePaise + txModel.amountPaise
          : accountModel.currentBalancePaise - txModel.amountPaise;

      final updatedAccount = accountModel.toEntity().copyWith(
        currentBalancePaise: restoredBalance,
        updatedAt: DateTime.now(),
      );
      await _dataSource.saveAccount(
        CashbookAccountModel.fromEntity(updatedAccount),
      );
    }

    await _dataSource.deleteTransaction(transactionId);
  }

  @override
  Future<List<CashbookAccount>> ensureDefaultAccounts(String fairId) async {
    final existing = await getAccounts(fairId: fairId);
    if (existing.isNotEmpty) return existing;

    final now = DateTime.now();
    final defaults = [
      CashbookAccount(
        id: _uuid.v4(),
        fairId: fairId,
        accountName: 'Main Cashbox',
        accountType: 'cash',
        openingBalancePaise: 0,
        currentBalancePaise: 0,
        createdAt: now,
        updatedAt: now,
      ),
      CashbookAccount(
        id: _uuid.v4(),
        fairId: fairId,
        accountName: 'Stall UPI / QR',
        accountType: 'upi',
        openingBalancePaise: 0,
        currentBalancePaise: 0,
        createdAt: now,
        updatedAt: now,
      ),
      CashbookAccount(
        id: _uuid.v4(),
        fairId: fairId,
        accountName: 'Current Bank Account',
        accountType: 'bank',
        openingBalancePaise: 0,
        currentBalancePaise: 0,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    for (final acc in defaults) {
      await _dataSource.saveAccount(CashbookAccountModel.fromEntity(acc));
    }

    return defaults;
  }
}
