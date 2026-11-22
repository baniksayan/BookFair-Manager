import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/partner.dart';
import 'book_fair_providers.dart';

class PartnerFormState {
  const PartnerFormState({
    this.editingId,
    this.fullName = '',
    this.phoneNumber = '',
    this.email = '',
    this.role = PartnerRole.partner,
    this.profitSharingPercentage = '',
    this.notes = '',
    this.isSubmitting = false,
    this.errorMessage,
    this.validationErrors = const {},
  });

  final String? editingId;
  final String fullName;
  final String phoneNumber;
  final String email;
  final PartnerRole role;
  final String profitSharingPercentage;
  final String notes;
  final bool isSubmitting;
  final String? errorMessage;
  final Map<String, String> validationErrors;

  bool get isEditMode => editingId != null;

  PartnerFormState copyWith({
    String? editingId,
    String? fullName,
    String? phoneNumber,
    String? email,
    PartnerRole? role,
    String? profitSharingPercentage,
    String? notes,
    bool? isSubmitting,
    String? errorMessage,
    Map<String, String>? validationErrors,
  }) {
    return PartnerFormState(
      editingId: editingId ?? this.editingId,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      role: role ?? this.role,
      profitSharingPercentage:
          profitSharingPercentage ?? this.profitSharingPercentage,
      notes: notes ?? this.notes,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage ?? this.errorMessage,
      validationErrors: validationErrors ?? this.validationErrors,
    );
  }
}

final partnerFormViewModelProvider =
    NotifierProvider.family<PartnerFormViewModel, PartnerFormState, String>(
      (fairId) => PartnerFormViewModel(fairId),
    );

class PartnerFormViewModel extends Notifier<PartnerFormState> {
  PartnerFormViewModel(this.fairId);

  final String fairId;
  final _uuid = const Uuid();

  @override
  PartnerFormState build() => const PartnerFormState();

  void loadForEdit(Partner partner) {
    state = PartnerFormState(
      editingId: partner.id,
      fullName: partner.fullName,
      phoneNumber: partner.phoneNumber ?? '',
      email: partner.email ?? '',
      role: partner.role,
      profitSharingPercentage: partner.profitSharingPercentage != null
          ? partner.profitSharingPercentage!.toString()
          : '',
      notes: partner.notes,
    );
  }

  void reset() => state = const PartnerFormState();

  void setFullName(String val) => state = state.copyWith(fullName: val);
  void setPhoneNumber(String val) => state = state.copyWith(phoneNumber: val);
  void setEmail(String val) => state = state.copyWith(email: val);
  void setRole(PartnerRole role) => state = state.copyWith(role: role);
  void setProfitSharingPercentage(String val) =>
      state = state.copyWith(profitSharingPercentage: val);
  void setNotes(String val) => state = state.copyWith(notes: val);

  bool validate() {
    final errors = <String, String>{};

    if (state.fullName.trim().isEmpty) {
      errors['fullName'] = 'Partner full name is required';
    }

    if (state.email.trim().isNotEmpty) {
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(state.email.trim())) {
        errors['email'] = 'Enter a valid email address';
      }
    }

    if (state.profitSharingPercentage.trim().isNotEmpty) {
      final pct = double.tryParse(state.profitSharingPercentage.trim());
      if (pct == null || pct < 0 || pct > 100) {
        errors['profitSharing'] = 'Enter a valid percentage between 0 and 100';
      }
    }

    state = state.copyWith(validationErrors: errors);
    return errors.isEmpty;
  }

  Future<bool> submit() async {
    if (!validate() || state.isSubmitting) return false;

    state = state.copyWith(isSubmitting: true, errorMessage: null);

    try {
      final repo = ref.read(partnerRepositoryProvider);
      final now = DateTime.now();

      final pct = double.tryParse(state.profitSharingPercentage.trim());

      if (state.isEditMode) {
        final existing = await repo.getPartnerById(state.editingId!);
        final updated = Partner(
          id: state.editingId!,
          fairId: fairId,
          fullName: state.fullName.trim(),
          phoneNumber: state.phoneNumber.trim().isEmpty
              ? null
              : state.phoneNumber.trim(),
          email: state.email.trim().isEmpty ? null : state.email.trim(),
          role: state.role,
          joinedAt: existing?.joinedAt ?? now,
          profitSharingPercentage: pct,
          notes: state.notes.trim(),
          isActive: existing?.isActive ?? true,
          createdAt: existing?.createdAt ?? now,
          updatedAt: now,
        );
        await repo.updatePartner(updated);
      } else {
        final newPartner = Partner(
          id: _uuid.v4(),
          fairId: fairId,
          fullName: state.fullName.trim(),
          phoneNumber: state.phoneNumber.trim().isEmpty
              ? null
              : state.phoneNumber.trim(),
          email: state.email.trim().isEmpty ? null : state.email.trim(),
          role: state.role,
          joinedAt: now,
          profitSharingPercentage: pct,
          notes: state.notes.trim(),
          isActive: true,
          createdAt: now,
          updatedAt: now,
        );
        await repo.addPartner(newPartner);
      }

      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> deletePartner(String partnerId, {bool force = false}) async {
    try {
      final repo = ref.read(partnerRepositoryProvider);
      await repo.deletePartner(partnerId, force: force);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }
}
