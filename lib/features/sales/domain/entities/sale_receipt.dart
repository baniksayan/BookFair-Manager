import 'package:flutter/foundation.dart';

import 'sale_item.dart';

/// Domain entity representing a customer point-of-sale receipt.
@immutable
class SaleReceipt {
  const SaleReceipt({
    required this.id,
    required this.receiptNumber,
    required this.fairId,
    this.cashierId,
    this.cashierName = 'Stall Volunteer',
    required this.subtotalAmountPaise,
    this.discountAmountPaise = 0,
    required this.totalAmountPaise,
    this.tenderedAmountPaise,
    this.changeAmountPaise,
    this.paymentStatus = 'paid',
    this.refundedAmountPaise = 0,
    this.customerName,
    this.customerPhone,
    this.notes = '',
    this.isUnverifiedStockSale = false,
    this.isCostProvisional = false,
    this.returnsJson = '[]',
    required this.createdAt,
    this.items = const [],
  });

  final String id;

  /// User-friendly, auditable receipt number (e.g. `RCP-20261122-0001`).
  final String receiptNumber;

  /// Mandatory associated Book Fair identifier.
  final String fairId;

  /// Optional partner ID of the volunteer/cashier who manned the counter.
  final String? cashierId;

  /// Name of the volunteer/cashier.
  final String cashierName;

  /// Sum of all item line totals before receipt-level discount in integer paise.
  final int subtotalAmountPaise;

  /// Receipt-level lump-sum discount in integer paise.
  final int discountAmountPaise;

  /// Net payable amount by customer in integer paise:
  /// `subtotalAmountPaise - discountAmountPaise`.
  final int totalAmountPaise;

  /// For cash transactions: amount handed over by customer in paise (e.g. ₹1,200).
  final int? tenderedAmountPaise;

  /// For cash transactions: change returned to customer in paise (e.g. ₹200).
  final int? changeAmountPaise;

  /// Status: 'paid', 'partially_refunded', 'fully_refunded'.
  final String paymentStatus;

  /// Cumulative refund amount disbursed back to customer in paise.
  final int refundedAmountPaise;

  final String? customerName;
  final String? customerPhone;
  final String notes;

  /// Flag indicating at least one item was sold with authorized negative stock.
  final bool isUnverifiedStockSale;

  /// Flag indicating at least one item had unknown acquisition cost.
  final bool isCostProvisional;

  /// Serialized audit log of customer return / refund events linked to this receipt.
  final String returnsJson;

  final DateTime createdAt;

  /// Itemized line items belonging to this receipt.
  final List<SaleItem> items;

  // Currency getters
  double get subtotal => subtotalAmountPaise / 100.0;
  double get discount => discountAmountPaise / 100.0;
  double get total => totalAmountPaise / 100.0;
  double? get tendered =>
      tenderedAmountPaise != null ? tenderedAmountPaise! / 100.0 : null;
  double? get change =>
      changeAmountPaise != null ? changeAmountPaise! / 100.0 : null;
  double get refundedAmount => refundedAmountPaise / 100.0;

  bool get isFullyRefunded => paymentStatus == 'fully_refunded';
  bool get isPartiallyRefunded => paymentStatus == 'partially_refunded';
  bool get hasRefunds => refundedAmountPaise > 0;

  /// Remaining net revenue retained by business after returns:
  int get netRevenuePaise => totalAmountPaise - refundedAmountPaise;
  double get netRevenue => netRevenuePaise / 100.0;

  /// Total physical units sold in this receipt.
  int get totalQuantity =>
      items.fold<int>(0, (sum, item) => sum + item.quantity);

  /// Net unreturned units sold in this receipt.
  int get netQuantity =>
      items.fold<int>(0, (sum, item) => sum + item.netQuantity);

  /// Total snapshotted Cost of Goods Sold for this receipt.
  int get totalCogsPaise =>
      items.fold<int>(0, (sum, item) => sum + item.lineCogsPaise);
  double get totalCogs => totalCogsPaise / 100.0;

