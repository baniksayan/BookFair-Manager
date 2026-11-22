import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/components/app_app_bar.dart';
import '../../../../core/components/app_button.dart';
import '../../../../core/components/app_card.dart';
import '../../../../core/components/app_dropdown.dart';
import '../../../../core/components/app_snackbar.dart';
import '../../../../core/components/app_text_field.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../domain/entities/book.dart';
import '../view_models/inventory_providers.dart';
import '../view_models/purchase_batch_form_view_model.dart';

/// Screen 05: Multi-Title Vendor Purchase Batch Entry Workflow.
class CreatePurchaseBatchScreen extends ConsumerStatefulWidget {
  const CreatePurchaseBatchScreen({super.key, this.fairId = 'global'});

  final String fairId;

  @override
  ConsumerState<CreatePurchaseBatchScreen> createState() =>
      _CreatePurchaseBatchScreenState();
}

class _CreatePurchaseBatchScreenState
    extends ConsumerState<CreatePurchaseBatchScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _invoiceController;
  late final TextEditingController _referenceController;
  late final TextEditingController _additionalChargesController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _invoiceController = TextEditingController();
    _referenceController = TextEditingController();
    _additionalChargesController = TextEditingController(text: '0');
    _notesController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(purchaseBatchFormViewModelProvider.notifier)
          .init(fairId: widget.fairId);
    });
  }

  @override
  void dispose() {
    _invoiceController.dispose();
    _referenceController.dispose();
    _additionalChargesController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final vm = ref.read(purchaseBatchFormViewModelProvider.notifier);
    final batchId = await vm.submit();

    if (!mounted) return;

    if (batchId != null) {
      AppSnackbar.show(
        context,
        message: 'Purchase batch recorded & stock movements ledger updated.',
        variant: AppSnackbarVariant.success,
      );
      final router = GoRouter.maybeOf(context);
      if (router != null) {
        if (router.canPop()) {
          router.pop();
        } else {
          context.go('/inventory/purchases');
        }
      } else if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } else {
      final state = ref.read(purchaseBatchFormViewModelProvider);
      final err =
          state.validationErrors['items'] ??
          state.validationErrors['quantity'] ??
          state.validationErrors['general'] ??
          'Please ensure all items and quantities are valid.';
      AppSnackbar.show(
        context,
        message: err,
        variant: AppSnackbarVariant.error,
      );
    }
  }

  void _showAddBookDialog(List<Book> books) {
    if (books.isEmpty) {
      AppSnackbar.show(
        context,
        message: 'No books available. Create books in catalogue first.',
        variant: AppSnackbarVariant.info,
      );
      return;
    }

    final vm = ref.read(purchaseBatchFormViewModelProvider.notifier);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final colors = ctx.colors;
        final textTheme = ctx.textTheme;

        return Material(
          color: colors.surface,
          borderRadius: AppRadius.brTopExtraLarge,
          clipBehavior: Clip.antiAlias,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.7,
            ),
            decoration: BoxDecoration(
              borderRadius: AppRadius.brTopExtraLarge,
              border: Border.all(color: colors.border, width: 1.0),
            ),
            child: Column(
              children: [
                Padding(
                  padding: AppSpacing.insetAll16,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Book Title',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                          fontFamily: 'Georgia',
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView.separated(
                    padding: AppSpacing.insetAll16,
                    itemCount: books.length,
                    separatorBuilder: (context, index) => AppSpacing.gapH8,
                    itemBuilder: (context, index) {
                      final book = books[index];
                      return ListTile(
                        tileColor: colors.surfaceSecondary,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.brMedium,
                          side: BorderSide(color: colors.border, width: 1.0),
                        ),
                        leading: Icon(
                          Icons.menu_book_rounded,
                          color: colors.primary,
                        ),
                        title: Text(
                          book.title,
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          'by ${book.author} • MRP: ${CurrencyFormatter.format(book.mrp)}',
                          style: textTheme.bodySmall?.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        onTap: () {
                          vm.addItem(book: book);
                          Navigator.of(ctx).pop();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;
    final state = ref.watch(purchaseBatchFormViewModelProvider);
    final vm = ref.read(purchaseBatchFormViewModelProvider.notifier);

    final suppliers = ref.watch(suppliersStreamProvider).value ?? [];
    final books = ref.watch(booksStreamProvider(null)).value ?? [];

    return Scaffold(
      appBar: const AppAppBar(
        title: 'New Purchase Batch',
        subtitle: 'Log vendor consignment & acquisition costs',
      ),
      body: SafeArea(
        child: ResponsiveContentContainer(
          child: SingleChildScrollView(
            padding: AppSpacing.insetAll16,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Section 1: Acquisition Header & Supplier Info
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Batch Header & Vendor Details',
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        AppSpacing.gapH16,
                        Row(
                          children: [
                            Expanded(
                              child: AppDropdown<String?>(
                                label: 'Vendor / Supplier',
                                value: state.supplierId,
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('Direct / Independent Vendor'),
                                  ),
                                  ...suppliers.map((s) {
                                    return DropdownMenuItem<String?>(
                                      value: s.id,
                                      child: Text(s.name),
                                    );
                                  }),
                                ],
                                onChanged: vm.setSupplierId,
                              ),
                            ),
                          ],
                        ),
                        AppSpacing.gapH16,
                        Row(
                          children: [
                            Expanded(
                              child: AppTextField(
                                controller: _invoiceController,
                                label: 'Invoice / Bill Number',
                                hint: 'e.g. INV-2026-089',
                                onChanged: vm.setInvoiceNumber,
                              ),
                            ),
                            AppSpacing.gapW12,
                            Expanded(
                              child: AppTextField(
                                controller: _referenceController,
                                label: 'PO / Tracking Reference',
                                hint: 'e.g. PO-BLR-42',
                                onChanged: vm.setPurchaseReference,
                              ),
                            ),
                          ],
                        ),
                        AppSpacing.gapH16,
                        Row(
                          children: [
                            Expanded(
                              child: AppDropdown<String>(
                                label: 'Payment Method',
                                value: state.paymentMethod,
                                items:
                                    const [
                                      'Bank Transfer',
                                      'UPI',
                                      'Cash',
                                      'Cheque',
                                    ].map((m) {
                                      return DropdownMenuItem(
                                        value: m,
                                        child: Text(m),
                                      );
                                    }).toList(),
                                onChanged: (val) {
                                  if (val != null) vm.setPaymentMethod(val);
                                },
                              ),
                            ),
                            AppSpacing.gapW12,
                            Expanded(
                              child: AppDropdown<String>(
                                label: 'Payment Status',
                                value: state.paymentStatus,
                                items: const ['Paid', 'Pending', 'Partial'].map(
                                  (s) {
                                    return DropdownMenuItem(
                                      value: s,
                                      child: Text(s),
                                    );
                                  },
                                ).toList(),
                                onChanged: (val) {
                                  if (val != null) vm.setPaymentStatus(val);
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.gapH16,

                  // Section 2: Line Items Header & Action
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Acquired Titles (${state.items.length})',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                              fontFamily: 'Georgia',
                            ),
                          ),
                          Text(
                            '${state.totalQuantity} physical copies selected',
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      AppButton.outlined(
                        text: 'Add Title',
                        icon: Icons.add_rounded,
                        size: AppButtonSize.small,
                        onPressed: () => _showAddBookDialog(books),
                      ),
                    ],
                  ),
                  AppSpacing.gapH12,

                  if (state.items.isEmpty)
                    AppCard(
                      padding: AppSpacing.insetAll24,
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.library_books_rounded,
                              size: 36.0,
                              color: colors.textSecondary,
                            ),
                            AppSpacing.gapH8,
                            Text(
                              'No Books Added to Batch',
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                              ),
                            ),
                            AppSpacing.gapH4,
                            Text(
                              'Tap "Add Title" to select books and enter unit costs.',
                              style: textTheme.bodySmall?.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: state.items.length,
                      separatorBuilder: (context, index) => AppSpacing.gapH12,
                      itemBuilder: (context, index) {
                        final item = state.items[index];
                        return AppCard(
                          padding: AppSpacing.insetAll16,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.bookTitle,
                                      style: textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: colors.textPrimary,
                                        fontFamily: 'Georgia',
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.delete_outline_rounded,
                                      size: 18.0,
                                      color: colors.error,
                                    ),
                                    onPressed: () => vm.removeItem(item.id),
                                  ),
                                ],
                              ),
                              AppSpacing.gapH8,
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      initialValue: item.quantity.toString(),
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: 'Copies (Qty)',
                                        fillColor: colors.surfaceSecondary,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: AppSpacing.s12,
                                              vertical: AppSpacing.s8,
                                            ),
                                      ),
                                      onChanged: (val) {
                                        final q = int.tryParse(val) ?? 1;
                                        vm.updateItemQuantity(item.id, q);
                                      },
                                    ),
                                  ),
                                  AppSpacing.gapW12,
                                  Expanded(
                                    flex: 3,
                                    child: TextFormField(
                                      initialValue: item.unitCostInput,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: 'Unit Cost (₹)',
                                        fillColor: colors.surfaceSecondary,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: AppSpacing.s12,
                                              vertical: AppSpacing.s8,
                                            ),
                                      ),
                                      onChanged: (val) {
                                        vm.updateItemUnitCost(item.id, val);
                                      },
                                    ),
                                  ),
                                  AppSpacing.gapW12,
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'LINE TOTAL',
                                          style: textTheme.labelSmall?.copyWith(
                                            fontSize: 9.0,
                                            color: colors.textSecondary,
                                          ),
                                        ),
                                        Text(
                                          CurrencyFormatter.format(
                                            item.lineTotalPaise / 100.0,
                                          ),
                                          style: textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: colors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  AppSpacing.gapH16,

                  // Section 3: Additional Charges & Overall Valuation
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ancillary Charges & Net Acquisition Valuation',
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        AppSpacing.gapH16,
                        AppTextField(
                          controller: _additionalChargesController,
                          label: 'Freight, Logistics & Additional Charges (₹)',
                          hint: '0',
                          keyboardType: TextInputType.number,
                          onChanged: vm.setAdditionalCharges,
                        ),
                        AppSpacing.gapH16,
                        const Divider(),
                        AppSpacing.gapH12,
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Pure Book Cost Subtotal:',
                              style: textTheme.bodyMedium?.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                            Text(
                              CurrencyFormatter.format(state.totalBookCost),
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        AppSpacing.gapH6,
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Additional Acquisition Charges:',
                              style: textTheme.bodyMedium?.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                            Text(
                              CurrencyFormatter.format(
                                state.additionalChargesDouble,
                              ),
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        AppSpacing.gapH8,
                        const Divider(),
                        AppSpacing.gapH8,
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'TOTAL ACQUISITION OUTLAY:',
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: colors.textPrimary,
                              ),
                            ),
                            Text(
                              CurrencyFormatter.format(
                                state.totalAcquisitionCost,
                              ),
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: colors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.gapH16,

                  // Notes
                  AppCard(
                    child: AppTextField(
                      controller: _notesController,
                      label: 'Consignment / Batch Notes',
                      hint: 'e.g. Delivered by Kolkata courier in 2 cartons',
                      maxLines: 2,
                      onChanged: vm.setNotes,
                    ),
                  ),
                  AppSpacing.gapH24,

                  // Submit Button
                  AppButton(
                    text: 'Confirm & Store Purchase Batch',
                    icon: Icons.check_circle_outline_rounded,
                    size: AppButtonSize.large,
                    isLoading: state.isSubmitting,
                    onPressed: _handleSubmit,
                  ),
                  AppSpacing.gapH32,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
