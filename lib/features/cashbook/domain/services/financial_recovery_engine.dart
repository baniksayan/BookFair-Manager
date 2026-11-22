import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../../core/database/app_database.dart';
import '../../data/datasources/financial_operation_local_datasource.dart';
import '../../data/models/account_transaction_model.dart';
import '../../data/models/cashbook_account_model.dart';
import '../../data/models/financial_operation_model.dart';
import '../../../expenses/data/models/expense_model.dart';
import '../../../inventory/data/models/purchase_batch_model.dart';
import '../../../payments/data/models/payment_record_model.dart';
import 'financial_operation_coordinator.dart';

/// Recovers, corroborates, and reconciles interrupted financial operations upon application launch.
class FinancialRecoveryEngine {
  FinancialRecoveryEngine({required this.db, required this.journalDataSource});

  final AppDatabase db;
  final FinancialOperationLocalDataSource journalDataSource;

  /// Executes startup recovery for all uncommitted financial operations.
  Future<int> runStartupRecovery() async {
    final pendingOps = journalDataSource.getPendingOperations();
    if (pendingOps.isEmpty) return 0;

    int recoveredCount = 0;
    for (final op in pendingOps) {
      try {
        await _recoverOperation(op);
        recoveredCount++;
      } catch (e, stack) {
        if (kDebugMode) {
          debugPrint('Recovery failed for operation ${op.id}: $e\n$stack');
        }
        await _handleRecoveryFailure(op, e, stack);
      }
    }

    return recoveredCount;
  }

  Future<void> _recoverOperation(FinancialOperationModel op) async {
    switch (op.operationType) {
      case 'account_transfer':
        await _reconcileTransfer(op);
        break;
      case 'expense_initial_business_payment':
      case 'expense_initial_payment':
        await _reconcileExpenseInitialPayment(op);
        break;
      case 'expense_initial_partner_payment':
        await _reconcileExpenseInitialPartnerPayment(op);
        break;
      case 'standalone_expense_payment':
      case 'disbursement':
        await _reconcileStandalonePayment(op);
        break;
      case 'purchase_batch_payment':
        await _reconcilePurchaseBatchPayment(op);
        break;
      case 'partner_reimbursement':
        await _reconcilePartnerReimbursement(op);
        break;
      case 'expense_cancellation':
      case 'expense_refund_reversal':
        await _reconcileExpenseCancellation(op);
        break;
      case 'expense_write_off':
        await _reconcileExpenseWriteOff(op);
        break;
      case 'sales_settlement':
        await _reconcileSalesSettlement(op);
        break;
      case 'sale_return_refund':
        await _reconcileSaleReturnRefund(op);
        break;
      default:
        // Unknown operation type: safely roll back
        await _markRolledBack(
          op,
          'Unknown operation type: ${op.operationType}',
        );
    }
  }

