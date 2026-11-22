import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/components/app_badge.dart';
import '../../../../core/components/app_button.dart';
import '../../../../core/components/app_card.dart';
import '../../../../core/components/app_dropdown.dart';
import '../../../../core/components/app_error_state.dart';
import '../../../../core/components/app_loading.dart';
import '../../../../core/components/app_snackbar.dart';
import '../../../../core/components/app_text_field.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../../cashbook/presentation/view_models/cashbook_providers.dart';
import '../../../inventory/domain/entities/book.dart';
import '../../domain/entities/sale_item.dart';
import '../../domain/entities/sale_receipt.dart';
import '../view_models/sales_providers.dart';

/// Screen 06: Audited itemized receipt details and customer return settlement.
class SaleReceiptDetailsScreen extends ConsumerStatefulWidget {
  const SaleReceiptDetailsScreen({super.key, required this.receiptId});

  final String receiptId;

  @override
  ConsumerState<SaleReceiptDetailsScreen> createState() =>
      _SaleReceiptDetailsScreenState();
}

class _SaleReceiptDetailsScreenState
    extends ConsumerState<SaleReceiptDetailsScreen> {
  Future<void> _showReturnDialog(SaleReceipt receipt, SaleItem item) async {
    final maxReturnable = item.quantity - item.returnedQuantity;
    if (maxReturnable <= 0) {
      AppSnackbar.show(
        context,
        message:
            'All copies of "${item.bookTitle}" have already been returned.',
      );
      return;
    }

    final cashbookRepo = ref.read(cashbookRepositoryProvider);
    final accounts = (await cashbookRepo.getAccounts(fairId: receipt.fairId))
        .where((a) => a.isActive)
        .toList();

    if (!mounted) return;

    final qtyController = TextEditingController(text: '1');
    final reasonController = TextEditingController(
      text: 'Customer requested refund',
    );
    BookCondition returnCondition = BookCondition.fromString(item.condition);
    bool isRestocked = true;
    String? selectedAccountId = accounts.isNotEmpty ? accounts.first.id : null;

    final perUnitRefund = (item.lineTotalPaise / item.quantity).round();
    final refundController = TextEditingController(
      text: (perUnitRefund / 100.0).toStringAsFixed(0),
    );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            final colors = sheetContext.colors;
            final textTheme = sheetContext.textTheme;

            return Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              padding: EdgeInsets.fromLTRB(
                AppSpacing.s20,
                AppSpacing.s16,
                AppSpacing.s20,
                MediaQuery.of(context).viewInsets.bottom + AppSpacing.s24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: AppSpacing.s16),
                        decoration: BoxDecoration(
                          color: colors.borderSubtle,
                          borderRadius: AppRadius.brFull,
                        ),
                      ),
                    ),
                    Text(
                      'Process Return: ${item.bookTitle}',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    AppSpacing.gapH4,
                    Text(
                      'Max returnable copies: $maxReturnable (Sold: ${item.quantity}, Prior returns: ${item.returnedQuantity})',
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceMuted,
                      ),
                    ),
                    AppSpacing.gapH16,
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: qtyController,
                            label: 'Return Quantity',
                            keyboardType: TextInputType.number,
                            onChanged: (val) {
                              final q = int.tryParse(val) ?? 1;
                              refundController.text =
                                  ((q * perUnitRefund) / 100.0).toStringAsFixed(
                                    0,
                                  );
                              setModalState(() {});
                            },
                          ),
                        ),
                        AppSpacing.gapW12,
                        Expanded(
                          child: AppTextField(
                            controller: refundController,
                            label: 'Refund Amount (₹)',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.gapH12,
                    AppDropdown<BookCondition>(
                      label: 'Verified Physical Condition',
                      value: returnCondition,
                      items: BookCondition.values
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(c.displayName),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() {
                            returnCondition = val;
                            if (val == BookCondition.damaged) {
                              isRestocked = false;
                            }
                          });
                        }
                      },
                    ),
                    AppSpacing.gapH8,
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Restock into available physical inventory',
                      ),
                      subtitle: Text(
                        isRestocked
                            ? 'Will increment active stock count for this title'
                            : 'Will NOT restock (marked damaged/unsellable)',
                        style: const TextStyle(fontSize: 12),
                      ),
                      value: isRestocked,
                      onChanged: (val) =>
                          setModalState(() => isRestocked = val),
                    ),
                    AppSpacing.gapH8,
                    if (accounts.isNotEmpty)
                      AppDropdown<String>(
                        label: 'Disburse Refund From Account',
                        value: selectedAccountId,
                        items: accounts
                            .map(
                              (a) => DropdownMenuItem(
                                value: a.id,
                                child: Text(
                                  '${a.accountName} (${CurrencyFormatter.format(a.currentBalance)})',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setModalState(() => selectedAccountId = val),
                      ),
                    AppSpacing.gapH8,
                    AppTextField(
                      controller: reasonController,
                      label: 'Return Justification / Reason',
                    ),
                    AppSpacing.gapH16,
                    AppButton(
                      text: 'Confirm Return & Refund',
                      icon: Icons.assignment_return_outlined,
                      onPressed: () async {
                        final q = int.tryParse(qtyController.text) ?? 0;
                        if (q <= 0 || q > maxReturnable) {
                          AppSnackbar.show(
                            context,
                            message:
                                'Please enter a valid return quantity (1 to $maxReturnable).',
                            variant: AppSnackbarVariant.error,
                          );
                          return;
                        }
                        final refundAmount =
                            ((double.tryParse(refundController.text) ?? 0) *
                                    100)
                                .round();
                        if (refundAmount < 0) {
                          AppSnackbar.show(
                            context,
                            message: 'Invalid refund amount.',
                          );
                          return;
                        }
                        if (selectedAccountId == null) {
                          AppSnackbar.show(
                            context,
                            message: 'Select refund source account.',
                          );
                          return;
                        }

                        Navigator.of(ctx).pop();

                        try {
                          final saleRepo = ref.read(saleRepositoryProvider);
                          final clientReqId =
                              'ret_${receipt.id}_${item.id}_${DateTime.now().millisecondsSinceEpoch}';
                          await saleRepo.processSaleReturn(
                            receiptId: receipt.id,
                            saleItemId: item.id,
                            returnQuantity: q,
                            condition: returnCondition,
                            isRestocked: isRestocked,
                            refundAmountPaise: refundAmount,
                            refundAccountId: selectedAccountId!,
                            reason: reasonController.text.trim(),
                            clientRequestId: clientReqId,
                          );

                          ref.invalidate(
                            saleReceiptDetailsProvider(receipt.id),
                          );

                          if (mounted) {
                            AppSnackbar.show(
                              context,
                              message: 'Return processed. Refund disbursed and inventory adjusted.',
                              variant: AppSnackbarVariant.success,
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            AppSnackbar.show(
                              context,
                              message:
                                  'Failed to process return: ${e.toString()}',
                              variant: AppSnackbarVariant.error,
                            );
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

  void _shareReceiptSummary(SaleReceipt receipt) {
    final sb = StringBuffer();
    sb.writeln('=== BOOKFAIR MANAGER RECEIPT ===');
    sb.writeln('Receipt #: ${receipt.receiptNumber}');
    sb.writeln('Date: ${DateFormatter.formatDateTime(receipt.createdAt)}');
    sb.writeln('Cashier: ${receipt.cashierName}');
    if (receipt.customerName != null) {
      sb.writeln('Customer: ${receipt.customerName}');
    }
    sb.writeln('--------------------------------');
    for (final item in receipt.items) {
      sb.writeln(
        '${item.bookTitle} x${item.quantity} = ${CurrencyFormatter.format(item.lineTotal)}',
      );
    }
    sb.writeln('--------------------------------');
    sb.writeln('Subtotal: ${CurrencyFormatter.format(receipt.subtotal)}');
    if (receipt.discountAmountPaise > 0) {
      sb.writeln('Discount: -${CurrencyFormatter.format(receipt.discount)}');
    }
    sb.writeln('TOTAL PAID: ${CurrencyFormatter.format(receipt.total)}');
    if (receipt.tenderedAmountPaise != null) {
      sb.writeln(
        'Tendered: ${CurrencyFormatter.format(receipt.tendered!)} | Change: ${CurrencyFormatter.format(receipt.change ?? 0)}',
      );
    }
    if (receipt.hasRefunds) {
      sb.writeln(
        'Refunded: ${CurrencyFormatter.format(receipt.refundedAmount)} (${receipt.paymentStatus})',
      );
    }
    sb.writeln('================================');
    Clipboard.setData(ClipboardData(text: sb.toString()));
    AppSnackbar.show(
      context,
      message: 'Receipt summary copied to clipboard for WhatsApp/SMS sharing.',
      variant: AppSnackbarVariant.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;
    final receiptAsync = ref.watch(
      saleReceiptDetailsProvider(widget.receiptId),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share Receipt',
            onPressed: () {
              receiptAsync.whenData((receipt) {
                if (receipt != null) _shareReceiptSummary(receipt);
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveContentContainer(
          child: receiptAsync.when(
            loading: () => const Center(child: AppLoadingIndicator()),
            error: (err, _) => AppErrorState(
              title: 'Unable to Load Receipt',
              description: err.toString(),
              onRetry: () =>
                  ref.invalidate(saleReceiptDetailsProvider(widget.receiptId)),
            ),
            data: (receipt) {
              if (receipt == null) {
                return const Center(child: Text('Receipt not found.'));
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header card with receipt metadata
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                receipt.receiptNumber,
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              AppBadge(
                                label: receipt.paymentStatus.toUpperCase(),
                                variant: receipt.isFullyRefunded
                                    ? AppBadgeVariant.error
                                    : (receipt.isPartiallyRefunded
                                          ? AppBadgeVariant.warning
                                          : AppBadgeVariant.success),
                              ),
                            ],
                          ),
                          AppSpacing.gapH8,
                          Text(
                            DateFormatter.formatDateTime(receipt.createdAt),
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceMuted,
                            ),
                          ),
                          AppSpacing.gapH4,
                          Text(
                            'Cashier: ${receipt.cashierName}',
                            style: textTheme.bodySmall,
                          ),
                          if (receipt.customerName != null) ...[
                            AppSpacing.gapH4,
                            Text(
                              'Customer: ${receipt.customerName} (${receipt.customerPhone ?? ''})',
                              style: textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                    AppSpacing.gapH16,

                    // Itemized line items
                    Text(
                      'Purchased Items (${receipt.items.length})',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    AppSpacing.gapH8,
                    ...receipt.items.map((item) {
                      return AppCard(
                        margin: const EdgeInsets.only(bottom: AppSpacing.s8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.bookTitle,
                                        style: textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      AppSpacing.gapH2,
                                      Text(
                                        item.bookAuthor,
                                        style: textTheme.bodySmall?.copyWith(
                                          color: colors.onSurfaceMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  CurrencyFormatter.format(item.lineTotal),
                                  style: textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            AppSpacing.gapH6,
                            Row(
                              children: [
                                Text(
                                  'Qty: ${item.quantity} × ${CurrencyFormatter.format(item.unitSellingPrice)}',
                                  style: textTheme.bodySmall,
                                ),
                                if (item.unitMrpPaise >
                                    item.unitSellingPricePaise) ...[
                                  AppSpacing.gapW8,
                                  Text(
                                    '(MRP ${CurrencyFormatter.format(item.unitMrp)})',
                                    style: textTheme.bodySmall?.copyWith(
                                      decoration: TextDecoration.lineThrough,
                                      color: colors.onSurfaceMuted,
                                    ),
                                  ),
                                ],
                                const Spacer(),
                                if (item.returnedQuantity > 0)
                                  AppBadge(
                                    label: 'Returned: ${item.returnedQuantity}',
                                    variant: AppBadgeVariant.warning,
                                  ),
                              ],
                            ),
                            if (!receipt.isFullyRefunded &&
                                item.returnedQuantity < item.quantity) ...[
                              AppSpacing.gapH8,
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  icon: const Icon(
                                    Icons.assignment_return_outlined,
                                    size: 16,
                                  ),
                                  label: const Text(
                                    'Return / Refund',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  onPressed: () =>
                                      _showReturnDialog(receipt, item),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),

                    AppSpacing.gapH16,
                    // Financial summary card
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSummaryRow(
                            'Subtotal',
                            CurrencyFormatter.format(receipt.subtotal),
                            textTheme,
                          ),
                          if (receipt.discountAmountPaise > 0) ...[
                            AppSpacing.gapH6,
                            _buildSummaryRow(
                              'General Discount',
                              '-${CurrencyFormatter.format(receipt.discount)}',
                              textTheme,
                              valueColor: colors.success,
                            ),
                          ],
                          const Divider(height: AppSpacing.s16),
                          _buildSummaryRow(
                            'Total Net Paid',
                            CurrencyFormatter.format(receipt.total),
                            textTheme,
                            isBold: true,
                          ),
                          if (receipt.tenderedAmountPaise != null) ...[
                            AppSpacing.gapH6,
                            _buildSummaryRow(
                              'Cash Tendered',
                              CurrencyFormatter.format(receipt.tendered!),
                              textTheme,
                            ),
                            AppSpacing.gapH4,
                            _buildSummaryRow(
                              'Change Returned',
                              CurrencyFormatter.format(receipt.change ?? 0),
                              textTheme,
                            ),
                          ],
                          if (receipt.hasRefunds) ...[
                            const Divider(height: AppSpacing.s16),
                            _buildSummaryRow(
                              'Total Refunded',
                              '-${CurrencyFormatter.format(receipt.refundedAmount)}',
                              textTheme,
                              valueColor: colors.error,
                            ),
                            AppSpacing.gapH4,
                            _buildSummaryRow(
                              'Net Retained Revenue',
                              CurrencyFormatter.format(receipt.netRevenue),
                              textTheme,
                              isBold: true,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value,
    TextTheme textTheme, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isBold
              ? textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)
              : textTheme.bodyMedium,
        ),
        Text(
          value,
          style: isBold
              ? textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: valueColor,
                )
              : textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: valueColor,
                ),
        ),
      ],
    );
  }
}
