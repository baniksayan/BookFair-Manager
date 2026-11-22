import 'package:flutter/foundation.dart';

import 'purchase_item.dart';

/// Domain entity representing a vendor acquisition batch containing multiple line items.
@immutable
class PurchaseBatch {
  const PurchaseBatch({
    required this.id,
    required this.fairId,
    this.supplierId,
    required this.purchaseDate,
    this.invoiceNumber,
    this.purchaseReference,
    required this.totalQuantity,
    required this.totalBookCostPaise,
    this.additionalChargesPaise = 0,
    required this.totalAcquisitionCostPaise,
    this.paymentStatus = 'Paid',
    this.paymentMethod = 'Bank Transfer',
    this.notes = '',
    this.items = const [],
    required this.createdAt,
  });

  final String id;
  final String fairId;
  final String? supplierId;
  final DateTime purchaseDate;
  final String? invoiceNumber;
  final String? purchaseReference;
  final int totalQuantity;

  /// Pure sum of book line items costs in integer paise.
  final int totalBookCostPaise;

  /// Ancillary acquisition costs (freight, packaging, transport) in integer paise.
  final int additionalChargesPaise;

  /// Combined overall acquisition investment in integer paise.
  final int totalAcquisitionCostPaise;

  final String paymentStatus;
  final String paymentMethod;
  final String notes;
  final List<PurchaseItem> items;
  final DateTime createdAt;

  // Convenience currency getters in INR units
  double get totalBookCost => totalBookCostPaise / 100.0;
  double get additionalCharges => additionalChargesPaise / 100.0;
  double get totalAcquisitionCost => totalAcquisitionCostPaise / 100.0;

  PurchaseBatch copyWith({
    String? id,
    String? fairId,
    String? supplierId,
    DateTime? purchaseDate,
    String? invoiceNumber,
    String? purchaseReference,
    int? totalQuantity,
    int? totalBookCostPaise,
    int? additionalChargesPaise,
    int? totalAcquisitionCostPaise,
    String? paymentStatus,
    String? paymentMethod,
    String? notes,
    List<PurchaseItem>? items,
    DateTime? createdAt,
  }) {
    return PurchaseBatch(
      id: id ?? this.id,
      fairId: fairId ?? this.fairId,
      supplierId: supplierId ?? this.supplierId,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      purchaseReference: purchaseReference ?? this.purchaseReference,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      totalBookCostPaise: totalBookCostPaise ?? this.totalBookCostPaise,
      additionalChargesPaise:
          additionalChargesPaise ?? this.additionalChargesPaise,
      totalAcquisitionCostPaise:
          totalAcquisitionCostPaise ?? this.totalAcquisitionCostPaise,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PurchaseBatch &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
