import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/components/app_button.dart';
import '../../../../core/components/app_dropdown.dart';
import '../../../../core/components/app_snackbar.dart';
import '../../../../core/components/app_text_field.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../cashbook/domain/entities/cashbook_account.dart';
import '../../../cashbook/presentation/view_models/cashbook_providers.dart';
import '../../domain/entities/sale_receipt.dart';
import '../view_models/pos_cart_view_model.dart';

/// Interactive modal sheet facilitating single-rail or split-rail POS payment settlement.
class PosCheckoutDialog extends ConsumerStatefulWidget {
  const PosCheckoutDialog({
    super.key,
    required this.fairId,
    required this.totalPayablePaise,
    required this.onCheckoutSuccess,
  });

  final String fairId;
  final int totalPayablePaise;
  final void Function(SaleReceipt receipt) onCheckoutSuccess;

  @override
  ConsumerState<PosCheckoutDialog> createState() => _PosCheckoutDialogState();
}

class _PosCheckoutDialogState extends ConsumerState<PosCheckoutDialog> {
  String _selectedMode = 'Cash'; // 'Cash', 'UPI', 'Bank', 'Split'
  String? _primaryAccountId;
  String? _secondaryAccountId;

  late final TextEditingController _tenderedCashController;
  late final TextEditingController _splitCashController;
  late final TextEditingController _splitUpiController;
  late final TextEditingController _upiRefController;

  bool _isProcessing = false;
  List<CashbookAccount> _accounts = [];

  @override
  void initState() {
    super.initState();
    _tenderedCashController = TextEditingController(
      text: (widget.totalPayablePaise / 100.0).toStringAsFixed(0),
    );
    _splitCashController = TextEditingController(
      text: ((widget.totalPayablePaise / 2) / 100.0).toStringAsFixed(0),
    );
    _splitUpiController = TextEditingController(
      text:
          ((widget.totalPayablePaise - (widget.totalPayablePaise / 2).round()) /
                  100.0)
              .toStringAsFixed(0),
    );
    _upiRefController = TextEditingController();

    _loadAccounts();
  }

  @override
  void dispose() {
    _tenderedCashController.dispose();
    _splitCashController.dispose();
    _splitUpiController.dispose();
    _upiRefController.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    final repo = ref.read(cashbookRepositoryProvider);
    final accs = await repo.getAccounts(fairId: widget.fairId);
    if (!mounted) return;
    setState(() {
      _accounts = accs.where((a) => a.isActive).toList();
      _pickDefaultAccounts();
    });
  }

  void _pickDefaultAccounts() {
    if (_accounts.isEmpty) return;

    final cashAcc = _accounts.firstWhere(
      (a) => a.accountType.toLowerCase() == 'cash',
      orElse: () => _accounts.first,
    );
    final upiAcc = _accounts.firstWhere(
      (a) => a.accountType.toLowerCase() == 'upi',
      orElse: () => _accounts.first,
    );

    if (_selectedMode == 'Cash') {
      _primaryAccountId = cashAcc.id;
    } else if (_selectedMode == 'UPI') {
      _primaryAccountId = upiAcc.id;
    } else if (_selectedMode == 'Split') {
      _primaryAccountId = cashAcc.id;
      _secondaryAccountId = upiAcc.id;
    } else {
      _primaryAccountId = _accounts.first.id;
    }
  }

  int get _calculatedChangePaise {
    if (_selectedMode != 'Cash') return 0;
    final tendered = (double.tryParse(_tenderedCashController.text) ?? 0) * 100;
    final change = tendered.round() - widget.totalPayablePaise;
    return change > 0 ? change : 0;
  }

