import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_exceptions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../book_fairs/domain/entities/activity_log.dart';
import '../../../book_fairs/domain/repositories/activity_log_repository.dart';
import '../../../cashbook/data/datasources/cashbook_local_datasource.dart';
import '../../../cashbook/data/models/account_transaction_model.dart';
import '../../../cashbook/data/models/cashbook_account_model.dart';
import '../../../cashbook/domain/entities/account_transaction.dart';
import '../../../cashbook/domain/services/financial_operation_coordinator.dart';
import '../../../inventory/data/datasources/inventory_local_datasource.dart';
import '../../../inventory/data/models/stock_movement_model.dart';
import '../../../inventory/domain/entities/book.dart';
import '../../../inventory/domain/entities/stock_movement.dart';
import '../../../inventory/domain/services/inventory_cost_calculator.dart';
import '../../../payments/data/datasources/payment_local_datasource.dart';
import '../../../payments/data/models/payment_record_model.dart';
import '../../../payments/domain/entities/payment_record.dart';
import '../../domain/entities/sale_item.dart';
import '../../domain/entities/sale_receipt.dart';
import '../../domain/repositories/sale_repository.dart';
import '../datasources/sales_local_datasource.dart';
import '../models/sale_item_model.dart';
import '../models/sale_receipt_model.dart';

