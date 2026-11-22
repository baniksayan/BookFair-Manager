import 'dart:async';

import '../../../../core/database/app_database.dart';
import '../models/sale_item_model.dart';
import '../models/sale_receipt_model.dart';

/// Contract for offline Hive operations on sales receipts and items.
abstract interface class SalesLocalDataSource {
  Future<List<SaleReceiptModel>> getAllReceipts({String? fairId});
  Future<SaleReceiptModel?> getReceiptById(String id);
  Future<List<SaleItemModel>> getItemsForReceipt(String receiptId);
  Future<void> createReceipt({
    required SaleReceiptModel receipt,
    required List<SaleItemModel> items,
  });
  Future<void> updateReceipt(SaleReceiptModel receipt);
  Future<void> updateSaleItem(SaleItemModel item);
  Future<void> deleteReceipt(String id);
  Stream<List<SaleReceiptModel>> watchReceipts({String? fairId});
}

/// Hive implementation of [SalesLocalDataSource].
class SalesLocalDataSourceImpl implements SalesLocalDataSource {
  const SalesLocalDataSourceImpl(this._db);

  final AppDatabase _db;

  @override
  Future<List<SaleReceiptModel>> getAllReceipts({String? fairId}) async {
    var receipts = _db.salesReceipts.values.toList();
    if (fairId != null && fairId.isNotEmpty) {
      receipts = receipts.where((r) => r.fairId == fairId).toList();
    }
    receipts.sort((a, b) => b.createdAtEpoch.compareTo(a.createdAtEpoch));
    return receipts;
  }

  @override
  Future<SaleReceiptModel?> getReceiptById(String id) async {
    return _db.salesReceipts.get(id);
  }

  @override
  Future<List<SaleItemModel>> getItemsForReceipt(String receiptId) async {
    final items = _db.saleItems.values
        .where((i) => i.receiptId == receiptId)
        .toList();
    items.sort((a, b) => a.createdAtEpoch.compareTo(b.createdAtEpoch));
    return items;
  }

  @override
  Future<void> createReceipt({
    required SaleReceiptModel receipt,
    required List<SaleItemModel> items,
  }) async {
    await _db.salesReceipts.put(receipt.id, receipt);
    final map = {for (final item in items) item.id: item};
    await _db.saleItems.putAll(map);
  }

  @override
  Future<void> updateReceipt(SaleReceiptModel receipt) async {
    await _db.salesReceipts.put(receipt.id, receipt);
  }

  @override
  Future<void> updateSaleItem(SaleItemModel item) async {
    await _db.saleItems.put(item.id, item);
  }

  @override
  Future<void> deleteReceipt(String id) async {
    await _db.salesReceipts.delete(id);
    final itemIds = _db.saleItems.values
        .where((i) => i.receiptId == id)
        .map((i) => i.id)
        .toList();
    await _db.saleItems.deleteAll(itemIds);
  }

  @override
  Stream<List<SaleReceiptModel>> watchReceipts({String? fairId}) {
    final controller = StreamController<List<SaleReceiptModel>>();

    List<SaleReceiptModel> sorted() {
      var all = _db.salesReceipts.values.toList();
      if (fairId != null && fairId.isNotEmpty) {
        all = all.where((r) => r.fairId == fairId).toList();
      }
      all.sort((a, b) => b.createdAtEpoch.compareTo(a.createdAtEpoch));
      return all;
    }

    controller.add(sorted());

    final sub = _db.salesReceipts.watch().listen((_) {
      if (!controller.isClosed) {
        controller.add(sorted());
      }
    });

    controller.onCancel = () => sub.cancel();
    return controller.stream;
  }
}
