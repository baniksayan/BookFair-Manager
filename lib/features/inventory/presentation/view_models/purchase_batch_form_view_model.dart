import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/financial_calculator.dart';
import '../../../../core/utils/financial_draft_manager.dart';
import '../../domain/entities/book.dart';
import '../../domain/entities/purchase_batch.dart';
import '../../domain/entities/purchase_item.dart';
import 'inventory_providers.dart';

class PurchaseBatchItemDraft {
  const PurchaseBatchItemDraft({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    required this.quantity,
    required this.unitCostInput,
    required this.condition,
    this.notes = '',
  });

  final String id;
  final String bookId;
  final String bookTitle;
  final int quantity;
  final String unitCostInput;
  final BookCondition condition;
  final String notes;

  int get unitCostPaise => FinancialCalculator.parseToPaise(unitCostInput);
  int get lineTotalPaise => quantity * unitCostPaise;

  PurchaseBatchItemDraft copyWith({
    String? id,
    String? bookId,
    String? bookTitle,
    int? quantity,
    String? unitCostInput,
    BookCondition? condition,
    String? notes,
  }) {
    return PurchaseBatchItemDraft(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      bookTitle: bookTitle ?? this.bookTitle,
      quantity: quantity ?? this.quantity,
      unitCostInput: unitCostInput ?? this.unitCostInput,
      condition: condition ?? this.condition,
      notes: notes ?? this.notes,
    );
  }
}

class PurchaseBatchFormState {
  const PurchaseBatchFormState({
    this.fairId = 'global',
    this.supplierId,
    required this.purchaseDate,
    this.invoiceNumber = '',
    this.purchaseReference = '',
    this.additionalCharges = '0',
    this.paymentStatus = 'Paid',
    this.paymentMethod = 'Bank Transfer',
    this.notes = '',
    this.clientRequestId = '',
    this.items = const [],
    this.isSubmitting = false,
    this.validationErrors = const {},
  });

  final String fairId;
  final String? supplierId;
  final DateTime purchaseDate;
  final String invoiceNumber;
  final String purchaseReference;
  final String additionalCharges;
  final String paymentStatus;
  final String paymentMethod;
  final String notes;
  final String clientRequestId;
  final List<PurchaseBatchItemDraft> items;
  final bool isSubmitting;
  final Map<String, String> validationErrors;

  int get totalQuantity => items.fold(0, (sum, i) => sum + i.quantity);
  int get totalBookCostPaise =>
      items.fold(0, (sum, i) => sum + i.lineTotalPaise);
  int get additionalChargesPaise =>
      FinancialCalculator.parseToPaise(additionalCharges);
  int get totalAcquisitionCostPaise =>
      totalBookCostPaise + additionalChargesPaise;

  double get totalBookCost => totalBookCostPaise / 100.0;
  double get additionalChargesDouble => additionalChargesPaise / 100.0;
  double get totalAcquisitionCost => totalAcquisitionCostPaise / 100.0;

  PurchaseBatchFormState copyWith({
    String? fairId,
    String? supplierId,
    DateTime? purchaseDate,
    String? invoiceNumber,
    String? purchaseReference,
    String? additionalCharges,
    String? paymentStatus,
    String? paymentMethod,
    String? notes,
    String? clientRequestId,
    List<PurchaseBatchItemDraft>? items,
    bool? isSubmitting,
    Map<String, String>? validationErrors,
    bool clearSupplier = false,
  }) {
    return PurchaseBatchFormState(
      fairId: fairId ?? this.fairId,
      supplierId: clearSupplier ? null : (supplierId ?? this.supplierId),
      purchaseDate: purchaseDate ?? this.purchaseDate,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      purchaseReference: purchaseReference ?? this.purchaseReference,
      additionalCharges: additionalCharges ?? this.additionalCharges,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      clientRequestId: clientRequestId ?? this.clientRequestId,
      items: items ?? this.items,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      validationErrors: validationErrors ?? this.validationErrors,
    );
  }
}

final purchaseBatchFormViewModelProvider =
    NotifierProvider<PurchaseBatchFormViewModel, PurchaseBatchFormState>(
      PurchaseBatchFormViewModel.new,
    );

class PurchaseBatchFormViewModel extends Notifier<PurchaseBatchFormState> {
  static const _uuid = Uuid();

  @override
  PurchaseBatchFormState build() =>
      PurchaseBatchFormState(purchaseDate: DateTime.now());

  void init({String? fairId}) {
    final effectiveFairId = fairId ?? 'global';
    final clientReqId = FinancialDraftManager.getOrCreateClientRequestId(
      operationType: 'purchase_batch',
      entityId: effectiveFairId,
    );
    state = PurchaseBatchFormState(
      fairId: effectiveFairId,
      purchaseDate: DateTime.now(),
      clientRequestId: clientReqId,
    );
  }

