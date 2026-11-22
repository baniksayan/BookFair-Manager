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
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../../book_fairs/presentation/view_models/book_fair_providers.dart';
import '../../../cashbook/presentation/view_models/cashbook_providers.dart';
import '../../../inventory/presentation/view_models/inventory_providers.dart';
import '../view_models/expense_form_view_model.dart';
import '../view_models/expense_providers.dart';

/// Screen 02: Add or Edit Expense with multi-payment allocation & partner reimbursement attribution.
class AddEditExpenseScreen extends ConsumerStatefulWidget {
  const AddEditExpenseScreen({super.key, this.expenseId, this.initialFairId});

  final String? expenseId;
  final String? initialFairId;

  @override
  ConsumerState<AddEditExpenseScreen> createState() =>
      _AddEditExpenseScreenState();
}

class _AddEditExpenseScreenState extends ConsumerState<AddEditExpenseScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _amountController;
  late final TextEditingController _paidAmountController;
  late final TextEditingController _referenceController;
  late final TextEditingController _notesController;

  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _amountController = TextEditingController();
    _paidAmountController = TextEditingController();
    _referenceController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    _paidAmountController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _syncControllers(ExpenseFormState state) {
    if (_titleController.text != state.title) {
      _titleController.text = state.title;
    }
    if (_descriptionController.text != state.description) {
      _descriptionController.text = state.description;
    }
    if (_amountController.text != state.amount) {
      _amountController.text = state.amount;
    }
    if (_paidAmountController.text != state.paidAmount) {
      _paidAmountController.text = state.paidAmount;
    }
    if (_referenceController.text != state.referenceNumber) {
      _referenceController.text = state.referenceNumber;
    }
    if (_notesController.text != state.notes) {
      _notesController.text = state.notes;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    final fairsAsync = ref.watch(bookFairsStreamProvider);
    final categoriesAsync = ref.watch(expenseCategoriesStreamProvider);
    final suppliersAsync = ref.watch(suppliersStreamProvider);

    final formState = ref.watch(
      expenseFormViewModelProvider(widget.initialFairId),
    );
    final formViewModel = ref.read(
      expenseFormViewModelProvider(widget.initialFairId).notifier,
    );

    // Load initial expense if in edit mode
    if (!_initialized) {
      _initialized = true;
      if (widget.expenseId != null) {
        Future.microtask(() async {
          final expense = await ref
              .read(expenseRepositoryProvider)
              .getExpenseById(widget.expenseId!);
          if (expense != null && mounted) {
            formViewModel.loadForEdit(expense);
            _syncControllers(formState);
          }
        });
      } else if (widget.initialFairId != null) {
        Future.microtask(() {
          formViewModel.setFairId(widget.initialFairId!);
        });
      }
    }

    final selectedFairId = formState.fairId.isNotEmpty
        ? formState.fairId
        : (widget.initialFairId ?? '');

    final partnersAsync = selectedFairId.isNotEmpty
        ? ref.watch(partnersForFairStreamProvider(selectedFairId))
        : null;

    final accountsAsync = selectedFairId.isNotEmpty
        ? ref.watch(cashbookAccountsStreamProvider(selectedFairId))
        : null;

    final totalAmountNum = double.tryParse(formState.amount) ?? 0.0;
    final paidAmountNum = double.tryParse(formState.paidAmount) ?? 0.0;
    final outstandingNum = (totalAmountNum - paidAmountNum).clamp(
      0.0,
      double.infinity,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.expenseId != null ? 'Edit Expense' : 'Record Expense',
        ),
      ),
      body: SafeArea(
        child: ResponsiveContentContainer(
          child: SingleChildScrollView(
            padding: AppSpacing.insetAll16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (formState.errorMessage != null) ...[
                  Container(
                    padding: AppSpacing.insetAll12,
                    decoration: BoxDecoration(
                      color: colors.error.withValues(alpha: 0.1),
                      borderRadius: AppRadius.brMedium,
                      border: Border.all(color: colors.error),
                    ),
                    child: Text(
                      formState.errorMessage!,
                      style: TextStyle(color: colors.error),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s16),
                ],

                // 1. Fair & Category Selection
                fairsAsync.when(
                  data: (fairs) => AppDropdown<String>(
                    label: 'Book Fair *',
                    hint: 'Select associated Book Fair',
                    value: formState.fairId.isNotEmpty
                        ? formState.fairId
                        : null,
                    items: fairs
                        .map(
                          (f) => DropdownMenuItem(
                            value: f.id,
                            child: Text(f.name),
                          ),
                        )
                        .toList(),
                    errorText: formState.validationErrors['fairId'],
                    onChanged: (val) {
                      if (val != null) formViewModel.setFairId(val);
                    },
                  ),
                  loading: () => const AppLoadingIndicator.small(),
                  error: (e, _) => Text('Error loading fairs: $e'),
                ),
                const SizedBox(height: AppSpacing.s16),

                categoriesAsync.when(
                  data: (categories) => AppDropdown<String>(
                    label: 'Expense Category *',
                    hint: 'Select category (Rent, Food, Decor, etc.)',
                    value: formState.categoryId.isNotEmpty
                        ? formState.categoryId
                        : null,
                    items: categories
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          ),
                        )
                        .toList(),
                    errorText: formState.validationErrors['categoryId'],
                    onChanged: (val) {
                      if (val != null) formViewModel.setCategoryId(val);
                    },
                  ),
                  loading: () => const AppLoadingIndicator.small(),
                  error: (e, _) => Text('Error loading categories: $e'),
                ),
                const SizedBox(height: AppSpacing.s16),

                // 2. Title & Description
                AppTextField(
                  controller: _titleController,
                  label: 'Expense Title *',
                  hint: 'e.g. Stall B-42 Flex Banner Printing',
                  errorText: formState.validationErrors['title'],
                  onChanged: formViewModel.setTitle,
                ),
                const SizedBox(height: AppSpacing.s16),

                AppTextField(
                  controller: _descriptionController,
                  label: 'Description / Purpose',
                  hint: 'Specific details about vendor, dimensions, scope...',
                  maxLines: 2,
                  onChanged: formViewModel.setDescription,
                ),
                const SizedBox(height: AppSpacing.s16),

                // 3. Amount & Date
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _amountController,
                        label: 'Total Obligation (₹) *',
                        hint: '0.00',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        errorText: formState.validationErrors['amount'],
                        prefixIcon: const Icon(
                          Icons.currency_rupee_rounded,
                          size: 18,
                        ),
                        onChanged: formViewModel.setAmount,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Expense Date *',
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
                                    formState.expenseDate ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2035),
                              );
                              if (picked != null) {
                                formViewModel.setExpenseDate(picked);
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
                                    formState.expenseDate != null
                                        ? '${formState.expenseDate!.day}/${formState.expenseDate!.month}/${formState.expenseDate!.year}'
                                        : 'Select Date',
                                    style: textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s16),

                // 4. Payment Settlement Section
                AppCard(
                  padding: AppSpacing.insetAll16,
                  backgroundColor: colors.surfaceContainerHigh,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PAYMENT ALLOCATION',
                        style: textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceMuted,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s12),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: _paidAmountController,
                              label: 'Paid Amount (₹)',
                              hint: '0.00 (Leave 0 if Unpaid)',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              errorText:
                                  formState.validationErrors['paidAmount'],
                              prefixIcon: const Icon(
                                Icons.currency_rupee_rounded,
                                size: 18,
                              ),
                              onChanged: formViewModel.setPaidAmount,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Outstanding Balance',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colors.onSurfaceMuted,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.s4),
                                Text(
                                  CurrencyFormatter.format(outstandingNum),
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: outstandingNum > 0
                                        ? colors.error
                                        : colors.success,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s16),

                      // Payment Method
                      AppDropdown<String>(
                        label: 'Payment Method',
                        value: formState.paymentMethod,
                        items: const [
                          DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                          DropdownMenuItem(
                            value: 'UPI',
                            child: Text('UPI / QR'),
                          ),
                          DropdownMenuItem(
                            value: 'Bank Transfer',
                            child: Text('Bank Transfer (NEFT/IMPS)'),
                          ),
                          DropdownMenuItem(
                            value: 'Cheque',
                            child: Text('Cheque'),
                          ),
                          DropdownMenuItem(
                            value: 'Other',
                            child: Text('Other'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) formViewModel.setPaymentMethod(val);
                        },
                      ),
                      const SizedBox(height: AppSpacing.s16),

                      // Payer Type Selection: Business Cashbook vs Partner Personal Outlay
                      Text(
                        'Payer Source',
                        style: textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('Business Account'),
                              selected: !formState.isPaidByPartner,
                              onSelected: (_) =>
                                  formViewModel.setIsPaidByPartner(false),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s8),
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('Partner Personal Cash'),
                              selected: formState.isPaidByPartner,
                              onSelected: (_) =>
                                  formViewModel.setIsPaidByPartner(true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s12),

                      if (formState.isPaidByPartner) ...[
                        if (partnersAsync != null)
                          partnersAsync.when(
                            data: (partners) => AppDropdown<String>(
                              label: 'Paying Partner *',
                              hint: 'Select partner who incurred outlay',
                              value: formState.paidByPartnerId,
                              errorText:
                                  formState.validationErrors['paidByPartnerId'],
                              items: partners
                                  .map(
                                    (p) => DropdownMenuItem(
                                      value: p.id,
                                      child: Text(
                                        '${p.fullName} (${p.role.displayName})',
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: formViewModel.setPaidByPartnerId,
                            ),
                            loading: () => const AppLoadingIndicator.small(),
                            error: (e, _) => Text('Error loading partners: $e'),
                          )
                        else
                          Text(
                            'Please select a Book Fair first to select paying partner.',
                            style: TextStyle(color: colors.onSurfaceMuted),
                          ),
                      ] else ...[
                        if (accountsAsync != null)
                          accountsAsync.when(
                            data: (accounts) => AppDropdown<String>(
                              label: 'Paid From Business Account',
                              hint: 'Select business cashbox or bank',
                              value: formState.paidFromAccountId,
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
                              onChanged: formViewModel.setPaidFromAccountId,
                            ),
                            loading: () => const AppLoadingIndicator.small(),
                            error: (e, _) => Text('Error loading accounts: $e'),
                          )
                        else
                          Text(
                            'Please select a Book Fair first to select payment account.',
                            style: TextStyle(color: colors.onSurfaceMuted),
                          ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s16),

                // 5. Optional Supplier & References
                suppliersAsync.when(
                  data: (suppliers) {
                    if (suppliers.isEmpty) return const SizedBox.shrink();
                    return Column(
                      children: [
                        AppDropdown<String>(
                          label: 'Associated Supplier (Optional)',
                          hint: 'Select vendor or contractor',
                          value: formState.supplierId,
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('None / Direct Vendor'),
                            ),
                            ...suppliers.map(
                              (s) => DropdownMenuItem(
                                value: s.id,
                                child: Text(s.name),
                              ),
                            ),
                          ],
                          onChanged: formViewModel.setSupplierId,
                        ),
                        const SizedBox(height: AppSpacing.s16),
                      ],
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),

                AppTextField(
                  controller: _referenceController,
                  label: 'Transaction Reference / Bill No.',
                  hint: 'e.g. UPI Ref #492819381 or Bill #104',
                  onChanged: formViewModel.setReferenceNumber,
                ),
                const SizedBox(height: AppSpacing.s16),

                AppTextField(
                  controller: _notesController,
                  label: 'Audit Notes',
                  hint: 'Any special accounting terms or notes...',
                  maxLines: 2,
                  onChanged: formViewModel.setNotes,
                ),
                const SizedBox(height: AppSpacing.s24),

                // Submit Button
                AppButton(
                  text: widget.expenseId != null
                      ? 'Update Expense'
                      : 'Record Expense',
                  isLoading: formState.isSubmitting,
                  isFullWidth: true,
                  onPressed: () async {
                    final result = await formViewModel.submit();
                    if (!context.mounted) return;
                    if (result != null) {
                      AppSnackbar.showSuccess(
                        context,
                        widget.expenseId != null
                            ? 'Expense updated successfully'
                            : 'Expense recorded successfully',
                      );
                      context.pop();
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.s32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
