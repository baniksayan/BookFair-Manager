import '../../../../core/database/app_database.dart';
import '../models/payment_record_model.dart';

/// Contract for low-level Hive operations on payment disbursement records.
abstract class PaymentLocalDataSource {
  List<PaymentRecordModel> getPayments({
    String? fairId,
    String? relatedEntityType,
    String? relatedEntityId,
  });
  Stream<List<PaymentRecordModel>> watchPayments({
    String? fairId,
    String? relatedEntityType,
    String? relatedEntityId,
  });
  PaymentRecordModel? getPaymentById(String id);
  Future<void> savePayment(PaymentRecordModel payment);
  Future<void> deletePayment(String id);
}

/// Hive implementation of [PaymentLocalDataSource].
class PaymentLocalDataSourceImpl implements PaymentLocalDataSource {
  const PaymentLocalDataSourceImpl(this._db);

  final AppDatabase _db;

  @override
  List<PaymentRecordModel> getPayments({
    String? fairId,
    String? relatedEntityType,
    String? relatedEntityId,
  }) {
    var list = _db.paymentRecords.values.toList();
    if (fairId != null) {
      list = list.where((p) => p.fairId == fairId).toList();
    }
    if (relatedEntityType != null) {
      list = list
          .where((p) => p.relatedEntityType == relatedEntityType)
          .toList();
    }
    if (relatedEntityId != null) {
      list = list.where((p) => p.relatedEntityId == relatedEntityId).toList();
    }
    list.sort((a, b) => b.paymentDateEpoch.compareTo(a.paymentDateEpoch));
    return list;
  }

  @override
  Stream<List<PaymentRecordModel>> watchPayments({
    String? fairId,
    String? relatedEntityType,
    String? relatedEntityId,
  }) async* {
    yield getPayments(
      fairId: fairId,
      relatedEntityType: relatedEntityType,
      relatedEntityId: relatedEntityId,
    );
    yield* _db.paymentRecords.watch().map(
      (_) => getPayments(
        fairId: fairId,
        relatedEntityType: relatedEntityType,
        relatedEntityId: relatedEntityId,
      ),
    );
  }

  @override
  PaymentRecordModel? getPaymentById(String id) {
    try {
      return _db.paymentRecords.values.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> savePayment(PaymentRecordModel payment) async {
    await _db.paymentRecords.put(payment.id, payment);
  }

  @override
  Future<void> deletePayment(String id) async {
    await _db.paymentRecords.delete(id);
  }
}
