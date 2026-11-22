import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
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
import '../../../../core/utils/responsive_layout.dart';
import '../../../book_fairs/presentation/view_models/book_fair_providers.dart';
import '../../domain/entities/cashbook_account.dart';
import '../view_models/cashbook_providers.dart';

/// Screen 01: Cashbook Overview showing liquid funds, account balances, and ledger timeline.
class CashbookOverviewScreen extends ConsumerStatefulWidget {
  const CashbookOverviewScreen({super.key});

  @override
  ConsumerState<CashbookOverviewScreen> createState() =>
      _CashbookOverviewScreenState();
}

class _CashbookOverviewScreenState
    extends ConsumerState<CashbookOverviewScreen> {
  String? _selectedFairId;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    final fairsAsync = ref.watch(bookFairsStreamProvider);
    final accountsAsync = ref.watch(
      cashbookAccountsStreamProvider(_selectedFairId),
    );
    final transactionsAsync = ref.watch(
      accountTransactionsStreamProvider((
        fairId: _selectedFairId,
        accountId: null,
      )),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cashbook & Accounts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz_rounded),
            tooltip: 'Transfer Funds',
            onPressed: () =>
                context.pushNamed(RouteNames.cashbookCreateTransfer),
          ),
          const PaletteSwitcherButton(),
          const SizedBox(width: AppSpacing.s8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAccountDialog(context, ref),
        icon: const Icon(Icons.account_balance_wallet_rounded),
        label: const Text('New Account'),
      ),
      body: SafeArea(
        child: ResponsiveContentContainer(
          child: accountsAsync.when(
            loading: () => const Center(
              child: AppLoadingIndicator.large(
                message: 'Calculating ledger balances...',
              ),
            ),
            error: (err, _) => Center(
              child: Text(
                'Error loading accounts: $err',
                style: TextStyle(color: colors.error),
              ),
            ),
            data: (accounts) {
              int totalCash = 0;
              int totalUpi = 0;
              int totalBank = 0;
              int totalFunds = 0;

              for (final a in accounts.where((acc) => acc.isActive)) {
                totalFunds += a.currentBalancePaise;
                switch (a.accountType.toLowerCase()) {
                  case 'cash':
                    totalCash += a.currentBalancePaise;
                    break;
                  case 'upi':
                    totalUpi += a.currentBalancePaise;
                    break;
                  case 'bank':
                    totalBank += a.currentBalancePaise;
                    break;
                }
              }

              return SingleChildScrollView(
                padding: AppSpacing.insetAll16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Fair Selector
                    fairsAsync.when(
                      data: (fairs) {
                        if (fairs.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppSpacing.s16,
                          ),
                          child: AppDropdown<String?>(
                            compact: true,
                            value: _selectedFairId,
                            sheetTitle: 'Select Book Fair',
                            sheetSubtitle:
                                'Filter accounts and cashbooks by fair',
                            prefixIcon: const Icon(
                              Icons.store_rounded,
                              size: 20,
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text(
                                  'All Book Fairs',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                              ...fairs.map(
                                (f) => DropdownMenuItem(
                                  value: f.id,
                                  child: Text(f.name),
                                ),
                              ),
                            ],
                            onChanged: (val) {
                              setState(() => _selectedFairId = val);
                            },
                          ),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),

                    // Hero Total Funds Card
                    AppCard(
                      padding: AppSpacing.insetAll16,
                      backgroundColor: colors.surfaceContainerHigh,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TOTAL BUSINESS LIQUID FUNDS',
                            style: textTheme.labelSmall?.copyWith(
                              color: colors.onSurfaceMuted,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s8),
                          Text(
                            CurrencyFormatter.formatPaise(totalFunds),
                            style: textTheme.headlineMedium?.copyWith(
                              color: colors.onSurface,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildFundTile(
                                  label: 'Physical Cash',
                                  value: CurrencyFormatter.formatPaise(
                                    totalCash,
                                  ),
                                  icon: Icons.payments_rounded,
                                  color: colors.primary,
                                  context: context,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: colors.borderSubtle,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.s8,
                                ),
                              ),
                              Expanded(
                                child: _buildFundTile(
                                  label: 'UPI / Online',
                                  value: CurrencyFormatter.formatPaise(
                                    totalUpi,
                                  ),
                                  icon: Icons.qr_code_rounded,
                                  color: colors.warning,
                                  context: context,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: colors.borderSubtle,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.s8,
                                ),
                              ),
                              Expanded(
                                child: _buildFundTile(
                                  label: 'Bank Account',
                                  value: CurrencyFormatter.formatPaise(
                                    totalBank,
                                  ),
                                  icon: Icons.account_balance_rounded,
                                  color: colors.success,
                                  context: context,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s16),

                    // Quick Actions
                    Row(
                      children: [
                        Expanded(
                          child: AppButton.outlined(
                            text: 'Transfer Funds',
                            icon: Icons.swap_horiz_rounded,
                            onPressed: () => context.pushNamed(
                              RouteNames.cashbookCreateTransfer,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s12),
                        Expanded(
                          child: AppButton(
                            text: 'New Account',
                            icon: Icons.add_rounded,
                            onPressed: () =>
                                _showAddAccountDialog(context, ref),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s24),

                    // Accounts Section
                    Text(
                      'Payment & Holding Accounts',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    if (accounts.isEmpty) ...[
                      const AppEmptyState(
                        title: 'No Accounts Configured',
                        description: 'Add your cashbox, UPI merchant handles, and bank accounts to track money movements.',
                        icon: Icons.account_balance_wallet_rounded,
                      ),
                    ] else ...[
                      ...accounts.map(
                        (a) => _buildAccountCard(account: a, context: context),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.s24),

                    // Recent Ledger Activity Section
                    Text(
                      'Recent Ledger Movements',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    transactionsAsync.when(
                      data: (txs) {
                        if (txs.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.s16,
                            ),
                            child: Text(
                              'No ledger transactions recorded yet.',
                              style: TextStyle(color: colors.onSurfaceMuted),
                            ),
                          );
                        }
                        return Column(
                          children: txs
                              .take(8)
                              .map(
                                (tx) => _buildTransactionCard(
                                  tx: tx,
                                  context: context,
                                ),
                              )
                              .toList(),
                        );
                      },
                      loading: () => const AppLoadingIndicator.small(),
                      error: (e, _) => Text('Error loading ledger: $e'),
                    ),
                    const SizedBox(height: AppSpacing.s80), // FAB spacing
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFundTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required BuildContext context,
  }) {
    final textTheme = context.textTheme;
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: AppSpacing.s4),
            Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s4),
        Text(
          value,
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: colors.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildAccountCard({
    required CashbookAccount account,
    required BuildContext context,
  }) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    IconData typeIcon;
    switch (account.accountType.toLowerCase()) {
      case 'cash':
        typeIcon = Icons.payments_rounded;
        break;
      case 'upi':
        typeIcon = Icons.qr_code_rounded;
        break;
      case 'bank':
        typeIcon = Icons.account_balance_rounded;
        break;
      default:
        typeIcon = Icons.credit_card_rounded;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s12),
      child: AppCard.interactive(
        padding: AppSpacing.insetAll16,
        onTap: () => context.pushNamed(
          RouteNames.cashbookAccountDetails,
          pathParameters: {'id': account.id},
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: AppRadius.brMedium,
              ),
              child: Icon(typeIcon, color: colors.primary, size: 22),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.accountName,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    '${account.accountType.toUpperCase()} • Opening: ${CurrencyFormatter.formatPaise(account.openingBalancePaise)}',
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyFormatter.formatPaise(account.currentBalancePaise),
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: account.currentBalancePaise >= 0
                        ? colors.onSurface
                        : colors.error,
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                AppBadge(
                  label: account.isActive ? 'Active' : 'Archived',
                  variant: account.isActive
                      ? AppBadgeVariant.success
                      : AppBadgeVariant.neutral,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard({
    required dynamic tx,
    required BuildContext context,
  }) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    final isInflow = tx.direction.toLowerCase() == 'inflow';
    final sign = isInflow ? '+' : '-';
    final amountColor = isInflow ? colors.success : colors.error;

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.s8),
      padding: AppSpacing.insetAll12,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: amountColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isInflow
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: amountColor,
              size: 18,
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.description.isNotEmpty
                      ? tx.description
                      : tx.transactionType.replaceAll('_', ' ').toUpperCase(),
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.s2),
                Text(
                  '${tx.transactionDate.day}/${tx.transactionDate.month}/${tx.transactionDate.year} • ${tx.transactionType}',
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          Text(
            '$sign${CurrencyFormatter.formatPaise(tx.amountPaise)}',
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: amountColor,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddAccountDialog(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final nameController = TextEditingController();
    final balanceController = TextEditingController(text: '0.00');
    String type = 'cash';
    String? fairId = _selectedFairId;

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (ctx, setState) {
          final fairsAsync = ref.watch(bookFairsStreamProvider);

          return AlertDialog(
            backgroundColor: colors.surface,
            title: const Text('Add Cashbook Account'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  fairsAsync.when(
                    data: (fairs) {
                      if (fairId == null && fairs.isNotEmpty) {
                        fairId = fairs.first.id;
                      }
                      return AppDropdown<String>(
                        label: 'Associated Book Fair *',
                        value: fairId,
                        items: fairs
                            .map(
                              (f) => DropdownMenuItem(
                                value: f.id,
                                child: Text(f.name),
                              ),
                            )
                            .toList(),
                        onChanged: (val) => setState(() => fairId = val),
                      );
                    },
                    loading: () => const AppLoadingIndicator.small(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  AppTextField(
                    controller: nameController,
                    label: 'Account Name *',
                    hint: 'e.g. Counter Cashbox or GPay Merchant',
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  AppDropdown<String>(
                    label: 'Account Type *',
                    value: type,
                    items: const [
                      DropdownMenuItem(
                        value: 'cash',
                        child: Text('Physical Cash'),
                      ),
                      DropdownMenuItem(
                        value: 'upi',
                        child: Text('UPI / QR Account'),
                      ),
                      DropdownMenuItem(
                        value: 'bank',
                        child: Text('Bank Account'),
                      ),
                      DropdownMenuItem(
                        value: 'other',
                        child: Text('Other Account'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => type = val);
                    },
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  AppTextField(
                    controller: balanceController,
                    label: 'Opening Balance (₹)',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    prefixIcon: const Icon(
                      Icons.currency_rupee_rounded,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dlgCtx).pop(),
                child: const Text('Cancel'),
              ),
              AppButton(
                text: 'Create Account',
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) {
                    AppSnackbar.showError(
                      dlgCtx,
                      'Account name cannot be empty',
                    );
                    return;
                  }
                  if (fairId == null || fairId!.isEmpty) {
                    AppSnackbar.showError(
                      dlgCtx,
                      'Please associate with a Book Fair',
                    );
                    return;
                  }

                  final openingNum =
                      double.tryParse(balanceController.text) ?? 0.0;
                  final openingPaise = (openingNum * 100).round();

                  Navigator.of(dlgCtx).pop();

                  final newAccount = CashbookAccount(
                    id: const Uuid().v4(),
                    fairId: fairId!,
                    accountName: name,
                    accountType: type,
                    openingBalancePaise: openingPaise,
                    currentBalancePaise: openingPaise,
                    isActive: true,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  );

                  await ref
                      .read(cashbookRepositoryProvider)
                      .createAccount(newAccount);

                  if (context.mounted) {
                    AppSnackbar.showSuccess(
                      context,
                      'Cashbook account created successfully',
                    );
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
