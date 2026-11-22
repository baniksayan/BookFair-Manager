import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../book_fairs/presentation/view_models/book_fair_providers.dart';
import '../../data/datasources/inventory_local_datasource.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/entities/book.dart';
import '../../domain/entities/purchase_batch.dart';
import '../../domain/entities/stock_movement.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/repositories/inventory_repository.dart';

// --- Data Source Provider ---
final inventoryLocalDataSourceProvider = Provider<InventoryLocalDataSource>((
  ref,
) {
  final db = ref.watch(appDatabaseProvider);
  return InventoryLocalDataSourceImpl(db);
});

// --- Repository Provider ---
final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  final ds = ref.watch(inventoryLocalDataSourceProvider);
  final activityRepo = ref.watch(activityLogRepositoryProvider);
  return InventoryRepositoryImpl(ds, activityRepo);
});

// --- Reactive Streams Providers ---

/// Stream of all active books, optionally filtered by [fairId].
final booksStreamProvider = StreamProvider.family<List<Book>, String?>((
  ref,
  fairId,
) {
  final repo = ref.watch(inventoryRepositoryProvider);
  return repo.watchBooks(fairId: fairId);
});

/// Stream of a specific book by [bookId].
final bookDetailsStreamProvider = StreamProvider.family<Book?, String>((
  ref,
  bookId,
) async* {
  final repo = ref.watch(inventoryRepositoryProvider);
  // Watch all books and yield the match
  await for (final books in repo.watchBooks()) {
    yield books.cast<Book?>().firstWhere(
      (b) => b?.id == bookId,
      orElse: () => null,
    );
  }
});

/// Stream of all purchase batches, optionally filtered by [fairId].
final purchaseBatchesStreamProvider =
    StreamProvider.family<List<PurchaseBatch>, String?>((ref, fairId) {
      final repo = ref.watch(inventoryRepositoryProvider);
      return repo.watchPurchaseBatches(fairId: fairId);
    });

/// Stream of all stock movements for a specific book.
final bookStockMovementsStreamProvider =
    StreamProvider.family<List<StockMovement>, String>((ref, bookId) {
      final repo = ref.watch(inventoryRepositoryProvider);
      return repo.watchStockMovements(bookId: bookId);
    });

/// Stream of all stock movements, optionally filtered by [fairId].
final stockMovementsStreamProvider =
    StreamProvider.family<List<StockMovement>, String?>((ref, fairId) {
      final repo = ref.watch(inventoryRepositoryProvider);
      return repo.watchStockMovements(fairId: fairId);
    });

/// Stream of all suppliers registered in the database.
final suppliersStreamProvider = StreamProvider<List<Supplier>>((ref) {
  final repo = ref.watch(inventoryRepositoryProvider);
  return repo.watchSuppliers();
});
