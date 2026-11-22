import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/supplier.dart';
import 'inventory_providers.dart';

class SupplierFormState {
  const SupplierFormState({
    this.editingId,
    this.name = '',
    this.contactNumber = '',
    this.email = '',
    this.address = '',
    this.notes = '',
    this.isSubmitting = false,
    this.errorMessage,
    this.validationErrors = const {},
  });

  final String? editingId;
  final String name;
  final String contactNumber;
  final String email;
  final String address;
  final String notes;
  final bool isSubmitting;
  final String? errorMessage;
  final Map<String, String> validationErrors;

  bool get isEditMode => editingId != null;

  SupplierFormState copyWith({
    String? editingId,
    String? name,
    String? contactNumber,
    String? email,
    String? address,
    String? notes,
    bool? isSubmitting,
    String? errorMessage,
    Map<String, String>? validationErrors,
  }) {
    return SupplierFormState(
      editingId: editingId ?? this.editingId,
      name: name ?? this.name,
      contactNumber: contactNumber ?? this.contactNumber,
      email: email ?? this.email,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage ?? this.errorMessage,
      validationErrors: validationErrors ?? this.validationErrors,
    );
  }
}

final supplierViewModelProvider =
    NotifierProvider<SupplierViewModel, SupplierFormState>(
      SupplierViewModel.new,
    );

class SupplierViewModel extends Notifier<SupplierFormState> {
  static const _uuid = Uuid();

  @override
  SupplierFormState build() => const SupplierFormState();

  void loadForEdit(Supplier supplier) {
    state = SupplierFormState(
      editingId: supplier.id,
      name: supplier.name,
      contactNumber: supplier.contactNumber ?? '',
      email: supplier.email ?? '',
      address: supplier.address ?? '',
      notes: supplier.notes,
    );
  }

  void reset() => state = const SupplierFormState();

  void setName(String val) => state = state.copyWith(name: val);
  void setContactNumber(String val) =>
      state = state.copyWith(contactNumber: val);
  void setEmail(String val) => state = state.copyWith(email: val);
  void setAddress(String val) => state = state.copyWith(address: val);
  void setNotes(String val) => state = state.copyWith(notes: val);

  bool validate() {
    final errors = <String, String>{};
    if (state.name.trim().isEmpty) {
      errors['name'] = 'Supplier / Vendor name is required.';
    }
    state = state.copyWith(validationErrors: errors);
    return errors.isEmpty;
  }

  Future<bool> submit() async {
    if (!validate() || state.isSubmitting) return false;

    state = state.copyWith(isSubmitting: true, errorMessage: null);

    try {
      final repo = ref.read(inventoryRepositoryProvider);
      final now = DateTime.now();

      if (state.isEditMode) {
        final existing = await repo.getSupplierById(state.editingId!);
        final updated = Supplier(
          id: state.editingId!,
          name: state.name.trim(),
          contactNumber: state.contactNumber.trim().isNotEmpty
              ? state.contactNumber.trim()
              : null,
          email: state.email.trim().isNotEmpty ? state.email.trim() : null,
          address: state.address.trim().isNotEmpty
              ? state.address.trim()
              : null,
          notes: state.notes.trim(),
          createdAt: existing?.createdAt ?? now,
          updatedAt: now,
        );
        await repo.updateSupplier(updated);
      } else {
        final newSupplier = Supplier(
          id: _uuid.v4(),
          name: state.name.trim(),
          contactNumber: state.contactNumber.trim().isNotEmpty
              ? state.contactNumber.trim()
              : null,
          email: state.email.trim().isNotEmpty ? state.email.trim() : null,
          address: state.address.trim().isNotEmpty
              ? state.address.trim()
              : null,
          notes: state.notes.trim(),
          createdAt: now,
          updatedAt: now,
        );
        await repo.createSupplier(newSupplier);
      }

      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> deleteSupplier(String id) async {
    try {
      final repo = ref.read(inventoryRepositoryProvider);
      await repo.deleteSupplier(id);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }
}
