import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/financial_draft_manager.dart';
import 'cashbook_providers.dart';

class TransferFundsState {
  const TransferFundsState({
    this.clientRequestId = '',
    this.fairId,
    this.fromAccountId = '',
    this.toAccountId = '',
    this.amount = '',
    this.transferDate,
    this.referenceNumber = '',
    this.notes = '',
    this.isSubmitting = false,
    this.errorMessage,
    this.validationErrors = const {},
  });

  final String clientRequestId;
  final String? fairId;
  final String fromAccountId;
  final String toAccountId;
  final String amount;
  final DateTime? transferDate;
  final String referenceNumber;
  final String notes;
  final bool isSubmitting;
  final String? errorMessage;
  final Map<String, String> validationErrors;

  TransferFundsState copyWith({
    String? clientRequestId,
    String? fairId,
    String? fromAccountId,
    String? toAccountId,
    String? amount,
    DateTime? transferDate,
    String? referenceNumber,
    String? notes,
    bool? isSubmitting,
    String? errorMessage,
    Map<String, String>? validationErrors,
  }) {
    return TransferFundsState(
      clientRequestId: clientRequestId ?? this.clientRequestId,
      fairId: fairId ?? this.fairId,
      fromAccountId: fromAccountId ?? this.fromAccountId,
      toAccountId: toAccountId ?? this.toAccountId,
      amount: amount ?? this.amount,
      transferDate: transferDate ?? this.transferDate,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      notes: notes ?? this.notes,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
      validationErrors: validationErrors ?? this.validationErrors,
    );
  }
}

final transferFundsViewModelProvider =
    NotifierProvider<TransferFundsViewModel, TransferFundsState>(
      () => TransferFundsViewModel(),
    );

class TransferFundsViewModel extends Notifier<TransferFundsState> {
  final _uuid = const Uuid();

  @override
  TransferFundsState build() {
    final clientReqId = FinancialDraftManager.getOrCreateClientRequestId(
      operationType: 'transfer',
      entityId: 'default',
    );

    return TransferFundsState(
      clientRequestId: clientReqId,
      transferDate: DateTime.now(),
    );
  }

  void setFairId(String? val) {
    final entityId = val?.trim().isNotEmpty == true ? val!.trim() : 'default';
    final clientReqId = FinancialDraftManager.getOrCreateClientRequestId(
      operationType: 'transfer',
      entityId: entityId,
    );

    state = state.copyWith(fairId: val, clientRequestId: clientReqId);
  }

  void setFromAccountId(String val) =>
      state = state.copyWith(fromAccountId: val);
  void setToAccountId(String val) => state = state.copyWith(toAccountId: val);
  void setAmount(String val) => state = state.copyWith(amount: val);
  void setTransferDate(DateTime val) =>
      state = state.copyWith(transferDate: val);
  void setReferenceNumber(String val) =>
      state = state.copyWith(referenceNumber: val);
  void setNotes(String val) => state = state.copyWith(notes: val);

  void reset() {
    final newId = _uuid.v4();
    final entityId = state.fairId?.trim().isNotEmpty == true
        ? state.fairId!.trim()
        : 'default';
    FinancialDraftManager.getOrCreateClientRequestId(
      operationType: 'transfer',
      entityId: entityId,
    );
    state = TransferFundsState(
      clientRequestId: newId,
      fairId: state.fairId,
      transferDate: DateTime.now(),
    );
  }

  bool validate() {
    final errors = <String, String>{};

    if (state.fromAccountId.trim().isEmpty) {
      errors['fromAccountId'] = 'Select source account to transfer from';
    }
    if (state.toAccountId.trim().isEmpty) {
      errors['toAccountId'] = 'Select destination account to transfer into';
    }
    if (state.fromAccountId.isNotEmpty &&
        state.toAccountId.isNotEmpty &&
        state.fromAccountId == state.toAccountId) {
      errors['toAccountId'] =
          'Source and destination accounts must be different';
    }

    final amountNum = double.tryParse(state.amount);
    if (amountNum == null || amountNum <= 0) {
      errors['amount'] = 'Enter a valid transfer amount greater than zero';
    }

    state = state.copyWith(validationErrors: errors);
    return errors.isEmpty;
  }

  Future<bool> executeTransfer() async {
    if (!validate()) return false;

    state = state.copyWith(isSubmitting: true, errorMessage: null);

    try {
      final repo = ref.read(cashbookRepositoryProvider);
      final amountPaise = ((double.tryParse(state.amount) ?? 0.0) * 100)
          .round();

      // Check balance
      final source = await repo.getAccountById(state.fromAccountId);
      if (source == null) {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: 'Source account not found',
        );
        return false;
      }

      if (source.currentBalancePaise < amountPaise) {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage:
              'Insufficient balance in ${source.accountName}. Available: ₹${source.currentBalance.toStringAsFixed(2)}',
        );
        return false;
      }

      await repo.transferFunds(
        fairId: state.fairId ?? source.fairId,
        fromAccountId: state.fromAccountId,
        toAccountId: state.toAccountId,
        amountPaise: amountPaise,
        transferDate: state.transferDate ?? DateTime.now(),
        referenceNumber: state.referenceNumber.trim().isNotEmpty
            ? state.referenceNumber.trim()
            : null,
        notes: state.notes.trim().isNotEmpty ? state.notes.trim() : null,
        clientRequestId: state.clientRequestId,
      );

      // On successful transfer, clear the draft entry
      final entityId = state.fairId?.trim().isNotEmpty == true
          ? state.fairId!.trim()
          : (source.fairId.trim().isNotEmpty
                ? source.fairId.trim()
                : 'default');
      await FinancialDraftManager.clearDraft(
        operationType: 'transfer',
        entityId: entityId,
      );

      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.toString());
      return false;
    }
  }
}
