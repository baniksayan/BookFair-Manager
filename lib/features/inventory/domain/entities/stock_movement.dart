import 'package:flutter/foundation.dart';

/// Classifies inventory movements for immutable stock audit trail tracking.
enum StockMovementType {
  openingStock,
  purchaseIn,
  partnerContributionIn,
  saleOut,
  customerReturnIn,
  supplierReturnOut,
  damaged,
  lost,
  manualAdjustment,
  transferIn,
  transferOut;

  String get displayName {
    switch (this) {
      case StockMovementType.openingStock:
        return 'Opening Stock';
      case StockMovementType.purchaseIn:
        return 'Purchase In';
      case StockMovementType.partnerContributionIn:
        return 'Partner Contribution In';
      case StockMovementType.saleOut:
        return 'Sale Out';
      case StockMovementType.customerReturnIn:
        return 'Customer Return In';
      case StockMovementType.supplierReturnOut:
        return 'Supplier Return Out';
      case StockMovementType.damaged:
        return 'Damaged / Written Off';
      case StockMovementType.lost:
        return 'Lost / Missing';
      case StockMovementType.manualAdjustment:
        return 'Manual Adjustment';
      case StockMovementType.transferIn:
        return 'Transfer In';
      case StockMovementType.transferOut:
        return 'Transfer Out';
    }
  }

  /// Whether this movement type intrinsically adds to on-hand physical stock.
  bool get isAddition {
    switch (this) {
      case StockMovementType.openingStock:
      case StockMovementType.purchaseIn:
      case StockMovementType.partnerContributionIn:
      case StockMovementType.customerReturnIn:
      case StockMovementType.transferIn:
        return true;
      case StockMovementType.saleOut:
      case StockMovementType.supplierReturnOut:
      case StockMovementType.damaged:
      case StockMovementType.lost:
      case StockMovementType.transferOut:
        return false;
      case StockMovementType.manualAdjustment:
        // Manual adjustment can be positive or negative depending on signed quantity
        return true;
    }
  }

  static StockMovementType fromString(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'openingstock':
      case 'opening stock':
        return StockMovementType.openingStock;
      case 'purchasein':
      case 'purchase in':
        return StockMovementType.purchaseIn;
      case 'partnercontributionin':
      case 'partner contribution in':
        return StockMovementType.partnerContributionIn;
      case 'saleout':
      case 'sale out':
        return StockMovementType.saleOut;
      case 'customerreturnin':
      case 'customer return in':
        return StockMovementType.customerReturnIn;
      case 'supplierreturnout':
      case 'supplier return out':
        return StockMovementType.supplierReturnOut;
      case 'damaged':
      case 'damaged / written off':
        return StockMovementType.damaged;
      case 'lost':
      case 'lost / missing':
        return StockMovementType.lost;
      case 'manualadjustment':
      case 'manual adjustment':
        return StockMovementType.manualAdjustment;
      case 'transferin':
      case 'transfer in':
        return StockMovementType.transferIn;
      case 'transferout':
      case 'transfer out':
        return StockMovementType.transferOut;
      default:
        return StockMovementType.manualAdjustment;
    }
  }
}

/// Domain entity representing a discrete stock ledger movement event.
@immutable
class StockMovement {
  const StockMovement({
    required this.id,
    required this.fairId,
    required this.bookId,
    required this.quantity,
    required this.movementType,
    this.referenceId,
    required this.movementDate,
    this.notes = '',
    required this.createdAt,
  });

  final String id;
  final String fairId;
  final String bookId;

  /// Quantity moved. For manual adjustments, positive represents increase, negative represents decrease.
  final int quantity;

  final StockMovementType movementType;
  final String? referenceId;
  final DateTime movementDate;
  final String notes;
  final DateTime createdAt;

  /// Effective signed delta applied to physical available inventory.
  int get netDelta {
    if (movementType == StockMovementType.manualAdjustment) {
      return quantity;
    }
    return movementType.isAddition ? quantity.abs() : -quantity.abs();
  }

  StockMovement copyWith({
    String? id,
    String? fairId,
    String? bookId,
    int? quantity,
    StockMovementType? movementType,
    String? referenceId,
    DateTime? movementDate,
    String? notes,
    DateTime? createdAt,
  }) {
    return StockMovement(
      id: id ?? this.id,
      fairId: fairId ?? this.fairId,
      bookId: bookId ?? this.bookId,
      quantity: quantity ?? this.quantity,
      movementType: movementType ?? this.movementType,
      referenceId: referenceId ?? this.referenceId,
      movementDate: movementDate ?? this.movementDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StockMovement &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
