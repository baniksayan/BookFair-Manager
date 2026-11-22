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
import '../../../expenses/data/datasources/expense_local_datasource.dart';
import '../../../expenses/data/models/expense_model.dart';
import '../../../inventory/data/models/purchase_batch_model.dart';
import '../../domain/entities/payment_record.dart';
import '../../domain/repositories/payment_repository.dart';
import '../datasources/payment_local_datasource.dart';
import '../models/payment_record_model.dart';

/// Concrete Hive implementation of [PaymentRepository] managing payment records and linking them to cashbook transactions and business entities.
class PaymentRepositoryImpl implements PaymentRepository {
  PaymentRepositoryImpl({
    required this.paymentDataSource,
    required this.cashbookRepository,
    required this.expenseDataSource,
    required this.database,
    required this.activityLogs,
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

  final PaymentLocalDataSource paymentDataSource;
  final CashbookRepository cashbookRepository;
  final ExpenseLocalDataSource expenseDataSource;
  final AppDatabase database;
  final ActivityLogRepository activityLogs;
  final FinancialOperationCoordinator _coordinator;
  final Uuid _uuid;

  @override
  Future<List<PaymentRecord>> getPayments({
    String? fairId,
    String? relatedEntityType,
    String? relatedEntityId,
  }) async {
    return paymentDataSource
        .getPayments(
          fairId: fairId,
          relatedEntityType: relatedEntityType,
          relatedEntityId: relatedEntityId,
        )
        .where((m) => m.relatedEntityType != 'void_abandoned')
        .map((m) => m.toEntity())
        .toList();
  }

  @override
  Stream<List<PaymentRecord>> watchPayments({
    String? fairId,
    String? relatedEntityType,
    String? relatedEntityId,
  }) {
    return paymentDataSource
        .watchPayments(
          fairId: fairId,
          relatedEntityType: relatedEntityType,
          relatedEntityId: relatedEntityId,
        )
        .map(
          (list) => list
              .where((m) => m.relatedEntityType != 'void_abandoned')
              .map((m) => m.toEntity())
              .toList(),
        );
  }

  @override
  Future<PaymentRecord?> getPaymentById(String id) async {
    return paymentDataSource.getPaymentById(id)?.toEntity();
  }

  @override
  Future<PaymentRecord> recordPayment(
    PaymentRecord payment, {
    String? clientRequestId,
  }) async {
    if (payment.amountPaise <= 0) {
      throw const ValidationException(
        'Payment amount must be greater than zero',
      );
    }

    if (payment.isPaidFromBusinessAccount) {
      final acc = database.cashbookAccounts.get(payment.accountId!);
      if (acc == null) {
        throw RecordNotFoundException('CashbookAccount', payment.accountId!);
      }
      if (!acc.isActive) {
        throw ValidationException(
          'Cannot record transactions on inactive account "${acc.accountName}"',
        );
      }
      if (acc.currentBalancePaise < payment.amountPaise) {
        throw ValidationException(
          'Insufficient balance in ${acc.accountName}. '
          'Available: ₹${(acc.currentBalancePaise / 100.0).toStringAsFixed(2)}, '
          'Required: ₹${(payment.amountPaise / 100.0).toStringAsFixed(2)}',
        );
      }
    }

    final String opType;
    switch (payment.relatedEntityType) {
      case 'expense':
        opType = 'standalone_expense_payment';
        break;
      case 'purchase_batch':
        opType = 'purchase_batch_payment';
        break;
      case 'reimbursement':
        opType = 'partner_reimbursement';
        break;
      default:
        opType = 'disbursement';
    }

    final effectiveReqId = clientRequestId ?? payment.id;
    final idempotencyKey =
        'payment_${payment.fairId}_${payment.relatedEntityType}_${payment.relatedEntityId}_$effectiveReqId';
    final txId = _uuid.v4();

    final affectedBoxes = [
      database.paymentRecords,
      if (payment.isPaidFromBusinessAccount) ...[
        database.accountTransactions,
        database.cashbookAccounts,
      ],
      if (payment.relatedEntityType == 'expense') database.expenses,
      if (payment.relatedEntityType == 'purchase_batch')
        database.purchaseBatches,
    ];

    final payload = {
      'fairId': payment.fairId,
      'paymentId': payment.id,
      'amountPaise': payment.amountPaise,
      'relatedEntityType': payment.relatedEntityType,
      'relatedEntityId': payment.relatedEntityId,
      if (payment.isPaidFromBusinessAccount) 'accountId': payment.accountId,
      if (payment.isPaidFromBusinessAccount) 'txId': txId,
      if (payment.relatedEntityType == 'expense')
        'expenseId': payment.relatedEntityId,
      if (payment.relatedEntityType == 'purchase_batch')
        'batchId': payment.relatedEntityId,
      if (payment.relatedEntityType == 'reimbursement')
        'partnerId': payment.recipientPartnerId ?? payment.relatedEntityId,
      'originalRecords': {
        'payment': {
          'id': payment.id,
          'fairId': payment.fairId,
          'amountPaise': payment.amountPaise,
          'paymentMethod': payment.paymentMethod,
          'paymentDateEpoch': payment.paymentDate.millisecondsSinceEpoch,
          'accountId': payment.accountId,
          'payerPartnerId': payment.payerPartnerId,
          'recipientPartnerId': payment.recipientPartnerId,
          'supplierId': payment.supplierId,
          'referenceNumber': payment.referenceNumber,
          'relatedEntityType': payment.relatedEntityType,
          'relatedEntityId': payment.relatedEntityId,
          'notes': payment.notes,
        },
        if (payment.isPaidFromBusinessAccount)
          'transaction': {
            'id': txId,
            'fairId': payment.fairId,
            'accountId': payment.accountId,
            'amountPaise': payment.amountPaise,
            'direction': 'outflow',
            'referenceType': payment.relatedEntityType,
            'referenceId': payment.id,
          },
      },
    };

    return await _coordinator.runCoordinatedOperation<PaymentRecord>(
      fairId: payment.fairId,
      operationType: opType,
      idempotencyKey: idempotencyKey,
      amountPaise: payment.amountPaise,
      primaryEntityId: payment.relatedEntityId,
      secondaryEntityId: payment.id,
      sourceAccountId: payment.isPaidFromBusinessAccount
          ? payment.accountId
          : null,
      payload: payload,
      affectedBoxes: affectedBoxes,
      executeWrites: (opId) async {
        // 1. If paid from business account, record cashbook debit
        if (payment.isPaidFromBusinessAccount) {
          final accModel = database.cashbookAccounts.get(payment.accountId!);
          if (accModel == null) {
            throw RecordNotFoundException(
              'CashbookAccount',
              payment.accountId!,
            );
          }
          if (accModel.currentBalancePaise < payment.amountPaise) {
            throw ValidationException(
              'Insufficient balance in ${accModel.accountName}. '
              'Available: ₹${(accModel.currentBalancePaise / 100.0).toStringAsFixed(2)}, '
              'Required: ₹${(payment.amountPaise / 100.0).toStringAsFixed(2)}',
            );
          }

          String txType;
          switch (payment.relatedEntityType) {
            case 'expense':
              txType = 'expense_payment';
              break;
            case 'purchase_batch':
              txType = 'purchase_payment';
              break;
            case 'reimbursement':
              txType = 'partner_reimbursement';
              break;
            default:
              txType = 'expense_payment';
          }

          final now = DateTime.now();
          final debitTx = AccountTransactionModel(
            id: txId,
            fairId: payment.fairId,
            accountId: payment.accountId!,
            transactionType: txType,
            direction: 'outflow',
            amountPaise: payment.amountPaise,
            transactionDateEpoch: payment.paymentDate.millisecondsSinceEpoch,
            referenceType: payment.relatedEntityType,
            referenceId: payment.id,
            description:
                'Payment (${payment.paymentMethod}) for ${payment.relatedEntityType}${payment.referenceNumber != null && payment.referenceNumber!.isNotEmpty ? ' (Ref: ${payment.referenceNumber})' : ''}',
            createdAtEpoch: now.millisecondsSinceEpoch,
          );
          await database.accountTransactions.put(txId, debitTx);

          final updatedAcc = CashbookAccountModel(
            id: accModel.id,
            fairId: accModel.fairId,
            accountName: accModel.accountName,
            accountType: accModel.accountType,
            openingBalancePaise: accModel.openingBalancePaise,
            currentBalancePaise:
                accModel.currentBalancePaise - payment.amountPaise,
            isActive: accModel.isActive,
            createdAtEpoch: accModel.createdAtEpoch,
            updatedAtEpoch: now.millisecondsSinceEpoch,
          );
          await database.cashbookAccounts.put(updatedAcc.id, updatedAcc);
        }

        // 2. Persist payment record
        await paymentDataSource.savePayment(
          PaymentRecordModel.fromEntity(payment),
        );

        // 3. If linked to an Expense, recalculate paid & outstanding amounts
        if (payment.relatedEntityType == 'expense') {
          final expenseModel = expenseDataSource.getExpenseById(
            payment.relatedEntityId,
          );
          if (expenseModel != null) {
            if (expenseModel.toEntity().isCancelled ||
                expenseModel.paymentStatus.toLowerCase().contains(
                  'written off',
                )) {
              throw const ValidationException(
                'Cannot record payment for a cancelled or written-off expense.',
              );
            }
            final validPayments = database.paymentRecords.values.where((p) {
              return p.relatedEntityType == 'expense' &&
                  p.relatedEntityId == payment.relatedEntityId &&
                  p.relatedEntityType != 'void_abandoned';
            }).toList();
            final totalPaid = validPayments.fold<int>(
              0,
              (sum, p) => sum + p.amountPaise,
            );
            final outstanding = max(0, expenseModel.amountPaise - totalPaid);
            final String newStatus;
            if (totalPaid >= expenseModel.amountPaise) {
              newStatus = 'Paid';
            } else if (totalPaid > 0) {
              newStatus = 'Partially Paid';
            } else {
              newStatus = 'Unpaid';
            }

            final updatedExpense = ExpenseModel(
              id: expenseModel.id,
              fairId: expenseModel.fairId,
              title: expenseModel.title,
              description: expenseModel.description,
              categoryId: expenseModel.categoryId,
              amountPaise: expenseModel.amountPaise,
              expenseDateEpoch: expenseModel.expenseDateEpoch,
              paymentStatus: newStatus,
              paidAmountPaise: totalPaid,
              outstandingAmountPaise: outstanding,
              paidByPartnerId: expenseModel.paidByPartnerId,
              paidFromAccountId: expenseModel.paidFromAccountId,
              paymentMethod: expenseModel.paymentMethod,
              referenceNumber: expenseModel.referenceNumber,
              notes: expenseModel.notes,
              createdAtEpoch: expenseModel.createdAtEpoch,
              updatedAtEpoch: DateTime.now().millisecondsSinceEpoch,
            );
            await expenseDataSource.saveExpense(updatedExpense);
          }
        }

        // 4. If linked to a Purchase Batch, update batch payment status
        if (payment.relatedEntityType == 'purchase_batch') {
          final batchModel = database.purchaseBatches.get(
            payment.relatedEntityId,
          );
          if (batchModel != null) {
            final validPayments = database.paymentRecords.values.where((p) {
              return p.relatedEntityType == 'purchase_batch' &&
                  p.relatedEntityId == payment.relatedEntityId &&
                  p.relatedEntityType != 'void_abandoned';
            }).toList();
            final totalPaid = validPayments.fold<int>(
              0,
              (sum, p) => sum + p.amountPaise,
            );

            final String newStatus;
            if (totalPaid >= batchModel.totalAcquisitionCostPaise) {
              newStatus = 'Paid';
            } else if (totalPaid > 0) {
              newStatus = 'Partially Paid';
            } else {
              newStatus = 'Unpaid';
            }

            final updatedBatch = PurchaseBatchModel(
              id: batchModel.id,
              fairId: batchModel.fairId,
              purchaseDateEpoch: batchModel.purchaseDateEpoch,
              totalQuantity: batchModel.totalQuantity,
              totalBookCostPaise: batchModel.totalBookCostPaise,
              additionalChargesPaise: batchModel.additionalChargesPaise,
              totalAcquisitionCostPaise: batchModel.totalAcquisitionCostPaise,
              paymentStatus: newStatus,
              supplierId: batchModel.supplierId,
              paymentMethod: batchModel.paymentMethod,
              notes: batchModel.notes,
              createdAtEpoch: batchModel.createdAtEpoch,
            );
            await database.purchaseBatches.put(updatedBatch.id, updatedBatch);
          }
        }

        try {
          await activityLogs.logEvent(
            ActivityLog(
              id: _uuid.v4(),
              fairId: payment.fairId,
              title: 'Payment Recorded',
              subtitle:
                  'Disbursed via ${payment.paymentMethod} for ${payment.relatedEntityType}',
              amount: '₹${(payment.amountPaise / 100.0).toStringAsFixed(2)}',
              type: ActivityLogType.paymentRecorded,
              timestamp: payment.createdAt,
            ),
          );
        } catch (_) {}

        return payment;
      },
      rollbackWrites: (opId) async {
        final p = database.paymentRecords.get(payment.id);
        if (p != null) {
          final voidedP = PaymentRecordModel(
            id: p.id,
            fairId: p.fairId,
            amountPaise: p.amountPaise,
            paymentMethod: p.paymentMethod,
            paymentDateEpoch: p.paymentDateEpoch,
            accountId: p.accountId,
            payerPartnerId: p.payerPartnerId,
            recipientPartnerId: p.recipientPartnerId,
            supplierId: p.supplierId,
            referenceNumber: p.referenceNumber,
            relatedEntityType: 'void_abandoned',
            relatedEntityId: p.relatedEntityId,
            notes:
                '[VOID_ABANDONED: origType=${p.relatedEntityType}, origMethod=${p.paymentMethod}, op=$opId] ${p.notes}',
            createdAtEpoch: p.createdAtEpoch,
          );
          await database.paymentRecords.put(voidedP.id, voidedP);
        }

        if (payment.isPaidFromBusinessAccount) {
          final tx = database.accountTransactions.get(txId);
          if (tx != null) {
            final voidedTx = AccountTransactionModel(
              id: tx.id,
              fairId: tx.fairId,
              accountId: tx.accountId,
              transactionType: 'void_abandoned',
              direction: tx.direction,
              amountPaise: tx.amountPaise,
              transactionDateEpoch: tx.transactionDateEpoch,
              referenceType: tx.referenceType,
              referenceId: tx.referenceId,
              description:
                  '[VOID_ABANDONED: origTxType=${tx.transactionType}, origRefType=${tx.referenceType}, op=$opId] ${tx.description}',
              createdAtEpoch: tx.createdAtEpoch,
            );
            await database.accountTransactions.put(voidedTx.id, voidedTx);
          }

          final acc = database.cashbookAccounts.get(payment.accountId!);
          if (acc != null) {
            final restored = CashbookAccountModel(
              id: acc.id,
              fairId: acc.fairId,
              accountName: acc.accountName,
              accountType: acc.accountType,
              openingBalancePaise: acc.openingBalancePaise,
              currentBalancePaise:
                  acc.currentBalancePaise + payment.amountPaise,
              isActive: acc.isActive,
              createdAtEpoch: acc.createdAtEpoch,
              updatedAtEpoch: DateTime.now().millisecondsSinceEpoch,
            );
            await database.cashbookAccounts.put(restored.id, restored);
          }
        }
      },
      validateInvariants: () {
        final p = database.paymentRecords.get(payment.id);
        if (p == null) {
          throw const ValidationException(
            'Payment record was not persisted to disk',
          );
        }
      },
      onAlreadyCommitted: (existingOp) async {
        final p = paymentDataSource.getPaymentById(payment.id);
        if (p != null) return p.toEntity();
        return payment;
      },
    );
  }

  @override
  Future<List<PaymentRecord>> getPartnerPersonalPayments({
    required String fairId,
    String? partnerId,
  }) async {
    final all = await getPayments(fairId: fairId);
    return all.where((p) {
      if (p.payerPartnerId == null || p.payerPartnerId!.isEmpty) return false;
      if (partnerId != null && p.payerPartnerId != partnerId) return false;
      return true;
    }).toList();
  }

  @override
  Future<List<PaymentRecord>> getPartnerReimbursements({
    required String fairId,
    String? partnerId,
  }) async {
    final all = await getPayments(
      fairId: fairId,
      relatedEntityType: 'reimbursement',
    );
    if (partnerId != null) {
      return all.where((p) => p.recipientPartnerId == partnerId).toList();
    }
    return all;
  }

  @override
  Future<List<PaymentRecord>> getSupplierPayments({
    required String fairId,
    String? supplierId,
  }) async {
    final all = await getPayments(
      fairId: fairId,
      relatedEntityType: 'purchase_batch',
    );
    if (supplierId != null) {
      return all.where((p) => p.supplierId == supplierId).toList();
    }
    return all;
  }

  @override
  Future<PaymentRecord> recordPartnerReimbursement({
    required String fairId,
    required String partnerId,
    required int amountPaise,
    required String fromAccountId,
    required String paymentMethod,
    String? referenceNumber,
    String? notes,
    required DateTime paymentDate,
    String? clientRequestId,
  }) async {
    final payment = PaymentRecord(
      id: _uuid.v4(),
      fairId: fairId,
      amountPaise: amountPaise,
      paymentMethod: paymentMethod,
      paymentDate: paymentDate,
      accountId: fromAccountId,
      recipientPartnerId: partnerId,
      relatedEntityType: 'reimbursement',
      relatedEntityId: partnerId,
      referenceNumber: referenceNumber,
      notes: notes ?? 'Partner reimbursement payment',
      createdAt: DateTime.now(),
    );

    return recordPayment(payment, clientRequestId: clientRequestId);
  }
}
