import 'package:flutter/foundation.dart';

enum ContributionType {
  cash,
  online,
  bookInventory,
  equipment,
  other;

  String get displayName {
    switch (this) {
      case ContributionType.cash:
        return 'Cash Contribution';
      case ContributionType.online:
        return 'Online Contribution';
      case ContributionType.bookInventory:
        return 'Book Inventory Contribution';
      case ContributionType.equipment:
        return 'Equipment Contribution';
      case ContributionType.other:
        return 'Other Contribution';
    }
  }

  static ContributionType fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'cash':
        return ContributionType.cash;
      case 'online':
        return ContributionType.online;
      case 'bookinventory':
      case 'book inventory':
        return ContributionType.bookInventory;
      case 'equipment':
        return ContributionType.equipment;
      case 'other':
      default:
        return ContributionType.other;
    }
  }
}

enum PaymentMethod {
  cash,
  upi,
  bankTransfer,
  other;

  String get displayName {
    switch (this) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.upi:
        return 'UPI';
      case PaymentMethod.bankTransfer:
        return 'Bank Transfer';
      case PaymentMethod.other:
        return 'Other';
    }
  }

  static PaymentMethod fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'cash':
        return PaymentMethod.cash;
      case 'upi':
        return PaymentMethod.upi;
      case 'banktransfer':
      case 'bank transfer':
        return PaymentMethod.bankTransfer;
      case 'other':
      default:
        return PaymentMethod.other;
    }
  }
}

/// Domain entity representing an individual capital or in-kind investment contribution transaction.
@immutable
class Investment {
  const Investment({
    required this.id,
    required this.fairId,
    required this.partnerId,
    required this.amountPaise,
    required this.contributionType,
    required this.paymentMethod,
    required this.contributionDate,
    this.referenceNumber,
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String fairId;
  final String partnerId;

  /// Stored as exact integer paise (1 INR = 100 paise) to prevent floating-point inaccuracies.
  final int amountPaise;

  /// Convenience monetary amount in INR units
  double get amount => amountPaise / 100.0;

  final ContributionType contributionType;
  final PaymentMethod paymentMethod;
  final DateTime contributionDate;
  final String? referenceNumber;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Investment copyWith({
    String? id,
    String? fairId,
    String? partnerId,
    int? amountPaise,
    ContributionType? contributionType,
    PaymentMethod? paymentMethod,
    DateTime? contributionDate,
    String? referenceNumber,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Investment(
      id: id ?? this.id,
      fairId: fairId ?? this.fairId,
      partnerId: partnerId ?? this.partnerId,
      amountPaise: amountPaise ?? this.amountPaise,
      contributionType: contributionType ?? this.contributionType,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      contributionDate: contributionDate ?? this.contributionDate,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
