import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/financial_draft_manager.dart';
import '../../../inventory/domain/entities/book.dart';
import '../../../inventory/domain/services/inventory_cost_calculator.dart';
import '../../../inventory/presentation/view_models/inventory_providers.dart';
import '../../../payments/domain/entities/payment_record.dart';
import '../../domain/entities/sale_item.dart';
import '../../domain/entities/sale_receipt.dart';
import 'sales_providers.dart';

/// Single cart line item representation within the POS counter.
class PosCartItem {
  const PosCartItem({
    required this.id,
    required this.book,
    required this.quantity,
    required this.unitMrpPaise,
    required this.unitSellingPricePaise,
    required this.unitCostPaise,
    required this.isCostProvisional,
    required this.availableStock,
    this.isUnverifiedStock = false,
    this.overrideAuthorizerId,
    this.overrideReason,
  });

  final String id;
  final Book book;
  final int quantity;
  final int unitMrpPaise;
  final int unitSellingPricePaise;
  final int unitCostPaise;
  final bool isCostProvisional;
  final int availableStock;
  final bool isUnverifiedStock;
  final String? overrideAuthorizerId;
  final String? overrideReason;

  // Currency helpers
  double get unitMrp => unitMrpPaise / 100.0;
  double get unitSellingPrice => unitSellingPricePaise / 100.0;
  double get unitCost => unitCostPaise / 100.0;
  int get lineTotalPaise => unitSellingPricePaise * quantity;
  double get lineTotal => lineTotalPaise / 100.0;

  /// Discount per copy below MRP
  int get itemDiscountPaise => unitMrpPaise > unitSellingPricePaise
      ? unitMrpPaise - unitSellingPricePaise
      : 0;
  double get itemDiscount => itemDiscountPaise / 100.0;

  /// Warning if cashier is selling below acquisition cost
  bool get isBelowCost =>
      !isCostProvisional &&
      unitCostPaise > 0 &&
      unitSellingPricePaise < unitCostPaise;

  /// Warning if requested quantity exceeds recorded available on-hand stock
  bool get isStockDepleted => quantity > availableStock;

  PosCartItem copyWith({
    String? id,
    Book? book,
    int? quantity,
    int? unitMrpPaise,
    int? unitSellingPricePaise,
    int? unitCostPaise,
    bool? isCostProvisional,
    int? availableStock,
    bool? isUnverifiedStock,
    String? overrideAuthorizerId,
    String? overrideReason,
  }) {
    return PosCartItem(
      id: id ?? this.id,
      book: book ?? this.book,
      quantity: quantity ?? this.quantity,
      unitMrpPaise: unitMrpPaise ?? this.unitMrpPaise,
      unitSellingPricePaise:
          unitSellingPricePaise ?? this.unitSellingPricePaise,
      unitCostPaise: unitCostPaise ?? this.unitCostPaise,
      isCostProvisional: isCostProvisional ?? this.isCostProvisional,
      availableStock: availableStock ?? this.availableStock,
      isUnverifiedStock: isUnverifiedStock ?? this.isUnverifiedStock,
      overrideAuthorizerId: overrideAuthorizerId ?? this.overrideAuthorizerId,
      overrideReason: overrideReason ?? this.overrideReason,
    );
  }
}

/// Draft representation of an individual payment rail component at POS checkout.
class PaymentRailDraft {
  const PaymentRailDraft({
    required this.paymentMethod,
    required this.accountId,
    required this.amountPaise,
    this.referenceNumber,
  });

  final String paymentMethod;
  final String accountId;
  final int amountPaise;
  final String? referenceNumber;

  double get amount => amountPaise / 100.0;
}

/// Immutable state holding POS cart contents, discounts, and customer details.
class PosCartState {
  const PosCartState({
    this.fairId = 'global',
    this.cashierId,
    this.cashierName = 'Stall Volunteer',
    this.items = const [],
    this.receiptDiscountPaise = 0,
    this.clientRequestId = '',
    this.customerName = '',
    this.customerPhone = '',
    this.notes = '',
    this.isSubmitting = false,
    this.validationErrors = const {},
  });

  final String fairId;
  final String? cashierId;
  final String cashierName;
  final List<PosCartItem> items;
  final int receiptDiscountPaise;
  final String clientRequestId;
  final String customerName;
  final String customerPhone;
  final String notes;
  final bool isSubmitting;
  final Map<String, String> validationErrors;

