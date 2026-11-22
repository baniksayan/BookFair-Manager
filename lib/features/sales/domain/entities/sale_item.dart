import 'package:flutter/foundation.dart';

/// Line item within a finalized or in-progress [SaleReceipt].
@immutable
class SaleItem {
  const SaleItem({
    required this.id,
    required this.receiptId,
    required this.bookId,
    required this.bookTitle,
    this.bookAuthor = '',
    this.isbn,
    this.condition = 'Brand New',
    required this.quantity,
    required this.unitMrpPaise,
    required this.unitSellingPricePaise,
    this.itemDiscountPaise = 0,
    this.allocatedReceiptDiscountPaise = 0,
    required this.lineTotalPaise,
    required this.unitCostPaise,
    required this.lineCogsPaise,
    required this.lineGrossProfitPaise,
    this.isUnverifiedStock = false,
    this.isCostProvisional = false,
    this.overrideAuthorizerId,
    this.overrideReason,
    this.returnedQuantity = 0,
    required this.createdAt,
  });

  final String id;
  final String receiptId;
  final String bookId;
  final String bookTitle;
  final String bookAuthor;
  final String? isbn;
  final String condition;

  /// Number of copies sold in this line item.
  final int quantity;

  /// Maximum Retail Price per unit in paise.
  final int unitMrpPaise;

  /// Agreed selling price per unit in paise (before receipt-level discount allocation).
  final int unitSellingPricePaise;

  /// Item-specific discount amount per copy below MRP in paise.
  final int itemDiscountPaise;

  /// Proportional share of receipt-level general discount allocated to this line item.
  final int allocatedReceiptDiscountPaise;

  /// Net line total payable by the customer in paise:
  /// `(unitSellingPricePaise * quantity) - allocatedReceiptDiscountPaise`
  final int lineTotalPaise;

  /// Permanently snapshotted weighted average acquisition cost per copy at the time of sale.
  /// Never recalculated retroactively by future purchase batches.
  final int unitCostPaise;

  /// Total Cost of Goods Sold for this line: `unitCostPaise * quantity`.
  final int lineCogsPaise;

  /// Realized gross profit in paise: `lineTotalPaise - lineCogsPaise`.
  final int lineGrossProfitPaise;

  /// Flag indicating this item was sold despite insufficient recorded inventory under manager override.
  final bool isUnverifiedStock;

  /// Flag indicating the acquisition cost was unknown at the time of sale (cost & profit are provisional).
  final bool isCostProvisional;

  /// Partner ID of the authorizing manager if sold under negative/unverified stock.
  final String? overrideAuthorizerId;

  /// Justification provided by the manager for selling unverified stock.
  final String? overrideReason;

  /// Number of copies returned by customer post-sale.
  final int returnedQuantity;

  final DateTime createdAt;

  // Currency helpers
  double get unitMrp => unitMrpPaise / 100.0;
  double get unitSellingPrice => unitSellingPricePaise / 100.0;
  double get lineTotal => lineTotalPaise / 100.0;
  double get unitCost => unitCostPaise / 100.0;
  double get lineCogs => lineCogsPaise / 100.0;
  double get lineGrossProfit => lineGrossProfitPaise / 100.0;

  /// Remaining active unreturned quantity.
  int get netQuantity => quantity - returnedQuantity;

  /// Whether this line item is fully returned.
  bool get isFullyReturned => returnedQuantity >= quantity;