/// Enterprise production implementation of [SaleRepository] with full
/// [FinancialOperationCoordinator] write-ahead durability.
class SaleRepositoryImpl implements SaleRepository {
  SaleRepositoryImpl({
    required this.salesDataSource,
    required this.inventoryDataSource,
    required this.cashbookDataSource,
    required this.paymentDataSource,
    required this.coordinator,
    required this.activityLogRepo,
    required this.db,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final SalesLocalDataSource salesDataSource;
  final InventoryLocalDataSource inventoryDataSource;
  final CashbookLocalDataSource cashbookDataSource;
  final PaymentLocalDataSource paymentDataSource;
  final FinancialOperationCoordinator coordinator;
  final ActivityLogRepository activityLogRepo;
  final AppDatabase db;
  final Uuid _uuid;

  @override
  Future<List<SaleReceipt>> getAllReceipts({String? fairId}) async {
    final models = await salesDataSource.getAllReceipts(fairId: fairId);
    final results = <SaleReceipt>[];
    for (final m in models) {
      final itemModels = await salesDataSource.getItemsForReceipt(m.id);
      results.add(
        m.toEntity(items: itemModels.map((i) => i.toEntity()).toList()),
      );
    }
    return results;
  }

  @override
  Future<SaleReceipt?> getReceiptById(String id) async {
    final model = await salesDataSource.getReceiptById(id);
    if (model == null) return null;
    final itemModels = await salesDataSource.getItemsForReceipt(id);
    return model.toEntity(items: itemModels.map((i) => i.toEntity()).toList());
  }

  @override
  Future<List<SaleItem>> getItemsForReceipt(String receiptId) async {
    final itemModels = await salesDataSource.getItemsForReceipt(receiptId);
    return itemModels.map((i) => i.toEntity()).toList();
  }

  @override
  Future<SaleReceipt> recordSale({
    required SaleReceipt receipt,
    required List<SaleItem> items,
    required List<PaymentRecord> payments,
    required String clientRequestId,
  }) async {
    // 1. Initial Invariant Validation
    if (items.isEmpty) {
      throw ValidationException('Cannot record sale with empty line items.');
    }

    if (receipt.totalAmountPaise < 0) {
      throw ValidationException(
        'Receipt total payable amount cannot be negative.',
      );
    }

    // Verify subtotal matches items
    final calculatedSubtotal = items.fold<int>(
      0,
      (sum, item) => sum + (item.unitSellingPricePaise * item.quantity),
    );
    if (calculatedSubtotal != receipt.subtotalAmountPaise) {
      throw ValidationException(
        'Receipt subtotal mismatch: Expected ₹${(calculatedSubtotal / 100.0).toStringAsFixed(2)}, but got ₹${(receipt.subtotalAmountPaise / 100.0).toStringAsFixed(2)}.',
      );
    }

    // Verify net total matches subtotal minus discount
    final expectedTotal = calculatedSubtotal - receipt.discountAmountPaise;
    if (expectedTotal != receipt.totalAmountPaise) {
      throw ValidationException(
        'Receipt net total mismatch: Expected ₹${(expectedTotal / 100.0).toStringAsFixed(2)}, but got ₹${(receipt.totalAmountPaise / 100.0).toStringAsFixed(2)}.',
      );
    }

    // Verify payments sum matches receipt net total exactly
    final totalPaymentsPaise = payments.fold<int>(
      0,
      (sum, p) => sum + p.amountPaise,
    );
    if (totalPaymentsPaise != receipt.totalAmountPaise) {
      throw ValidationException(
        'Total payments (₹${(totalPaymentsPaise / 100.0).toStringAsFixed(2)}) must exactly match receipt total payable (₹${(receipt.totalAmountPaise / 100.0).toStringAsFixed(2)}).',
      );
    }

    // Validate cash tendered and change if present
    if (receipt.tenderedAmountPaise != null &&
        receipt.changeAmountPaise != null) {
      final cashPayments = payments.where(
        (p) => p.paymentMethod.toLowerCase() == 'cash',
      );
      final totalCashPayable = cashPayments.fold<int>(
        0,
        (sum, p) => sum + p.amountPaise,
      );
      if (receipt.tenderedAmountPaise! < totalCashPayable) {
        throw ValidationException(
          'Tendered cash (₹${(receipt.tenderedAmountPaise! / 100.0).toStringAsFixed(2)}) cannot be less than cash payable amount (₹${(totalCashPayable / 100.0).toStringAsFixed(2)}).',
        );
      }
      final expectedChange = receipt.tenderedAmountPaise! - totalCashPayable;
      if (expectedChange != receipt.changeAmountPaise) {
        throw ValidationException(
          'Change calculation error: Expected ₹${(expectedChange / 100.0).toStringAsFixed(2)}, got ₹${(receipt.changeAmountPaise! / 100.0).toStringAsFixed(2)}.',
        );
      }
    }

    // 2. Check stock availability for all items
    final allMovements = await inventoryDataSource.getAllStockMovements(
      fairId: receipt.fairId,
    );
    for (final item in items) {
      if (item.quantity <= 0) {
        throw ValidationException(
          'Line item "${item.bookTitle}" has invalid quantity: ${item.quantity}. Must be at least 1.',
        );
      }

      final available = InventoryCostCalculator.calculateAvailableStockForBook(
        movements: allMovements.map((m) => m.toEntity()).toList(),
        bookId: item.bookId,
      );

      if (available < item.quantity) {
        if (!item.isUnverifiedStock) {
          throw ValidationException(
            'Insufficient physical stock for "${item.bookTitle}". Available: $available, Requested: ${item.quantity}. Normal cashiers cannot checkout out-of-stock titles without authorized manager override.',
          );
        }
        if (item.overrideAuthorizerId == null ||
            item.overrideAuthorizerId!.trim().isEmpty ||
            item.overrideReason == null ||
            item.overrideReason!.trim().isEmpty) {
          throw ValidationException(
            'Manager override for negative stock on "${item.bookTitle}" requires valid authorizing manager ID and explicit justification reason.',
          );
        }
      }
    }

    // 3. Assemble Lock Keys & Durability Invariants
    final idempotencyKey = 'sale_${receipt.fairId}_$clientRequestId';
    final paymentAccountIds = payments
        .map((p) => p.accountId)
        .where((id) => id != null && id.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();

    final additionalLockKeys = [
      for (final accId in paymentAccountIds) 'account:$accId',
      for (final item in items) 'book:${item.bookId}',
      'sale:${receipt.id}',
    ];

    // Tracking variables for compensating rollback
    final createdTxIds = <String>[];
    final createdPaymentIds = <String>[];
    final createdStockMovementIds = <String>[];
    final creditedAccountDeltas = <String, int>{};
    bool receiptSaved = false;

    return coordinator.runCoordinatedOperation<SaleReceipt>(
      fairId: receipt.fairId,
      operationType: 'sales_settlement',
      idempotencyKey: idempotencyKey,
      amountPaise: receipt.totalAmountPaise,
      primaryEntityId: receipt.id,
      additionalLockKeys: additionalLockKeys,
      payload: {
        'receiptId': receipt.id,
        'clientRequestId': clientRequestId,
        'fairId': receipt.fairId,
        'totalAmountPaise': receipt.totalAmountPaise,
        'saleItemIds': items.map((i) => i.id).toList(),
        'accountIds': paymentAccountIds,
        'originalRecords': {
          'receipt': receipt.toMap(),
          'items': items.map((i) => i.toMap()).toList(),
          'payments': payments.map((p) => p.toMap()).toList(),
        },
      },
      affectedBoxes: [
        db.salesReceipts,
        db.saleItems,
        db.stockMovements,
        db.paymentRecords,
        db.accountTransactions,
        db.cashbookAccounts,
      ],
      executeWrites: (opId) async {
        // A. Re-verify fresh stock under lock
        final freshMovements = await inventoryDataSource.getAllStockMovements(
          fairId: receipt.fairId,
        );
        for (final item in items) {
          final liveStock =
              InventoryCostCalculator.calculateAvailableStockForBook(
                movements: freshMovements.map((m) => m.toEntity()).toList(),
                bookId: item.bookId,
              );
          if (liveStock < item.quantity && !item.isUnverifiedStock) {
            throw ValidationException(
              'Concurrent stock depletion: "${item.bookTitle}" has only $liveStock copies available under lock. Sale cannot proceed without manager override.',
            );
          }
        }

        // B. Re-verify fresh accounts under lock
        for (final accId in paymentAccountIds) {
          final acc = cashbookDataSource.getAccountById(accId);
          if (acc == null) {
            throw RecordNotFoundException('CashbookAccount', accId);
          }
          if (!acc.isActive) {
            throw ValidationException(
              'Cannot receive funds into inactive account "${acc.accountName}".',
            );
          }
        }

        // C. Save Sale Receipt & Sale Items
        final receiptModel = SaleReceiptModel.fromEntity(receipt);
        final itemModels = items
            .map((i) => SaleItemModel.fromEntity(i))
            .toList();
        await salesDataSource.createReceipt(
          receipt: receiptModel,
          items: itemModels,
        );
        receiptSaved = true;

        // D. Create and save StockMovements (saleOut)
        final movementEntities = <StockMovement>[];
        for (final item in items) {
          final movement = StockMovement(
            id: _uuid.v4(),
            fairId: receipt.fairId,
            bookId: item.bookId,
            quantity: item.quantity,
            movementType: StockMovementType.saleOut,
            referenceId: receipt.id,
            movementDate: receipt.createdAt,
            notes: item.isUnverifiedStock
                ? 'POS Sale #${receipt.receiptNumber} (Manager Override: ${item.overrideReason})'
                : 'POS Sale #${receipt.receiptNumber}',
            createdAt: receipt.createdAt,
          );
          movementEntities.add(movement);
          createdStockMovementIds.add(movement.id);
          await inventoryDataSource.recordStockMovement(
            StockMovementModel.fromEntity(movement),
          );
        }

        // E. Save Payment Records and credit Account Balances
        for (final payment in payments) {
          createdPaymentIds.add(payment.id);
          await paymentDataSource.savePayment(
            PaymentRecordModel.fromEntity(payment),
          );

          if (payment.accountId != null && payment.accountId!.isNotEmpty) {
            final accId = payment.accountId!;
            final freshAcc = cashbookDataSource.getAccountById(accId)!;

            final txId = 'tx_sale_${payment.id}';
            final tx = AccountTransaction(
              id: txId,
              fairId: receipt.fairId,
              accountId: accId,
              transactionType: 'sale_receipt',
              direction: 'inflow',
              amountPaise: payment.amountPaise,
              transactionDate: payment.paymentDate,
              referenceType: 'sale_receipt',
              referenceId: receipt.id,
              description:
                  'Sale Receipt #${receipt.receiptNumber} (${payment.paymentMethod})',
              createdAt: DateTime.now(),
            );
            createdTxIds.add(tx.id);
            await cashbookDataSource.saveTransaction(
              AccountTransactionModel.fromEntity(tx),
            );

            // Inflow credits account: add payment.amountPaise (NOT tendered cash!)
            final newBalance =
                freshAcc.currentBalancePaise + payment.amountPaise;
            final updatedAcc = freshAcc.toEntity().copyWith(
              currentBalancePaise: newBalance,
              updatedAt: DateTime.now(),
            );
            await cashbookDataSource.saveAccount(
              CashbookAccountModel.fromEntity(updatedAcc),
            );
            creditedAccountDeltas[accId] =
                (creditedAccountDeltas[accId] ?? 0) + payment.amountPaise;
          }
        }

        // F. Audit Activity Log
        try {
          await activityLogRepo.logEvent(
            ActivityLog(
              id: _uuid.v4(),
              fairId: receipt.fairId,
              title: 'POS Sale Completed',
              subtitle:
                  'Receipt #${receipt.receiptNumber} • ${receipt.totalQuantity} items',
              amount: CurrencyFormatter.format(receipt.total),
              type: ActivityLogType.paymentRecorded,
              timestamp: DateTime.now(),
            ),
          );
        } catch (_) {}

        return receipt.copyWith(items: items);
      },
      rollbackWrites: (opId) async {
        // Void transactions
        for (final txId in createdTxIds) {
          try {
            final tx = cashbookDataSource.getTransactionById(txId);
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
                description: '[VOID_ABANDONED: op=$opId] ${tx.description}',
                createdAtEpoch: tx.createdAtEpoch,
              );
              await cashbookDataSource.saveTransaction(voided);
            }
          } catch (_) {}
        }

        // Void payments
        for (final pId in createdPaymentIds) {
          try {
            final p = paymentDataSource.getPaymentById(pId);
            if (p != null) {
              final voided = PaymentRecordModel(
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
                notes: '[VOID_ABANDONED: op=$opId] ${p.notes}',
                createdAtEpoch: p.createdAtEpoch,
              );
              await paymentDataSource.savePayment(voided);
            }
          } catch (_) {}
        }

        // Undo credited account balances
        for (final entry in creditedAccountDeltas.entries) {
          try {
            final curAcc = cashbookDataSource.getAccountById(entry.key);
            if (curAcc != null) {
              final reverted = curAcc.toEntity().copyWith(
                currentBalancePaise: curAcc.currentBalancePaise - entry.value,
                updatedAt: DateTime.now(),
              );
              await cashbookDataSource.saveAccount(
                CashbookAccountModel.fromEntity(reverted),
              );
            }
          } catch (_) {}
        }

        // Delete stock movements
        for (final mvId in createdStockMovementIds) {
          try {
            await db.stockMovements.delete(mvId);
          } catch (_) {}
        }

        // Delete receipt and items if partially written
        if (receiptSaved) {
          try {
            await salesDataSource.deleteReceipt(receipt.id);
          } catch (_) {}
        }
      },
      validateInvariants: () {
        // Confirm net revenue matches sum of active transactions
      },
      onAlreadyCommitted: (existingOp) async {
        final existingReceipt = await getReceiptById(receipt.id);
        if (existingReceipt != null) {
          return existingReceipt;
        }
        // Fallback: reconstruct from payload
        final payload = existingOp.payload;
        final origRecords = payload['originalRecords'] as Map<String, dynamic>?;
        if (origRecords != null && origRecords['receipt'] != null) {
          final origReceiptMap = origRecords['receipt'] as Map<String, dynamic>;
          final origItemsList = (origRecords['items'] as List<dynamic>? ?? [])
              .map((e) => SaleItem.fromMap(e as Map<String, dynamic>))
              .toList();
          return SaleReceipt.fromMap(origReceiptMap, items: origItemsList);
        }
        return receipt.copyWith(items: items);
      },
    );
  }

  @override
  Future<SaleReceipt> processSaleReturn({
    required String receiptId,
    required String saleItemId,
    required int returnQuantity,
    required BookCondition condition,
    required bool isRestocked,
    required int refundAmountPaise,
    required String refundAccountId,
    required String reason,
    String? processedByPartnerId,
    required String clientRequestId,
  }) async {
    final liveReceipt = await getReceiptById(receiptId);
    if (liveReceipt == null) {
      throw RecordNotFoundException('SaleReceipt', receiptId);
    }

    if (liveReceipt.isFullyRefunded) {
      throw ValidationException(
        'Cannot process return on a fully refunded receipt.',
      );
    }

    final item = liveReceipt.items.cast<SaleItem?>().firstWhere(
      (i) => i?.id == saleItemId,
      orElse: () => null,
    );
    if (item == null) {
      throw RecordNotFoundException('SaleItem', saleItemId);
    }

    if (returnQuantity <= 0) {
      throw ValidationException('Return quantity must be at least 1.');
    }

    final maxReturnableQuantity = item.quantity - item.returnedQuantity;
    if (returnQuantity > maxReturnableQuantity) {
      throw ValidationException(
        'Return quantity ($returnQuantity) exceeds remaining unreturned copies ($maxReturnableQuantity) for "${item.bookTitle}".',
      );
    }

    if (refundAmountPaise < 0) {
      throw ValidationException('Refund amount cannot be negative.');
    }

    final remainingRefundablePaise =
        liveReceipt.totalAmountPaise - liveReceipt.refundedAmountPaise;
    if (refundAmountPaise > remainingRefundablePaise) {
      throw ValidationException(
        'Refund amount (₹${(refundAmountPaise / 100.0).toStringAsFixed(2)}) exceeds remaining refundable balance (₹${(remainingRefundablePaise / 100.0).toStringAsFixed(2)}) for Receipt #${liveReceipt.receiptNumber}.',
      );
    }

    final idempotencyKey =
        'sale_return_${receiptId}_${saleItemId}_$clientRequestId';

    String? createdTxId;
    String? createdPaymentId;
    String? createdMovementId;
    bool accountDebited = false;

    return coordinator.runCoordinatedOperation<SaleReceipt>(
      fairId: liveReceipt.fairId,
      operationType: 'sale_return_refund',
      idempotencyKey: idempotencyKey,
      amountPaise: refundAmountPaise,
      primaryEntityId: receiptId,
      secondaryEntityId: saleItemId,
      sourceAccountId: refundAccountId,
      additionalLockKeys: [
        'account:$refundAccountId',
        'book:${item.bookId}',
        'sale:$receiptId',
      ],
      payload: {
        'receiptId': receiptId,
        'saleItemId': saleItemId,
        'returnQuantity': returnQuantity,
        'condition': condition.name,
        'isRestocked': isRestocked,
        'refundAmountPaise': refundAmountPaise,
        'refundAccountId': refundAccountId,
        'reason': reason,
        'clientRequestId': clientRequestId,
      },
      affectedBoxes: [
        db.salesReceipts,
        db.saleItems,
        db.stockMovements,
        db.paymentRecords,
        db.accountTransactions,
        db.cashbookAccounts,
      ],
      executeWrites: (opId) async {
        final freshAcc = cashbookDataSource.getAccountById(refundAccountId);
        if (freshAcc == null) {
          throw RecordNotFoundException('CashbookAccount', refundAccountId);
        }
        if (!freshAcc.isActive) {
          throw ValidationException(
            'Cannot disburse refund from inactive account "${freshAcc.accountName}".',
          );
        }
        if (freshAcc.currentBalancePaise < refundAmountPaise) {
          throw ValidationException(
            'Insufficient funds in account "${freshAcc.accountName}" to issue refund. Available: ₹${(freshAcc.currentBalancePaise / 100.0).toStringAsFixed(2)}, Required: ₹${(refundAmountPaise / 100.0).toStringAsFixed(2)}.',
          );
        }

        // A. Stock Movement for returned title
        if (isRestocked) {
          final movement = StockMovement(
            id: _uuid.v4(),
            fairId: liveReceipt.fairId,
            bookId: item.bookId,
            quantity: returnQuantity,
            movementType: StockMovementType.customerReturnIn,
            referenceId: receiptId,
            movementDate: DateTime.now(),
            notes:
                'Customer Return (Restocked) from Receipt #${liveReceipt.receiptNumber} • Condition: ${condition.displayName}',
            createdAt: DateTime.now(),
          );
          createdMovementId = movement.id;
          await inventoryDataSource.recordStockMovement(
            StockMovementModel.fromEntity(movement),
          );
        } else {
          final movement = StockMovement(
            id: _uuid.v4(),
            fairId: liveReceipt.fairId,
            bookId: item.bookId,
            quantity: 0,
            movementType: StockMovementType.damaged,
            referenceId: receiptId,
            movementDate: DateTime.now(),
            notes:
                'Customer Return (Damaged / Not Restocked) from Receipt #${liveReceipt.receiptNumber}',
            createdAt: DateTime.now(),
          );
          createdMovementId = movement.id;
          await inventoryDataSource.recordStockMovement(
            StockMovementModel.fromEntity(movement),
          );
        }

        // B. Payment Record (Refund disbursement)
        final refundPayment = PaymentRecord(
          id: _uuid.v4(),
          fairId: liveReceipt.fairId,
          amountPaise: refundAmountPaise,
          paymentMethod: freshAcc.accountType,
          paymentDate: DateTime.now(),
          accountId: refundAccountId,
          relatedEntityType: 'sale',
          relatedEntityId: receiptId,
          notes:
              'Customer return refund ($returnQuantity copy/copies of "${item.bookTitle}"): $reason',
          createdAt: DateTime.now(),
        );
        createdPaymentId = refundPayment.id;
        await paymentDataSource.savePayment(
          PaymentRecordModel.fromEntity(refundPayment),
        );

        // C. Account Transaction (Outflow)
        final tx = AccountTransaction(
          id: _uuid.v4(),
          fairId: liveReceipt.fairId,
          accountId: refundAccountId,
          transactionType: 'sale_refund',
          direction: 'outflow',
          amountPaise: refundAmountPaise,
          transactionDate: DateTime.now(),
          referenceType: 'sale_receipt',
          referenceId: receiptId,
          description:
              'Refund for Receipt #${liveReceipt.receiptNumber} (${item.bookTitle})',
          createdAt: DateTime.now(),
        );
        createdTxId = tx.id;
        await cashbookDataSource.saveTransaction(
          AccountTransactionModel.fromEntity(tx),
        );

        // Debit account
        final updatedAcc = freshAcc.toEntity().copyWith(
          currentBalancePaise: freshAcc.currentBalancePaise - refundAmountPaise,
          updatedAt: DateTime.now(),
        );
        await cashbookDataSource.saveAccount(
          CashbookAccountModel.fromEntity(updatedAcc),
        );
        accountDebited = true;

        // D. Update SaleItem
        final updatedItem = item.copyWith(
          returnedQuantity: item.returnedQuantity + returnQuantity,
        );
        await salesDataSource.updateSaleItem(
          SaleItemModel.fromEntity(updatedItem),
        );

        // E. Update SaleReceipt
        final newTotalRefunded =
            liveReceipt.refundedAmountPaise + refundAmountPaise;
        final newStatus = newTotalRefunded >= liveReceipt.totalAmountPaise
            ? 'fully_refunded'
            : 'partially_refunded';

        final existingReturns = () {
          try {
            return jsonDecode(liveReceipt.returnsJson) as List<dynamic>;
          } catch (_) {
            return <dynamic>[];
          }
        }();

        final returnEntry = {
          'returnId': _uuid.v4(),
          'saleItemId': saleItemId,
          'bookTitle': item.bookTitle,
          'returnQuantity': returnQuantity,
          'condition': condition.name,
          'isRestocked': isRestocked,
          'refundAmountPaise': refundAmountPaise,
          'refundAccountId': refundAccountId,
          'reason': reason,
          'timestamp': DateTime.now().toIso8601String(),
        };
        final updatedReturnsJson = jsonEncode([
          ...existingReturns,
          returnEntry,
        ]);

        final updatedReceipt = liveReceipt.copyWith(
          refundedAmountPaise: newTotalRefunded,
          paymentStatus: newStatus,
          returnsJson: updatedReturnsJson,
        );
        await salesDataSource.updateReceipt(
          SaleReceiptModel.fromEntity(updatedReceipt),
        );

        // Audit Log
        try {
          await activityLogRepo.logEvent(
            ActivityLog(
              id: _uuid.v4(),
              fairId: liveReceipt.fairId,
              title: 'Customer Return Processed',
              subtitle:
                  'Receipt #${liveReceipt.receiptNumber} • $returnQuantity copy/copies of ${item.bookTitle}',
              amount: CurrencyFormatter.format(refundAmountPaise / 100.0),
              type: ActivityLogType.paymentRecorded,
              timestamp: DateTime.now(),
            ),
          );
        } catch (_) {}

        return updatedReceipt;
      },
      rollbackWrites: (opId) async {
        if (createdTxId != null) {
          try {
            final tx = cashbookDataSource.getTransactionById(createdTxId!);
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
                description: '[VOID_ABANDONED: op=$opId] ${tx.description}',
                createdAtEpoch: tx.createdAtEpoch,
              );
              await cashbookDataSource.saveTransaction(voided);
            }
          } catch (_) {}
        }

        if (createdPaymentId != null) {
          try {
            final p = paymentDataSource.getPaymentById(createdPaymentId!);
            if (p != null) {
              final voided = PaymentRecordModel(
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
                notes: '[VOID_ABANDONED: op=$opId] ${p.notes}',
                createdAtEpoch: p.createdAtEpoch,
              );
              await paymentDataSource.savePayment(voided);
            }
          } catch (_) {}
        }

        if (accountDebited) {
          try {
            final curAcc = cashbookDataSource.getAccountById(refundAccountId);
            if (curAcc != null) {
              final restored = curAcc.toEntity().copyWith(
                currentBalancePaise:
                    curAcc.currentBalancePaise + refundAmountPaise,
                updatedAt: DateTime.now(),
              );
              await cashbookDataSource.saveAccount(
                CashbookAccountModel.fromEntity(restored),
              );
            }
          } catch (_) {}
        }

        if (createdMovementId != null) {
          try {
            await db.stockMovements.delete(createdMovementId!);
          } catch (_) {}
        }
      },
      validateInvariants: () {},
      onAlreadyCommitted: (existingOp) async {
        return (await getReceiptById(receiptId)) ?? liveReceipt;
      },
    );
  }

  @override
  Stream<List<SaleReceipt>> watchReceipts({String? fairId}) {
    return salesDataSource.watchReceipts(fairId: fairId).asyncMap((
      models,
    ) async {
      final list = <SaleReceipt>[];
      for (final m in models) {
        final itemModels = await salesDataSource.getItemsForReceipt(m.id);
        list.add(
          m.toEntity(items: itemModels.map((i) => i.toEntity()).toList()),
        );
      }
      return list;
    });
  }
}
