import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/financial_calculator.dart';
import '../../domain/entities/investment.dart';
import 'book_fair_providers.dart';

class InvestmentFormState {
  const InvestmentFormState({
    this.editingId,
    this.partnerId = '',
    this.amount = '',
    this.contributionType = ContributionType.cash,
    this.paymentMethod = PaymentMethod.cash,
    this.contributionDate,
    this.referenceNumber = '',
    this.notes = '',
    this.isSubmitting = false,
    this.errorMessage,
    this.validationErrors = const {},
  });

  final String? editingId;
  final String partnerId;
  final String amount;
  final ContributionType contributionType;
  final PaymentMethod paymentMethod;
  final DateTime? contributionDate;
  final String referenceNumber;
  final String notes;
  final bool isSubmitting;
  final String? errorMessage;
  final Map<String, String> validationErrors;

  bool get isEditMode => editingId != null;

  InvestmentFormState copyWith({
    String? editingId,
    String? partnerId,
    String? amount,
    ContributionType? contributionType,
    PaymentMethod? paymentMethod,
    DateTime? contributionDate,
    String? referenceNumber,
    String? notes,
    bool? isSubmitting,
    String? errorMessage,
    Map<String, String>? validationErrors,
  }) {
    return InvestmentFormState(
      editingId: editingId ?? this.editingId,
      partnerId: partnerId ?? this.partnerId,
      amount: amount ?? this.amount,
      contributionType: contributionType ?? this.contributionType,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      contributionDate: contributionDate ?? this.contributionDate,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      notes: notes ?? this.notes,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage ?? this.errorMessage,
      validationErrors: validationErrors ?? this.validationErrors,
    );
  }
}

final investmentFormViewModelProvider =
    NotifierProvider.family<
      InvestmentFormViewModel,
      InvestmentFormState,
      String
    >((fairId) => InvestmentFormViewModel(fairId));

class InvestmentFormViewModel extends Notifier<InvestmentFormState> {
  InvestmentFormViewModel(this.fairId);

  final String fairId;
  final _uuid = const Uuid();

  @override
  InvestmentFormState build() {
    return InvestmentFormState(contributionDate: DateTime.now());
  }

  void loadForEdit(Investment investment) {
    state = InvestmentFormState(
      editingId: investment.id,
      partnerId: investment.partnerId,
      amount: investment.amount.toStringAsFixed(0),
      contributionType: investment.contributionType,
      paymentMethod: investment.paymentMethod,
      contributionDate: investment.contributionDate,
      referenceNumber: investment.referenceNumber ?? '',
      notes: investment.notes,
    );
  }

  void reset({String? defaultPartnerId}) {
    state = InvestmentFormState(
      partnerId: defaultPartnerId ?? '',
      contributionDate: DateTime.now(),
    );
  }

  void setPartnerId(String val) => state = state.copyWith(partnerId: val);
  void setAmount(String val) => state = state.copyWith(amount: val);
  void setContributionType(ContributionType val) =>
      state = state.copyWith(contributionType: val);
  void setPaymentMethod(PaymentMethod val) =>
      state = state.copyWith(paymentMethod: val);
  void setContributionDate(DateTime val) =>
      state = state.copyWith(contributionDate: val);
  void setReferenceNumber(String val) =>
      state = state.copyWith(referenceNumber: val);
  void setNotes(String val) => state = state.copyWith(notes: val);

  bool validate() {
    final errors = <String, String>{};

    if (state.partnerId.trim().isEmpty) {
      errors['partnerId'] = 'Please select a contributing partner';
    }

    final parsed = double.tryParse(state.amount.trim());
    if (state.amount.trim().isEmpty) {
      errors['amount'] = 'Contribution amount is required';
    } else if (parsed == null || parsed <= 0) {
      errors['amount'] = 'Amount must be greater than zero';
    }

    if (state.contributionDate == null) {
      errors['date'] = 'Contribution date is required';
    }

    state = state.copyWith(validationErrors: errors);
    return errors.isEmpty;
  }

  Future<bool> submit() async {
    if (!validate() || state.isSubmitting) return false;

    state = state.copyWith(isSubmitting: true, errorMessage: null);

    try {
      final repo = ref.read(investmentRepositoryProvider);
      final amountPaise = FinancialCalculator.parseToPaise(state.amount);
      final now = DateTime.now();

      if (state.isEditMode) {
        final existing = await repo.getInvestmentById(state.editingId!);
        final updated = Investment(
          id: state.editingId!,
          fairId: fairId,
          partnerId: state.partnerId,
          amountPaise: amountPaise,
          contributionType: state.contributionType,
          paymentMethod: state.paymentMethod,
          contributionDate: state.contributionDate ?? now,
          referenceNumber: state.referenceNumber.trim().isEmpty
              ? null
              : state.referenceNumber.trim(),
          notes: state.notes.trim(),
          createdAt: existing?.createdAt ?? now,
          updatedAt: now,
        );
        await repo.updateInvestment(updated);
      } else {
        final newInvestment = Investment(
          id: _uuid.v4(),
          fairId: fairId,
          partnerId: state.partnerId,
          amountPaise: amountPaise,
          contributionType: state.contributionType,
          paymentMethod: state.paymentMethod,
          contributionDate: state.contributionDate ?? now,
          referenceNumber: state.referenceNumber.trim().isEmpty
              ? null
              : state.referenceNumber.trim(),
          notes: state.notes.trim(),
          createdAt: now,
          updatedAt: now,
        );
        await repo.addInvestment(newInvestment);
      }

      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> deleteInvestment(String id) async {
    try {
      final repo = ref.read(investmentRepositoryProvider);
      await repo.deleteInvestment(id);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }
}
