import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/components/app_bottom_sheet.dart';
import '../../../../core/components/app_button.dart';
import '../../../../core/components/app_dropdown.dart';
import '../../../../core/components/app_snackbar.dart';
import '../../../../core/components/app_text_field.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../domain/entities/investment.dart';
import '../view_models/book_fair_providers.dart';
import '../view_models/investment_view_model.dart';

/// Modal bottom sheet to record an investment transaction for a fair.
class RecordInvestmentSheet extends ConsumerStatefulWidget {
  const RecordInvestmentSheet({
    super.key,
    required this.fairId,
    this.preselectedPartnerId,
    this.investmentToEdit,
  });

  final String fairId;
  final String? preselectedPartnerId;
  final Investment? investmentToEdit;

  static Future<void> show({
    required BuildContext context,
    required String fairId,
    String? preselectedPartnerId,
    Investment? investmentToEdit,
  }) {
    return AppBottomSheet.show(
      context: context,
      title: investmentToEdit != null
          ? 'Edit Capital Contribution'
          : 'Record Capital Contribution',
      subtitle: 'Log partner capital or in-kind inventory for this stall',
      child: RecordInvestmentSheet(
        fairId: fairId,
        preselectedPartnerId: preselectedPartnerId,
        investmentToEdit: investmentToEdit,
      ),
    );
  }

  @override
  ConsumerState<RecordInvestmentSheet> createState() =>
      _RecordInvestmentSheetState();
}

class _RecordInvestmentSheetState extends ConsumerState<RecordInvestmentSheet> {
  final _amountController = TextEditingController();
  final _refController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = ref.read(
        investmentFormViewModelProvider(widget.fairId).notifier,
      );
      if (widget.investmentToEdit != null) {
        vm.loadForEdit(widget.investmentToEdit!);
        _amountController.text = widget.investmentToEdit!.amount
            .toStringAsFixed(0);
        _refController.text = widget.investmentToEdit!.referenceNumber ?? '';
        _notesController.text = widget.investmentToEdit!.notes;
      } else {
        vm.reset(defaultPartnerId: widget.preselectedPartnerId);
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _refController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final state = ref.read(investmentFormViewModelProvider(widget.fairId));
    final initial = state.contributionDate ?? DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) =>
          Theme(data: Theme.of(context), child: child!),
    );

    if (picked != null) {
      ref
          .read(investmentFormViewModelProvider(widget.fairId).notifier)
          .setContributionDate(picked);
    }
  }

  Future<void> _handleSubmit() async {
    final vm = ref.read(
      investmentFormViewModelProvider(widget.fairId).notifier,
    );
    final success = await vm.submit();

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop();
      AppSnackbar.show(
        context,
        message: 'Capital contribution recorded in fair ledger.',
        variant: AppSnackbarVariant.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final state = ref.watch(investmentFormViewModelProvider(widget.fairId));
    final vm = ref.read(
      investmentFormViewModelProvider(widget.fairId).notifier,
    );
    final partnersAsync = ref.watch(
      partnersForFairStreamProvider(widget.fairId),
    );

    return partnersAsync.when(
      loading: () => const Padding(
        padding: AppSpacing.insetAll32,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Padding(
        padding: AppSpacing.insetAll32,
        child: Text('Error loading partners: $err'),
      ),
      data: (partners) {
        if (partners.isEmpty) {
          return Padding(
            padding: AppSpacing.insetAll24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.person_add_disabled_outlined,
                  size: 40.0,
                  color: colors.warning,
                ),
                AppSpacing.gapH12,
                Text(
                  'No Partners Registered',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                AppSpacing.gapH8,
                Text(
                  'You must add at least one partner to this fair before recording contributions.',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                AppSpacing.gapH24,
                AppButton(
                  text: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  size: AppButtonSize.small,
                ),
              ],
            ),
          );
        }

        final selectedPartnerId = state.partnerId.isNotEmpty
            ? state.partnerId
            : partners.first.id;

        return SingleChildScrollView(
          padding: AppSpacing.insetAll20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Contributing Partner Dropdown
              AppDropdown<String>(
                label: 'Contributing Partner',
                value: selectedPartnerId,
                prefixIcon: Icon(
                  Icons.person_outline_rounded,
                  color: colors.textSecondary,
                  size: 20.0,
                ),
                errorText: state.validationErrors['partnerId'],
                items: partners.map((p) {
                  return DropdownMenuItem(
                    value: p.id,
                    child: Text('${p.fullName} (${p.role.displayName})'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) vm.setPartnerId(val);
                },
              ),
              AppSpacing.gapH16,

              // Amount
              AppTextField(
                controller: _amountController,
                label: 'Contribution Amount (₹)',
                hint: 'e.g. 50000',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                prefixIcon: Icon(
                  Icons.currency_rupee_rounded,
                  color: colors.textSecondary,
                  size: 20.0,
                ),
                errorText: state.validationErrors['amount'],
                onChanged: vm.setAmount,
              ),
              AppSpacing.gapH16,

              // Contribution Type & Payment Method
              Row(
                children: [
                  Expanded(
                    child: AppDropdown<ContributionType>(
                      label: 'Contribution Type',
                      value: state.contributionType,
                      items: ContributionType.values.map((t) {
                        return DropdownMenuItem(
                          value: t,
                          child: Text(t.displayName),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) vm.setContributionType(val);
                      },
                    ),
                  ),
                  AppSpacing.gapW12,
                  Expanded(
                    child: AppDropdown<PaymentMethod>(
                      label: 'Payment Method',
                      value: state.paymentMethod,
                      items: PaymentMethod.values.map((m) {
                        return DropdownMenuItem(
                          value: m,
                          child: Text(m.displayName),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) vm.setPaymentMethod(val);
                      },
                    ),
                  ),
                ],
              ),
              AppSpacing.gapH16,

              // Date & Reference
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _selectDate(context),
                      child: AbsorbPointer(
                        child: AppTextField(
                          key: ValueKey(state.contributionDate),
                          label: 'Transaction Date',
                          hint: state.contributionDate != null
                              ? DateFormatter.formatDisplay(
                                  state.contributionDate!,
                                )
                              : 'Select date',
                          prefixIcon: Icon(
                            Icons.calendar_today_outlined,
                            color: colors.textSecondary,
                            size: 18.0,
                          ),
                          errorText: state.validationErrors['date'],
                          readOnly: true,
                        ),
                      ),
                    ),
                  ),
                  AppSpacing.gapW12,
                  Expanded(
                    child: AppTextField(
                      controller: _refController,
                      label: 'Reference # (Optional)',
                      hint: 'e.g. UPI-928371',
                      onChanged: vm.setReferenceNumber,
                    ),
                  ),
                ],
              ),
              AppSpacing.gapH16,

              // Notes
              AppTextField(
                controller: _notesController,
                label: 'Notes / Valuation Details',
                hint: 'e.g. Received for bulk classic reprint batch purchase',
                maxLines: 2,
                onChanged: vm.setNotes,
              ),
              AppSpacing.gapH24,

              // Submit Button
              AppButton(
                text: state.isEditMode
                    ? 'Update Contribution'
                    : 'Record Contribution',
                onPressed: _handleSubmit,
                isLoading: state.isSubmitting,
                isFullWidth: true,
                size: AppButtonSize.large,
                icon: Icons.check_circle_outline_rounded,
              ),
              AppSpacing.gapH16,
            ],
          ),
        );
      },
    );
  }
}
