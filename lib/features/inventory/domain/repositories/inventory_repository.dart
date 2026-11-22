import '../entities/book.dart';
import '../entities/purchase_batch.dart';
import '../entities/purchase_item.dart';
import '../entities/stock_movement.dart';
import '../entities/supplier.dart';

/// Domain contract defining inventory, purchasing, supplier, and stock ledger operations.
abstract interface class InventoryRepository {
  // --- Book Operations ---
  Future<List<Book>> getAllBooks({String? fairId});
  Future<Book?> getBookById(String id);
  Future<void> addBook(Book book);
  Future<void> updateBook(Book book);
  Future<void> deleteBook(String id);
  Stream<List<Book>> watchBooks({String? fairId});

  // --- Purchase Batch Operations ---
  Future<List<PurchaseBatch>> getAllPurchaseBatches({String? fairId});
  Future<PurchaseBatch?> getPurchaseBatchById(String id);
  Future<List<PurchaseItem>> getItemsForBatch(String batchId);
  Future<void> createPurchaseBatch({
    required PurchaseBatch batch,
    required List<PurchaseItem> items,
  });
  Stream<List<PurchaseBatch>> watchPurchaseBatches({String? fairId});

  // --- Stock Movement Ledger Operations ---
  Future<List<StockMovement>> getAllStockMovements({
    String? fairId,
    String? bookId,
  });
  Future<void> recordStockMovement(StockMovement movement);
  Stream<List<StockMovement>> watchStockMovements({
    String? fairId,
    String? bookId,
  });
  Future<int> getAvailableStockForBook(String bookId);

  // --- Supplier Operations ---
  Future<List<Supplier>> getAllSuppliers();
  Future<Supplier?> getSupplierById(String id);
  Future<void> createSupplier(Supplier supplier);
  Future<void> updateSupplier(Supplier supplier);
  Future<void> deleteSupplier(String id);
  Stream<List<Supplier>> watchSuppliers();
}