  SaleItem copyWith({
    String? id,
    String? receiptId,
    String? bookId,
    String? bookTitle,
    String? bookAuthor,
    String? isbn,
    String? condition,
    int? quantity,
    int? unitMrpPaise,
    int? unitSellingPricePaise,
    int? itemDiscountPaise,
    int? allocatedReceiptDiscountPaise,
    int? lineTotalPaise,
    int? unitCostPaise,
    int? lineCogsPaise,
    int? lineGrossProfitPaise,
    bool? isUnverifiedStock,
    bool? isCostProvisional,
    String? overrideAuthorizerId,
    String? overrideReason,
    int? returnedQuantity,
    DateTime? createdAt,
  }) {
    return SaleItem(
      id: id ?? this.id,
      receiptId: receiptId ?? this.receiptId,
      bookId: bookId ?? this.bookId,
      bookTitle: bookTitle ?? this.bookTitle,
      bookAuthor: bookAuthor ?? this.bookAuthor,
      isbn: isbn ?? this.isbn,
      condition: condition ?? this.condition,
      quantity: quantity ?? this.quantity,
      unitMrpPaise: unitMrpPaise ?? this.unitMrpPaise,
      unitSellingPricePaise:
          unitSellingPricePaise ?? this.unitSellingPricePaise,
      itemDiscountPaise: itemDiscountPaise ?? this.itemDiscountPaise,
      allocatedReceiptDiscountPaise:
          allocatedReceiptDiscountPaise ?? this.allocatedReceiptDiscountPaise,
      lineTotalPaise: lineTotalPaise ?? this.lineTotalPaise,
      unitCostPaise: unitCostPaise ?? this.unitCostPaise,
      lineCogsPaise: lineCogsPaise ?? this.lineCogsPaise,
      lineGrossProfitPaise: lineGrossProfitPaise ?? this.lineGrossProfitPaise,
      isUnverifiedStock: isUnverifiedStock ?? this.isUnverifiedStock,
      isCostProvisional: isCostProvisional ?? this.isCostProvisional,
      overrideAuthorizerId: overrideAuthorizerId ?? this.overrideAuthorizerId,
      overrideReason: overrideReason ?? this.overrideReason,
      returnedQuantity: returnedQuantity ?? this.returnedQuantity,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'receiptId': receiptId,
      'bookId': bookId,
      'bookTitle': bookTitle,
      'bookAuthor': bookAuthor,
      'isbn': isbn,
      'condition': condition,
      'quantity': quantity,
      'unitMrpPaise': unitMrpPaise,
      'unitSellingPricePaise': unitSellingPricePaise,
      'itemDiscountPaise': itemDiscountPaise,
      'allocatedReceiptDiscountPaise': allocatedReceiptDiscountPaise,
      'lineTotalPaise': lineTotalPaise,
      'unitCostPaise': unitCostPaise,
      'lineCogsPaise': lineCogsPaise,
      'lineGrossProfitPaise': lineGrossProfitPaise,
      'isUnverifiedStock': isUnverifiedStock,
      'isCostProvisional': isCostProvisional,
      'overrideAuthorizerId': overrideAuthorizerId,
      'overrideReason': overrideReason,
      'returnedQuantity': returnedQuantity,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      id: map['id'] as String,
      receiptId: map['receiptId'] as String,
      bookId: map['bookId'] as String,
      bookTitle: map['bookTitle'] as String,
      bookAuthor: (map['bookAuthor'] as String?) ?? '',
      isbn: map['isbn'] as String?,
      condition: (map['condition'] as String?) ?? 'Brand New',
      quantity: (map['quantity'] as num).toInt(),
      unitMrpPaise: (map['unitMrpPaise'] as num).toInt(),
      unitSellingPricePaise: (map['unitSellingPricePaise'] as num).toInt(),
      itemDiscountPaise: (map['itemDiscountPaise'] as num?)?.toInt() ?? 0,
      allocatedReceiptDiscountPaise:
          (map['allocatedReceiptDiscountPaise'] as num?)?.toInt() ?? 0,
      lineTotalPaise: (map['lineTotalPaise'] as num).toInt(),
      unitCostPaise: (map['unitCostPaise'] as num).toInt(),
      lineCogsPaise: (map['lineCogsPaise'] as num).toInt(),
      lineGrossProfitPaise: (map['lineGrossProfitPaise'] as num).toInt(),
      isUnverifiedStock: map['isUnverifiedStock'] as bool? ?? false,
      isCostProvisional: map['isCostProvisional'] as bool? ?? false,
      overrideAuthorizerId: map['overrideAuthorizerId'] as String?,
      overrideReason: map['overrideReason'] as String?,
      returnedQuantity: (map['returnedQuantity'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}