  int get subtotalPaise =>
      items.fold<int>(0, (sum, i) => sum + i.lineTotalPaise);
  double get subtotal => subtotalPaise / 100.0;

  int get totalPayablePaise => (subtotalPaise - receiptDiscountPaise) > 0
      ? subtotalPaise - receiptDiscountPaise
      : 0;
  double get totalPayable => totalPayablePaise / 100.0;

  int get totalQuantity => items.fold<int>(0, (sum, i) => sum + i.quantity);

  bool get hasStockWarnings =>
      items.any((i) => i.isStockDepleted && !i.isUnverifiedStock);
  bool get hasBelowCostWarnings => items.any((i) => i.isBelowCost);

  PosCartState copyWith({
    String? fairId,
    String? cashierId,
    String? cashierName,
    List<PosCartItem>? items,
    int? receiptDiscountPaise,
    String? clientRequestId,
    String? customerName,
    String? customerPhone,
    String? notes,
    bool? isSubmitting,
    Map<String, String>? validationErrors,
  }) {
    return PosCartState(
      fairId: fairId ?? this.fairId,
      cashierId: cashierId ?? this.cashierId,
      cashierName: cashierName ?? this.cashierName,
      items: items ?? this.items,
      receiptDiscountPaise: receiptDiscountPaise ?? this.receiptDiscountPaise,
      clientRequestId: clientRequestId ?? this.clientRequestId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      notes: notes ?? this.notes,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      validationErrors: validationErrors ?? this.validationErrors,
    );
  }
}

/// Provider for [PosCartViewModel].
final posCartViewModelProvider =
    NotifierProvider<PosCartViewModel, PosCartState>(PosCartViewModel.new);

/// Point-of-Sale cart controller managing scanning, line discounts, manager overrides,
/// and durable settlement checkout.
class PosCartViewModel extends Notifier<PosCartState> {
  static const _uuid = Uuid();

  @override
  PosCartState build() {
    final clientReqId = FinancialDraftManager.getOrCreateClientRequestId(
      operationType: 'pos_sale',
      entityId: 'global',
    );
    return PosCartState(clientRequestId: clientReqId);
  }

  void init({required String fairId, String? cashierId, String? cashierName}) {
    final clientReqId = FinancialDraftManager.getOrCreateClientRequestId(
      operationType: 'pos_sale',
      entityId: fairId,
    );
    state = state.copyWith(
      fairId: fairId,
      cashierId: cashierId,
      cashierName: cashierName ?? 'Stall Volunteer',
      clientRequestId: clientReqId,
    );
  }

  /// Adds a book to the active cart or increments quantity if already present.
  Future<void> addBook(
    Book book, {
    int quantity = 1,
    int? customSellingPricePaise,
  }) async {
    final inventoryRepo = ref.read(inventoryRepositoryProvider);
    final available = await inventoryRepo.getAvailableStockForBook(book.id);

    // Fetch weighted average acquisition cost for this book title
    final batches = await inventoryRepo.getAllPurchaseBatches(
      fairId: state.fairId,
    );
    final allItems = <dynamic>[];
    for (final b in batches) {
      final bItems = await inventoryRepo.getItemsForBatch(b.id);
      allItems.addAll(bItems.where((i) => i.bookId == book.id));
    }
    final weightedCost =
        InventoryCostCalculator.calculateBookWeightedAverageCostPaise(
          book: book,
          purchaseItemsForBook: allItems.cast(),
        );
    final isCostUnknown =
        weightedCost <= 0 &&
        (book.estimatedCostPaise == null || book.estimatedCostPaise! <= 0);

    final existingIndex = state.items.indexWhere((i) => i.book.id == book.id);

    if (existingIndex >= 0) {
      final existing = state.items[existingIndex];
      final newQty = existing.quantity + quantity;
      final updated = existing.copyWith(
        quantity: newQty,
        availableStock: available,
      );
      final newItems = List<PosCartItem>.from(state.items);
      newItems[existingIndex] = updated;
      state = state.copyWith(items: newItems);
    } else {
      final sellingPrice =
          customSellingPricePaise ?? book.defaultSellingPricePaise;
      final newItem = PosCartItem(
        id: _uuid.v4(),
        book: book,
        quantity: quantity,
        unitMrpPaise: book.mrpPaise,
        unitSellingPricePaise: sellingPrice,
        unitCostPaise: weightedCost > 0
            ? weightedCost
            : (book.estimatedCostPaise ?? 0),
        isCostProvisional: isCostUnknown,
        availableStock: available,
      );
      state = state.copyWith(items: [...state.items, newItem]);
    }
  }

