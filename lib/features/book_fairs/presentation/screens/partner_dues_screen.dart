import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/components/app_badge.dart';
import '../../../../core/components/app_button.dart';
import '../../../../core/components/app_card.dart';
import '../../../../core/components/app_dropdown.dart';
import '../../../../core/components/app_empty_state.dart';
import '../../../../core/components/app_loading.dart';
import '../../../../core/components/app_snackbar.dart';
import '../../../../core/components/app_text_field.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../../accounting/domain/models/financial_models.dart';
import '../../../accounting/presentation/view_models/accounting_providers.dart';
import '../../../cashbook/presentation/view_models/cashbook_providers.dart';
import '../view_models/book_fair_providers.dart';
import '../view_models/partner_dues_view_model.dart';

/// Screen: Partner Personal Outlays & Reimbursement Liability Management.
class PartnerDuesScreen extends ConsumerWidget {
  const PartnerDuesScreen({super.key, required this.fairId});

  final String fairId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    final fairAsync = ref.watch(bookFairDetailsStreamProvider(fairId));
    final partnerDues = ref.watch(partnerDuesProvider(fairId));

    final totalPersonallyPaid = partnerDues.fold<int>(
      0,
      (sum, p) => sum + p.personallyPaidPaise,
    );
    final totalReimbursed = partnerDues.fold<int>(
      0,
      (sum, p) => sum + p.reimbursedPaise,
    );
    final totalOutstanding = partnerDues.fold<int>(
      0,
      (sum, p) => sum + p.outstandingReimbursementPaise,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          fairAsync.value != null
              ? '${fairAsync.value!.name} — Partner Dues'
              : 'Partner Dues & Reimbursements',
        ),
      ),
      body: SafeArea(
        child: ResponsiveContentContainer(
          child: SingleChildScrollView(
            padding: AppSpacing.insetAll16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Explanatory Notice
                AppCard(
                  padding: AppSpacing.insetAll12,
                  backgroundColor: colors.primary.withValues(alpha: 0.08),
                  borderColor: colors.primary.withValues(alpha: 0.25),
                  child: Row(
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        color: colors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(
                        child: Text(
                          'Personal expense outlays paid by partners are business reimbursement liabilities. They do not alter capital investment ratios.',
                          style: textTheme.bodySmall?.copyWith(
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s16),

                // Overall Liability Summary Card
                AppCard(
                  padding: AppSpacing.insetAll16,
                  backgroundColor: colors.surfaceContainerHigh,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TOTAL REIMBURSEMENT LIABILITY',
                        style: textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceMuted,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      Text(
                        CurrencyFormatter.formatPaise(totalOutstanding),
                        style: textTheme.headlineMedium?.copyWith(
                          color: totalOutstanding > 0
                              ? colors.error
                              : colors.success,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryMetric(
                              label: 'Personally Incurred',
                              value: CurrencyFormatter.formatPaise(
                                totalPersonallyPaid,
                              ),
                              context: context,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 36,
                            color: colors.borderSubtle,
                            margin: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s8,
                            ),
                          ),
                          Expanded(
                            child: _buildSummaryMetric(
                              label: 'Settled Reimbursements',
                              value: CurrencyFormatter.formatPaise(
                                totalReimbursed,
                              ),
                              valueColor: colors.success,
                              context: context,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s24),

                // Partner-wise Breakdown
                Text(
                  'Partner Account Balances',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.s12),

                if (partnerDues.isEmpty) ...[
                  const AppEmptyState(
                    title: 'No Partners Registered',
                    description: 'Add business partners to track individual expense outlays and settlements.',
                    icon: Icons.people_outline_rounded,
                  ),
                ] else ...[
                  ...partnerDues.map(
                    (due) => _buildPartnerDueCard(
                      due: due,
                      context: context,
                      ref: ref,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.s32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryMetric({
    required String label,
    required String value,
    Color? valueColor,
    required BuildContext context,
  }) {
    final textTheme = context.textTheme;
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceMuted,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: AppSpacing.s4),
        Text(
          value,
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor ?? colors.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildPartnerDueCard({
    required PartnerDuesSummary due,
    required BuildContext context,
    required WidgetRef ref,
  }) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s12),
      child: AppCard(
        padding: AppSpacing.insetAll16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        due.partnerName,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.onSurface,
                        ),
                      ),
                      Text(
                        due.role,
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                AppBadge(
                  label: due.outstandingReimbursementPaise > 0
                      ? 'Reimbursement Due'
                      : 'All Settled',
                  variant: due.outstandingReimbursementPaise > 0
                      ? AppBadgeVariant.warning
                      : AppBadgeVariant.success,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s12),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.s12),

            Row(
              children: [
                Expanded(
                  child: _buildMetricCol(
                    label: 'Personal Outlay',
                    value: CurrencyFormatter.formatPaise(
                      due.personallyPaidPaise,
                    ),
                    context: context,
                  ),
                ),
                Expanded(
                  child: _buildMetricCol(
                    label: 'Reimbursed',
                    value: CurrencyFormatter.formatPaise(due.reimbursedPaise),
                    valueColor: colors.success,
                    context: context,
                  ),
                ),
                Expanded(
                  child: _buildMetricCol(
                    label: 'Outstanding Due',
                    value: CurrencyFormatter.formatPaise(
                      due.outstandingReimbursementPaise,
                    ),
                    valueColor: due.outstandingReimbursementPaise > 0
                        ? colors.error
                        : colors.onSurfaceMuted,
                    context: context,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Capital Invested: ${CurrencyFormatter.formatPaise(due.totalCapitalInvestedPaise)}',
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceMuted,
                  ),
                ),
                if (due.outstandingReimbursementPaise > 0)
                  AppButton(
                    text: 'Settle Reimbursement',
                    size: AppButtonSize.small,
                    icon: Icons.payments_rounded,
                    onPressed: () => _showSettleReimbursementModal(
                      context: context,
                      ref: ref,
                      due: due,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCol({
    required String label,
    required String value,
    Color? valueColor,
    required BuildContext context,
  }) {
    final textTheme = context.textTheme;
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceMuted,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: AppSpacing.s4),
        Text(
          value,
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor ?? colors.onSurface,
          ),
        ),
      ],
    );
  }

  void _showSettleReimbursementModal({
    required BuildContext context,
    required WidgetRef ref,
    required PartnerDuesSummary due,
  }) {
    final colors = context.colors;
    final amountController = TextEditingController(
      text: (due.outstandingReimbursementPaise / 100.0).toStringAsFixed(2),
    );
    final refController = TextEditingController();
    final notesController = TextEditingController();
    String method = 'Cash';
    String? selectedAccountId;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setState) {
            final accountsAsync = ref.watch(
              cashbookAccountsStreamProvider(fairId),
            );

            return Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.s16,
                right: AppSpacing.s16,
                top: AppSpacing.s20,
                bottom:
                    MediaQuery.of(sheetCtx).viewInsets.bottom + AppSpacing.s20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Settle Reimbursement to ${due.partnerName}',
                      style: sheetCtx.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    AppTextField(
                      controller: amountController,
                      label: 'Reimbursement Amount (₹) *',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      prefixIcon: const Icon(
                        Icons.currency_rupee_rounded,
                        size: 18,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    AppDropdown<String>(
                      label: 'Disbursement Method',
                      value: method,
                      items: const [
                        DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                        DropdownMenuItem(value: 'UPI', child: Text('UPI / QR')),
                        DropdownMenuItem(
                          value: 'Bank Transfer',
                          child: Text('Bank Transfer'),
                        ),
                        DropdownMenuItem(
                          value: 'Cheque',
                          child: Text('Cheque'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => method = val);
                      },
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    accountsAsync.when(
                      data: (accounts) {
                        final active = accounts
                            .where((a) => a.isActive)
                            .toList();
                        return AppDropdown<String>(
                          label: 'Pay From Business Account *',
                          hint: 'Select business cashbox or bank account',
                          value: selectedAccountId,
                          items: active
                              .map(
                                (a) => DropdownMenuItem(
                                  value: a.id,
                                  child: Text(
                                    '${a.accountName} (Available: ₹${a.currentBalance.toStringAsFixed(2)})',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) =>
                              setState(() => selectedAccountId = val),
                        );
                      },
                      loading: () => const AppLoadingIndicator.small(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    AppTextField(
                      controller: refController,
                      label: 'Reference Number',
                      hint: 'e.g. UPI Ref # or Cheque #',
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    AppTextField(
                      controller: notesController,
                      label: 'Notes',
                      hint: 'Reimbursement details...',
                    ),
                    const SizedBox(height: AppSpacing.s24),
                    AppButton(
                      text: 'Confirm Reimbursement Settlement',
                      isLoading: isSubmitting,
                      isFullWidth: true,
                      onPressed: () async {
                        final enteredAmount =
                            double.tryParse(amountController.text) ?? 0.0;
                        if (enteredAmount <= 0) {
                          AppSnackbar.showError(
                            sheetCtx,
                            'Enter an amount greater than zero',
                          );
                          return;
                        }
                        if (selectedAccountId == null ||
                            selectedAccountId!.isEmpty) {
                          AppSnackbar.showError(
                            sheetCtx,
                            'Please select a payment account',
                          );
                          return;
                        }

                        setState(() => isSubmitting = true);

                        final partnerDuesVm = ref.read(
                          partnerDuesViewModelProvider(fairId).notifier,
                        );

                        final success = await partnerDuesVm.settleReimbursement(
                          partnerId: due.partnerId,
                          amount: enteredAmount,
                          fromAccountId: selectedAccountId!,
                          paymentMethod: method,
                          referenceNumber: refController.text.trim(),
                          notes: notesController.text.trim(),
                        );

                        if (success && sheetCtx.mounted) {
                          Navigator.of(sheetCtx).pop();
                          if (context.mounted) {
                            AppSnackbar.showSuccess(
                              context,
                              'Reimbursement settled successfully',
                            );
                          }
                        } else {
                          setState(() => isSubmitting = false);
                          final err = ref
                              .read(partnerDuesViewModelProvider(fairId))
                              .errorMessage;
                          if (sheetCtx.mounted && err != null) {
                            AppSnackbar.showError(sheetCtx, err);
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