  void setSupplierId(String? supplierId) {
    if (supplierId == null) {
      state = state.copyWith(clearSupplier: true);
    } else {
      state = state.copyWith(supplierId: supplierId);
    }
  }

  void setPurchaseDate(DateTime date) =>
      state = state.copyWith(purchaseDate: date);
  void setInvoiceNumber(String val) =>
      state = state.copyWith(invoiceNumber: val);
  void setPurchaseReference(String val) =>
      state = state.copyWith(purchaseReference: val);
  void setAdditionalCharges(String val) =>
      state = state.copyWith(additionalCharges: val);
  void setPaymentStatus(String val) =>
      state = state.copyWith(paymentStatus: val);
  void setPaymentMethod(String val) =>
      state = state.copyWith(paymentMethod: val);
  void setNotes(String val) => state = state.copyWith(notes: val);

  void addItem({
    required Book book,
    int quantity = 1,
    String unitCost = '',
    BookCondition? condition,
  }) {
    final newItem = PurchaseBatchItemDraft(
      id: _uuid.v4(),
      bookId: book.id,
      bookTitle: book.title,
      quantity: quantity,
      unitCostInput: unitCost.isNotEmpty
          ? unitCost
          : (book.mrpPaise > 0
                ? (book.condition.calculateSuggestedSellingPricePaise(
                            book.mrpPaise,
                          ) /
                          100.0)
                      .toStringAsFixed(0)
                : '0'),
      condition: condition ?? book.condition,
    );
    state = state.copyWith(items: [...state.items, newItem]);
  }

  void updateItemQuantity(String itemId, int qty) {
    if (qty <= 0) return;
    state = state.copyWith(
      items: state.items.map((i) {
        if (i.id == itemId) return i.copyWith(quantity: qty);
        return i;
      }).toList(),
    );
  }

  void updateItemUnitCost(String itemId, String unitCost) {
    state = state.copyWith(
      items: state.items.map((i) {
        if (i.id == itemId) return i.copyWith(unitCostInput: unitCost);
        return i;
      }).toList(),
    );
  }

  void removeItem(String itemId) {
    state = state.copyWith(
      items: state.items.where((i) => i.id != itemId).toList(),
    );
  }

  bool validate() {
    final errors = <String, String>{};

    if (state.items.isEmpty) {
      errors['items'] =
          'At least one book title must be included in the purchase batch.';
    }

    for (final item in state.items) {
      if (item.quantity <= 0) {
        errors['quantity'] =
            'All line items must have a quantity of at least 1.';
      }
      if (item.unitCostPaise < 0) {
        errors['cost'] = 'Unit purchase cost cannot be negative.';
      }
    }

    state = state.copyWith(validationErrors: errors);
    return errors.isEmpty;
  }

  Future<String?> submit() async {
    if (!validate() || state.isSubmitting) return null;

    state = state.copyWith(isSubmitting: true);

    try {
      final repo = ref.read(inventoryRepositoryProvider);
      final batchId = _uuid.v4();
      final now = DateTime.now();

      final purchaseBatch = PurchaseBatch(
        id: batchId,
        fairId: state.fairId,
        supplierId: state.supplierId,
        purchaseDate: state.purchaseDate,
        invoiceNumber: state.invoiceNumber.trim().isNotEmpty
            ? state.invoiceNumber.trim()
            : null,
        purchaseReference: state.purchaseReference.trim().isNotEmpty
            ? state.purchaseReference.trim()
            : null,
        totalQuantity: state.totalQuantity,
        totalBookCostPaise: state.totalBookCostPaise,
        additionalChargesPaise: state.additionalChargesPaise,
        totalAcquisitionCostPaise: state.totalAcquisitionCostPaise,
        paymentStatus: state.paymentStatus,
        paymentMethod: state.paymentMethod,
        notes: state.notes.trim(),
        createdAt: now,
      );

      final purchaseItems = state.items.map((draft) {
        return PurchaseItem(
          id: _uuid.v4(),
          batchId: batchId,
          bookId: draft.bookId,
          quantity: draft.quantity,
          unitPurchaseCostPaise: draft.unitCostPaise,
          lineTotalPaise: draft.lineTotalPaise,
          condition: draft.condition,
          notes: draft.notes,
        );
      }).toList();

      await repo.createPurchaseBatch(
        batch: purchaseBatch,
        items: purchaseItems,
      );

      await FinancialDraftManager.clearDraft(
        operationType: 'purchase_batch',
        entityId: state.fairId,
      );

      final nextDraftId = FinancialDraftManager.getOrCreateClientRequestId(
        operationType: 'purchase_batch',
        entityId: state.fairId,
      );

      state = state.copyWith(isSubmitting: false, clientRequestId: nextDraftId);
      return batchId;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        validationErrors: {'general': e.toString()},
      );
      return null;
    }
  }
}
