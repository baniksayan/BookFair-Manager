import '../../../../core/database/app_database.dart';
import '../models/financial_operation_model.dart';

/// Contract for durable write-ahead journal storage of financial operations.
abstract class FinancialOperationLocalDataSource {
  List<FinancialOperationModel> getAllOperations({String? fairId});
  FinancialOperationModel? getOperationById(String id);
  FinancialOperationModel? getOperationByIdempotencyKey(String idempotencyKey);
  List<FinancialOperationModel> getPendingOperations({String? fairId});
  Future<void> saveOperation(FinancialOperationModel operation);
  Future<void> deleteOperation(String id);
  Future<void> flush();
}

/// Hive implementation of [FinancialOperationLocalDataSource].
class FinancialOperationLocalDataSourceImpl
    implements FinancialOperationLocalDataSource {
  const FinancialOperationLocalDataSourceImpl(this._db);

  final AppDatabase _db;

  @override
  List<FinancialOperationModel> getAllOperations({String? fairId}) {
    final list = _db.financialOperations.values.toList();
    if (fairId != null) {
      return list.where((op) => op.fairId == fairId).toList();
    }
    return list;
  }

  @override
  FinancialOperationModel? getOperationById(String id) {
    try {
      return _db.financialOperations.values.firstWhere((op) => op.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  FinancialOperationModel? getOperationByIdempotencyKey(String idempotencyKey) {
    final matches = _db.financialOperations.values
        .where((op) => op.idempotencyKey == idempotencyKey)
        .toList();
    if (matches.isEmpty) return null;
    // Return the latest attempt
    matches.sort((a, b) => b.attemptNumber.compareTo(a.attemptNumber));
    return matches.first;
  }

  @override
  List<FinancialOperationModel> getPendingOperations({String? fairId}) {
    var list = _db.financialOperations.values.where((op) {
      return op.status == 'prepared' || op.status == 'processing';
    }).toList();
    if (fairId != null) {
      list = list.where((op) => op.fairId == fairId).toList();
    }
    // Sort oldest first so recovery replays in execution order
    list.sort((a, b) => a.createdAtEpoch.compareTo(b.createdAtEpoch));
    return list;
  }

  @override
  Future<void> saveOperation(FinancialOperationModel operation) async {
    await _db.financialOperations.put(operation.id, operation);
  }

  @override
  Future<void> deleteOperation(String id) async {
    await _db.financialOperations.delete(id);
  }

  @override
  Future<void> flush() async {
    await _db.financialOperations.flush();
  }
}
