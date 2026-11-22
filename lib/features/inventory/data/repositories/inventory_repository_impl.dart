import 'package:uuid/uuid.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../book_fairs/domain/entities/activity_log.dart';
import '../../../book_fairs/domain/repositories/activity_log_repository.dart';
import '../../domain/entities/book.dart';
import '../../domain/entities/purchase_batch.dart';
import '../../domain/entities/purchase_item.dart';
import '../../domain/entities/stock_movement.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../../domain/services/inventory_cost_calculator.dart';
import '../datasources/inventory_local_datasource.dart';
import '../models/book_model.dart';
import '../models/purchase_batch_model.dart';
import '../models/purchase_item_model.dart';
import '../models/stock_movement_model.dart';
import '../models/supplier_model.dart';

/// Concrete implementation of [InventoryRepository] backed by Hive local persistence.
class InventoryRepositoryImpl implements InventoryRepository {
  InventoryRepositoryImpl(this._dataSource, this._activityLogRepo);

  final InventoryLocalDataSource _dataSource;
  final ActivityLogRepository _activityLogRepo;
  final _uuid = const Uuid();

  // --- Book Operations ---

  @override
  Future<List<Book>> getAllBooks({String? fairId}) async {
    final models = await _dataSource.getAllBooks(fairId: fairId);
    final entities = models.map((m) => m.toEntity()).toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return entities;
  }

  @override
  Future<Book?> getBookById(String id) async {
    final model = await _dataSource.getBookById(id);
    return model?.toEntity();
  }

