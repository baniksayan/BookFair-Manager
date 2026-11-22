import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/components/app_button.dart';
import '../../../../core/components/app_card.dart';
import '../../../../core/components/app_dropdown.dart';
import '../../../../core/components/app_loading.dart';
import '../../../../core/components/app_snackbar.dart';
import '../../../../core/components/app_text_field.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../view_models/cashbook_providers.dart';
import '../view_models/transfer_funds_view_model.dart';

/// Screen 03: Coordinated Fund Transfers between cashbook accounts with atomic balance integrity.
class TransferFundsScreen extends ConsumerStatefulWidget {
  const TransferFundsScreen({super.key});

  @override
  ConsumerState<TransferFundsScreen> createState() =>
      _TransferFundsScreenState();
}

class _TransferFundsScreenState extends ConsumerState<TransferFundsScreen> {
  late final TextEditingController _amountController;
  late final TextEditingController _refController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _refController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _refController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    final transferState = ref.watch(transferFundsViewModelProvider);
    final transferVm = ref.read(transferFundsViewModelProvider.notifier);
    final accountsAsync = ref.watch(cashbookAccountsStreamProvider(null));

    return Scaffold(
      appBar: AppBar(title: const Text('Transfer Funds')),
      body: SafeArea(
        child: ResponsiveContentContainer(
          child: accountsAsync.when(
            loading: () => const Center(
              child: AppLoadingIndicator.large(
                message: 'Loading account balances...',
              ),
            ),
            error: (err, _) => Center(
              child: Text(
                'Failed to load accounts: $err',
                style: TextStyle(color: colors.error),
              ),
            ),
            data: (accounts) {
              final activeAccounts = accounts.where((a) => a.isActive).toList();

              return SingleChildScrollView(
                padding: AppSpacing.insetAll16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Information Notice
                    AppCard(
                      padding: AppSpacing.insetAll12,
                      backgroundColor: colors.primary.withValues(alpha: 0.1),
                      borderColor: colors.primary.withValues(alpha: 0.3),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: colors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.s12),
                          Expanded(
                            child: Text(
                              'Internal transfers shift balances between cash, bank, or UPI without modifying total business capital or creating expenses.',
                              style: textTheme.bodySmall?.copyWith(
                                color: colors.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s16),

                    if (transferState.errorMessage != null) ...[
                      Container(
                        padding: AppSpacing.insetAll12,
                        decoration: BoxDecoration(
                          color: colors.error.withValues(alpha: 0.1),
                          borderRadius: AppRadius.brMedium,
                          border: Border.all(color: colors.error),
                        ),
                        child: Text(
                          transferState.errorMessage!,
                          style: TextStyle(color: colors.error),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s16),
                    ],

                    // Source Account
                    AppDropdown<String>(
                      label: 'Source Account (From) *',
                      hint: 'Select account to transfer funds from',
                      value: transferState.fromAccountId.isNotEmpty
                          ? transferState.fromAccountId
                          : null,
                      errorText:
                          transferState.validationErrors['fromAccountId'],
                      items: activeAccounts
                          .map(
                            (a) => DropdownMenuItem(
                              value: a.id,
                              child: Text(
                                '${a.accountName} (Available: ₹${a.currentBalance.toStringAsFixed(2)})',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) transferVm.setFromAccountId(val);
                      },
                    ),
                    const SizedBox(height: AppSpacing.s16),

                    // Destination Account
                    AppDropdown<String>(
                      label: 'Destination Account (To) *',
                      hint: 'Select account to receive funds',
                      value: transferState.toAccountId.isNotEmpty
                          ? transferState.toAccountId
                          : null,
                      errorText: transferState.validationErrors['toAccountId'],
                      items: activeAccounts
                          .map(
                            (a) => DropdownMenuItem(
                              value: a.id,
                              child: Text(
                                '${a.accountName} (Available: ₹${a.currentBalance.toStringAsFixed(2)})',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) transferVm.setToAccountId(val);
                      },
                    ),
                    const SizedBox(height: AppSpacing.s16),

                    // Amount
                    AppTextField(
                      controller: _amountController,
                      label: 'Transfer Amount (₹) *',
                      hint: '0.00',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      prefixIcon: const Icon(
                        Icons.currency_rupee_rounded,
                        size: 18,
                      ),
                      errorText: transferState.validationErrors['amount'],
                      onChanged: transferVm.setAmount,
                    ),
                    const SizedBox(height: AppSpacing.s16),

                    // Date Picker
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Transfer Date *',
                          style: textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s6),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate:
                                  transferState.transferDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                            );
                            if (picked != null) {
                              transferVm.setTransferDate(picked);
                            }
                          },
                          child: Container(
                            height: 52,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s12,
                            ),
                            decoration: BoxDecoration(
                              color: colors.surfaceContainer,
                              borderRadius: AppRadius.brMedium,
                              border: Border.all(color: colors.borderSubtle),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: 18,
                                  color: colors.primary,
                                ),
                                const SizedBox(width: AppSpacing.s8),
                                Text(
                                  transferState.transferDate != null
                                      ? '${transferState.transferDate!.day}/${transferState.transferDate!.month}/${transferState.transferDate!.year}'
                                      : 'Select Date',
                                  style: textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s16),

                    // Reference
                    AppTextField(
                      controller: _refController,
                      label: 'Reference / Cheque / Txn ID',
                      hint: 'e.g. ATM withdrawal slip or bank ref',
                      onChanged: transferVm.setReferenceNumber,
                    ),
                    const SizedBox(height: AppSpacing.s16),

                    // Notes
                    AppTextField(
                      controller: _notesController,
                      label: 'Notes / Reason',
                      hint: 'e.g. Replenishing counter cashbox from bank',
                      maxLines: 2,
                      onChanged: transferVm.setNotes,
                    ),
                    const SizedBox(height: AppSpacing.s24),

                    // Submit Button
                    AppButton(
                      text: 'Confirm & Transfer Funds',
                      icon: Icons.check_circle_outline_rounded,
                      isLoading: transferState.isSubmitting,
                      isFullWidth: true,
                      onPressed: () async {
                        final success = await transferVm.executeTransfer();
                        if (!context.mounted) return;
                        if (success) {
                          AppSnackbar.showSuccess(
                            context,
                            'Funds transferred successfully',
                          );
                          context.pop();
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.s32),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