  Future<void> _handleConfirmCheckout() async {
    if (_accounts.isEmpty) {
      AppSnackbar.show(
        context,
        message: 'No active cashbook accounts found. Please configure accounts first.',
        variant: AppSnackbarVariant.error,
      );
      return;
    }

    final paymentRails = <PaymentRailDraft>[];
    int? tenderedPaise;
    int? changePaise;

    if (_selectedMode == 'Cash') {
      if (_primaryAccountId == null) {
        AppSnackbar.show(
          context,
          message: 'Please select a receiving cash account.',
        );
        return;
      }
      final tendered =
          (double.tryParse(_tenderedCashController.text) ?? 0) * 100;
      tenderedPaise = tendered.round();
      if (tenderedPaise < widget.totalPayablePaise) {
        AppSnackbar.show(
          context,
          message: 'Tendered cash cannot be less than total payable amount.',
          variant: AppSnackbarVariant.error,
        );
        return;
      }
      changePaise = tenderedPaise - widget.totalPayablePaise;

      paymentRails.add(
        PaymentRailDraft(
          paymentMethod: 'Cash',
          accountId: _primaryAccountId!,
          amountPaise: widget.totalPayablePaise,
        ),
      );
    } else if (_selectedMode == 'UPI') {
      if (_primaryAccountId == null) {
        AppSnackbar.show(
          context,
          message: 'Please select a receiving UPI account.',
        );
        return;
      }
      paymentRails.add(
        PaymentRailDraft(
          paymentMethod: 'UPI',
          accountId: _primaryAccountId!,
          amountPaise: widget.totalPayablePaise,
          referenceNumber: _upiRefController.text.trim().isNotEmpty
              ? _upiRefController.text.trim()
              : null,
        ),
      );
    } else if (_selectedMode == 'Bank') {
      if (_primaryAccountId == null) {
        AppSnackbar.show(
          context,
          message: 'Please select a receiving Bank account.',
        );
        return;
      }
      paymentRails.add(
        PaymentRailDraft(
          paymentMethod: 'Bank Transfer',
          accountId: _primaryAccountId!,
          amountPaise: widget.totalPayablePaise,
          referenceNumber: _upiRefController.text.trim().isNotEmpty
              ? _upiRefController.text.trim()
              : null,
        ),
      );
    } else if (_selectedMode == 'Split') {
      if (_primaryAccountId == null || _secondaryAccountId == null) {
        AppSnackbar.show(
          context,
          message:
              'Please select both Cash and UPI accounts for split payment.',
        );
        return;
      }
      final cashPaise =
          ((double.tryParse(_splitCashController.text) ?? 0) * 100).round();
      final upiPaise = ((double.tryParse(_splitUpiController.text) ?? 0) * 100)
          .round();

      if (cashPaise + upiPaise != widget.totalPayablePaise) {
        AppSnackbar.show(
          context,
          message:
              'Split sums (₹${((cashPaise + upiPaise) / 100.0).toStringAsFixed(2)}) must equal payable (₹${(widget.totalPayablePaise / 100.0).toStringAsFixed(2)}).',
          variant: AppSnackbarVariant.error,
        );
        return;
      }

      if (cashPaise > 0) {
        paymentRails.add(
          PaymentRailDraft(
            paymentMethod: 'Cash',
            accountId: _primaryAccountId!,
            amountPaise: cashPaise,
          ),
        );
      }
      if (upiPaise > 0) {
        paymentRails.add(
          PaymentRailDraft(
            paymentMethod: 'UPI',
            accountId: _secondaryAccountId!,
            amountPaise: upiPaise,
            referenceNumber: _upiRefController.text.trim().isNotEmpty
                ? _upiRefController.text.trim()
                : null,
          ),
        );
      }
    }

    setState(() => _isProcessing = true);
    try {
      final receipt = await ref
          .read(posCartViewModelProvider.notifier)
          .checkout(
            paymentRails: paymentRails,
            tenderedAmountPaise: tenderedPaise,
            changeAmountPaise: changePaise,
          );

      if (!mounted) return;
      if (receipt != null) {
        Navigator.of(context).pop();
        widget.onCheckoutSuccess(receipt);
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: 'Checkout error: ${e.toString()}',
        variant: AppSnackbarVariant.error,
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Settle Payment',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  CurrencyFormatter.format(widget.totalPayablePaise / 100.0),
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.primary,
                  ),
                ),
              ],
            ),
            AppSpacing.gapH16,

            // Payment Mode Selector Chips
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'Cash',
                  label: Text('Cash'),
                  icon: Icon(Icons.money),
                ),
                ButtonSegment(
                  value: 'UPI',
                  label: Text('UPI / QR'),
                  icon: Icon(Icons.qr_code),
                ),
                ButtonSegment(
                  value: 'Split',
                  label: Text('Split'),
                  icon: Icon(Icons.pie_chart_outline),
                ),
              ],
              selected: {_selectedMode},
              onSelectionChanged: (val) {
                setState(() {
                  _selectedMode = val.first;
                  _pickDefaultAccounts();
                });
              },
            ),
            AppSpacing.gapH16,

            // Specific Mode UI Form
            if (_selectedMode == 'Cash') ...[
              AppTextField(
                controller: _tenderedCashController,
                label: 'Tendered Cash (₹)',
                hint: '0',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
              AppSpacing.gapH8,
              // Quick Cash suggestions
              Wrap(
                spacing: AppSpacing.s8,
                children: [
                  ActionChip(
                    label: const Text('Exact'),
                    onPressed: () {
                      _tenderedCashController.text =
                          (widget.totalPayablePaise / 100.0).toStringAsFixed(0);
                      setState(() {});
                    },
                  ),
                  ActionChip(
                    label: Text('+₹100'),
                    onPressed: () {
                      final cur =
                          double.tryParse(_tenderedCashController.text) ?? 0;
                      _tenderedCashController.text = (cur + 100)
                          .toStringAsFixed(0);
                      setState(() {});
                    },
                  ),
                  ActionChip(
                    label: Text('+₹500'),
                    onPressed: () {
                      final cur =
                          double.tryParse(_tenderedCashController.text) ?? 0;
                      _tenderedCashController.text = (cur + 500)
                          .toStringAsFixed(0);
                      setState(() {});
                    },
                  ),
                ],
              ),
              AppSpacing.gapH12,
              Container(
                padding: const EdgeInsets.all(AppSpacing.s12),
                decoration: BoxDecoration(
                  color: colors.surfaceContainer,
                  borderRadius: AppRadius.brMedium,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Change to Return:', style: textTheme.bodyMedium),
                    Text(
                      CurrencyFormatter.format(_calculatedChangePaise / 100.0),
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: _calculatedChangePaise > 0
                            ? colors.success
                            : colors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              AppSpacing.gapH12,
              if (_accounts.isNotEmpty)
                AppDropdown<String>(
                  label: 'Deposit into Cash Account',
                  value: _primaryAccountId,
                  items: _accounts
                      .map(
                        (a) => DropdownMenuItem(
                          value: a.id,
                          child: Text('${a.accountName} (${a.accountType})'),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => _primaryAccountId = val),
                ),
            ] else if (_selectedMode == 'UPI') ...[
              if (_accounts.isNotEmpty)
                AppDropdown<String>(
                  label: 'Credit into UPI Account',
                  value: _primaryAccountId,
                  items: _accounts
                      .map(
                        (a) => DropdownMenuItem(
                          value: a.id,
                          child: Text('${a.accountName} (${a.accountType})'),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => _primaryAccountId = val),
                ),
              AppSpacing.gapH12,
              AppTextField(
                controller: _upiRefController,
                label: 'UPI Reference / UTR Number (Optional)',
                hint: 'e.g. 412345678901',
              ),
            ] else if (_selectedMode == 'Split') ...[
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _splitCashController,
                      label: 'Cash Amount (₹)',
                      hint: '0',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  AppSpacing.gapW12,
                  Expanded(
                    child: AppTextField(
                      controller: _splitUpiController,
                      label: 'UPI Amount (₹)',
                      hint: '0',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              AppSpacing.gapH12,
              if (_accounts.isNotEmpty) ...[
                AppDropdown<String>(
                  label: 'Cash Account',
                  value: _primaryAccountId,
                  items: _accounts
                      .map(
                        (a) => DropdownMenuItem(
                          value: a.id,
                          child: Text(a.accountName),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => _primaryAccountId = val),
                ),
                AppSpacing.gapH8,
                AppDropdown<String>(
                  label: 'UPI Account',
                  value: _secondaryAccountId,
                  items: _accounts
                      .map(
                        (a) => DropdownMenuItem(
                          value: a.id,
                          child: Text(a.accountName),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => _secondaryAccountId = val),
                ),
              ],
            ],

            AppSpacing.gapH24,
            AppButton(
              text: 'Complete Checkout',
              icon: Icons.check_circle_outline,
              isLoading: _isProcessing,
              onPressed: _handleConfirmCheckout,
            ),
          ],
        ),
      ),
    );
  }
}
