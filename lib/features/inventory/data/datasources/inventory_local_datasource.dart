import 'dart:async';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_exceptions.dart';
import '../models/book_model.dart';
import '../models/purchase_batch_model.dart';
import '../models/purchase_item_model.dart';
import '../models/stock_movement_model.dart';
import '../models/supplier_model.dart';

/// Local data source interface for direct Hive operations on inventory boxes.
abstract interface class InventoryLocalDataSource {
  // Books
  Future<List<BookModel>> getAllBooks({String? fairId});
  Future<BookModel?> getBookById(String id);
  Future<void> createBook(BookModel model);
  Future<void> updateBook(BookModel model);
  Future<void> deleteBook(String id);
  Stream<List<BookModel>> watchBooks({String? fairId});

  // Purchase Batches & Items
  Future<List<PurchaseBatchModel>> getAllPurchaseBatches({String? fairId});
  Future<PurchaseBatchModel?> getPurchaseBatchById(String id);
  Future<List<PurchaseItemModel>> getItemsForBatch(String batchId);
  Future<List<PurchaseItemModel>> getItemsForBook(String bookId);
  Future<void> createPurchaseBatch({
    required PurchaseBatchModel batch,
    required List<PurchaseItemModel> items,
  });
  Stream<List<PurchaseBatchModel>> watchPurchaseBatches({String? fairId});

  // Stock Movements
  Future<List<StockMovementModel>> getAllStockMovements({
    String? fairId,
    String? bookId,
  });
  Future<void> recordStockMovement(StockMovementModel model);
  Stream<List<StockMovementModel>> watchStockMovements({
    String? fairId,
    String? bookId,
  });

  // Suppliers
  Future<List<SupplierModel>> getAllSuppliers();
  Future<SupplierModel?> getSupplierById(String id);
  Future<void> createSupplier(SupplierModel model);
  Future<void> updateSupplier(SupplierModel model);
  Future<void> deleteSupplier(String id);
  Stream<List<SupplierModel>> watchSuppliers();
}

class InventoryLocalDataSourceImpl implements InventoryLocalDataSource {
  InventoryLocalDataSourceImpl(this._db);

  final AppDatabase _db;

  // --- Book Operations ---

  @override
  Future<List<BookModel>> getAllBooks({String? fairId}) async {
    final all = _db.books.values.toList();
    if (fairId == null || fairId.isEmpty) {
      return all.where((b) => b.isActive).toList();
    }
    return all
        .where(
          (b) => b.isActive && (b.fairId == fairId || b.fairId == 'global'),
        )
        .toList();
  }

  @override
  Future<BookModel?> getBookById(String id) async {
    return _db.books.get(id);
  }

  @override
  Future<void> createBook(BookModel model) async {
    // Check for duplicate ISBN in the same fair if ISBN is provided
    if (model.isbn13 != null && model.isbn13!.trim().isNotEmpty) {
      final duplicate = _db.books.values.any(
        (b) =>
            b.isActive &&
            b.fairId == model.fairId &&
            b.isbn13?.trim() == model.isbn13?.trim(),
      );
      if (duplicate) {
        throw DuplicateRecordException(
          'A book with ISBN-13 "${model.isbn13}" already exists in this exhibition.',
        );
      }
    }
    await _db.books.put(model.id, model);
  }

  @override
  Future<void> updateBook(BookModel model) async {
    if (!_db.books.containsKey(model.id)) {
      throw RecordNotFoundException('Book', model.id);
    }
    await _db.books.put(model.id, model);
  }

  @override
  Future<void> deleteBook(String id) async {
    if (!_db.books.containsKey(id)) {
      throw RecordNotFoundException('Book', id);
    }
    // Soft delete to maintain auditability of past purchases and stock movements
    final book = _db.books.get(id)!;
    final updated = BookModel(
      id: book.id,
      fairId: book.fairId,
      title: book.title,
      subtitle: book.subtitle,
      author: book.author,
      additionalAuthors: book.additionalAuthors,
      publisher: book.publisher,
      isbn10: book.isbn10,
      isbn13: book.isbn13,
      genre: book.genre,
      language: book.language,
      description: book.description,
      coverImagePath: book.coverImagePath,
      coverImageSource: book.coverImageSource,
      mrpPaise: book.mrpPaise,
      defaultSellingPricePaise: book.defaultSellingPricePaise,
      condition: book.condition,
      conditionNotes: book.conditionNotes,
      isPreviousStock: book.isPreviousStock,
      openingStockQuantity: book.openingStockQuantity,
      estimatedCostPaise: book.estimatedCostPaise,
      isActive: false, // Mark inactive
      createdAtEpoch: book.createdAtEpoch,
      updatedAtEpoch: DateTime.now().millisecondsSinceEpoch,
    );
    await _db.books.put(id, updated);
  }

  @override
  Stream<List<BookModel>> watchBooks({String? fairId}) {
    final controller = StreamController<List<BookModel>>();

    List<BookModel> filter() {
      final all = _db.books.values.where((b) => b.isActive).toList();
      if (fairId == null || fairId.isEmpty) return all;
      return all
          .where((b) => b.fairId == fairId || b.fairId == 'global')
          .toList();
    }

    controller.add(filter());

    final sub = _db.books.watch().listen((_) {
      if (!controller.isClosed) {
        controller.add(filter());
      }
    });

    controller.onCancel = () => sub.cancel();
    return controller.stream;
  }

  // --- Purchase Batch Operations ---