  void updateQuantity(String cartItemId, int newQty) {
    if (newQty <= 0) {
      removeItem(cartItemId);
      return;
    }
    state = state.copyWith(
      items: state.items.map((i) {
        if (i.id == cartItemId) {
          return i.copyWith(quantity: newQty);
        }
        return i;
      }).toList(),
    );
  }

  void updateItemPrice(String cartItemId, int newUnitPricePaise) {
    if (newUnitPricePaise < 0) return;
    state = state.copyWith(
      items: state.items.map((i) {
        if (i.id == cartItemId) {
          return i.copyWith(unitSellingPricePaise: newUnitPricePaise);
        }
        return i;
      }).toList(),
    );
  }

  void applyItemDiscountPercent(String cartItemId, double percent) {
    if (percent < 0 || percent > 100) return;
    state = state.copyWith(
      items: state.items.map((i) {
        if (i.id == cartItemId) {
          final discounted = (i.unitMrpPaise * (1.0 - (percent / 100.0)))
              .round();
          return i.copyWith(unitSellingPricePaise: discounted);
        }
        return i;
      }).toList(),
    );
  }

  void applyItemDiscountAmount(String cartItemId, int discountAmountPaise) {
    state = state.copyWith(
      items: state.items.map((i) {
        if (i.id == cartItemId) {
          final discounted = i.unitMrpPaise - discountAmountPaise;
          return i.copyWith(
            unitSellingPricePaise: discounted > 0 ? discounted : 0,
          );
        }
        return i;
      }).toList(),
    );
  }

  void setReceiptDiscount(int discountAmountPaise) {
    state = state.copyWith(
      receiptDiscountPaise: discountAmountPaise >= 0 ? discountAmountPaise : 0,
    );
  }

  /// Authorizes manager override for negative/unverified physical stock.
  void applyManagerOverride(
    String cartItemId, {
    required String authorizerId,
    required String reason,
  }) {
    state = state.copyWith(
      items: state.items.map((i) {
        if (i.id == cartItemId) {
          return i.copyWith(
            isUnverifiedStock: true,
            overrideAuthorizerId: authorizerId.trim(),
            overrideReason: reason.trim(),
          );
        }
        return i;
      }).toList(),
    );
  }

  void removeItem(String cartItemId) {
    state = state.copyWith(
      items: state.items.where((i) => i.id != cartItemId).toList(),
    );
  }

  void clearCart() {
    state = state.copyWith(
      items: const [],
      receiptDiscountPaise: 0,
      customerName: '',
      customerPhone: '',
      notes: '',
      validationErrors: const {},
    );
  }

  void setCustomerInfo({String? name, String? phone, String? notes}) {
    state = state.copyWith(
      customerName: name ?? state.customerName,
      customerPhone: phone ?? state.customerPhone,
      notes: notes ?? state.notes,
    );
  }

