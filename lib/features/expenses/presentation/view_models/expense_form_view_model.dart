import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/financial_draft_manager.dart';
import '../../domain/entities/expense.dart';
import 'expense_providers.dart';

class ExpenseFormState {
  const ExpenseFormState({
    this.clientRequestId = '',
    this.editingId,
    this.fairId = '',
    this.title = '',
    this.description = '',
    this.categoryId = '',
    this.amount = '',
    this.paidAmount = '',
    this.expenseDate,
    this.paymentMethod = 'Cash',
    this.isPaidByPartner = false,
    this.paidByPartnerId,
    this.paidFromAccountId,
    this.supplierId,
    this.referenceNumber = '',
    this.notes = '',
    this.isSubmitting = false,
    this.errorMessage,
    this.validationErrors = const {},
  });

  final String clientRequestId;
  final String? editingId;
  final String fairId;
  final String title;
  final String description;
  final String categoryId;
  final String amount;
  final String paidAmount;
  final DateTime? expenseDate;
  final String paymentMethod;
  final bool isPaidByPartner;
  final String? paidByPartnerId;
  final String? paidFromAccountId;
  final String? supplierId;
  final String referenceNumber;
  final String notes;
  final bool isSubmitting;
  final String? errorMessage;
  final Map<String, String> validationErrors;

  bool get isEditMode => editingId != null;

  ExpenseFormState copyWith({
    String? clientRequestId,
    String? editingId,
    String? fairId,
    String? title,
    String? description,
    String? categoryId,
    String? amount,
    String? paidAmount,
    DateTime? expenseDate,
    String? paymentMethod,
    bool? isPaidByPartner,
    String? paidByPartnerId,
    String? paidFromAccountId,
    String? supplierId,
    String? referenceNumber,
    String? notes,
    bool? isSubmitting,
    String? errorMessage,
    Map<String, String>? validationErrors,
  }) {
    return ExpenseFormState(
      clientRequestId: clientRequestId ?? this.clientRequestId,
      editingId: editingId ?? this.editingId,
      fairId: fairId ?? this.fairId,
      title: title ?? this.title,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      paidAmount: paidAmount ?? this.paidAmount,
      expenseDate: expenseDate ?? this.expenseDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isPaidByPartner: isPaidByPartner ?? this.isPaidByPartner,
      paidByPartnerId: paidByPartnerId ?? this.paidByPartnerId,
      paidFromAccountId: paidFromAccountId ?? this.paidFromAccountId,
      supplierId: supplierId ?? this.supplierId,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      notes: notes ?? this.notes,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
      validationErrors: validationErrors ?? this.validationErrors,
    );
  }
}

final expenseFormViewModelProvider =
    NotifierProvider.family<ExpenseFormViewModel, ExpenseFormState, String?>(
      (fairId) => ExpenseFormViewModel(fairId),
    );

class ExpenseFormViewModel extends Notifier<ExpenseFormState> {
  ExpenseFormViewModel(this.initialFairId);

  final String? initialFairId;
  final _uuid = const Uuid();

  @override
  ExpenseFormState build() {
    final keySuffix =
        (initialFairId != null && initialFairId!.trim().isNotEmpty)
        ? initialFairId!.trim()
        : 'default';
    final clientReqId = FinancialDraftManager.getOrCreateClientRequestId(
      operationType: 'expense',
      entityId: keySuffix,
    );

    return ExpenseFormState(
      clientRequestId: clientReqId,
      fairId: initialFairId ?? '',
      expenseDate: DateTime.now(),
    );
  }

  void loadForEdit(Expense expense) {
    state = ExpenseFormState(
      clientRequestId: state.clientRequestId,
      editingId: expense.id,
      fairId: expense.fairId,
      title: expense.title,
      description: expense.description,
      categoryId: expense.categoryId,
      amount: (expense.amountPaise / 100.0).toStringAsFixed(2),
      paidAmount: (expense.paidAmountPaise / 100.0).toStringAsFixed(2),
      expenseDate: expense.expenseDate,
      paymentMethod: expense.paymentMethod,
      isPaidByPartner: expense.paidByPartnerId != null,
      paidByPartnerId: expense.paidByPartnerId,
      paidFromAccountId: expense.paidFromAccountId,
      supplierId: expense.supplierId,
      referenceNumber: expense.referenceNumber ?? '',
      notes: expense.notes,
    );
  }

  void reset() {
    final keySuffix = state.fairId.trim().isNotEmpty
        ? state.fairId.trim()
        : ((initialFairId != null && initialFairId!.trim().isNotEmpty)
              ? initialFairId!.trim()
              : 'default');
    final newId = _uuid.v4();
    FinancialDraftManager.getOrCreateClientRequestId(
      operationType: 'expense',
      entityId: keySuffix,
    );
    state = ExpenseFormState(
      clientRequestId: newId,
      fairId: initialFairId ?? '',
      expenseDate: DateTime.now(),
    );
  }

  void setFairId(String val) {
    final keySuffix = val.trim().isNotEmpty ? val.trim() : 'default';
    final clientReqId = FinancialDraftManager.getOrCreateClientRequestId(
      operationType: 'expense',
      entityId: keySuffix,
    );

    state = state.copyWith(fairId: val, clientRequestId: clientReqId);
  }

