import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/components/app_button.dart';
import '../../../../core/components/app_dropdown.dart';
import '../../../../core/components/app_snackbar.dart';
import '../../../../core/components/app_text_field.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../domain/entities/book.dart';
import '../../domain/entities/stock_movement.dart';
import '../../domain/services/inventory_cost_calculator.dart';
import '../view_models/inventory_providers.dart';

/// Modal dialog for recording manual stock adjustments (Damaged, Lost, Correction, Return).
class StockMovementDialog extends ConsumerStatefulWidget {
  const StockMovementDialog({
    super.key,
    required this.book,
    required this.currentStock,
  });

  final Book book;
  final int currentStock;

  static Future<bool?> show(
    BuildContext context, {
    required Book book,
    required int currentStock,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) =>
          StockMovementDialog(book: book, currentStock: currentStock),
    );
  }

  @override
  ConsumerState<StockMovementDialog> createState() =>
      _StockMovementDialogState();
}

class _StockMovementDialogState extends ConsumerState<StockMovementDialog> {
  final _qtyController = TextEditingController(text: '1');
  final _notesController = TextEditingController();

  StockMovementType _selectedType = StockMovementType.manualAdjustment;
  bool _isAddition = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _qtyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final qty = int.tryParse(_qtyController.text.trim()) ?? 0;
    if (qty <= 0) {
      setState(() => _errorMessage = 'Please enter a valid quantity.');
      return;
    }

    final effectiveDelta = _selectedType == StockMovementType.manualAdjustment
        ? (_isAddition ? qty : -qty)
        : (_selectedType.isAddition ? qty : -qty);

    // Negative inventory guard
    if (effectiveDelta < 0 &&
        !InventoryCostCalculator.canDeductStock(
          currentStock: widget.currentStock,
          quantityToDeduct: effectiveDelta.abs(),
        )) {
      setState(
        () => _errorMessage =
            'Cannot deduct $qty copies. Only ${widget.currentStock} copies are currently on hand.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(inventoryRepositoryProvider);
      final movement = StockMovement(
        id: const Uuid().v4(),
        fairId: widget.book.fairId,
        bookId: widget.book.id,
        quantity: effectiveDelta,
        movementType: _selectedType,
        movementDate: DateTime.now(),
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : 'Stock adjusted manually',
        createdAt: DateTime.now(),
      );

      await repo.recordStockMovement(movement);

      if (mounted) {
        Navigator.of(context).pop(true);
        AppSnackbar.show(
          context,
          message:
              'Stock adjusted successfully: ${movement.netDelta > 0 ? '+' : ''}${movement.netDelta} copies.',
          variant: AppSnackbarVariant.success,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.brLarge,
        side: BorderSide(color: colors.border, width: 1.0),
      ),
      child: Container(
        padding: AppSpacing.insetAll24,
        constraints: const BoxConstraints(maxWidth: 420.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.tune_rounded, color: colors.primary, size: 22.0),
                AppSpacing.gapW8,
                Expanded(
                  child: Text(
                    'Adjust Book Stock',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                      fontFamily: 'Georgia',
                    ),
                  ),
                ),
              ],
            ),
            AppSpacing.gapH4,
            Text(
              '${widget.book.title} (Currently: ${widget.currentStock} in stock)',
              style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
            AppSpacing.gapH16,

            // Movement Type Dropdown
            AppDropdown<StockMovementType>(
              label: 'Adjustment Category',
              value: _selectedType,
              items: const [
                DropdownMenuItem(
                  value: StockMovementType.manualAdjustment,
                  child: Text('Manual Adjustment / Audit'),
                ),
                DropdownMenuItem(
                  value: StockMovementType.damaged,
                  child: Text('Damaged / Written Off'),
                ),
                DropdownMenuItem(
                  value: StockMovementType.lost,
                  child: Text('Lost / Missing'),
                ),
                DropdownMenuItem(
                  value: StockMovementType.customerReturnIn,
                  child: Text('Customer Return In (+ stock)'),
                ),
                DropdownMenuItem(
                  value: StockMovementType.partnerContributionIn,
                  child: Text('Partner Contributed (+ stock)'),
                ),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedType = val);
              },
            ),

            if (_selectedType == StockMovementType.manualAdjustment) ...[
              AppSpacing.gapH12,
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _isAddition = true),
                      borderRadius: AppRadius.brMedium,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        decoration: BoxDecoration(
                          color: _isAddition
                              ? colors.primary
                              : colors.surfaceSecondary,
                          borderRadius: AppRadius.brMedium,
                        ),
                        child: Center(
                          child: Text(
                            '+ Add Stock',
                            style: TextStyle(
                              color: _isAddition
                                  ? (colors.isDark
                                        ? AppColors.c03071E
                                        : AppColors.cFFFFFF)
                                  : colors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  AppSpacing.gapW8,
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _isAddition = false),
                      borderRadius: AppRadius.brMedium,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        decoration: BoxDecoration(
                          color: !_isAddition
                              ? colors.primary
                              : colors.surfaceSecondary,
                          borderRadius: AppRadius.brMedium,
                        ),
                        child: Center(
                          child: Text(
                            '- Deduct Stock',
                            style: TextStyle(
                              color: !_isAddition
                                  ? (colors.isDark
                                        ? AppColors.c03071E
                                        : AppColors.cFFFFFF)
                                  : colors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            AppSpacing.gapH16,
            AppTextField(
              controller: _qtyController,
              label: 'Quantity of Copies',
              hint: '1',
              keyboardType: TextInputType.number,
            ),
            AppSpacing.gapH12,
            AppTextField(
              controller: _notesController,
              label: 'Adjustment Reason / Notes',
              hint: 'e.g. Stock count audit discrepancy, damaged in transit',
            ),

            if (_errorMessage != null) ...[
              AppSpacing.gapH12,
              Text(
                _errorMessage!,
                style: TextStyle(
                  color: colors.error,
                  fontSize: 12.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],

            AppSpacing.gapH24,
            Row(
              children: [
                Expanded(
                  child: AppButton.outlined(
                    text: 'Cancel',
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
                AppSpacing.gapW12,
                Expanded(
                  child: AppButton(
                    text: 'Confirm',
                    isLoading: _isSubmitting,
                    onPressed: _handleSubmit,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
