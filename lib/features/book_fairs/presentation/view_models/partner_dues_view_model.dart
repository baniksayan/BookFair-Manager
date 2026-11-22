import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/financial_draft_manager.dart';
import '../../../cashbook/presentation/view_models/cashbook_providers.dart';
import '../../../payments/domain/entities/payment_record.dart';
import '../../../payments/presentation/view_models/payment_providers.dart';

class PartnerDuesState {
  const PartnerDuesState({this.isSubmitting = false, this.errorMessage});

  final bool isSubmitting;
  final String? errorMessage;

  PartnerDuesState copyWith({bool? isSubmitting, String? errorMessage}) {
    return PartnerDuesState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
    );
  }
}

final partnerDuesViewModelProvider =
    NotifierProvider.family<PartnerDuesViewModel, PartnerDuesState, String>(
      (fairId) => PartnerDuesViewModel(fairId),
    );

class PartnerDuesViewModel extends Notifier<PartnerDuesState> {
  PartnerDuesViewModel(this.fairId);

  final String fairId;

  @override
  PartnerDuesState build() => const PartnerDuesState();

  Future<bool> settleReimbursement({
    required String partnerId,
    required double amount,
    required String fromAccountId,
    required String paymentMethod,
    String? referenceNumber,
    String? notes,
  }) async {
    final amountPaise = (amount * 100).round();
    if (amountPaise <= 0) {
      state = state.copyWith(
        errorMessage: 'Enter a valid reimbursement amount',
      );
      return false;
    }

    state = state.copyWith(isSubmitting: true, errorMessage: null);

    try {
      final cashbookRepo = ref.read(cashbookRepositoryProvider);
      final paymentRepo = ref.read(paymentRepositoryProvider);

      final account = await cashbookRepo.getAccountById(fromAccountId);
      if (account == null) {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: 'Selected payment account was not found',
        );
        return false;
      }

      if (account.currentBalancePaise < amountPaise) {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage:
              'Insufficient funds in ${account.accountName}. Available: ₹${account.currentBalance.toStringAsFixed(2)}',
        );
        return false;
      }

      final clientReqId = FinancialDraftManager.getOrCreateClientRequestId(
        operationType: 'reimbursement',
        entityId: partnerId,
      );

      final payment = PaymentRecord(
        id: clientReqId,
        fairId: fairId,
        relatedEntityType: 'reimbursement',
        relatedEntityId: partnerId,
        amountPaise: amountPaise,
        paymentDate: DateTime.now(),
        paymentMethod: paymentMethod,
        accountId: fromAccountId,
        recipientPartnerId: partnerId,
        referenceNumber: referenceNumber?.trim().isNotEmpty == true
            ? referenceNumber!.trim()
            : null,
        notes: notes?.trim().isNotEmpty == true
            ? notes!.trim()
            : 'Settled partner reimbursement',
        createdAt: DateTime.now(),
      );

      await paymentRepo.recordPayment(payment, clientRequestId: clientReqId);

      await FinancialDraftManager.clearDraft(
        operationType: 'reimbursement',
        entityId: partnerId,
      );

      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.toString());
      return false;
    }
  }
}