  // --- 1. Account Transfer Reconciliation ---
  Future<void> _reconcileTransfer(FinancialOperationModel op) async {
    final payload = op.payload;
    final debitTxId = payload['debitTxId'] as String?;
    final creditTxId = payload['creditTxId'] as String?;
    final fromAccountId = op.sourceAccountId;
    final toAccountId = op.targetAccountId;

    final debitTx = debitTxId != null
        ? db.accountTransactions.get(debitTxId)
        : null;
    final creditTx = creditTxId != null
        ? db.accountTransactions.get(creditTxId)
        : null;

    final hasValidDebit =
        debitTx != null &&
        debitTx.transactionType != 'void_abandoned' &&
        debitTx.amountPaise == op.amountPaise;
    final hasValidCredit =
        creditTx != null &&
        creditTx.transactionType != 'void_abandoned' &&
        creditTx.amountPaise == op.amountPaise;

    if (hasValidDebit &&
        hasValidCredit &&
        fromAccountId != null &&
        toAccountId != null) {
      // Both transactions exist and match: roll forward
      await _reprojectAccountBalance(fromAccountId);
      await _reprojectAccountBalance(toAccountId);
      await _markCommitted(op);
    } else {
      // Incomplete transfer: roll back and tag partial records as void_abandoned
      if (debitTx != null && debitTx.transactionType != 'void_abandoned') {
        final voided = AccountTransactionModel(
          id: debitTx.id,
          fairId: debitTx.fairId,
          accountId: debitTx.accountId,
          transactionType: 'void_abandoned',
          direction: debitTx.direction,
          amountPaise: debitTx.amountPaise,
          transactionDateEpoch: debitTx.transactionDateEpoch,
          referenceType: 'void_abandoned',
          referenceId: debitTx.referenceId,
          description:
              '[VOID_ABANDONED: origTxType=${debitTx.transactionType}, origRefType=${debitTx.referenceType}, op=${op.id}] ${debitTx.description}',
          createdAtEpoch: debitTx.createdAtEpoch,
        );
        await db.accountTransactions.put(voided.id, voided);
      }
      if (creditTx != null && creditTx.transactionType != 'void_abandoned') {
        final voided = AccountTransactionModel(
          id: creditTx.id,
          fairId: creditTx.fairId,
          accountId: creditTx.accountId,
          transactionType: 'void_abandoned',
          direction: creditTx.direction,
          amountPaise: creditTx.amountPaise,
          transactionDateEpoch: creditTx.transactionDateEpoch,
          referenceType: 'void_abandoned',
          referenceId: creditTx.referenceId,
          description:
              '[VOID_ABANDONED: origTxType=${creditTx.transactionType}, origRefType=${creditTx.referenceType}, op=${op.id}] ${creditTx.description}',
          createdAtEpoch: creditTx.createdAtEpoch,
        );
        await db.accountTransactions.put(voided.id, voided);
      }

      if (fromAccountId != null) await _reprojectAccountBalance(fromAccountId);
      if (toAccountId != null) await _reprojectAccountBalance(toAccountId);

      await _markRolledBack(op, 'Incomplete transfer transactions on disk');
    }
  }

