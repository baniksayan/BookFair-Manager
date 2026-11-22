import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/components/app_badge.dart';
import '../../../../core/components/app_button.dart';
import '../../../../core/components/app_card.dart';
import '../../../../core/components/app_dropdown.dart';
import '../../../../core/components/app_loading.dart';
import '../../../../core/components/app_snackbar.dart';
import '../../../../core/components/app_text_field.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/financial_draft_manager.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../../book_fairs/presentation/view_models/book_fair_providers.dart';
import '../../../cashbook/presentation/view_models/cashbook_providers.dart';
import '../../../payments/domain/entities/payment_record.dart';
import '../../../payments/presentation/view_models/payment_providers.dart';
import '../../domain/entities/expense.dart';
import '../view_models/expense_providers.dart';

/// Screen 03: Comprehensive Expense Details with payment history & additional payment disbursements.
class ExpenseDetailsScreen extends ConsumerWidget {
  const ExpenseDetailsScreen({super.key, required this.expenseId});

  final String expenseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    final expenseAsync = ref.watch(expenseDetailsStreamProvider(expenseId));
    final categoriesAsync = ref.watch(expenseCategoriesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'Edit Expense',
            onPressed: () => context.pushNamed(
              RouteNames.editExpense,
              pathParameters: {'id': expenseId},
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveContentContainer(
          child: expenseAsync.when(
            loading: () => const Center(
              child: AppLoadingIndicator.large(
                message: 'Loading expense details...',
              ),
            ),
            error: (err, _) => Center(
              child: Text(
                'Failed to load expense: $err',
                style: TextStyle(color: colors.error),
              ),
            ),
            data: (expense) {
              if (expense == null) {
                return const Center(child: Text('Expense record not found'));
              }

              final categories = categoriesAsync.value ?? [];
              final category = categories.cast<dynamic>().firstWhere(
                (c) => c.id == expense.categoryId,
                orElse: () => null,
              );

              final fairAsync = ref.watch(
                bookFairDetailsStreamProvider(expense.fairId),
              );
              final fair = fairAsync.value;

              final paymentsAsync = ref.watch(
                paymentsStreamProvider((
                  fairId: expense.fairId,
                  relatedEntityType: 'expense',
                  relatedEntityId: expense.id,
                )),
              );

              AppBadgeVariant badgeVariant;
              if (expense.isPaid) {
                badgeVariant = AppBadgeVariant.success;
              } else if (expense.isPartiallyPaid) {
                badgeVariant = AppBadgeVariant.warning;
              } else if (expense.isCancelled) {
                badgeVariant = AppBadgeVariant.neutral;
              } else {
                badgeVariant = AppBadgeVariant.error;
              }

              return SingleChildScrollView(
                padding: AppSpacing.insetAll16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Title Card
                    AppCard(
                      padding: AppSpacing.insetAll16,
                      backgroundColor: colors.surfaceContainerHigh,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  expense.title,
                                  style: textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colors.onSurface,
                                  ),
                                ),
                              ),
                              AppBadge(
                                label: expense.paymentStatus,
                                variant: badgeVariant,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.s8),
                          Row(
                            children: [
                              Icon(
                                Icons.category_rounded,
                                size: 16,
                                color: colors.primary,
                              ),
                              const SizedBox(width: AppSpacing.s6),
                              Text(
                                category?.name ?? 'Operational Expense',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (fair != null) ...[
                                const SizedBox(width: AppSpacing.s8),
                                Text(
                                  '•',
                                  style: TextStyle(
                                    color: colors.onSurfaceMuted,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s8),
                                Expanded(
                                  child: Text(
                                    fair.name,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colors.onSurfaceMuted,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (expense.description.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.s12),
                            Text(
                              expense.description,
                              style: textTheme.bodyMedium?.copyWith(
                                color: colors.onSurfaceMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s16),

                    // Financial Summary Breakdown Card
                    AppCard(
                      padding: AppSpacing.insetAll16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FINANCIAL STATUS',
                            style: textTheme.labelSmall?.copyWith(
                              color: colors.onSurfaceMuted,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildAmountStat(
                                label: 'Total Obligation',
                                amount: CurrencyFormatter.formatPaise(
                                  expense.amountPaise,
                                ),
                                context: context,
                              ),
                              _buildAmountStat(
                                label: 'Paid Amount',
                                amount: CurrencyFormatter.formatPaise(
                                  expense.paidAmountPaise,
                                ),
                                valueColor: colors.success,
                                context: context,
                              ),
                              _buildAmountStat(
                                label: 'Outstanding',
                                amount: CurrencyFormatter.formatPaise(
                                  expense.outstandingAmountPaise,
                                ),
                                valueColor: expense.outstandingAmountPaise > 0
                                    ? colors.error
                                    : colors.onSurfaceMuted,
                                context: context,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s16),

                    // Audit Attributes Card
                    AppCard(
                      padding: AppSpacing.insetAll16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TRANSACTION ATTRIBUTES',
                            style: textTheme.labelSmall?.copyWith(
                              color: colors.onSurfaceMuted,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s12),
                          _buildDetailRow(
                            label: 'Expense Date',
                            value:
                                '${expense.expenseDate.day}/${expense.expenseDate.month}/${expense.expenseDate.year}',
                            context: context,
                          ),
                          _buildDetailRow(
                            label: 'Payment Method',
                            value: expense.paymentMethod,
                            context: context,
                          ),
                          if (expense.paidByPartnerId != null)
                            _buildDetailRow(
                              label: 'Paid Personally By',
                              value:
                                  'Partner Outlay (Liable for Reimbursement)',
                              context: context,
                            ),
                          if (expense.referenceNumber != null &&
                              expense.referenceNumber!.isNotEmpty)
                            _buildDetailRow(
                              label: 'Reference / Invoice',
                              value: expense.referenceNumber!,
                              context: context,
                            ),
                          if (expense.notes.isNotEmpty)
                            _buildDetailRow(
                              label: 'Notes',
                              value: expense.notes,
                              context: context,
                            ),
                          _buildDetailRow(
                            label: 'Created At',
                            value:
                                '${expense.createdAt.day}/${expense.createdAt.month}/${expense.createdAt.year} ${expense.createdAt.hour}:${expense.createdAt.minute.toString().padLeft(2, '0')}',
                            context: context,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s24),

                    // Payment Transactions Ledger
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Payment Disbursements',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.onSurface,
                          ),
                        ),
                        if (expense.outstandingAmountPaise > 0 &&
                            !expense.isCancelled)
                          TextButton.icon(
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Add Payment'),
                            onPressed: () => _showAddPaymentModal(
                              context: context,
                              ref: ref,
                              expense: expense,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s8),

                    paymentsAsync.when(
                      data: (payments) {
                        if (payments.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.s12,
                            ),
                            child: Text(
                              'No individual disbursement records logged yet.',
                              style: TextStyle(color: colors.onSurfaceMuted),
                            ),
                          );
                        }
                        return Column(
                          children: payments.map((p) {
                            return AppCard(
                              margin: const EdgeInsets.only(
                                bottom: AppSpacing.s8,
                              ),
                              padding: AppSpacing.insetAll12,
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: colors.success.withValues(
                                        alpha: 0.15,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.check_rounded,
                                      color: colors.success,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.s12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Disbursed ${CurrencyFormatter.formatPaise(p.amountPaise)}',
                                          style: textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: colors.onSurface,
                                          ),
                                        ),
                                        Text(
                                          '${p.paymentMethod} • ${p.paymentDate.day}/${p.paymentDate.month}/${p.paymentDate.year}${p.referenceNumber != null ? ' (Ref: ${p.referenceNumber})' : ''}',
                                          style: textTheme.bodySmall?.copyWith(
                                            color: colors.onSurfaceMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                      loading: () => const AppLoadingIndicator.small(),
                      error: (err, _) => Text('Error loading payments: $err'),
                    ),
                    const SizedBox(height: AppSpacing.s24),

                    // Actions
                    if (!expense.isCancelled) ...[
                      if (expense.outstandingAmountPaise > 0) ...[
                        AppButton(
                          text: 'Record Additional Payment',
                          icon: Icons.payments_rounded,
                          isFullWidth: true,
                          onPressed: () => _showAddPaymentModal(
                            context: context,
                            ref: ref,
                            expense: expense,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s12),
                      ],
                      AppButton.destructive(
                        text: 'Cancel Expense',
                        icon: Icons.cancel_outlined,
                        isFullWidth: true,
                        onPressed: () => _showCancelDialog(
                          context: context,
                          ref: ref,
                          expense: expense,
                        ),
                      ),
                    ],
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

  Widget _buildAmountStat({
    required String label,
    required String amount,
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
          amount,
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor ?? colors.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    required BuildContext context,
  }) {
    final textTheme = context.textTheme;
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(color: colors.onSurfaceMuted),
          ),
          Flexible(
            child: Text(
              value,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddPaymentModal({
    required BuildContext context,
    required WidgetRef ref,
    required Expense expense,
  }) {
    final colors = context.colors;
    final amountController = TextEditingController(
      text: (expense.outstandingAmountPaise / 100.0).toStringAsFixed(2),
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
              cashbookAccountsStreamProvider(expense.fairId),
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
                      'Record Payment Disbursement',
                      style: sheetCtx.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    AppTextField(
                      controller: amountController,
                      label: 'Payment Amount (₹) *',
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
                      label: 'Payment Method',
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
                        if (accounts.isEmpty) return const SizedBox.shrink();
                        return AppDropdown<String>(
                          label: 'Pay From Business Account',
                          hint: 'Select cashbox or bank',
                          value: selectedAccountId,
                          items: accounts
                              .map(
                                (a) => DropdownMenuItem(
                                  value: a.id,
                                  child: Text(
                                    '${a.accountName} (₹${a.currentBalance.toStringAsFixed(0)})',
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
                      label: 'Transaction Reference',
                      hint: 'e.g. UPI Ref # or Cheque #',
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    AppTextField(
                      controller: notesController,
                      label: 'Notes',
                      hint: 'Payment remarks...',
                    ),
                    const SizedBox(height: AppSpacing.s24),
                    AppButton(
                      text: 'Confirm Disbursement',
                      isLoading: isSubmitting,
                      isFullWidth: true,
                      onPressed: () async {
                        final enteredAmount =
                            double.tryParse(amountController.text) ?? 0.0;
                        final amountPaise = (enteredAmount * 100).round();

                        if (amountPaise <= 0) {
                          AppSnackbar.showError(
                            sheetCtx,
                            'Enter an amount greater than zero',
                          );
                          return;
                        }

                        if (amountPaise > expense.outstandingAmountPaise) {
                          AppSnackbar.showError(
                            sheetCtx,
                            'Payment cannot exceed outstanding balance of ₹${expense.outstandingAmount.toStringAsFixed(2)}',
                          );
                          return;
                        }

                        setState(() => isSubmitting = true);

                        try {
                          final paymentRepo = ref.read(
                            paymentRepositoryProvider,
                          );
                          final clientReqId =
                              FinancialDraftManager.getOrCreateClientRequestId(
                                operationType: 'standalone_payment',
                                entityId: expense.id,
                              );
                          final payment = PaymentRecord(
                            id: clientReqId,
                            fairId: expense.fairId,
                            relatedEntityType: 'expense',
                            relatedEntityId: expense.id,
                            amountPaise: amountPaise,
                            paymentDate: DateTime.now(),
                            paymentMethod: method,
                            accountId: selectedAccountId,
                            referenceNumber:
                                refController.text.trim().isNotEmpty
                                ? refController.text.trim()
                                : null,
                            notes: notesController.text.trim().isNotEmpty
                                ? notesController.text.trim()
                                : 'Expense partial/full settlement',
                            createdAt: DateTime.now(),
                          );

                          await paymentRepo.recordPayment(
                            payment,
                            clientRequestId: clientReqId,
                          );
                          await FinancialDraftManager.clearDraft(
                            operationType: 'standalone_payment',
                            entityId: expense.id,
                          );
                          if (sheetCtx.mounted) {
                            Navigator.of(sheetCtx).pop();
                            if (context.mounted) {
                              AppSnackbar.showSuccess(
                                context,
                                'Payment recorded successfully',
                              );
                            }
                          }
                        } catch (e) {
                          setState(() => isSubmitting = false);
                          if (sheetCtx.mounted) {
                            AppSnackbar.showError(sheetCtx, e.toString());
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

  void _showCancelDialog({
    required BuildContext context,
    required WidgetRef ref,
    required Expense expense,
  }) {
    final colors = context.colors;
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: colors.surface,
        title: const Text('Cancel Expense?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to cancel this expense? The outstanding amount will become zero and the record will be marked as cancelled in the ledger.',
            ),
            const SizedBox(height: AppSpacing.s16),
            AppTextField(
              controller: reasonController,
              label: 'Cancellation Reason *',
              hint: 'e.g. Duplicate booking, supplier cancelled order...',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dlgCtx).pop(),
            child: const Text('Keep Expense'),
          ),
          AppButton.destructive(
            text: 'Confirm Cancellation',
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                AppSnackbar.showError(
                  dlgCtx,
                  'Please provide a cancellation reason',
                );
                return;
              }
              Navigator.of(dlgCtx).pop();
              final clientReqId =
                  FinancialDraftManager.getOrCreateClientRequestId(
                    operationType: 'refund',
                    entityId: expense.id,
                  );
              try {
                await ref
                    .read(expenseRepositoryProvider)
                    .cancelExpense(
                      expense.id,
                      reason,
                      refundToAccountId: expense.paidFromAccountId,
                      clientRequestId: clientReqId,
                    );
                await FinancialDraftManager.clearDraft(
                  operationType: 'refund',
                  entityId: expense.id,
                );
                if (context.mounted) {
                  AppSnackbar.showSuccess(
                    context,
                    'Expense has been cancelled',
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  AppSnackbar.showError(context, e.toString());
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
