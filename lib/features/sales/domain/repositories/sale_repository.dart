import '../../../inventory/domain/entities/book.dart';
import '../../../payments/domain/entities/payment_record.dart';
import '../entities/sale_item.dart';
import '../entities/sale_receipt.dart';

/// Domain contract defining POS sales checkout, customer returns, and receipt retrieval.
abstract interface class SaleRepository {
  Future<List<SaleReceipt>> getAllReceipts({String? fairId});
  Future<SaleReceipt?> getReceiptById(String id);
  Future<List<SaleItem>> getItemsForReceipt(String receiptId);

  /// Executes an atomic, durable point-of-sale checkout operation.
  ///
  /// Atomically coordinates:
  /// - Creating [SaleReceipt] and [SaleItem] records.
  /// - Writing [StockMovement] deductions (`saleOut`).
  /// - Logging [PaymentRecord] customer payment receipts.
  /// - Crediting respective [CashbookAccount] balances with `direction: inflow`.
  /// - Journaling via [FinancialOperationCoordinator] under `sales_settlement`.
  Future<SaleReceipt> recordSale({
    required SaleReceipt receipt,
    required List<SaleItem> items,
    required List<PaymentRecord> payments,
    required String clientRequestId,
  });

  /// Processes a receipt-linked customer return with optional restocking and cashbook refund.
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
  });

  Stream<List<SaleReceipt>> watchReceipts({String? fairId});
}