  void setTitle(String val) => state = state.copyWith(title: val);
  void setDescription(String val) => state = state.copyWith(description: val);
  void setCategoryId(String val) => state = state.copyWith(categoryId: val);
  void setAmount(String val) => state = state.copyWith(amount: val);
  void setPaidAmount(String val) => state = state.copyWith(paidAmount: val);
  void setExpenseDate(DateTime val) => state = state.copyWith(expenseDate: val);
  void setPaymentMethod(String val) =>
      state = state.copyWith(paymentMethod: val);
  void setIsPaidByPartner(bool val) => state = state.copyWith(
    isPaidByPartner: val,
    paidFromAccountId: val ? null : state.paidFromAccountId,
  );
  void setPaidByPartnerId(String? val) =>
      state = state.copyWith(paidByPartnerId: val);
  void setPaidFromAccountId(String? val) =>
      state = state.copyWith(paidFromAccountId: val);
  void setSupplierId(String? val) => state = state.copyWith(supplierId: val);
  void setReferenceNumber(String val) =>
      state = state.copyWith(referenceNumber: val);
  void setNotes(String val) => state = state.copyWith(notes: val);

  bool validate() {
    final errors = <String, String>{};

    if (state.fairId.trim().isEmpty) {
      errors['fairId'] = 'Please select a Book Fair';
    }
    if (state.title.trim().isEmpty) {
      errors['title'] = 'Expense title is required';
    }
    if (state.categoryId.trim().isEmpty) {
      errors['categoryId'] = 'Please select an expense category';
    }

    final amountNum = double.tryParse(state.amount);
    if (amountNum == null || amountNum <= 0) {
      errors['amount'] = 'Enter a valid expense amount greater than zero';
    }

    if (state.paidAmount.isNotEmpty) {
      final paidNum = double.tryParse(state.paidAmount);
      if (paidNum == null || paidNum < 0) {
        errors['paidAmount'] = 'Paid amount must be zero or positive';
      } else if (amountNum != null && paidNum > amountNum) {
        errors['paidAmount'] = 'Paid amount cannot exceed total expense amount';
      }
    }

    if (state.isPaidByPartner &&
        (state.paidByPartnerId == null || state.paidByPartnerId!.isEmpty)) {
      errors['paidByPartnerId'] = 'Please select the paying partner';
    }

    state = state.copyWith(validationErrors: errors);
    return errors.isEmpty;
  }

  Future<Expense?> submit() async {
    if (!validate()) return null;

    state = state.copyWith(isSubmitting: true, errorMessage: null);

    try {
      final repo = ref.read(expenseRepositoryProvider);
      final amountPaise = ((double.tryParse(state.amount) ?? 0.0) * 100)
          .round();
      final paidPaise = state.paidAmount.isNotEmpty
          ? ((double.tryParse(state.paidAmount) ?? 0.0) * 100).round()
          : 0;

      final expenseDate = state.expenseDate ?? DateTime.now();

      if (state.isEditMode) {
        final existing = await repo.getExpenseById(state.editingId!);
        if (existing == null) {
          state = state.copyWith(
            isSubmitting: false,
            errorMessage: 'Expense record not found',
          );
          return null;
        }

        final updated = existing.copyWith(
          fairId: state.fairId,
          title: state.title.trim(),
          description: state.description.trim(),
          categoryId: state.categoryId,
          amountPaise: amountPaise,
          expenseDate: expenseDate,
          paymentMethod: state.paymentMethod,
          paidByPartnerId: state.isPaidByPartner ? state.paidByPartnerId : null,
          paidFromAccountId: !state.isPaidByPartner
              ? state.paidFromAccountId
              : null,
          supplierId: state.supplierId,
          referenceNumber: state.referenceNumber.trim().isNotEmpty
              ? state.referenceNumber.trim()
              : null,
          notes: state.notes.trim(),
        );

        final result = await repo.updateExpense(updated);
        state = state.copyWith(isSubmitting: false);
        return result;
      } else {
        final newExpense = Expense(
          id: _uuid.v4(),
          fairId: state.fairId,
          title: state.title.trim(),
          description: state.description.trim(),
          categoryId: state.categoryId,
          amountPaise: amountPaise,
          expenseDate: expenseDate,
          paymentStatus: paidPaise >= amountPaise
              ? 'Paid'
              : paidPaise > 0
              ? 'Partially Paid'
              : 'Unpaid',
          paidAmountPaise: paidPaise,
          outstandingAmountPaise: amountPaise - paidPaise,
          paymentMethod: state.paymentMethod,
          paidByPartnerId: state.isPaidByPartner ? state.paidByPartnerId : null,
          paidFromAccountId: !state.isPaidByPartner
              ? state.paidFromAccountId
              : null,
          supplierId: state.supplierId,
          referenceNumber: state.referenceNumber.trim().isNotEmpty
              ? state.referenceNumber.trim()
              : null,
          notes: state.notes.trim(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final result = await repo.createExpense(
          newExpense,
          initialPaymentAmountPaise: paidPaise,
          paymentMethod: state.paymentMethod,
          paidByPartnerId: state.isPaidByPartner ? state.paidByPartnerId : null,
          paidFromAccountId: !state.isPaidByPartner
              ? state.paidFromAccountId
              : null,
          referenceNumber: state.referenceNumber.trim().isNotEmpty
              ? state.referenceNumber.trim()
              : null,
          clientRequestId: state.clientRequestId,
        );

        // Delete draft entry upon successful creation
        final keySuffix = state.fairId.trim().isNotEmpty
            ? state.fairId.trim()
            : 'default';
        await FinancialDraftManager.clearDraft(
          operationType: 'expense',
          entityId: keySuffix,
        );

        state = state.copyWith(isSubmitting: false);
        return result;
      }
    } catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.toString());
      return null;
    }
  }
}
