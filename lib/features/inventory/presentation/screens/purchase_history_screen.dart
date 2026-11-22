import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/components/app_app_bar.dart';
import '../../../../core/components/app_badge.dart';
import '../../../../core/components/app_button.dart';
import '../../../../core/components/app_card.dart';
import '../../../../core/components/app_dropdown.dart';
import '../../../../core/components/app_empty_state.dart';
import '../../../../core/components/app_loading.dart';
import '../../../../core/components/app_snackbar.dart';
import '../../../../core/components/app_text_field.dart';
import '../../../../core/components/palette_switcher_button.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/financial_draft_manager.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../../cashbook/presentation/view_models/cashbook_providers.dart';
import '../../../payments/domain/entities/payment_record.dart';
import '../../../payments/presentation/view_models/payment_providers.dart';
import '../../domain/entities/purchase_batch.dart';
import '../../domain/entities/purchase_item.dart';
import '../view_models/inventory_providers.dart';

/// Screen 06: Purchase History & Procurement Batch Ledger.
class PurchaseHistoryScreen extends ConsumerStatefulWidget {
  const PurchaseHistoryScreen({super.key});

  @override
  ConsumerState<PurchaseHistoryScreen> createState() =>
      _PurchaseHistoryScreenState();
}

class _PurchaseHistoryScreenState extends ConsumerState<PurchaseHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatus = 'All';

  final List<String> _statusFilters = const [
    'All',
    'Paid',
    'Partial',
    'Unpaid',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;
    final batchesAsync = ref.watch(purchaseBatchesStreamProvider(null));
    final suppliersAsync = ref.watch(suppliersStreamProvider);

    final suppliers = suppliersAsync.value ?? [];
    final supplierMap = {for (final s in suppliers) s.id: s.name};

    return Scaffold(
      appBar: const AppAppBar(
        title: 'Purchase History',
        subtitle: 'Procurement Batch Ledger',
        actions: [PaletteSwitcherButton(compact: true), AppSpacing.gapW12],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushNamed(RouteNames.createPurchaseBatch),
        backgroundColor: colors.accent,
        foregroundColor: colors.primaryDark,
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: const Text(
          'New Purchase',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: ResponsiveContentContainer(
          child: Column(
            children: [
              _buildFilterAndSearchBar(context),
              Expanded(
                child: batchesAsync.when(
                  loading: () => const Center(
                    child: AppLoadingIndicator.large(
                      message: 'Loading purchase history...',
                    ),
                  ),
                  error: (err, _) => Center(
                    child: Text(
                      'Failed to load purchases: $err',
                      style: TextStyle(color: colors.error),
                    ),
                  ),
                  data: (batches) {
                    final query = _searchController.text.trim().toLowerCase();
                    final filtered = batches.where((b) {
                      final matchesStatus =
                          _selectedStatus == 'All' ||
                          b.paymentStatus.toLowerCase() ==
                              _selectedStatus.toLowerCase();
                      final supplierName = (supplierMap[b.supplierId] ?? '')
                          .toLowerCase();
                      final inv = (b.invoiceNumber ?? '').toLowerCase();
                      final refStr = (b.purchaseReference ?? '').toLowerCase();
                      final matchesSearch =
                          query.isEmpty ||
                          supplierName.contains(query) ||
                          inv.contains(query) ||
                          refStr.contains(query);
                      return matchesStatus && matchesSearch;
                    }).toList();

                    if (batches.isEmpty) {
                      return _buildEmptyState(context);
                    }

                    if (filtered.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 48,
                              color: colors.textSecondary,
                            ),
                            AppSpacing.gapH12,
                            Text(
                              'No matching purchases found',
                              style: textTheme.titleMedium?.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            AppSpacing.gapH4,
                            Text(
                              'Try adjusting your search or filter criteria.',
                              style: textTheme.bodySmall?.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => AppSpacing.gapH12,
                      itemBuilder: (context, index) {
                        final batch = filtered[index];
                        final supplierName =
                            supplierMap[batch.supplierId] ??
                            'Direct / Independent Vendor';
                        return _buildBatchCard(context, batch, supplierName);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterAndSearchBar(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: colors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search by supplier, invoice, reference...',
              prefixIcon: Icon(Icons.search, color: colors.textSecondary),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: colors.textSecondary),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              filled: true,
              fillColor: colors.surfaceSecondary,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: AppRadius.allMedium,
                borderSide: BorderSide(color: colors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.allMedium,
                borderSide: BorderSide(color: colors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.allMedium,
                borderSide: BorderSide(color: colors.accent, width: 1.5),
              ),
            ),
          ),
          AppSpacing.gapH8,
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _statusFilters.map((status) {
                final isSelected = _selectedStatus == status;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(status),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedStatus = selected ? status : 'All';
                      });
                    },
                    selectedColor: colors.accent,
                    backgroundColor: colors.surfaceSecondary,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? colors.primaryDark
                          : colors.textPrimary,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      fontSize: 12,
                    ),
                    side: BorderSide(
                      color: isSelected ? colors.accent : colors.border,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.allFull,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchCard(
    BuildContext context,
    PurchaseBatch batch,
    String supplierName,
  ) {
    final colors = context.colors;
    final textTheme = context.textTheme;
    final dateStr = DateFormat('dd MMM yyyy').format(batch.purchaseDate);

    Color statusBg;
    Color statusFg;
    switch (batch.paymentStatus.toLowerCase()) {
      case 'paid':
        statusBg = colors.accent;
        statusFg = colors.primaryDark;
        break;
      case 'partial':
        statusBg = colors.warning;
        statusFg = colors.primaryDark;
        break;
      default:
        statusBg = colors.error;
        statusFg = colors.surface;
    }

    return AppCard.interactive(
      onTap: () => _showBatchDetailsModal(context, batch, supplierName),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      supplierName,
                      style: textTheme.titleMedium?.copyWith(
                        fontFamily: 'Georgia',
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    AppSpacing.gapH2,
                    Text(
                      'Date: $dateStr • Ref: ${batch.purchaseReference?.isNotEmpty == true ? batch.purchaseReference : batch.id.substring(0, 8)}',
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: AppRadius.allFull,
                ),
                child: Text(
                  batch.paymentStatus.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: statusFg,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          if (batch.invoiceNumber != null &&
              batch.invoiceNumber!.trim().isNotEmpty) ...[
            AppSpacing.gapH6,
            Row(
              children: [
                Icon(
                  Icons.receipt_outlined,
                  size: 14,
                  color: colors.textSecondary,
                ),
                AppSpacing.gapW4,
                Text(
                  'Invoice #${batch.invoiceNumber}',
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          AppSpacing.gapH12,
          Divider(color: colors.divider, height: 1),
          AppSpacing.gapH12,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDetailItem(
                context,
                label: 'TOTAL UNITS',
                value: '${batch.totalQuantity} copies',
              ),
              _buildDetailItem(
                context,
                label: 'PAYMENT',
                value: batch.paymentMethod,
              ),
              _buildDetailItem(
                context,
                label: 'ACQUISITION OUTLAY',
                value: CurrencyFormatter.format(batch.totalAcquisitionCost),
                isHighlight: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(
    BuildContext context, {
    required String label,
    required String value,
    bool isHighlight = false,
  }) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    return Column(
      crossAxisAlignment: isHighlight
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(
            fontSize: 9,
            letterSpacing: 0.8,
            color: colors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        AppSpacing.gapH2,
        Text(
          value,
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
            color: isHighlight ? colors.accent : colors.textPrimary,
          ),
        ),
      ],
    );
  }

  void _showBatchDetailsModal(
    BuildContext context,
    PurchaseBatch batch,
    String supplierName,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return _BatchDetailsSheet(batch: batch, supplierName: supplierName);
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return AppEmptyState(
      icon: Icons.receipt_long_outlined,
      title: 'No Purchases Recorded',
      description: 'Procure inventory batches, track supplier invoices, and maintain weighted average acquisition costs.',
      actionLabel: 'Record First Purchase',
      onAction: () => context.pushNamed(RouteNames.createPurchaseBatch),
    );
  }
}

class _BatchDetailsSheet extends ConsumerWidget {
  const _BatchDetailsSheet({required this.batch, required this.supplierName});

  final PurchaseBatch batch;
  final String supplierName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final textTheme = context.textTheme;
    final repo = ref.watch(inventoryRepositoryProvider);
    final booksAsync = ref.watch(booksStreamProvider(null));
    final books = booksAsync.value ?? [];
    final bookMap = {for (final b in books) b.id: b};
    final dateStr = DateFormat('dd MMMM yyyy').format(batch.purchaseDate);

    return Material(
      color: colors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: AppRadius.allFull,
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Batch Overview',
                          style: textTheme.titleMedium?.copyWith(
                            fontFamily: 'Georgia',
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          '$supplierName • $dateStr',
                          style: textTheme.bodySmall?.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Divider(color: colors.divider, height: 1),
            // Content
            Expanded(
              child: FutureBuilder<List<PurchaseItem>>(
                future: repo.getItemsForBatch(batch.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: AppLoadingIndicator(
                        message: 'Loading batch line items...',
                      ),
                    );
                  }

                  final items = snapshot.data ?? [];

                  return ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Summary Card
                      AppCard.outlined(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Procurement Summary',
                                  style: textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                AppBadge(
                                  label: batch.paymentStatus,
                                  variant:
                                      batch.paymentStatus.toLowerCase() ==
                                          'paid'
                                      ? AppBadgeVariant.success
                                      : AppBadgeVariant.warning,
                                ),
                              ],
                            ),
                            AppSpacing.gapH12,
                            _buildSummaryRow(
                              context,
                              'Reference ID',
                              batch.purchaseReference?.isNotEmpty == true
                                  ? batch.purchaseReference!
                                  : batch.id,
                            ),
                            if (batch.invoiceNumber != null &&
                                batch.invoiceNumber!.isNotEmpty)
                              _buildSummaryRow(
                                context,
                                'Invoice Number',
                                batch.invoiceNumber!,
                              ),
                            _buildSummaryRow(
                              context,
                              'Payment Method',
                              batch.paymentMethod,
                            ),
                            _buildSummaryRow(
                              context,
                              'Total Titles in Batch',
                              '${items.length} titles',
                            ),
                            _buildSummaryRow(
                              context,
                              'Total Book Units',
                              '${batch.totalQuantity} copies',
                            ),
                            Divider(color: colors.divider, height: 16),
                            _buildSummaryRow(
                              context,
                              'Gross Book Net Cost',
                              CurrencyFormatter.format(batch.totalBookCost),
                            ),
                            if (batch.additionalChargesPaise > 0)
                              _buildSummaryRow(
                                context,
                                'Transport / Ancillary Charges',
                                '+ ${CurrencyFormatter.format(batch.additionalCharges)}',
                              ),
                            AppSpacing.gapH4,
                            _buildSummaryRow(
                              context,
                              'Total Acquisition Outlay',
                              CurrencyFormatter.format(
                                batch.totalAcquisitionCost,
                              ),
                              isBold: true,
                            ),
                            if (batch.notes.isNotEmpty) ...[
                              AppSpacing.gapH8,
                              Text(
                                'Notes:',
                                style: textTheme.labelSmall?.copyWith(
                                  color: colors.textSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                batch.notes,
                                style: textTheme.bodySmall?.copyWith(
                                  color: colors.textPrimary,
                                ),
                              ),
                            ],
                            if (batch.paymentStatus.toLowerCase() !=
                                'paid') ...[
                              AppSpacing.gapH12,
                              AppButton(
                                text: 'Record Supplier Payment',
                                icon: Icons.payments_outlined,
                                variant: AppButtonVariant.primary,
                                size: AppButtonSize.small,
                                isFullWidth: true,
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  _showRecordPurchasePaymentDialog(
                                    context,
                                    ref,
                                    batch,
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                      AppSpacing.gapH20,
                      Text(
                        'Line Items (${items.length})',
                        style: textTheme.titleSmall?.copyWith(
                          fontFamily: 'Georgia',
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      AppSpacing.gapH8,
                      if (items.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'No items registered for this batch.',
                              style: TextStyle(color: colors.textSecondary),
                            ),
                          ),
                        )
                      else
                        ...items.map((item) {
                          final book = bookMap[item.bookId];
                          final bookTitle =
                              book?.title ?? 'Item #${item.id.substring(0, 6)}';
                          final isbn = book?.isbn13 ?? book?.isbn10;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: AppCard(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: colors.surfaceSecondary,
                                      borderRadius: AppRadius.allSmall,
                                    ),
                                    child: Icon(
                                      Icons.book_outlined,
                                      size: 20,
                                      color: colors.accent,
                                    ),
                                  ),
                                  AppSpacing.gapW12,
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          bookTitle,
                                          style: textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: colors.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (isbn != null && isbn.isNotEmpty)
                                          Text(
                                            'ISBN: $isbn',
                                            style: textTheme.labelSmall
                                                ?.copyWith(
                                                  color: colors.textSecondary,
                                                ),
                                          ),
                                        Text(
                                          '${item.quantity} copies @ ${CurrencyFormatter.format(item.unitPurchaseCost)} / unit',
                                          style: textTheme.bodySmall?.copyWith(
                                            color: colors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    CurrencyFormatter.format(item.lineTotal),
                                    style: textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    BuildContext context,
    String label,
    String value, {
    bool isBold = false,
  }) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: colors.textSecondary,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          Text(
            value,
            style: textTheme.bodySmall?.copyWith(
              color: isBold ? colors.accent : colors.textPrimary,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showRecordPurchasePaymentDialog(
    BuildContext context,
    WidgetRef ref,
    PurchaseBatch batch,
  ) async {
    final accounts = await ref
        .read(cashbookRepositoryProvider)
        .getAccounts(fairId: batch.fairId);
    final activeAccounts = accounts.where((a) => a.isActive).toList();

    if (!context.mounted) return;

    if (activeAccounts.isEmpty) {
      AppSnackbar.showError(
        context,
        'No active cashbook accounts found. Please create an account in Cashbook first.',
      );
      return;
    }

    final totalCost = batch.totalAcquisitionCost;
    final amountController = TextEditingController(
      text: totalCost.toStringAsFixed(2),
    );
    final refController = TextEditingController();
    final notesController = TextEditingController();
    String selectedAccountId = activeAccounts.first.id;
    String method = 'Bank Transfer';
    bool isSubmitting = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            final colors = ctx.colors;
            final textTheme = ctx.textTheme;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Material(
                color: colors.surface,
                borderRadius: AppRadius.brTopExtraLarge,
                child: Padding(
                  padding: AppSpacing.insetAll20,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Record Supplier Payment',
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                          fontFamily: 'Georgia',
                        ),
                      ),
                      AppSpacing.gapH4,
                      Text(
                        'Disburse payment for Batch #${batch.invoiceNumber ?? batch.id.substring(0, 8)}',
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      AppSpacing.gapH16,
                      AppTextField(
                        controller: amountController,
                        label: 'Payment Amount (₹)',
                        hint: '0.00',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      AppSpacing.gapH12,
                      AppDropdown<String>(
                        label: 'Disbursing Account',
                        value: selectedAccountId,
                        items: activeAccounts.map((a) {
                          return DropdownMenuItem(
                            value: a.id,
                            child: Text(
                              '${a.accountName} (₹${(a.currentBalancePaise / 100).toStringAsFixed(2)})',
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => selectedAccountId = val);
                          }
                        },
                      ),
                      AppSpacing.gapH12,
                      AppDropdown<String>(
                        label: 'Payment Method',
                        value: method,
                        items: const ['Bank Transfer', 'UPI', 'Cash', 'Cheque']
                            .map((m) {
                              return DropdownMenuItem(value: m, child: Text(m));
                            })
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => method = val);
                        },
                      ),
                      AppSpacing.gapH12,
                      AppTextField(
                        controller: refController,
                        label: 'Reference / UTR Number',
                        hint: 'e.g. UTR-9876543210',
                      ),
                      AppSpacing.gapH12,
                      AppTextField(
                        controller: notesController,
                        label: 'Payment Notes',
                        hint: 'Optional settlement notes',
                      ),
                      AppSpacing.gapH20,
                      AppButton(
                        text: 'Confirm & Disburse Payment',
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

                          setState(() => isSubmitting = true);
                          try {
                            final paymentRepo = ref.read(
                              paymentRepositoryProvider,
                            );
                            final clientReqId =
                                FinancialDraftManager.getOrCreateClientRequestId(
                                  operationType: 'purchase_payment',
                                  entityId: batch.id,
                                );

                            final payment = PaymentRecord(
                              id: clientReqId,
                              fairId: batch.fairId,
                              amountPaise: amountPaise,
                              paymentMethod: method,
                              paymentDate: DateTime.now(),
                              accountId: selectedAccountId,
                              supplierId: batch.supplierId,
                              referenceNumber:
                                  refController.text.trim().isNotEmpty
                                  ? refController.text.trim()
                                  : null,
                              notes: notesController.text.trim().isNotEmpty
                                  ? notesController.text.trim()
                                  : 'Supplier payment for batch #${batch.invoiceNumber ?? batch.id.substring(0, 8)}',
                              relatedEntityType: 'purchase_batch',
                              relatedEntityId: batch.id,
                              createdAt: DateTime.now(),
                            );

                            await paymentRepo.recordPayment(
                              payment,
                              clientRequestId: clientReqId,
                            );
                            await FinancialDraftManager.clearDraft(
                              operationType: 'purchase_payment',
                              entityId: batch.id,
                            );

                            if (sheetCtx.mounted) {
                              Navigator.of(sheetCtx).pop();
                              if (context.mounted) {
                                AppSnackbar.showSuccess(
                                  context,
                                  'Supplier payment recorded successfully',
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
              ),
            );
          },
        );
      },
    );
  }
}