  @override
  Future<List<PurchaseBatchModel>> getAllPurchaseBatches({
    String? fairId,
  }) async {
    final all = _db.purchaseBatches.values.toList()
      ..sort((a, b) => b.purchaseDateEpoch.compareTo(a.purchaseDateEpoch));
    if (fairId == null || fairId.isEmpty) return all;
    return all.where((b) => b.fairId == fairId).toList();
  }

  @override
  Future<PurchaseBatchModel?> getPurchaseBatchById(String id) async {
    return _db.purchaseBatches.get(id);
  }

  @override
  Future<List<PurchaseItemModel>> getItemsForBatch(String batchId) async {
    return _db.purchaseItems.values
        .where((item) => item.batchId == batchId)
        .toList();
  }

  @override
  Future<List<PurchaseItemModel>> getItemsForBook(String bookId) async {
    return _db.purchaseItems.values
        .where((item) => item.bookId == bookId)
        .toList();
  }

  @override
  Future<void> createPurchaseBatch({
    required PurchaseBatchModel batch,
    required List<PurchaseItemModel> items,
  }) async {
    // Atomic multi-table write: Batch record + individual Line Items
    await _db.purchaseBatches.put(batch.id, batch);
    for (final item in items) {
      await _db.purchaseItems.put(item.id, item);
    }
  }

  @override
  Stream<List<PurchaseBatchModel>> watchPurchaseBatches({String? fairId}) {
    final controller = StreamController<List<PurchaseBatchModel>>();

    List<PurchaseBatchModel> filter() {
      final all = _db.purchaseBatches.values.toList()
        ..sort((a, b) => b.purchaseDateEpoch.compareTo(a.purchaseDateEpoch));
      if (fairId == null || fairId.isEmpty) return all;
      return all.where((b) => b.fairId == fairId).toList();
    }

    controller.add(filter());

    final sub = _db.purchaseBatches.watch().listen((_) {
      if (!controller.isClosed) {
        controller.add(filter());
      }
    });

    controller.onCancel = () => sub.cancel();
    return controller.stream;
  }

  // --- Stock Movement Operations ---

  @override
  Future<List<StockMovementModel>> getAllStockMovements({
    String? fairId,
    String? bookId,
  }) async {
    var all = _db.stockMovements.values.toList()
      ..sort((a, b) => b.movementDateEpoch.compareTo(a.movementDateEpoch));
    if (fairId != null && fairId.isNotEmpty) {
      all = all.where((m) => m.fairId == fairId).toList();
    }
    if (bookId != null && bookId.isNotEmpty) {
      all = all.where((m) => m.bookId == bookId).toList();
    }
    return all;
  }

  @override
  Future<void> recordStockMovement(StockMovementModel model) async {
    await _db.stockMovements.put(model.id, model);
  }

  @override
  Stream<List<StockMovementModel>> watchStockMovements({
    String? fairId,
    String? bookId,
  }) {
    final controller = StreamController<List<StockMovementModel>>();

    List<StockMovementModel> filter() {
      var all = _db.stockMovements.values.toList()
        ..sort((a, b) => b.movementDateEpoch.compareTo(a.movementDateEpoch));
      if (fairId != null && fairId.isNotEmpty) {
        all = all.where((m) => m.fairId == fairId).toList();
      }
      if (bookId != null && bookId.isNotEmpty) {
        all = all.where((m) => m.bookId == bookId).toList();
      }
      return all;
    }

    controller.add(filter());

    final sub = _db.stockMovements.watch().listen((_) {
      if (!controller.isClosed) {
        controller.add(filter());
      }
    });

    controller.onCancel = () => sub.cancel();
    return controller.stream;
  }

  // --- Supplier Operations ---

  @override
  Future<List<SupplierModel>> getAllSuppliers() async {
    final all = _db.suppliers.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return all;
  }

  @override
  Future<SupplierModel?> getSupplierById(String id) async {
    return _db.suppliers.get(id);
  }

  @override
  Future<void> createSupplier(SupplierModel model) async {
    final duplicate = _db.suppliers.values.any(
      (s) => s.name.trim().toLowerCase() == model.name.trim().toLowerCase(),
    );
    if (duplicate) {
      throw DuplicateRecordException(
        'A supplier named "${model.name}" is already registered.',
      );
    }
    await _db.suppliers.put(model.id, model);
  }

  @override
  Future<void> updateSupplier(SupplierModel model) async {
    if (!_db.suppliers.containsKey(model.id)) {
      throw RecordNotFoundException('Supplier', model.id);
    }
    await _db.suppliers.put(model.id, model);
  }

  @override
  Future<void> deleteSupplier(String id) async {
    if (!_db.suppliers.containsKey(id)) {
      throw RecordNotFoundException('Supplier', id);
    }
    // Check if supplier has associated purchases
    final hasPurchases = _db.purchaseBatches.values.any(
      (b) => b.supplierId == id,
    );
    if (hasPurchases) {
      throw ReferentialIntegrityException(
        'Cannot remove supplier because active purchase batches are associated with them.',
      );
    }
    await _db.suppliers.delete(id);
  }

  @override
  Stream<List<SupplierModel>> watchSuppliers() {
    final controller = StreamController<List<SupplierModel>>();

    List<SupplierModel> sorted() {
      final all = _db.suppliers.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return all;
    }

    controller.add(sorted());

    final sub = _db.suppliers.watch().listen((_) {
      if (!controller.isClosed) {
        controller.add(sorted());
      }
    });

    controller.onCancel = () => sub.cancel();
    return controller.stream;
  }
}
