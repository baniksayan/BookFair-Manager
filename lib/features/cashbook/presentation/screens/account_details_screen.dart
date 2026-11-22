import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/components/app_badge.dart';
import '../../../../core/components/app_card.dart';
import '../../../../core/components/app_empty_state.dart';
import '../../../../core/components/app_loading.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../view_models/cashbook_providers.dart';

/// Screen 02: Detailed Account Ledger with credits, debits, and chronological movement history.
class AccountDetailsScreen extends ConsumerStatefulWidget {
  const AccountDetailsScreen({super.key, required this.accountId});

  final String accountId;

  @override
  ConsumerState<AccountDetailsScreen> createState() =>
      _AccountDetailsScreenState();
}

class _AccountDetailsScreenState extends ConsumerState<AccountDetailsScreen> {
  String _directionFilter = 'All'; // 'All', 'Inflow', 'Outflow'

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    final accountAsync = ref.watch(
      cashbookAccountDetailsStreamProvider(widget.accountId),
    );
    final transactionsAsync = ref.watch(
      accountTransactionsStreamProvider((
        fairId: null,
        accountId: widget.accountId,
      )),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Account Details')),
      body: SafeArea(
        child: ResponsiveContentContainer(
          child: accountAsync.when(
            loading: () => const Center(
              child: AppLoadingIndicator.large(
                message: 'Loading account details...',
              ),
            ),
            error: (err, _) => Center(
              child: Text(
                'Failed to load account: $err',
                style: TextStyle(color: colors.error),
              ),
            ),
            data: (account) {
              if (account == null) {
                return const Center(child: Text('Account not found'));
              }

              return transactionsAsync.when(
                loading: () => const Center(child: AppLoadingIndicator.small()),
                error: (err, _) =>
                    Center(child: Text('Error loading transactions: $err')),
                data: (transactions) {
                  int totalInflows = 0;
                  int totalOutflows = 0;

                  for (final tx in transactions) {
                    if (tx.direction.toLowerCase() == 'inflow') {
                      totalInflows += tx.amountPaise;
                    } else if (tx.direction.toLowerCase() == 'outflow') {
                      totalOutflows += tx.amountPaise;
                    }
                  }

                  var filteredTx = transactions.where((tx) {
                    if (_directionFilter == 'Inflow') {
                      return tx.direction.toLowerCase() == 'inflow';
                    }
                    if (_directionFilter == 'Outflow') {
                      return tx.direction.toLowerCase() == 'outflow';
                    }
                    return true;
                  }).toList();

                  return SingleChildScrollView(
                    padding: AppSpacing.insetAll16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Account Header Card
                        AppCard(
                          padding: AppSpacing.insetAll16,
                          backgroundColor: colors.surfaceContainerHigh,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      account.accountName,
                                      style: textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: colors.onSurface,
                                      ),
                                    ),
                                  ),
                                  AppBadge(
                                    label: account.accountType.toUpperCase(),
                                    variant: AppBadgeVariant.primary,
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.s12),
                              Text(
                                'CURRENT BALANCE',
                                style: textTheme.labelSmall?.copyWith(
                                  color: colors.onSurfaceMuted,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.s4),
                              Text(
                                CurrencyFormatter.formatPaise(
                                  account.currentBalancePaise,
                                ),
                                style: textTheme.headlineMedium?.copyWith(
                                  color: account.currentBalancePaise >= 0
                                      ? colors.onSurface
                                      : colors.error,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.s16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildMiniStat(
                                      label: 'Opening Balance',
                                      amount: CurrencyFormatter.formatPaise(
                                        account.openingBalancePaise,
                                      ),
                                      context: context,
                                    ),
                                  ),
                                  Expanded(
                                    child: _buildMiniStat(
                                      label: 'Total Credits',
                                      amount: CurrencyFormatter.formatPaise(
                                        totalInflows,
                                      ),
                                      valueColor: colors.success,
                                      context: context,
                                    ),
                                  ),
                                  Expanded(
                                    child: _buildMiniStat(
                                      label: 'Total Debits',
                                      amount: CurrencyFormatter.formatPaise(
                                        totalOutflows,
                                      ),
                                      valueColor: colors.error,
                                      context: context,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s20),

                        // Filter Chips
                        Row(
                          children: [
                            Text(
                              'Transactions',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colors.onSurface,
                              ),
                            ),
                            const Spacer(),
                            ChoiceChip(
                              label: const Text('All'),
                              selected: _directionFilter == 'All',
                              onSelected: (_) =>
                                  setState(() => _directionFilter = 'All'),
                            ),
                            const SizedBox(width: AppSpacing.s6),
                            ChoiceChip(
                              label: const Text('Inflows'),
                              selected: _directionFilter == 'Inflow',
                              onSelected: (_) =>
                                  setState(() => _directionFilter = 'Inflow'),
                            ),
                            const SizedBox(width: AppSpacing.s6),
                            ChoiceChip(
                              label: const Text('Outflows'),
                              selected: _directionFilter == 'Outflow',
                              onSelected: (_) =>
                                  setState(() => _directionFilter = 'Outflow'),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s12),

                        if (filteredTx.isEmpty) ...[
                          const AppEmptyState(
                            title: 'No Movements Found',
                            description: 'No transactions match the selected ledger direction.',
                            icon: Icons.receipt_long_rounded,
                          ),
                        ] else ...[
                          ...filteredTx.map(
                            (tx) => _buildLedgerItem(tx: tx, context: context),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat({
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
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor ?? colors.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildLedgerItem({
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
                ),
                const SizedBox(height: AppSpacing.s2),
                Text(
                  '${tx.transactionDate.day}/${tx.transactionDate.month}/${tx.transactionDate.year} • Type: ${tx.transactionType}',
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
}
