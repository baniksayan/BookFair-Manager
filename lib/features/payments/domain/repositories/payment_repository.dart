import '../entities/payment_record.dart';

/// Contract for recording, tracking, and allocating monetary settlements.
abstract class PaymentRepository {
  Future<List<PaymentRecord>> getPayments({
    String? fairId,
    String? relatedEntityType,
    String? relatedEntityId,
  });

  Stream<List<PaymentRecord>> watchPayments({
    String? fairId,
    String? relatedEntityType,
    String? relatedEntityId,
  });

  Future<PaymentRecord?> getPaymentById(String id);

  /// Records an audited payment transaction against an expense, purchase, or reimbursement.
  Future<PaymentRecord> recordPayment(
    PaymentRecord payment, {
    String? clientRequestId,
  });

  /// Retrieves all payments personally financed by partners on behalf of the stall.
  Future<List<PaymentRecord>> getPartnerPersonalPayments({
    required String fairId,
    String? partnerId,
  });

  /// Retrieves all reimbursements disbursed back to partners.
  Future<List<PaymentRecord>> getPartnerReimbursements({
    required String fairId,
    String? partnerId,
  });

  /// Retrieves all payments disbursed to vendors/suppliers.
  Future<List<PaymentRecord>> getSupplierPayments({
    required String fairId,
    String? supplierId,
  });

  /// Settles a partner reimbursement from a business holding account.
  ///
  /// Reduces business cash/account balance and records a balanced ledger entry.
  /// Does NOT create a second business expense.
  Future<PaymentRecord> recordPartnerReimbursement({
    required String fairId,
    required String partnerId,
    required int amountPaise,
    required String fromAccountId,
    required String paymentMethod,
    String? referenceNumber,
    String? notes,
    required DateTime paymentDate,
    String? clientRequestId,
  });
}