  // --- 2. Expense with Initial Business Payment ---
  Future<void> _reconcileExpenseInitialPayment(
    FinancialOperationModel op,
  ) async {
    final payload = op.payload;
    final expenseId = op.primaryEntityId;
    final paymentId = op.secondaryEntityId ?? payload['paymentId'] as String?;
    final txId = payload['txId'] as String?;
    final accountId = op.sourceAccountId;

    final expense = db.expenses.get(expenseId);
    final payment = paymentId != null ? db.paymentRecords.get(paymentId) : null;
    final tx = txId != null ? db.accountTransactions.get(txId) : null;

    final hasPayment =
        payment != null &&
        payment.relatedEntityType != 'void_abandoned' &&
        payment.amountPaise == op.amountPaise;
    final hasTx =
        tx != null &&
        tx.transactionType != 'void_abandoned' &&
        tx.amountPaise == op.amountPaise;

    if (expense != null && hasPayment && hasTx && accountId != null) {
      // All writes present: roll forward and sync expense summary
      await _syncExpenseSummary(expenseId);
      await _reprojectAccountBalance(accountId);
      await _markCommitted(op);
    } else {
      // Incomplete: void payment & tx, delete preliminary expense
      if (tx != null && tx.transactionType != 'void_abandoned') {
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
              '[VOID_ABANDONED: origTxType=${tx.transactionType}, origRefType=${tx.referenceType}, op=${op.id}] ${tx.description}',
          createdAtEpoch: tx.createdAtEpoch,
        );
        await db.accountTransactions.put(voided.id, voided);
      }
      if (payment != null && payment.relatedEntityType != 'void_abandoned') {
        final voidedPay = PaymentRecordModel(
          id: payment.id,
          fairId: payment.fairId,
          amountPaise: payment.amountPaise,
          paymentMethod: payment.paymentMethod,
          paymentDateEpoch: payment.paymentDateEpoch,
          accountId: payment.accountId,
          payerPartnerId: payment.payerPartnerId,
          recipientPartnerId: payment.recipientPartnerId,
          supplierId: payment.supplierId,
          referenceNumber: payment.referenceNumber,
          relatedEntityType: 'void_abandoned',
          relatedEntityId: payment.relatedEntityId,
          notes:
              '[VOID_ABANDONED: origType=${payment.relatedEntityType}, origMethod=${payment.paymentMethod}, op=${op.id}] ${payment.notes}',
          createdAtEpoch: payment.createdAtEpoch,
        );
        await db.paymentRecords.put(voidedPay.id, voidedPay);
      }
      if (expense != null && expense.paidAmountPaise == 0) {
        await db.expenses.delete(expenseId);
      }

      if (accountId != null) await _reprojectAccountBalance(accountId);
      await _markRolledBack(op, 'Incomplete initial expense payment on disk');
    }
  }

  // --- 3. Expense with Partner Payment ---
  Future<void> _reconcileExpenseInitialPartnerPayment(
    FinancialOperationModel op,
  ) async {
    final payload = op.payload;
    final expenseId = op.primaryEntityId;
    final paymentId = op.secondaryEntityId ?? payload['paymentId'] as String?;

    final expense = db.expenses.get(expenseId);
    final payment = paymentId != null ? db.paymentRecords.get(paymentId) : null;

    if (expense != null &&
        payment != null &&
        payment.relatedEntityType != 'void_abandoned') {
      await _syncExpenseSummary(expenseId);
      await _markCommitted(op);
    } else {
      if (payment != null && payment.relatedEntityType != 'void_abandoned') {
        final voided = PaymentRecordModel(
          id: payment.id,
          fairId: payment.fairId,
          amountPaise: payment.amountPaise,
          paymentMethod: payment.paymentMethod,
          paymentDateEpoch: payment.paymentDateEpoch,
          accountId: payment.accountId,
          payerPartnerId: payment.payerPartnerId,
          recipientPartnerId: payment.recipientPartnerId,
          supplierId: payment.supplierId,
          referenceNumber: payment.referenceNumber,
          relatedEntityType: 'void_abandoned',
          relatedEntityId: payment.relatedEntityId,
          notes:
              '[VOID_ABANDONED: origType=${payment.relatedEntityType}, origMethod=${payment.paymentMethod}, op=${op.id}] ${payment.notes}',
          createdAtEpoch: payment.createdAtEpoch,
        );
        await db.paymentRecords.put(voided.id, voided);
      }
      if (expense != null && expense.paidAmountPaise == 0) {
        await db.expenses.delete(expenseId);
      }
      await _markRolledBack(op, 'Incomplete partner-financed expense payment');
    }
  }

  // --- 4. Standalone Expense Payment ---
  Future<void> _reconcileStandalonePayment(FinancialOperationModel op) async {
    final payload = op.payload;
    final expenseId = op.primaryEntityId;
    final paymentId = op.secondaryEntityId ?? payload['paymentId'] as String?;
    final txId = payload['txId'] as String?;
    final accountId = op.sourceAccountId;

    final payment = paymentId != null ? db.paymentRecords.get(paymentId) : null;
    final tx = txId != null ? db.accountTransactions.get(txId) : null;

    final hasPayment =
        payment != null &&
        payment.relatedEntityType != 'void_abandoned' &&
        payment.amountPaise == op.amountPaise;

    if (hasPayment) {
      if (accountId != null) await _reprojectAccountBalance(accountId);
      await _syncExpenseSummary(expenseId);
      await _markCommitted(op);
    } else {
      if (tx != null && tx.transactionType != 'void_abandoned') {
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
              '[VOID_ABANDONED: origTxType=${tx.transactionType}, origRefType=${tx.referenceType}, op=${op.id}] ${tx.description}',
          createdAtEpoch: tx.createdAtEpoch,
        );
        await db.accountTransactions.put(voided.id, voided);
      }
      if (accountId != null) await _reprojectAccountBalance(accountId);
      await _markRolledBack(
        op,
        'Missing payment record for standalone payment',
      );
    }
  }

  // --- 5. Purchase Batch Payment ---
  Future<void> _reconcilePurchaseBatchPayment(
    FinancialOperationModel op,
  ) async {
    final payload = op.payload;
    final batchId = op.primaryEntityId;
    final paymentId = op.secondaryEntityId ?? payload['paymentId'] as String?;
    final txId = payload['txId'] as String?;
    final accountId = op.sourceAccountId;

    final payment = paymentId != null ? db.paymentRecords.get(paymentId) : null;
    final tx = txId != null ? db.accountTransactions.get(txId) : null;

    if (payment != null && payment.relatedEntityType != 'void_abandoned') {
      if (accountId != null) await _reprojectAccountBalance(accountId);
      await _syncPurchaseBatchPaymentStatus(batchId);
      await _markCommitted(op);
    } else {
      if (tx != null && tx.transactionType != 'void_abandoned') {
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
              '[VOID_ABANDONED: origTxType=${tx.transactionType}, origRefType=${tx.referenceType}, op=${op.id}] ${tx.description}',
          createdAtEpoch: tx.createdAtEpoch,
        );
        await db.accountTransactions.put(voided.id, voided);
      }
      if (accountId != null) await _reprojectAccountBalance(accountId);
      await _markRolledBack(op, 'Missing payment record for purchase batch');
    }
  }

  // --- 6. Partner Reimbursement ---
  Future<void> _reconcilePartnerReimbursement(
    FinancialOperationModel op,
  ) async {
    final payload = op.payload;
    final paymentId = op.secondaryEntityId ?? payload['paymentId'] as String?;
    final txId = payload['txId'] as String?;
    final accountId = op.sourceAccountId;

    final payment = paymentId != null ? db.paymentRecords.get(paymentId) : null;
    final tx = txId != null ? db.accountTransactions.get(txId) : null;

    if (payment != null &&
        payment.relatedEntityType != 'void_abandoned' &&
        tx != null &&
        tx.transactionType != 'void_abandoned') {
      if (accountId != null) await _reprojectAccountBalance(accountId);
      await _markCommitted(op);
    } else {
      if (tx != null && tx.transactionType != 'void_abandoned') {
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
              '[VOID_ABANDONED: origTxType=${tx.transactionType}, origRefType=${tx.referenceType}, op=${op.id}] ${tx.description}',
          createdAtEpoch: tx.createdAtEpoch,
        );
        await db.accountTransactions.put(voided.id, voided);
      }
      if (payment != null && payment.relatedEntityType != 'void_abandoned') {
        final voidedPay = PaymentRecordModel(
          id: payment.id,
          fairId: payment.fairId,
          amountPaise: payment.amountPaise,
          paymentMethod: payment.paymentMethod,
          paymentDateEpoch: payment.paymentDateEpoch,
          accountId: payment.accountId,
          payerPartnerId: payment.payerPartnerId,
          recipientPartnerId: payment.recipientPartnerId,
          supplierId: payment.supplierId,
          referenceNumber: payment.referenceNumber,
          relatedEntityType: 'void_abandoned',
          relatedEntityId: payment.relatedEntityId,
          notes:
              '[VOID_ABANDONED: origType=${payment.relatedEntityType}, origMethod=${payment.paymentMethod}, op=${op.id}] ${payment.notes}',
          createdAtEpoch: payment.createdAtEpoch,
        );
        await db.paymentRecords.put(voidedPay.id, voidedPay);
      }
      if (accountId != null) await _reprojectAccountBalance(accountId);
      await _markRolledBack(op, 'Incomplete partner reimbursement on disk');
    }
  }

  // --- 7. Expense Cancellation & Refund Reversal ---
  Future<void> _reconcileExpenseCancellation(FinancialOperationModel op) async {
    final expenseId = op.primaryEntityId;
    final expense = db.expenses.get(expenseId);
    final payload = op.payload;
    final refundTxId = payload['refundTxId'] as String?;
    final refundPaymentId = payload['refundPaymentId'] as String?;
    final refundAccountId =
        op.targetAccountId ?? payload['refundToAccountId'] as String?;

    if (op.operationType == 'expense_refund_reversal') {
      final refundTx = refundTxId != null
          ? db.accountTransactions.get(refundTxId)
          : null;
      final refundPayment = refundPaymentId != null
          ? db.paymentRecords.get(refundPaymentId)
          : null;

      final hasValidTx =
          refundTx != null && refundTx.transactionType != 'void_abandoned';
      final hasValidPayment =
          refundPayment != null &&
          refundPayment.relatedEntityType != 'void_abandoned';

      if (expense != null &&
          (expense.paymentStatus == 'Cancelled (Refunded)' ||
              expense.paymentStatus == 'Partially Refunded') &&
          hasValidTx &&
          hasValidPayment) {
        if (refundAccountId != null) {
          await _reprojectAccountBalance(refundAccountId);
        }
        await _markCommitted(op);
      } else {
        if (refundTx != null && refundTx.transactionType != 'void_abandoned') {
          final voided = AccountTransactionModel(
            id: refundTx.id,
            fairId: refundTx.fairId,
            accountId: refundTx.accountId,
            transactionType: 'void_abandoned',
            direction: refundTx.direction,
            amountPaise: refundTx.amountPaise,
            transactionDateEpoch: refundTx.transactionDateEpoch,
            referenceType: 'void_abandoned',
            referenceId: refundTx.referenceId,
            description:
                '[VOID_ABANDONED: origTxType=${refundTx.transactionType}, origRefType=${refundTx.referenceType}, op=${op.id}] ${refundTx.description}',
            createdAtEpoch: refundTx.createdAtEpoch,
          );
          await db.accountTransactions.put(voided.id, voided);
        }
        if (refundPayment != null &&
            refundPayment.relatedEntityType != 'void_abandoned') {
          final voidedPay = PaymentRecordModel(
            id: refundPayment.id,
            fairId: refundPayment.fairId,
            amountPaise: refundPayment.amountPaise,
            paymentMethod: refundPayment.paymentMethod,
            paymentDateEpoch: refundPayment.paymentDateEpoch,
            accountId: refundPayment.accountId,
            payerPartnerId: refundPayment.payerPartnerId,
            recipientPartnerId: refundPayment.recipientPartnerId,
            supplierId: refundPayment.supplierId,
            referenceNumber: refundPayment.referenceNumber,
            relatedEntityType: 'void_abandoned',
            relatedEntityId: refundPayment.relatedEntityId,
            notes:
                '[VOID_ABANDONED: origType=${refundPayment.relatedEntityType}, origMethod=${refundPayment.paymentMethod}, op=${op.id}] ${refundPayment.notes}',
            createdAtEpoch: refundPayment.createdAtEpoch,
          );
          await db.paymentRecords.put(voidedPay.id, voidedPay);
        }
        if (refundAccountId != null) {
          await _reprojectAccountBalance(refundAccountId);
        }
        await _markRolledBack(op, 'Incomplete expense refund reversal on disk');
      }
    } else {
      if (expense != null && expense.paymentStatus == 'Cancelled') {
        await _markCommitted(op);
      } else {
        await _markRolledBack(op, 'Expense cancellation was not persisted');
      }
    }
  }

  // --- 8. Expense Write-Off ---
  Future<void> _reconcileExpenseWriteOff(FinancialOperationModel op) async {
    final expenseId = op.primaryEntityId;
    final expense = db.expenses.get(expenseId);
    if (expense != null &&
        (expense.paymentStatus == 'Written Off' ||
            expense.paymentStatus == 'Partially Paid (Written Off)')) {
      await _markCommitted(op);
    } else {
      await _markRolledBack(op, 'Incomplete expense write-off on disk');
    }
  }

  // --- 9. Sales Settlement ---
  Future<void> _reconcileSalesSettlement(FinancialOperationModel op) async {
    final payload = op.payload;
    final receiptId = op.primaryEntityId;
    final receipt = db.salesReceipts.get(receiptId);
    final rawItemIds = payload['saleItemIds'] as List<dynamic>? ?? const [];
    final itemIds = rawItemIds.map((e) => e.toString()).toList();
    final rawTxIds = payload['transactionIds'] as List<dynamic>? ?? const [];
    final txIds = rawTxIds.map((e) => e.toString()).toList();
    final rawPayIds = payload['paymentIds'] as List<dynamic>? ?? const [];
    final payIds = rawPayIds.map((e) => e.toString()).toList();
    final rawMvIds = payload['stockMovementIds'] as List<dynamic>? ?? const [];
    final mvIds = rawMvIds.map((e) => e.toString()).toList();
    final rawAccIds = payload['accountIds'] as List<dynamic>? ?? const [];
    final accountIds = rawAccIds.map((e) => e.toString()).toList();

    final allItemsExist =
        itemIds.isNotEmpty &&
        itemIds.every((id) => db.saleItems.containsKey(id));
    final allTxsExist = txIds.every(
      (id) => db.accountTransactions.containsKey(id),
    );
    final allPaysExist = payIds.every(
      (id) => db.paymentRecords.containsKey(id),
    );
    final allMvsExist = mvIds.every((id) => db.stockMovements.containsKey(id));

    if (receipt != null &&
        allItemsExist &&
        allTxsExist &&
        allPaysExist &&
        allMvsExist) {
      for (final accId in accountIds) {
        await _reprojectAccountBalance(accId);
      }
      await _markCommitted(op);
    } else {
      // Incomplete write: void transactions and payment records, delete stock movements, receipt, and items
      for (final txId in txIds) {
        final tx = db.accountTransactions.get(txId);
        if (tx != null && tx.transactionType != 'void_abandoned') {
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
                '[VOID_ABANDONED: origTxType=${tx.transactionType}, op=${op.id}] ${tx.description}',
            createdAtEpoch: tx.createdAtEpoch,
          );
          await db.accountTransactions.put(voided.id, voided);
        }
      }
      for (final payId in payIds) {
        final pay = db.paymentRecords.get(payId);
        if (pay != null && pay.relatedEntityType != 'void_abandoned') {
          final voidedPay = PaymentRecordModel(
            id: pay.id,
            fairId: pay.fairId,
            amountPaise: pay.amountPaise,
            paymentMethod: pay.paymentMethod,
            paymentDateEpoch: pay.paymentDateEpoch,
            accountId: pay.accountId,
            payerPartnerId: pay.payerPartnerId,
            recipientPartnerId: pay.recipientPartnerId,
            supplierId: pay.supplierId,
            referenceNumber: pay.referenceNumber,
            relatedEntityType: 'void_abandoned',
            relatedEntityId: pay.relatedEntityId,
            notes:
                '[VOID_ABANDONED: origType=${pay.relatedEntityType}, op=${op.id}] ${pay.notes}',
            createdAtEpoch: pay.createdAtEpoch,
          );
          await db.paymentRecords.put(voidedPay.id, voidedPay);
        }
      }
      for (final mvId in mvIds) {
        await db.stockMovements.delete(mvId);
      }
      // Also delete any orphaned stock movements written with referenceId == receiptId
      final orphanedMovements = db.stockMovements.values
          .where((m) => m.referenceId == receiptId)
          .toList();
      for (final m in orphanedMovements) {
        await db.stockMovements.delete(m.id);
      }

      // Also void any orphaned transactions referencing receiptId
      final orphanedTxs = db.accountTransactions.values
          .where(
            (t) =>
                t.referenceId == receiptId &&
                t.transactionType != 'void_abandoned',
          )
          .toList();
      for (final tx in orphanedTxs) {
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
              '[VOID_ABANDONED: origTxType=${tx.transactionType}, op=${op.id}] ${tx.description}',
          createdAtEpoch: tx.createdAtEpoch,
        );
        await db.accountTransactions.put(voided.id, voided);
      }

      for (final itemId in itemIds) {
        await db.saleItems.delete(itemId);
      }
      if (receipt != null) {
        await db.salesReceipts.delete(receiptId);
      }
      for (final accId in accountIds) {
        await _reprojectAccountBalance(accId);
      }
      await _markRolledBack(op, 'Incomplete sales settlement on disk');
    }
  }

  // --- 10. Sale Return Refund ---
  Future<void> _reconcileSaleReturnRefund(FinancialOperationModel op) async {
    final payload = op.payload;
    final txId = payload['transactionId'] as String?;
    final payId = payload['paymentId'] as String?;
    final mvId = payload['stockMovementId'] as String?;
    final refundAccountId =
        op.sourceAccountId ?? payload['refundAccountId'] as String?;

    final tx = txId != null ? db.accountTransactions.get(txId) : null;
    final pay = payId != null ? db.paymentRecords.get(payId) : null;

    if (tx != null && pay != null && tx.transactionType != 'void_abandoned') {
      if (refundAccountId != null) {
        await _reprojectAccountBalance(refundAccountId);
      }
      await _markCommitted(op);
    } else {
      if (tx != null && tx.transactionType != 'void_abandoned') {
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
          description: '[VOID_ABANDONED: op=${op.id}] ${tx.description}',
          createdAtEpoch: tx.createdAtEpoch,
        );
        await db.accountTransactions.put(voided.id, voided);
      }
      if (pay != null && pay.relatedEntityType != 'void_abandoned') {
        final voidedPay = PaymentRecordModel(
          id: pay.id,
          fairId: pay.fairId,
          amountPaise: pay.amountPaise,
          paymentMethod: pay.paymentMethod,
          paymentDateEpoch: pay.paymentDateEpoch,
          accountId: pay.accountId,
          payerPartnerId: pay.payerPartnerId,
          recipientPartnerId: pay.recipientPartnerId,
          supplierId: pay.supplierId,
          referenceNumber: pay.referenceNumber,
          relatedEntityType: 'void_abandoned',
          relatedEntityId: pay.relatedEntityId,
          notes: '[VOID_ABANDONED: op=${op.id}] ${pay.notes}',
          createdAtEpoch: pay.createdAtEpoch,
        );
        await db.paymentRecords.put(voidedPay.id, voidedPay);
      }
      if (mvId != null) {
        await db.stockMovements.delete(mvId);
      }
      if (refundAccountId != null) {
        await _reprojectAccountBalance(refundAccountId);
      }
      await _markRolledBack(op, 'Incomplete sale return refund on disk');
    }
  }

  // --- Canonical Derived Balance Projection ---
  Future<void> _reprojectAccountBalance(String accountId) async {
    final account = db.cashbookAccounts.get(accountId);
    if (account == null) return;

    final baselineKey = 'account_baseline_v5_$accountId';
    final cutoverKey = 'account_cutover_epoch_v5_$accountId';
    final baseline =
        db.metadata.get(baselineKey) as int? ?? account.openingBalancePaise;
    final cutoverEpoch = db.metadata.get(cutoverKey) as int? ?? 0;

    // Sum all valid non-voided transactions for this account created at or after cutoverEpoch.
    // Opening balance transactions are unconditionally excluded because openingBalancePaise
    // is already accounted for in the baseline snapshot.
    final txs = db.accountTransactions.values.where((t) {
      if (t.accountId != accountId ||
          t.transactionType == 'void_abandoned' ||
          t.transactionType == 'opening_balance') {
        return false;
      }
      if (cutoverEpoch > 0) {
        return t.createdAtEpoch >= cutoverEpoch;
      }
      return true;
    }).toList();

    int netDelta = 0;
    for (final t in txs) {
      if (t.transactionType == 'opening_balance') continue;

      if (t.direction.toLowerCase() == 'inflow' ||
          t.direction.toLowerCase() == 'credit') {
        netDelta += t.amountPaise;
      } else {
        netDelta -= t.amountPaise;
      }
    }

    final projectedBalance = baseline + netDelta;
    if (account.currentBalancePaise != projectedBalance) {
      final updatedAccount = CashbookAccountModel(
        id: account.id,
        fairId: account.fairId,
        accountName: account.accountName,
        accountType: account.accountType,
        openingBalancePaise: account.openingBalancePaise,
        currentBalancePaise: projectedBalance,
        isActive: account.isActive,
        createdAtEpoch: account.createdAtEpoch,
        updatedAtEpoch: DateTime.now().millisecondsSinceEpoch,
      );
      await db.cashbookAccounts.put(updatedAccount.id, updatedAccount);
    }
  }

  // --- Summary Synchronizations ---
  Future<void> _syncExpenseSummary(String expenseId) async {
    final expense = db.expenses.get(expenseId);
    if (expense == null) return;

    final payments = db.paymentRecords.values.where((p) {
      return p.relatedEntityType == 'expense' && p.relatedEntityId == expenseId;
    }).toList();

    final totalPaid = payments.fold<int>(0, (sum, p) => sum + p.amountPaise);
    final outstanding = (expense.amountPaise - totalPaid).clamp(
      0,
      expense.amountPaise,
    );
    final String status;
    if (totalPaid >= expense.amountPaise) {
      status = 'Paid';
    } else if (totalPaid > 0) {
      status = 'Partially Paid';
    } else {
      status = 'Unpaid';
    }

    final updated = ExpenseModel(
      id: expense.id,
      fairId: expense.fairId,
      title: expense.title,
      description: expense.description,
      categoryId: expense.categoryId,
      amountPaise: expense.amountPaise,
      expenseDateEpoch: expense.expenseDateEpoch,
      paymentStatus: status,
      paidAmountPaise: totalPaid,
      outstandingAmountPaise: outstanding,
      paidByPartnerId: expense.paidByPartnerId,
      paidFromAccountId: expense.paidFromAccountId,
      paymentMethod: expense.paymentMethod,
      referenceNumber: expense.referenceNumber,
      notes: expense.notes,
      createdAtEpoch: expense.createdAtEpoch,
      updatedAtEpoch: DateTime.now().millisecondsSinceEpoch,
    );
    await db.expenses.put(updated.id, updated);
  }

  Future<void> _syncPurchaseBatchPaymentStatus(String batchId) async {
    final batch = db.purchaseBatches.get(batchId);
    if (batch == null) return;

    final payments = db.paymentRecords.values.where((p) {
      return p.relatedEntityType == 'purchase_batch' &&
          p.relatedEntityId == batchId;
    }).toList();

    final totalPaid = payments.fold<int>(0, (sum, p) => sum + p.amountPaise);
    final String status;
    if (totalPaid >= batch.totalAcquisitionCostPaise) {
      status = 'Paid';
    } else if (totalPaid > 0) {
      status = 'Partially Paid';
    } else {
      status = 'Unpaid';
    }

    final updated = PurchaseBatchModel(
      id: batch.id,
      fairId: batch.fairId,
      purchaseDateEpoch: batch.purchaseDateEpoch,
      totalQuantity: batch.totalQuantity,
      totalBookCostPaise: batch.totalBookCostPaise,
      additionalChargesPaise: batch.additionalChargesPaise,
      totalAcquisitionCostPaise: batch.totalAcquisitionCostPaise,
      paymentStatus: status,
      supplierId: batch.supplierId,
      paymentMethod: batch.paymentMethod,
      notes: batch.notes,
      createdAtEpoch: batch.createdAtEpoch,
    );
    await db.purchaseBatches.put(updated.id, updated);
  }

  Future<void> _markCommitted(FinancialOperationModel op) async {
    final updated = op.copyWith(
      status: 'committed',
      updatedAtEpoch: DateTime.now().millisecondsSinceEpoch,
    );
    await journalDataSource.saveOperation(updated);
    await journalDataSource.flush();
  }

  Future<void> _markRolledBack(
    FinancialOperationModel op,
    String reason,
  ) async {
    final payload = Map<String, dynamic>.from(op.payload);
    payload['reversalReason'] = reason;
    payload['reversalEpoch'] = DateTime.now().millisecondsSinceEpoch;

    final updated = op.copyWith(
      status: 'rolled_back',
      payloadJson: jsonEncode(payload),
      updatedAtEpoch: DateTime.now().millisecondsSinceEpoch,
    );
    await journalDataSource.saveOperation(updated);
    await journalDataSource.flush();
  }

  Future<void> _handleRecoveryFailure(
    FinancialOperationModel op,
    dynamic error,
    StackTrace stack,
  ) async {
    if (op.sourceAccountId != null) {
      FinancialOperationCoordinator.quarantineAccount(op.sourceAccountId!);
    }
    if (op.targetAccountId != null) {
      FinancialOperationCoordinator.quarantineAccount(op.targetAccountId!);
    }

    final payload = Map<String, dynamic>.from(op.payload);
    payload['recoveryError'] = error.toString();
    payload['recoveryStack'] = stack.toString();
    payload['failedAtEpoch'] = DateTime.now().millisecondsSinceEpoch;

    final updated = op.copyWith(
      status: 'recovery_failed',
      payloadJson: jsonEncode(payload),
      updatedAtEpoch: DateTime.now().millisecondsSinceEpoch,
    );
    await journalDataSource.saveOperation(updated);
    await journalDataSource.flush();
  }
}