  /// Total realized gross profit for this receipt: `totalAmountPaise - totalCogsPaise`.
  int get totalGrossProfitPaise => totalAmountPaise - totalCogsPaise;
  double get totalGrossProfit => totalGrossProfitPaise / 100.0;

  SaleReceipt copyWith({
    String? id,
    String? receiptNumber,
    String? fairId,
    String? cashierId,
    String? cashierName,
    int? subtotalAmountPaise,
    int? discountAmountPaise,
    int? totalAmountPaise,
    int? tenderedAmountPaise,
    int? changeAmountPaise,
    String? paymentStatus,
    int? refundedAmountPaise,
    String? customerName,
    String? customerPhone,
    String? notes,
    bool? isUnverifiedStockSale,
    bool? isCostProvisional,
    String? returnsJson,
    DateTime? createdAt,
    List<SaleItem>? items,
  }) {
    return SaleReceipt(
      id: id ?? this.id,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      fairId: fairId ?? this.fairId,
      cashierId: cashierId ?? this.cashierId,
      cashierName: cashierName ?? this.cashierName,
      subtotalAmountPaise: subtotalAmountPaise ?? this.subtotalAmountPaise,
      discountAmountPaise: discountAmountPaise ?? this.discountAmountPaise,
      totalAmountPaise: totalAmountPaise ?? this.totalAmountPaise,
      tenderedAmountPaise: tenderedAmountPaise ?? this.tenderedAmountPaise,
      changeAmountPaise: changeAmountPaise ?? this.changeAmountPaise,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      refundedAmountPaise: refundedAmountPaise ?? this.refundedAmountPaise,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      notes: notes ?? this.notes,
      isUnverifiedStockSale:
          isUnverifiedStockSale ?? this.isUnverifiedStockSale,
      isCostProvisional: isCostProvisional ?? this.isCostProvisional,
      returnsJson: returnsJson ?? this.returnsJson,
      createdAt: createdAt ?? this.createdAt,
      items: items ?? this.items,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'receiptNumber': receiptNumber,
      'fairId': fairId,
      'cashierId': cashierId,
      'cashierName': cashierName,
      'subtotalAmountPaise': subtotalAmountPaise,
      'discountAmountPaise': discountAmountPaise,
      'totalAmountPaise': totalAmountPaise,
      'tenderedAmountPaise': tenderedAmountPaise,
      'changeAmountPaise': changeAmountPaise,
      'paymentStatus': paymentStatus,
      'refundedAmountPaise': refundedAmountPaise,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'notes': notes,
      'isUnverifiedStockSale': isUnverifiedStockSale,
      'isCostProvisional': isCostProvisional,
      'returnsJson': returnsJson,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SaleReceipt.fromMap(
    Map<String, dynamic> map, {
    List<SaleItem> items = const [],
  }) {
    return SaleReceipt(
      id: map['id'] as String,
      receiptNumber: map['receiptNumber'] as String,
      fairId: map['fairId'] as String,
      cashierId: map['cashierId'] as String?,
      cashierName: (map['cashierName'] as String?) ?? 'Stall Volunteer',
      subtotalAmountPaise: (map['subtotalAmountPaise'] as num).toInt(),
      discountAmountPaise: (map['discountAmountPaise'] as num?)?.toInt() ?? 0,
      totalAmountPaise: (map['totalAmountPaise'] as num).toInt(),
      tenderedAmountPaise: (map['tenderedAmountPaise'] as num?)?.toInt(),
      changeAmountPaise: (map['changeAmountPaise'] as num?)?.toInt(),
      paymentStatus: (map['paymentStatus'] as String?) ?? 'paid',
      refundedAmountPaise: (map['refundedAmountPaise'] as num?)?.toInt() ?? 0,
      customerName: map['customerName'] as String?,
      customerPhone: map['customerPhone'] as String?,
      notes: (map['notes'] as String?) ?? '',
      isUnverifiedStockSale: map['isUnverifiedStockSale'] as bool? ?? false,
      isCostProvisional: map['isCostProvisional'] as bool? ?? false,
      returnsJson: (map['returnsJson'] as String?) ?? '[]',
      createdAt: DateTime.parse(map['createdAt'] as String),
      items: items,
    );
  }
}