  @override
  Future<void> addBook(Book book) async {
    final model = BookModel.fromEntity(book);
    await _dataSource.createBook(model);

    // If opening stock was registered, create initial opening stock movement
    if (book.isPreviousStock && book.openingStockQuantity > 0) {
      final movement = StockMovement(
        id: _uuid.v4(),
        fairId: book.fairId,
        bookId: book.id,
        quantity: book.openingStockQuantity,
        movementType: StockMovementType.openingStock,
        movementDate: book.createdAt,
        notes: 'Initial opening / previous stock registration',
        createdAt: book.createdAt,
      );
      await _dataSource.recordStockMovement(
        StockMovementModel.fromEntity(movement),
      );

      await _activityLogRepo.logEvent(
        ActivityLog(
          id: _uuid.v4(),
          fairId: book.fairId,
          title: 'Previous Stock Registered',
          subtitle: '${book.title} (${book.openingStockQuantity} copies)',
          amount: '${book.openingStockQuantity} copies',
          type: ActivityLogType.previousStockRegistered,
          timestamp: DateTime.now(),
        ),
      );
    } else {
      await _activityLogRepo.logEvent(
        ActivityLog(
          id: _uuid.v4(),
          fairId: book.fairId,
          title: 'Book Added',
          subtitle: '${book.title} by ${book.author}',
          amount: CurrencyFormatter.format(book.mrp),
          type: ActivityLogType.bookAdded,
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  @override
  Future<void> updateBook(Book book) async {
    final updated = book.copyWith(updatedAt: DateTime.now());
    await _dataSource.updateBook(BookModel.fromEntity(updated));

    await _activityLogRepo.logEvent(
      ActivityLog(
        id: _uuid.v4(),
        fairId: book.fairId,
        title: 'Book Updated',
        subtitle: '${book.title} catalogue entry revised',
        amount: CurrencyFormatter.format(book.defaultSellingPrice),
        type: ActivityLogType.bookUpdated,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> deleteBook(String id) async {
    await _dataSource.deleteBook(id);
  }

  @override
  Stream<List<Book>> watchBooks({String? fairId}) {
    return _dataSource.watchBooks(fairId: fairId).map((models) {
      final list = models.map((m) => m.toEntity()).toList()
        ..sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
      return list;
    });
  }

  // --- Purchase Batch Operations ---

  @override
  Future<List<PurchaseBatch>> getAllPurchaseBatches({String? fairId}) async {
    final models = await _dataSource.getAllPurchaseBatches(fairId: fairId);
    final entities = <PurchaseBatch>[];
    for (final m in models) {
      final itemModels = await _dataSource.getItemsForBatch(m.id);
      entities.add(
        m.toEntity(items: itemModels.map((i) => i.toEntity()).toList()),
      );
    }
    return entities;
  }

  @override
  Future<PurchaseBatch?> getPurchaseBatchById(String id) async {
    final model = await _dataSource.getPurchaseBatchById(id);
    if (model == null) return null;
    final itemModels = await _dataSource.getItemsForBatch(id);
    return model.toEntity(items: itemModels.map((i) => i.toEntity()).toList());
  }

  @override
  Future<List<PurchaseItem>> getItemsForBatch(String batchId) async {
    final models = await _dataSource.getItemsForBatch(batchId);
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<void> createPurchaseBatch({
    required PurchaseBatch batch,
    required List<PurchaseItem> items,
  }) async {
    final batchModel = PurchaseBatchModel.fromEntity(batch);
    final itemModels = items
        .map((i) => PurchaseItemModel.fromEntity(i))
        .toList();

    // Persist batch and line items
    await _dataSource.createPurchaseBatch(batch: batchModel, items: itemModels);

    // Create a PurchaseIn stock movement for every purchased book item
    for (final item in items) {
      final movement = StockMovement(
        id: _uuid.v4(),
        fairId: batch.fairId,
        bookId: item.bookId,
        quantity: item.quantity,
        movementType: StockMovementType.purchaseIn,
        referenceId: batch.id,
        movementDate: batch.purchaseDate,
        notes:
            'Acquired via Purchase Batch #${batch.invoiceNumber ?? batch.id}',
        createdAt: batch.createdAt,
      );
      await _dataSource.recordStockMovement(
        StockMovementModel.fromEntity(movement),
      );
    }

    // Record activity audit log
    await _activityLogRepo.logEvent(
      ActivityLog(
        id: _uuid.v4(),
        fairId: batch.fairId,
        title: 'Purchase Batch Created',
        subtitle:
            '${batch.totalQuantity} books acquired across ${items.length} titles',
        amount: CurrencyFormatter.format(batch.totalAcquisitionCost),
        type: ActivityLogType.purchaseBatchCreated,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  Stream<List<PurchaseBatch>> watchPurchaseBatches({String? fairId}) {
    return _dataSource.watchPurchaseBatches(fairId: fairId).asyncMap((
      models,
    ) async {
      final list = <PurchaseBatch>[];
      for (final m in models) {
        final itemModels = await _dataSource.getItemsForBatch(m.id);
        list.add(
          m.toEntity(items: itemModels.map((i) => i.toEntity()).toList()),
        );
      }
      return list;
    });
  }

  // --- Stock Movement Operations ---

  @override
  Future<List<StockMovement>> getAllStockMovements({
    String? fairId,
    String? bookId,
  }) async {
    final models = await _dataSource.getAllStockMovements(
      fairId: fairId,
      bookId: bookId,
    );
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<void> recordStockMovement(StockMovement movement) async {
    final model = StockMovementModel.fromEntity(movement);
    await _dataSource.recordStockMovement(model);

    await _activityLogRepo.logEvent(
      ActivityLog(
        id: _uuid.v4(),
        fairId: movement.fairId,
        title: movement.movementType.displayName,
        subtitle: movement.notes.isNotEmpty ? movement.notes : 'Stock adjusted',
        amount: '${movement.quantity > 0 ? '+' : ''}${movement.quantity} qty',
        type: ActivityLogType.stockAdjusted,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  Stream<List<StockMovement>> watchStockMovements({
    String? fairId,
    String? bookId,
  }) {
    return _dataSource
        .watchStockMovements(fairId: fairId, bookId: bookId)
        .map((models) => models.map((m) => m.toEntity()).toList());
  }

  @override
  Future<int> getAvailableStockForBook(String bookId) async {
    final movements = await _dataSource.getAllStockMovements(bookId: bookId);
    final entities = movements.map((m) => m.toEntity()).toList();
    return InventoryCostCalculator.calculateAvailableStock(entities);
  }

  // --- Supplier Operations ---

  @override
  Future<List<Supplier>> getAllSuppliers() async {
    final models = await _dataSource.getAllSuppliers();
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<Supplier?> getSupplierById(String id) async {
    final model = await _dataSource.getSupplierById(id);
    return model?.toEntity();
  }

  @override
  Future<void> createSupplier(Supplier supplier) async {
    final model = SupplierModel.fromEntity(supplier);
    await _dataSource.createSupplier(model);

    await _activityLogRepo.logEvent(
      ActivityLog(
        id: _uuid.v4(),
        title: 'Supplier Added',
        subtitle: supplier.name,
        amount: 'Vendor Partner',
        type: ActivityLogType.supplierAdded,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> updateSupplier(Supplier supplier) async {
    final updated = supplier.copyWith(updatedAt: DateTime.now());
    await _dataSource.updateSupplier(SupplierModel.fromEntity(updated));
  }

  @override
  Future<void> deleteSupplier(String id) async {
    await _dataSource.deleteSupplier(id);
  }

  @override
  Stream<List<Supplier>> watchSuppliers() {
    return _dataSource.watchSuppliers().map((models) {
      return models.map((m) => m.toEntity()).toList();
    });
  }
}
