import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/constants/app_constants.dart';
import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/theme_controller.dart';
import '../../../../core/components/app_app_bar.dart';
import '../../../../core/components/app_badge.dart';
import '../../../../core/components/app_button.dart';
import '../../../../core/components/app_card.dart';
import '../../../../core/components/palette_switcher_sheet.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../../book_fairs/presentation/view_models/book_fair_providers.dart';
import '../../../cashbook/presentation/view_models/cashbook_providers.dart';
import '../../../expenses/presentation/view_models/expense_providers.dart';
import '../../../inventory/presentation/view_models/inventory_providers.dart';

/// Screen 08: Global Settings & Application Preferences Screen.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final textTheme = context.textTheme;
    final themeState = ref.watch(themeControllerProvider);
    final themeNotifier = ref.read(themeControllerProvider.notifier);

    // Database counts for live data section
    final bookFairs = ref.watch(bookFairsStreamProvider).value ?? [];
    final books = ref.watch(booksStreamProvider(null)).value ?? [];
    final batches = ref.watch(purchaseBatchesStreamProvider(null)).value ?? [];
    final suppliers = ref.watch(suppliersStreamProvider).value ?? [];
    final expenses = ref.watch(expensesStreamProvider(null)).value ?? [];
    final accounts =
        ref.watch(cashbookAccountsStreamProvider(null)).value ?? [];

    return Scaffold(
      appBar: const AppAppBar(
        title: 'Settings & Preferences',
        subtitle: 'Theme engine, storage, and application configuration',
      ),
      body: SafeArea(
        child: ResponsiveContentContainer(
          child: SingleChildScrollView(
            padding: AppSpacing.insetAll16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ==========================================
                // SECTION A: APPEARANCE & THEME ENGINE
                // ==========================================
                _buildSectionHeader(
                  context,
                  title: 'Appearance & Themes',
                  icon: Icons.palette_outlined,
                ),
                AppSpacing.gapH12,

                // Current Palette Overview Card
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ACTIVE BRAND PALETTE',
                                style: textTheme.labelSmall?.copyWith(
                                  color: colors.textSecondary,
                                  fontSize: 9.0,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              AppSpacing.gapH4,
                              Text(
                                themeState.palette.name,
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          AppButton.outlined(
                            text: 'Switch Palette',
                            icon: Icons.color_lens_outlined,
                            size: AppButtonSize.small,
                            onPressed: () => PaletteSwitcherSheet.show(context),
                          ),
                        ],
                      ),
                      AppSpacing.gapH12,
                      Text(
                        themeState.palette.description,
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      AppSpacing.gapH12,

                      // 10-Color Swatch Strip
                      ClipRRect(
                        borderRadius: AppRadius.brSmall,
                        child: SizedBox(
                          height: 24.0,
                          child: Row(
                            children: themeState.palette.colors.map((c) {
                              return Expanded(child: Container(color: c));
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                AppSpacing.gapH16,

                // Theme Mode Selector Card
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Display Mode',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      AppSpacing.gapH4,
                      Text(
                        'Choose between system automatic, light, or dark visual mode',
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      AppSpacing.gapH16,
                      SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.system,
                            label: Text('System'),
                            icon: Icon(
                              Icons.brightness_auto_rounded,
                              size: 16.0,
                            ),
                          ),
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.light,
                            label: Text('Light'),
                            icon: Icon(Icons.wb_sunny_outlined, size: 16.0),
                          ),
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.dark,
                            label: Text('Dark'),
                            icon: Icon(Icons.nightlight_round, size: 16.0),
                          ),
                        ],
                        selected: {themeState.themeMode},
                        onSelectionChanged: (Set<ThemeMode> newSelection) {
                          themeNotifier.setThemeMode(newSelection.first);
                        },
                        style: ButtonStyle(
                          side: WidgetStateProperty.all(
                            BorderSide(color: colors.border, width: 1.0),
                          ),
                          backgroundColor: WidgetStateProperty.resolveWith((
                            states,
                          ) {
                            if (states.contains(WidgetState.selected)) {
                              return colors.primary;
                            }
                            return colors.surface;
                          }),
                          foregroundColor: WidgetStateProperty.resolveWith((
                            states,
                          ) {
                            if (states.contains(WidgetState.selected)) {
                              return colors.onPrimary;
                            }
                            return colors.textSecondary;
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
                AppSpacing.gapH24,

                // ==========================================
                // SECTION B: FINANCE, CASHBOOK & ACCOUNTING
                // ==========================================
                _buildSectionHeader(
                  context,
                  title: 'Finance & Accounting',
                  icon: Icons.account_balance_wallet_outlined,
                ),
                AppSpacing.gapH12,
                AppCard(
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.15),
                            borderRadius: AppRadius.brSmall,
                          ),
                          child: Icon(
                            Icons.receipt_long_rounded,
                            color: colors.primary,
                            size: 20,
                          ),
                        ),
                        title: const Text('Operating Expenses'),
                        subtitle: Text(
                          '${expenses.length} recorded expense(s)',
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                        ),
                        onTap: () => context.pushNamed(RouteNames.expenses),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: colors.warning.withValues(alpha: 0.15),
                            borderRadius: AppRadius.brSmall,
                          ),
                          child: Icon(
                            Icons.account_balance_wallet_rounded,
                            color: colors.warning,
                            size: 20,
                          ),
                        ),
                        title: const Text('Cashbook & Accounts'),
                        subtitle: Text('${accounts.length} active account(s)'),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                        ),
                        onTap: () => context.pushNamed(RouteNames.cashbook),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: colors.success.withValues(alpha: 0.15),
                            borderRadius: AppRadius.brSmall,
                          ),
                          child: Icon(
                            Icons.account_balance_rounded,
                            color: colors.success,
                            size: 20,
                          ),
                        ),
                        title: const Text('Financial Dashboard'),
                        subtitle: const Text(
                          'Consolidated funds, capital & dues',
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                        ),
                        onTap: () => context.pushNamed(RouteNames.accounting),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: colors.secondary.withValues(alpha: 0.15),
                            borderRadius: AppRadius.brSmall,
                          ),
                          child: Icon(
                            Icons.analytics_rounded,
                            color: colors.secondary,
                            size: 20,
                          ),
                        ),
                        title: const Text('Financial Reports'),
                        subtitle: const Text(
                          'Category breakdown & cashflow analysis',
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                        ),
                        onTap: () =>
                            context.pushNamed(RouteNames.accountingReports),
                      ),
                    ],
                  ),
                ),
                AppSpacing.gapH24,

                // ==========================================
                // SECTION C: APPLICATION INFORMATION
                // ==========================================
                _buildSectionHeader(
                  context,
                  title: 'Application Details',
                  icon: Icons.info_outline_rounded,
                ),
                AppSpacing.gapH12,
                AppCard(
                  child: Column(
                    children: [
                      _buildInfoRow(
                        context,
                        label: 'Application Name',
                        value: AppConstants.appName,
                      ),
                      const Divider(),
                      _buildInfoRow(
                        context,
                        label: 'Release Version',
                        value: '${AppConstants.appVersion} (Stage 04)',
                      ),
                      const Divider(),
                      _buildInfoRow(
                        context,
                        label: 'Operational Architecture',
                        value: 'Offline-First MVVM + Hive',
                      ),
                      const Divider(),
                      _buildInfoRow(
                        context,
                        label: 'Local Persistence Engine',
                        value: 'Hive v2.2.3 (10 Box Collections)',
                        badge: const AppBadge(
                          label: 'ACTIVE',
                          variant: AppBadgeVariant.success,
                        ),
                      ),
                    ],
                  ),
                ),
                AppSpacing.gapH24,

                // ==========================================
                // SECTION C: DATA & LOCAL STORAGE
                // ==========================================
                _buildSectionHeader(
                  context,
                  title: 'Storage & Database Registry',
                  icon: Icons.storage_rounded,
                ),
                AppSpacing.gapH12,
                AppCard(
                  child: Column(
                    children: [
                      _buildInfoRow(
                        context,
                        label: 'Registered Book Fairs',
                        value: '${bookFairs.length} records',
                      ),
                      const Divider(),
                      _buildInfoRow(
                        context,
                        label: 'Master Catalog Titles',
                        value: '${books.length} titles',
                      ),
                      const Divider(),
                      _buildInfoRow(
                        context,
                        label: 'Purchase Batches Stored',
                        value: '${batches.length} batches',
                      ),
                      const Divider(),
                      _buildInfoRow(
                        context,
                        label: 'Registered Suppliers',
                        value: '${suppliers.length} vendors',
                      ),
                      const Divider(),
                      _buildInfoRow(
                        context,
                        label: 'Recorded Expenses',
                        value: '${expenses.length} records',
                      ),
                      const Divider(),
                      _buildInfoRow(
                        context,
                        label: 'Cashbook Accounts',
                        value: '${accounts.length} accounts',
                      ),
                    ],
                  ),
                ),
                AppSpacing.gapH32,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required IconData icon,
  }) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    return Row(
      children: [
        Icon(icon, size: 18.0, color: colors.primary),
        AppSpacing.gapW8,
        Text(
          title,
          style: textTheme.titleMedium?.copyWith(
            fontFamily: 'Georgia',
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required String label,
    required String value,
    Widget? badge,
  }) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
          ),
          if (badge != null)
            badge
          else
            Text(
              value,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
        ],
      ),
    );
  }
}
