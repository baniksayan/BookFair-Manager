import 'package:flutter/foundation.dart';

import 'book.dart';

/// Domain entity representing a line item within a purchase batch.
@immutable
class PurchaseItem {
  const PurchaseItem({
    required this.id,
    required this.batchId,
    required this.bookId,
    required this.quantity,
    required this.unitPurchaseCostPaise,
    required this.lineTotalPaise,
    this.condition = BookCondition.brandNew,
    this.notes = '',
  });

  final String id;
  final String batchId;
  final String bookId;
  final int quantity;
  final int unitPurchaseCostPaise;
  final int lineTotalPaise;
  final BookCondition condition;
  final String notes;

  // Convenience getters in currency units (INR)
  double get unitPurchaseCost => unitPurchaseCostPaise / 100.0;
  double get lineTotal => lineTotalPaise / 100.0;

  PurchaseItem copyWith({
    String? id,
    String? batchId,
    String? bookId,
    int? quantity,
    int? unitPurchaseCostPaise,
    int? lineTotalPaise,
    BookCondition? condition,
    String? notes,
  }) {
    return PurchaseItem(
      id: id ?? this.id,
      batchId: batchId ?? this.batchId,
      bookId: bookId ?? this.bookId,
      quantity: quantity ?? this.quantity,
      unitPurchaseCostPaise:
          unitPurchaseCostPaise ?? this.unitPurchaseCostPaise,
      lineTotalPaise: lineTotalPaise ?? this.lineTotalPaise,
      condition: condition ?? this.condition,
      notes: notes ?? this.notes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PurchaseItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
