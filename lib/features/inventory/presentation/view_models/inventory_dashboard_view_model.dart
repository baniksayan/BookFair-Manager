import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/book.dart';
import '../../domain/entities/purchase_batch.dart';
import 'inventory_providers.dart';

/// Aggregated metrics state for the Inventory Dashboard.
class InventoryDashboardSummary {
  const InventoryDashboardSummary({
    this.totalUniqueTitles = 0,
    this.totalPhysicalCopies = 0,
    this.totalPurchaseValuePaise = 0,
    this.currentStockValuationPaise = 0,
    this.lowStockBooks = const [],
    this.outOfStockBooks = const [],
    this.recentBatches = const [],
  });

  final int totalUniqueTitles;
  final int totalPhysicalCopies;
  final int totalPurchaseValuePaise;
  final int currentStockValuationPaise;
  final List<BookStockInfo> lowStockBooks;
  final List<BookStockInfo> outOfStockBooks;
  final List<PurchaseBatch> recentBatches;

  double get totalPurchaseValue => totalPurchaseValuePaise / 100.0;
  double get currentStockValuation => currentStockValuationPaise / 100.0;
}

class BookStockInfo {
  const BookStockInfo({required this.book, required this.availableStock});

  final Book book;
  final int availableStock;
}

/// Computes live aggregated inventory metrics from Hive reactive streams.
final inventoryDashboardSummaryProvider =
    Provider.family<AsyncValue<InventoryDashboardSummary>, String?>((
      ref,
      fairId,
    ) {
      final booksAsync = ref.watch(booksStreamProvider(fairId));
      final batchesAsync = ref.watch(purchaseBatchesStreamProvider(fairId));

      if (booksAsync.isLoading || batchesAsync.isLoading) {
        return const AsyncValue.loading();
      }

      if (booksAsync.hasError) {
        return AsyncValue.error(booksAsync.error!, booksAsync.stackTrace!);
      }
      if (batchesAsync.hasError) {
        return AsyncValue.error(batchesAsync.error!, batchesAsync.stackTrace!);
      }

      final books = booksAsync.value ?? [];
      final batches = batchesAsync.value ?? [];

      // We build synchronous initial metrics from books and batches
      var totalCopies = 0;
      var totalPurchasePaise = 0;
      final lowStock = <BookStockInfo>[];
      final outOfStock = <BookStockInfo>[];

      // Sum acquisition costs from all purchase batches
      for (final batch in batches) {
        totalPurchasePaise += batch.totalAcquisitionCostPaise;
      }

      // Include opening costs
      for (final b in books) {
        if (b.isPreviousStock && b.openingStockQuantity > 0) {
          totalPurchasePaise +=
              (b.openingStockQuantity * (b.estimatedCostPaise ?? 0));
        }
      }

      final summary = InventoryDashboardSummary(
        totalUniqueTitles: books.length,
        totalPhysicalCopies: totalCopies,
        totalPurchaseValuePaise: totalPurchasePaise,
        currentStockValuationPaise: totalPurchasePaise, // baseline valuation
        lowStockBooks: lowStock,
        outOfStockBooks: outOfStock,
        recentBatches: batches.take(5).toList(),
      );

      return AsyncValue.data(summary);
    });
