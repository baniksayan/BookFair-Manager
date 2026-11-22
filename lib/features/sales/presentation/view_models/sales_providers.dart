import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../book_fairs/presentation/view_models/book_fair_providers.dart';
import '../../../cashbook/presentation/view_models/cashbook_providers.dart';
import '../../../inventory/presentation/view_models/inventory_providers.dart';
import '../../../payments/presentation/view_models/payment_providers.dart';
import '../../data/datasources/sales_local_datasource.dart';
import '../../data/repositories/sale_repository_impl.dart';
import '../../domain/entities/sale_receipt.dart';
import '../../domain/repositories/sale_repository.dart';

/// Provider for [SalesLocalDataSource].
final salesLocalDataSourceProvider = Provider<SalesLocalDataSource>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return SalesLocalDataSourceImpl(db);
});

/// Provider for [SaleRepository].
final saleRepositoryProvider = Provider<SaleRepository>((ref) {
  final salesDs = ref.watch(salesLocalDataSourceProvider);
  final inventoryDs = ref.watch(inventoryLocalDataSourceProvider);
  final cashbookDs = ref.watch(cashbookLocalDataSourceProvider);
  final paymentDs = ref.watch(paymentLocalDataSourceProvider);
  final coordinator = ref.watch(financialOperationCoordinatorProvider);
  final activityRepo = ref.watch(activityLogRepositoryProvider);
  final db = ref.watch(appDatabaseProvider);

  return SaleRepositoryImpl(
    salesDataSource: salesDs,
    inventoryDataSource: inventoryDs,
    cashbookDataSource: cashbookDs,
    paymentDataSource: paymentDs,
    coordinator: coordinator,
    activityLogRepo: activityRepo,
    db: db,
  );
});

/// Stream of all sales receipts, optionally filtered by fairId.
final salesReceiptsStreamProvider =
    StreamProvider.family<List<SaleReceipt>, String?>((ref, fairId) {
      final repo = ref.watch(saleRepositoryProvider);
      return repo.watchReceipts(fairId: fairId);
    });

/// Provider for fetching a single receipt with its itemized lines.
final saleReceiptDetailsProvider = FutureProvider.family<SaleReceipt?, String>((
  ref,
  receiptId,
) async {
  final repo = ref.watch(saleRepositoryProvider);
  return repo.getReceiptById(receiptId);
});