  /// Executes checkout settlement across one or more payment rails.
  Future<SaleReceipt?> checkout({
    required List<PaymentRailDraft> paymentRails,
    int? tenderedAmountPaise,
    int? changeAmountPaise,
  }) async {
    if (state.items.isEmpty) {
      state = state.copyWith(
        validationErrors: {'items': 'Cart is empty. Add at least one book.'},
      );
      return null;
    }

    // Check unverified stock without override
    for (final item in state.items) {
      if (item.isStockDepleted && !item.isUnverifiedStock) {
        state = state.copyWith(
          validationErrors: {
            'stock':
                'Cannot checkout "${item.book.title}". Available stock (${item.availableStock}) is less than requested (${item.quantity}). Manager override required.',
          },
        );
        return null;
      }
    }

    final totalPayments = paymentRails.fold<int>(
      0,
      (sum, p) => sum + p.amountPaise,
    );
    if (totalPayments != state.totalPayablePaise) {
      state = state.copyWith(
        validationErrors: {
          'payments':
              'Total payments (₹${(totalPayments / 100.0).toStringAsFixed(2)}) must match payable amount (₹${(state.totalPayablePaise / 100.0).toStringAsFixed(2)}).',
        },
      );
      return null;
    }

    state = state.copyWith(isSubmitting: true, validationErrors: const {});

    try {
      final saleRepo = ref.read(saleRepositoryProvider);
      final receiptId = _uuid.v4();
      final now = DateTime.now();
      final receiptNum =
          'RCP-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch.toString().substring(7)}';

      // Allocate receipt discount proportionally across items
      final totalSubtotal = state.subtotalPaise;
      var allocatedDiscountRemaining = state.receiptDiscountPaise;

      final saleItems = <SaleItem>[];
      for (int i = 0; i < state.items.length; i++) {
        final item = state.items[i];
        final isLast = i == state.items.length - 1;

        int itemAllocatedReceiptDiscount = 0;
        if (totalSubtotal > 0 && state.receiptDiscountPaise > 0) {
          if (isLast) {
            itemAllocatedReceiptDiscount = allocatedDiscountRemaining;
          } else {
            final share =
                (item.lineTotalPaise.toDouble() / totalSubtotal.toDouble()) *
                state.receiptDiscountPaise.toDouble();
            itemAllocatedReceiptDiscount = share.round();
            allocatedDiscountRemaining -= itemAllocatedReceiptDiscount;
          }
        }

        final lineTotal = item.lineTotalPaise - itemAllocatedReceiptDiscount;
        final lineCogs = item.unitCostPaise * item.quantity;
        final lineGrossProfit = lineTotal - lineCogs;

        saleItems.add(
          SaleItem(
            id: _uuid.v4(),
            receiptId: receiptId,
            bookId: item.book.id,
            bookTitle: item.book.title,
            bookAuthor: item.book.author,
            isbn: item.book.primaryIsbn,
            condition: item.book.condition.displayName,
            quantity: item.quantity,
            unitMrpPaise: item.unitMrpPaise,
            unitSellingPricePaise: item.unitSellingPricePaise,
            itemDiscountPaise: item.itemDiscountPaise,
            allocatedReceiptDiscountPaise: itemAllocatedReceiptDiscount,
            lineTotalPaise: lineTotal > 0 ? lineTotal : 0,
            unitCostPaise: item.unitCostPaise,
            lineCogsPaise: lineCogs,
            lineGrossProfitPaise: lineGrossProfit,
            isUnverifiedStock: item.isUnverifiedStock,
            isCostProvisional: item.isCostProvisional,
            overrideAuthorizerId: item.overrideAuthorizerId,
            overrideReason: item.overrideReason,
            createdAt: now,
          ),
        );
      }

      final saleReceipt = SaleReceipt(
        id: receiptId,
        receiptNumber: receiptNum,
        fairId: state.fairId,
        cashierId: state.cashierId,
        cashierName: state.cashierName,
        subtotalAmountPaise: state.subtotalPaise,
        discountAmountPaise: state.receiptDiscountPaise,
        totalAmountPaise: state.totalPayablePaise,
        tenderedAmountPaise: tenderedAmountPaise,
        changeAmountPaise: changeAmountPaise,
        paymentStatus: 'paid',
        customerName: state.customerName.trim().isNotEmpty
            ? state.customerName.trim()
            : null,
        customerPhone: state.customerPhone.trim().isNotEmpty
            ? state.customerPhone.trim()
            : null,
        notes: state.notes.trim(),
        isUnverifiedStockSale: state.items.any((i) => i.isUnverifiedStock),
        isCostProvisional: state.items.any((i) => i.isCostProvisional),
        createdAt: now,
        items: saleItems,
      );

      final payments = paymentRails.map((p) {
        return PaymentRecord(
          id: _uuid.v4(),
          fairId: state.fairId,
          amountPaise: p.amountPaise,
          paymentMethod: p.paymentMethod,
          paymentDate: now,
          accountId: p.accountId,
          referenceNumber: p.referenceNumber,
          relatedEntityType: 'sale',
          relatedEntityId: receiptId,
          notes: 'POS payment for Receipt #$receiptNum via ${p.paymentMethod}',
          createdAt: now,
        );
      }).toList();

      final committedReceipt = await saleRepo.recordSale(
        receipt: saleReceipt,
        items: saleItems,
        payments: payments,
        clientRequestId: state.clientRequestId,
      );

      // Clear draft upon successful commit
      await FinancialDraftManager.clearDraft(
        operationType: 'pos_sale',
        entityId: state.fairId,
      );

      final newClientReqId = FinancialDraftManager.getOrCreateClientRequestId(
        operationType: 'pos_sale',
        entityId: state.fairId,
      );

      state = PosCartState(
        fairId: state.fairId,
        cashierId: state.cashierId,
        cashierName: state.cashierName,
        clientRequestId: newClientReqId,
      );

      return committedReceipt;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        validationErrors: {'general': e.toString()},
      );
      rethrow;
    }
  }
}
