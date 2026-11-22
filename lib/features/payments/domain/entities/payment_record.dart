import 'package:flutter/foundation.dart';

/// Supported physical and digital payment rails.
enum PaymentMethod {
  cash,
  upi,
  bankTransfer,
  cheque,
  other;

  String get displayName {
    switch (this) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.upi:
        return 'UPI / QR';
      case PaymentMethod.bankTransfer:
        return 'Bank Transfer';
      case PaymentMethod.cheque:
        return 'Cheque';
      case PaymentMethod.other:
        return 'Other';
    }
  }

  static PaymentMethod fromString(String? val) {
    switch (val?.toLowerCase().trim()) {
      case 'cash':
        return PaymentMethod.cash;
      case 'upi':
      case 'upi / qr':
      case 'gpay':
      case 'phonepe':
        return PaymentMethod.upi;
      case 'bank':
      case 'bank transfer':
      case 'neft':
      case 'rtgs':
      case 'imps':
        return PaymentMethod.bankTransfer;
      case 'cheque':
      case 'check':
        return PaymentMethod.cheque;
      default:
        return PaymentMethod.other;
    }
  }
}

/// Domain entity representing an audited payment disbursement or receipt transaction.
@immutable
class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.fairId,
    required this.amountPaise,
    required this.paymentMethod,
    required this.paymentDate,
    this.accountId,
    String? payerPartnerId,
    String? paidByPartnerId,
    this.recipientPartnerId,
    this.supplierId,
    this.referenceNumber,
    required this.relatedEntityType,
    required this.relatedEntityId,
    this.notes = '',
    required this.createdAt,
  }) : payerPartnerId = payerPartnerId ?? paidByPartnerId;

  final String id;
  final String fairId;

  /// Exact payment amount in integer paise.
  final int amountPaise;
  final String paymentMethod;
  final DateTime paymentDate;

  /// Business account holding the funds (if paid from or received into business accounts).
  final String? accountId;

  /// Partner who personally financed this payment (creates a reimbursement liability).
  final String? payerPartnerId;

  /// Partner receiving reimbursement or withdrawal.
  final String? recipientPartnerId;

  /// Supplier receiving purchase settlement.
  final String? supplierId;

  /// Offline user-entered reference (e.g. UPI 12-digit ref, cheque number).
  final String? referenceNumber;

  /// Category: 'expense', 'purchase_batch', 'reimbursement', 'investment'
  final String relatedEntityType;

  /// Foreign key of the associated entity (expenseId, batchId, partnerId, etc.).
  final String relatedEntityId;

  final String notes;
  final DateTime createdAt;

  // Convenience currency getters in INR units
  double get amount => amountPaise / 100.0;

  String? get paidByPartnerId => payerPartnerId;
  bool get isPaidByPartner =>
      payerPartnerId != null && payerPartnerId!.isNotEmpty;
  bool get isPaidFromBusinessAccount =>
      accountId != null && accountId!.isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fairId': fairId,
      'amountPaise': amountPaise,
      'paymentMethod': paymentMethod,
      'paymentDate': paymentDate.toIso8601String(),
      'accountId': accountId,
      'payerPartnerId': payerPartnerId,
      'recipientPartnerId': recipientPartnerId,
      'supplierId': supplierId,
      'referenceNumber': referenceNumber,
      'relatedEntityType': relatedEntityType,
      'relatedEntityId': relatedEntityId,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  PaymentRecord copyWith({
    String? id,
    String? fairId,
    int? amountPaise,
    String? paymentMethod,
    DateTime? paymentDate,
    String? accountId,
    String? payerPartnerId,
    String? recipientPartnerId,
    String? supplierId,
    String? referenceNumber,
    String? relatedEntityType,
    String? relatedEntityId,
    String? notes,
    DateTime? createdAt,
  }) {
    return PaymentRecord(
      id: id ?? this.id,
      fairId: fairId ?? this.fairId,
      amountPaise: amountPaise ?? this.amountPaise,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentDate: paymentDate ?? this.paymentDate,
      accountId: accountId ?? this.accountId,
      payerPartnerId: payerPartnerId ?? this.payerPartnerId,
      recipientPartnerId: recipientPartnerId ?? this.recipientPartnerId,
      supplierId: supplierId ?? this.supplierId,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      relatedEntityType: relatedEntityType ?? this.relatedEntityType,
      relatedEntityId: relatedEntityId ?? this.relatedEntityId,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaymentRecord &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
