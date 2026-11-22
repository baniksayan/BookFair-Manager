import 'dart:math';

import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_exceptions.dart';
import '../../../book_fairs/domain/entities/activity_log.dart';
import '../../../book_fairs/domain/repositories/activity_log_repository.dart';
import '../../../cashbook/data/datasources/financial_operation_local_datasource.dart';
import '../../../cashbook/data/models/account_transaction_model.dart';
import '../../../cashbook/data/models/cashbook_account_model.dart';
import '../../../cashbook/domain/repositories/cashbook_repository.dart';
import '../../../cashbook/domain/services/financial_operation_coordinator.dart';
import '../../../payments/data/models/payment_record_model.dart';
import '../../../payments/domain/entities/payment_record.dart';
import '../../../payments/domain/repositories/payment_repository.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_category.dart';
import '../../domain/repositories/expense_repository.dart';
import '../datasources/expense_local_datasource.dart';
import '../models/expense_category_model.dart';
import '../models/expense_model.dart';

/// Concrete Hive implementation of [ExpenseRepository].
class ExpenseRepositoryImpl implements ExpenseRepository {
  ExpenseRepositoryImpl({
    required this.expenseDataSource,
    required this.paymentRepository,
    required this.activityLogs,
    this.cashbookRepository,
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

  final ExpenseLocalDataSource expenseDataSource;
  final PaymentRepository paymentRepository;
  final ActivityLogRepository activityLogs;
  final CashbookRepository? cashbookRepository;
  final FinancialOperationCoordinator _coordinator;
  final Uuid _uuid;

  @override
  Future<List<Expense>> getExpenses({String? fairId}) async {
    return expenseDataSource
        .getAllExpenses(fairId: fairId)
        .map((m) => m.toEntity())
        .toList();
  }

  @override
  Stream<List<Expense>> watchExpenses({String? fairId}) {
    return expenseDataSource
        .watchExpenses(fairId: fairId)
        .map((list) => list.map((m) => m.toEntity()).toList());
  }

  @override
  Future<Expense?> getExpenseById(String id) async {
    return expenseDataSource.getExpenseById(id)?.toEntity();
  }

  @override
  Future<Expense> createExpense(
    Expense expense, {
    int? initialPaymentAmountPaise,
    String? paymentMethod,
    String? paidByPartnerId,
    String? paidFromAccountId,
    String? referenceNumber,
    String? clientRequestId,
  }) async {
    if (expense.title.trim().isEmpty) {
      throw const ValidationException('Expense title cannot be empty');
    }
    if (expense.amountPaise <= 0) {
      throw const ValidationException(
        'Expense amount must be greater than zero',
      );
    }

    // Determine initial payment status and amounts
    final initialPayPaise = initialPaymentAmountPaise ?? 0;
    if (initialPayPaise > expense.amountPaise) {
      throw const ValidationException(
        'Initial payment cannot exceed the total expense amount',
      );
    }

    // Pre-flight check: If paying from a business cashbook account, validate account and balance upfront
    final effectiveAccountId = paidFromAccountId ?? expense.paidFromAccountId;
    final isBusinessPayment =
        initialPayPaise > 0 &&
        effectiveAccountId != null &&
        effectiveAccountId.isNotEmpty;

    if (isBusinessPayment && cashbookRepository != null) {
      final account = await cashbookRepository!.getAccountById(
        effectiveAccountId,
      );
      if (account == null) {
        throw RecordNotFoundException('CashbookAccount', effectiveAccountId);
      }
      if (!account.isActive) {
        throw ValidationException(
          'Cannot record transactions on inactive account "${account.accountName}"',
        );
      }
      if (account.currentBalancePaise < initialPayPaise) {
        throw ValidationException(
          'Insufficient balance in ${account.accountName}. '
          'Available: ₹${(account.currentBalancePaise / 100.0).toStringAsFixed(2)}, '
          'Required: ₹${(initialPayPaise / 100.0).toStringAsFixed(2)}',
        );
      }
    }

    final initialPaid = initialPayPaise;
    final initialOutstanding = expense.amountPaise - initialPaid;
    final String initialStatus;
    if (initialPaid >= expense.amountPaise) {
      initialStatus = 'Paid';
    } else if (initialPaid > 0) {
      initialStatus = 'Partially Paid';
    } else {
      initialStatus = 'Unpaid';
    }

    final sanitizedExpense = expense.copyWith(
      paidAmountPaise: initialPaid,
      outstandingAmountPaise: initialOutstanding,
      paymentStatus: initialStatus,
      paidByPartnerId: paidByPartnerId ?? expense.paidByPartnerId,
      paidFromAccountId: paidFromAccountId ?? expense.paidFromAccountId,
      paymentMethod: paymentMethod ?? expense.paymentMethod,
      referenceNumber: referenceNumber ?? expense.referenceNumber,
    );

    // Save preliminary expense record
    await expenseDataSource.saveExpense(
      ExpenseModel.fromEntity(sanitizedExpense),
    );

    // If an initial payment is specified, record it via PaymentRepository (journal-backed)
    if (initialPayPaise > 0) {
      final paymentRecord = PaymentRecord(
        id: _uuid.v4(),
        fairId: expense.fairId,
        relatedEntityType: 'expense',
        relatedEntityId: expense.id,
        amountPaise: initialPayPaise,
        paymentDate: expense.expenseDate,
        paymentMethod: paymentMethod ?? expense.paymentMethod,
        accountId: isBusinessPayment ? effectiveAccountId : null,
        paidByPartnerId: !isBusinessPayment
            ? (paidByPartnerId ?? expense.paidByPartnerId)
            : null,
        referenceNumber: referenceNumber ?? expense.referenceNumber,
        notes: 'Initial payment for ${expense.title}',
        createdAt: DateTime.now(),
      );

      try {
        await paymentRepository.recordPayment(
          paymentRecord,
          clientRequestId: clientRequestId,
        );
      } catch (e) {
        // Rollback preliminary expense write if payment fails
        // to prevent inconsistent orphan records in the expenses box.
        await expenseDataSource.deleteExpense(expense.id);
        rethrow;
      }

      // Reload updated expense after payment updates
      final updated = expenseDataSource.getExpenseById(expense.id);
      if (updated != null) {
        await activityLogs.logEvent(
          ActivityLog(
            id: _uuid.v4(),
            fairId: expense.fairId,
            title: 'Expense Incurred',
            subtitle: '${expense.title} ($initialStatus)',
            amount: '₹${(expense.amountPaise / 100.0).toStringAsFixed(2)}',
            type: ActivityLogType.expenseRecorded,
            timestamp: DateTime.now(),
          ),
        );
        return updated.toEntity();
      }
    }

    await activityLogs.logEvent(
      ActivityLog(
        id: _uuid.v4(),
        fairId: expense.fairId,
        title: 'Expense Incurred',
        subtitle: '${expense.title} ($initialStatus)',
        amount: '₹${(expense.amountPaise / 100.0).toStringAsFixed(2)}',
        type: ActivityLogType.expenseRecorded,
        timestamp: DateTime.now(),
      ),
    );

    return sanitizedExpense;
  }

  @override
  Future<Expense> updateExpense(Expense expense) async {
    return await _coordinator.withResourceLocks(
      resourceKeys: ['expense:${expense.id}'],
      action: () async {
        final existing = expenseDataSource.getExpenseById(expense.id);
        if (existing == null) {
          throw RecordNotFoundException('Expense', expense.id);
        }

        if (existing.isCancelled ||
            existing.paymentStatus.toLowerCase().contains('written off')) {
          throw const ValidationException(
            'Cannot modify a cancelled or written-off expense.',
          );
        }

        if (expense.title.trim().isEmpty) {
          throw const ValidationException('Expense title cannot be empty');
        }
        if (expense.amountPaise <= 0) {
          throw const ValidationException(
            'Expense amount must be greater than zero',
          );
        }

        // Financial obligation guard: Cannot reduce expense total below already paid disbursements
        final paid = existing.paidAmountPaise;
        if (expense.amountPaise < paid) {
          throw ValidationException(
            'Expense amount (₹${(expense.amountPaise / 100.0).toStringAsFixed(2)}) '
            'cannot be reduced below the amount already disbursed '
            '(₹${(paid / 100.0).toStringAsFixed(2)}). Process a refund first.',
          );
        }

        // Recalculate outstanding based on current payments
        final outstanding = max(0, expense.amountPaise - paid);
        String status = existing.paymentStatus;
        if (!existing.isCancelled) {
          if (paid >= expense.amountPaise) {
            status = 'Paid';
          } else if (paid > 0) {
            status = 'Partially Paid';
          } else {
            status = 'Unpaid';
          }
        }

        final updated = expense.copyWith(
          fairId: existing.fairId,
          paidAmountPaise: paid,
          outstandingAmountPaise: outstanding,
          paymentStatus: status,
          updatedAt: DateTime.now(),
        );

        await expenseDataSource.saveExpense(ExpenseModel.fromEntity(updated));

        await activityLogs.logEvent(
          ActivityLog(
            id: _uuid.v4(),
            fairId: expense.fairId,
            title: 'Expense Updated',
            subtitle: 'Updated details for expense ${expense.title}',
            amount: '₹${(expense.amountPaise / 100.0).toStringAsFixed(2)}',
            type: ActivityLogType.expenseRecorded,
            timestamp: DateTime.now(),
          ),
        );

        return updated;
      },
    );
  }

  @override
  Future<int> getCumulativeRefundsPaise(String expenseId) async {
    const db = AppDatabase();
    final refundPayments = db.paymentRecords.values.where((p) {
      return p.relatedEntityType == 'expense_refund' &&
          p.relatedEntityId == expenseId &&
          p.paymentMethod != 'void_abandoned' &&
          p.relatedEntityType != 'void_abandoned';
    });
    return refundPayments.fold<int>(0, (sum, p) => sum + p.amountPaise);
  }

  @override
  Future<void> cancelExpense(
    String id,
    String reason, {
    String? refundToAccountId,
    int? refundAmountPaise,
    String? clientRequestId,
  }) async {
    return await _coordinator.withResourceLocks(
      resourceKeys: ['expense:$id'],
      action: () async {
        final existing = expenseDataSource.getExpenseById(id);
        if (existing == null) {
          throw RecordNotFoundException('Expense', id);
        }

        if (existing.isCancelled) {
          return;
        }

        // Unpaid expense can be cancelled directly without financial movement
        if (existing.paidAmountPaise == 0) {
          final cancelled = existing.toEntity().copyWith(
            paymentStatus: 'Cancelled',
            outstandingAmountPaise: 0,
            notes: existing.notes.isEmpty
                ? 'Cancelled: $reason'
                : '${existing.notes} | Cancelled: $reason',
            updatedAt: DateTime.now(),
          );

          await expenseDataSource.saveExpense(
            ExpenseModel.fromEntity(cancelled),
          );

          try {
            await activityLogs.logEvent(
              ActivityLog(
                id: _uuid.v4(),
                fairId: existing.fairId,
                title: 'Expense Cancelled',
                subtitle: 'Cancelled ${existing.title}: $reason',
                amount: '₹${(existing.amountPaise / 100.0).toStringAsFixed(2)}',
                type: ActivityLogType.expenseRecorded,
                timestamp: DateTime.now(),
              ),
            );
          } catch (_) {}
          return;
        }

        // If money was disbursed (partially or fully paid), cancellation requires a refund destination
        if (refundToAccountId == null || refundToAccountId.trim().isEmpty) {
          throw ValidationException(
            'Cannot cancel expense with disbursed payments (₹${(existing.paidAmountPaise / 100.0).toStringAsFixed(2)}) '
            'without refunding previously disbursed funds. Provide a refund destination account or record an explicit write-off.',
          );
        }

        final cumulativeRefunded = await getCumulativeRefundsPaise(existing.id);
        final remainingRefundable =
            existing.paidAmountPaise - cumulativeRefunded;
        final amountToRefund = refundAmountPaise ?? remainingRefundable;

        await recordExpenseRefund(
          expenseId: id,
          toAccountId: refundToAccountId,
          amountPaise: amountToRefund,
          reason: reason,
          clientRequestId: clientRequestId,
        );
      },
    );
  }

  @override
  Future<void> recordExpenseRefund({
    required String expenseId,
    required String toAccountId,
    required int amountPaise,
    required String reason,
    String? clientRequestId,
  }) async {
    if (amountPaise <= 0) {
      throw const ValidationException(
        'Refund amount must be strictly positive',
      );
    }

    final existing = expenseDataSource.getExpenseById(expenseId);
    if (existing == null) {
      throw RecordNotFoundException('Expense', expenseId);
    }

    if (existing.paidAmountPaise == 0) {
      throw const ValidationException(
        'Cannot refund an unpaid expense with no disbursed payments',
      );
    }

    const db = AppDatabase();
    final refundAccount = db.cashbookAccounts.get(toAccountId);
    if (refundAccount == null) {
      throw RecordNotFoundException('CashbookAccount', toAccountId);
    }
    if (!refundAccount.isActive) {
      throw ValidationException(
        'Cannot refund to inactive account "${refundAccount.accountName}"',
      );
    }

    final currentCumulativeRefunds = await getCumulativeRefundsPaise(expenseId);
    final maxRefundable = existing.paidAmountPaise - currentCumulativeRefunds;

    if (amountPaise > maxRefundable) {
      throw ValidationException(
        'Refund amount (₹${(amountPaise / 100.0).toStringAsFixed(2)}) exceeds '
        'remaining refundable balance (₹${(maxRefundable / 100.0).toStringAsFixed(2)}). '
        'Total disbursed: ₹${(existing.paidAmountPaise / 100.0).toStringAsFixed(2)}, '
        'already refunded: ₹${(currentCumulativeRefunds / 100.0).toStringAsFixed(2)}.',
      );
    }

    final effectiveRequestId = clientRequestId ?? _uuid.v4();
    final refundTxId = 'tx_refund_${existing.id}_$effectiveRequestId';
    final refundPaymentId = 'pay_refund_${existing.id}_$effectiveRequestId';
    final idempotencyKey =
        'expense_refund_${existing.fairId}_${existing.id}_$effectiveRequestId';

    final payload = {
      'fairId': existing.fairId,
      'expenseId': existing.id,
      'refundToAccountId': toAccountId,
      'refundAmountPaise': amountPaise,
      'refundTxId': refundTxId,
      'refundPaymentId': refundPaymentId,
      'reason': reason,
      'clientRequestId': effectiveRequestId,
      'originalRecords': {
        'refundTx': {
          'id': refundTxId,
          'fairId': existing.fairId,
          'accountId': toAccountId,
          'transactionType': 'refund_received',
          'direction': 'inflow',
          'amountPaise': amountPaise,
          'referenceType': 'expense',
          'referenceId': existing.id,
        },
        'refundPayment': {
          'id': refundPaymentId,
          'fairId': existing.fairId,
          'amountPaise': amountPaise,
          'paymentMethod': 'Refund',
          'relatedEntityType': 'expense_refund',
          'relatedEntityId': existing.id,
        },
      },
    };

    final affectedBoxes = [
      db.expenses,
      db.paymentRecords,
      db.accountTransactions,
      db.cashbookAccounts,
    ];

    await _coordinator.runCoordinatedOperation<void>(
      fairId: existing.fairId,
      operationType: 'expense_refund_reversal',
      idempotencyKey: idempotencyKey,
      amountPaise: amountPaise,
      primaryEntityId: existing.id,
      targetAccountId: toAccountId,
      payload: payload,
      affectedBoxes: affectedBoxes,
      executeWrites: (opId) async {
        final now = DateTime.now();

        // 1. Re-read expense and cumulative refunds inside lock to protect against concurrent mutations
        final liveExpense = expenseDataSource.getExpenseById(expenseId);
        if (liveExpense == null) {
          throw RecordNotFoundException('Expense', expenseId);
        }
        if (liveExpense.paidAmountPaise == 0) {
          throw const ValidationException(
            'Cannot refund an unpaid expense with no disbursed payments',
          );
        }

        final liveCumulativeRefunds = await getCumulativeRefundsPaise(
          expenseId,
        );
        final liveMaxRefundable =
            liveExpense.paidAmountPaise - liveCumulativeRefunds;
        if (amountPaise > liveMaxRefundable) {
          throw ValidationException(
            'Refund amount (₹${(amountPaise / 100.0).toStringAsFixed(2)}) exceeds '
            'live remaining refundable balance (₹${(liveMaxRefundable / 100.0).toStringAsFixed(2)}).',
          );
        }

        // 2. Create refund inflow transaction
        final refundTx = AccountTransactionModel(
          id: refundTxId,
          fairId: liveExpense.fairId,
          accountId: toAccountId,
          transactionType: 'refund_received',
          direction: 'inflow',
          amountPaise: amountPaise,
          transactionDateEpoch: now.millisecondsSinceEpoch,
          referenceType: 'expense',
          referenceId: liveExpense.id,
          description:
              'Refund for expense: ${liveExpense.title}${reason.isNotEmpty ? ' • $reason' : ''}',
          createdAtEpoch: now.millisecondsSinceEpoch,
        );
        await db.accountTransactions.put(refundTxId, refundTx);

        // 3. Update account balance with re-read under lock
        final freshRefundAccount = db.cashbookAccounts.get(toAccountId);
        if (freshRefundAccount == null) {
          throw RecordNotFoundException('CashbookAccount', toAccountId);
        }
        final updatedAccount = CashbookAccountModel(
          id: freshRefundAccount.id,
          fairId: freshRefundAccount.fairId,
          accountName: freshRefundAccount.accountName,
          accountType: freshRefundAccount.accountType,
          openingBalancePaise: freshRefundAccount.openingBalancePaise,
          currentBalancePaise:
              freshRefundAccount.currentBalancePaise + amountPaise,
          isActive: freshRefundAccount.isActive,
          createdAtEpoch: freshRefundAccount.createdAtEpoch,
          updatedAtEpoch: now.millisecondsSinceEpoch,
        );
        await db.cashbookAccounts.put(updatedAccount.id, updatedAccount);

        // 4. Create reversing payment record
        final refundPayment = PaymentRecordModel(
          id: refundPaymentId,
          fairId: liveExpense.fairId,
          amountPaise: amountPaise,
          paymentMethod: 'Refund',
          paymentDateEpoch: now.millisecondsSinceEpoch,
          accountId: toAccountId,
          payerPartnerId: null,
          recipientPartnerId: null,
          supplierId: null,
          referenceNumber: 'REFUND-${liveExpense.id}',
          relatedEntityType: 'expense_refund',
          relatedEntityId: liveExpense.id,
          notes: 'Refund reversal: $reason',
          createdAtEpoch: now.millisecondsSinceEpoch,
        );
        await db.paymentRecords.put(refundPaymentId, refundPayment);

        // 5. Update expense status based on total refunds received:
        final newTotalRefunded = liveCumulativeRefunds + amountPaise;
        final bool isFullyRefunded =
            newTotalRefunded >= liveExpense.paidAmountPaise;

        final newStatus = isFullyRefunded
            ? 'Cancelled (Refunded)'
            : 'Partially Refunded';

        final updatedExpense = liveExpense.toEntity().copyWith(
          paymentStatus: newStatus,
          outstandingAmountPaise: isFullyRefunded
              ? 0
              : liveExpense.outstandingAmountPaise,
          notes: liveExpense.notes.isEmpty
              ? 'Refund: ₹${(amountPaise / 100.0).toStringAsFixed(2)} ($reason)'
              : '${liveExpense.notes} | Refund: ₹${(amountPaise / 100.0).toStringAsFixed(2)} ($reason)',
          updatedAt: now,
        );
        await db.expenses.put(
          liveExpense.id,
          ExpenseModel.fromEntity(updatedExpense),
        );

        // 6. Log activity
        try {
          await activityLogs.logEvent(
            ActivityLog(
              id: _uuid.v4(),
              fairId: existing.fairId,
              title: isFullyRefunded
                  ? 'Expense Fully Refunded'
                  : 'Expense Partial Refund',
              subtitle:
                  'Refund of ₹${(amountPaise / 100.0).toStringAsFixed(2)} to ${freshRefundAccount.accountName}',
              amount: '+₹${(amountPaise / 100.0).toStringAsFixed(2)}',
              type: ActivityLogType.fundsTransferred,
              timestamp: now,
            ),
          );
        } catch (_) {}
      },
      rollbackWrites: (opId) async {
        final tx = db.accountTransactions.get(refundTxId);
        if (tx != null) {
          final voided = AccountTransactionModel(
            id: tx.id,
            fairId: tx.fairId,
            accountId: tx.accountId,
            transactionType: 'void_abandoned',
            direction: tx.direction,
            amountPaise: tx.amountPaise,
            transactionDateEpoch: tx.transactionDateEpoch,
            referenceType: 'void_abandoned',
            referenceId: tx.referenceId,
            description:
                '[VOID_ABANDONED: origTxType=${tx.transactionType}, origRefType=${tx.referenceType}, op=$opId] ${tx.description}',
            createdAtEpoch: tx.createdAtEpoch,
          );
          await db.accountTransactions.put(voided.id, voided);
        }

        final pay = db.paymentRecords.get(refundPaymentId);
        if (pay != null) {
          final voidedPay = PaymentRecordModel(
            id: pay.id,
            fairId: pay.fairId,
            amountPaise: pay.amountPaise,
            paymentMethod: 'void_abandoned',
            paymentDateEpoch: pay.paymentDateEpoch,
            accountId: pay.accountId,
            payerPartnerId: pay.payerPartnerId,
            recipientPartnerId: pay.recipientPartnerId,
            supplierId: pay.supplierId,
            referenceNumber: pay.referenceNumber,
            relatedEntityType: 'void_abandoned',
            relatedEntityId: pay.relatedEntityId,
            notes:
                '[VOID_ABANDONED: origType=${pay.relatedEntityType}, origMethod=${pay.paymentMethod}, op=$opId] ${pay.notes}',
            createdAtEpoch: pay.createdAtEpoch,
          );
          await db.paymentRecords.put(voidedPay.id, voidedPay);
        }

        final acc = db.cashbookAccounts.get(toAccountId);
        if (acc != null && tx != null) {
          final restored = CashbookAccountModel(
            id: acc.id,
            fairId: acc.fairId,
            accountName: acc.accountName,
            accountType: acc.accountType,
            openingBalancePaise: acc.openingBalancePaise,
            currentBalancePaise: acc.currentBalancePaise - amountPaise,
            isActive: acc.isActive,
            createdAtEpoch: acc.createdAtEpoch,
            updatedAtEpoch: DateTime.now().millisecondsSinceEpoch,
          );
          await db.cashbookAccounts.put(restored.id, restored);
        }

        await db.expenses.put(existing.id, existing);
      },
      validateInvariants: () {
        final exp = db.expenses.get(existing.id);
        final acc = db.cashbookAccounts.get(toAccountId);
        if (exp == null || acc == null) {
          throw const ValidationException(
            'Expense refund target records missing after write',
          );
        }
      },
      onAlreadyCommitted: (existingOp) async {
        return;
      },
    );
  }

  @override
  Future<Expense> writeOffExpenseOutstanding({
    required String expenseId,
    required String reason,
    String? clientRequestId,
  }) async {
    if (reason.trim().isEmpty) {
      throw const ValidationException(
        'A documented reason is required for a business write-off.',
      );
    }

    final existing = expenseDataSource.getExpenseById(expenseId);
    if (existing == null) {
      throw RecordNotFoundException('Expense', expenseId);
    }

    if (existing.outstandingAmountPaise <= 0) {
      throw const ValidationException(
        'Expense has no outstanding obligation to write off.',
      );
    }

    const db = AppDatabase();
    final effectiveRequestId = clientRequestId ?? _uuid.v4();
    final idempotencyKey =
        'expense_writeoff_${existing.fairId}_${existing.id}_$effectiveRequestId';
    final writtenOffPaise = existing.outstandingAmountPaise;

    final payload = {
      'fairId': existing.fairId,
      'expenseId': existing.id,
      'writtenOffPaise': writtenOffPaise,
      'reason': reason.trim(),
      'originalExpense': {
        'id': existing.id,
        'fairId': existing.fairId,
        'title': existing.title,
        'amountPaise': existing.amountPaise,
        'paidAmountPaise': existing.paidAmountPaise,
        'outstandingAmountPaise': existing.outstandingAmountPaise,
        'paymentStatus': existing.paymentStatus,
      },
    };

    Expense? resultExpense;

    await _coordinator.runCoordinatedOperation<void>(
      fairId: existing.fairId,
      operationType: 'expense_write_off',
      idempotencyKey: idempotencyKey,
      amountPaise: writtenOffPaise,
      primaryEntityId: existing.id,
      payload: payload,
      affectedBoxes: [db.expenses],
      executeWrites: (opId) async {
        final now = DateTime.now();

        // Re-read expense freshly inside lock to prevent race conditions
        final freshExisting = expenseDataSource.getExpenseById(expenseId);
        if (freshExisting == null) {
          throw RecordNotFoundException('Expense', expenseId);
        }
        if (freshExisting.isCancelled ||
            freshExisting.paymentStatus.toLowerCase().contains('written off')) {
          throw const ValidationException(
            'Cannot write off a cancelled or already written-off expense.',
          );
        }
        if (freshExisting.outstandingAmountPaise <= 0) {
          throw const ValidationException(
            'Expense has no outstanding obligation to write off.',
          );
        }

        final liveWrittenOffPaise = freshExisting.outstandingAmountPaise;
        final newStatus = freshExisting.paidAmountPaise == 0
            ? 'Written Off'
            : 'Partially Paid (Written Off)';

        final updated = freshExisting.toEntity().copyWith(
          outstandingAmountPaise: 0,
          paymentStatus: newStatus,
          notes: freshExisting.notes.isEmpty
              ? 'Written Off: ${reason.trim()} (Waived: ₹${(liveWrittenOffPaise / 100.0).toStringAsFixed(2)})'
              : '${freshExisting.notes} | Written Off: ${reason.trim()} (Waived: ₹${(liveWrittenOffPaise / 100.0).toStringAsFixed(2)})',
          updatedAt: now,
        );

        await db.expenses.put(
          freshExisting.id,
          ExpenseModel.fromEntity(updated),
        );
        resultExpense = updated;

        try {
          await activityLogs.logEvent(
            ActivityLog(
              id: _uuid.v4(),
              fairId: freshExisting.fairId,
              title: 'Expense Outstanding Written Off',
              subtitle: 'Written off ${freshExisting.title}: ${reason.trim()}',
              amount: '₹${(liveWrittenOffPaise / 100.0).toStringAsFixed(2)}',
              type: ActivityLogType.expenseRecorded,
              timestamp: now,
            ),
          );
        } catch (_) {}
      },
      rollbackWrites: (opId) async {
        await db.expenses.put(existing.id, existing);
      },
      validateInvariants: () {
        final exp = db.expenses.get(existing.id);
        if (exp == null) {
          throw const ValidationException(
            'Expense record missing after write-off',
          );
        }
      },
      onAlreadyCommitted: (existingOp) async {
        resultExpense = (await getExpenseById(expenseId))!;
      },
    );

    return resultExpense ?? (await getExpenseById(expenseId))!;
  }

  @override
  Future<List<ExpenseCategory>> getCategories() async {
    return expenseDataSource
        .getAllCategories()
        .map((m) => m.toEntity())
        .toList();
  }

  @override
  Stream<List<ExpenseCategory>> watchCategories() {
    return expenseDataSource.watchCategories().map(
      (list) => list.map((m) => m.toEntity()).toList(),
    );
  }

  @override
  Future<ExpenseCategory> addCategory(String name, {String? iconName}) async {
    if (name.trim().isEmpty) {
      throw const ValidationException('Category name cannot be empty');
    }

    final category = ExpenseCategory(
      id: _uuid.v4(),
      name: name.trim(),
      iconName: iconName,
      isCustom: true,
      isSystem: false,
      createdAt: DateTime.now(),
    );

    await expenseDataSource.saveCategory(
      ExpenseCategoryModel.fromEntity(category),
    );

    return category;
  }
}
