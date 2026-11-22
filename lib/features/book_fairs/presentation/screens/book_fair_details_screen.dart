import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/components/app_app_bar.dart';
import '../../../../core/components/app_badge.dart';
import '../../../../core/components/app_button.dart';
import '../../../../core/components/app_card.dart';
import '../../../../core/components/app_dialog.dart';
import '../../../../core/components/app_empty_state.dart';
import '../../../../core/components/app_loading.dart';
import '../../../../core/components/app_snackbar.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../domain/entities/book_fair.dart';
import '../../domain/entities/partner.dart';
import '../view_models/book_fair_providers.dart';
import '../widgets/record_investment_sheet.dart';

/// Screen 03: Comprehensive Book Fair Details, Financial Ledger & Partnerships.
class BookFairDetailsScreen extends ConsumerWidget {
  const BookFairDetailsScreen({super.key, required this.fairId});

  final String fairId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    final fairAsync = ref.watch(bookFairDetailsStreamProvider(fairId));
    final partnersAsync = ref.watch(partnersForFairStreamProvider(fairId));
    final investmentsAsync = ref.watch(
      investmentsForFairStreamProvider(fairId),
    );
    final finSummary = ref.watch(fairFinancialSummaryProvider(fairId));

    return Scaffold(
      appBar: AppAppBar(
        title: 'Exhibition Details',
        actions: [
          IconButton(
            tooltip: 'Partner Dues & Reimbursements',
            icon: Icon(Icons.handshake_outlined, color: colors.textPrimary),
            onPressed: () => context.push('/book-fairs/$fairId/partner-dues'),
          ),
          IconButton(
            tooltip: 'Manage Partners',
            icon: Icon(Icons.people_outline_rounded, color: colors.textPrimary),
            onPressed: () => context.push('/book-fairs/$fairId/partners'),
          ),
          IconButton(
            tooltip: 'Edit Fair',
            icon: Icon(Icons.edit_outlined, color: colors.textPrimary),
            onPressed: () => context.push('/book-fairs/$fairId/edit'),
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveContentContainer(
          child: fairAsync.when(
            loading: () => const Center(
              child: AppLoadingIndicator.large(
                message: 'Loading exhibition overview...',
              ),
            ),
            error: (err, _) => Center(
              child: Text('Error: $err', style: TextStyle(color: colors.error)),
            ),
            data: (fair) {
              if (fair == null) {
                return AppEmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'Book Fair Not Found',
                  description: 'This book fair record may have been removed or does not exist.',
                  actionLabel: 'Return to Listings',
                  onAction: () => context.go('/book-fairs'),
                );
              }

              final partners = partnersAsync.value ?? [];
              final investments = investmentsAsync.value ?? [];

              return SingleChildScrollView(
                padding: AppSpacing.insetAll16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- Section A: Fair Overview Banner ---
                    _buildOverviewCard(context, fair),
                    AppSpacing.gapH24,

                    // --- Section B: Financial Overview ---
                    _buildFinancialSection(
                      context,
                      fair,
                      finSummary,
                      investments.isNotEmpty,
                    ),
                    AppSpacing.gapH24,

                    // --- Section C: Partnership Summary ---
                    _buildPartnershipSection(
                      context,
                      fair,
                      partners,
                      investments,
                    ),
                    AppSpacing.gapH24,

                    // --- Section D: Management Actions ---
                    _buildManagementActions(context, ref, fair),
                    AppSpacing.gapH24,

                    // --- Section E: Future Modules (Stage 03+) ---
                    _buildFutureModulesSection(context),
                    AppSpacing.gapH32,
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewCard(BuildContext context, BookFair fair) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    final dateRangeStr = DateFormatter.formatRange(
      fair.startDate,
      fair.endDate,
    );
    final locationDisplay = [
      fair.location,
      if (fair.city.isNotEmpty) fair.city,
      if (fair.state.isNotEmpty) fair.state,
    ].join(', ');

    return AppCard(
      padding: AppSpacing.insetAll20,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors.isDark
            ? const [AppColors.c370617, AppColors.c03071E]
            : const [AppColors.c370617, AppColors.c6A040F],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBadge(fair.status),
              Text(
                'CREATED ${DateFormatter.formatDisplay(fair.createdAt)}',
                style: textTheme.labelSmall?.copyWith(
                  color: AppColors.cFFBA08,
                  letterSpacing: 0.8,
                  fontSize: 10.0,
                ),
              ),
            ],
          ),
          AppSpacing.gapH12,
          Text(
            fair.name,
            style: textTheme.headlineMedium?.copyWith(
              fontFamily: 'Georgia',
              fontWeight: FontWeight.w700,
              color: AppColors.cFFFFFF,
            ),
          ),
          AppSpacing.gapH4,
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 16.0,
                color: AppColors.cFFBA08,
              ),
              AppSpacing.gapW4,
              Expanded(
                child: Text(
                  locationDisplay,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.cFFFFFF,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.gapH4,
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 14.0,
                color: AppColors.cFFBA08,
              ),
              AppSpacing.gapW4,
              Text(
                dateRangeStr,
                style: textTheme.bodySmall?.copyWith(color: AppColors.cFFBA08),
              ),
            ],
          ),
          if (fair.description.isNotEmpty) ...[
            AppSpacing.gapH12,
            Text(
              fair.description,
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.cFFFFFF,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFinancialSection(
    BuildContext context,
    BookFair fair,
    FairFinancialSummary fin,
    bool hasInvestments,
  ) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Financial Overview',
              style: textTheme.titleLarge?.copyWith(
                fontFamily: 'Georgia',
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            AppButton(
              text: 'Record Contribution',
              icon: Icons.add_circle_outline_rounded,
              size: AppButtonSize.small,
              onPressed: () =>
                  RecordInvestmentSheet.show(context: context, fairId: fair.id),
            ),
          ],
        ),
        AppSpacing.gapH4,
        Text(
          'Capital mobilization vs. estimated stall budget',
          style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
        ),
        AppSpacing.gapH12,

        // 2x2 Financial Metrics
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'ESTIMATED BUDGET',
                value: CurrencyFormatter.format(fin.estimatedBudget),
                subtitle: 'Target expense budget',
                icon: Icons.account_balance_outlined,
              ),
            ),
            AppSpacing.gapW12,
            Expanded(
              child: _MetricCard(
                title: 'TOTAL MOBILIZED',
                value: CurrencyFormatter.format(fin.totalRecordedInvestment),
                subtitle: '${fin.investmentsCount} recorded entries',
                icon: Icons.savings_outlined,
                isHighlighted: true,
              ),
            ),
          ],
        ),
        AppSpacing.gapH12,
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'INITIAL SEED CAPITAL',
                value: CurrencyFormatter.format(fair.initialInvestment),
                subtitle: 'Committed at fair creation',
                icon: Icons.monetization_on_outlined,
              ),
            ),
            AppSpacing.gapW12,
            Expanded(
              child: _MetricCard(
                title: 'PLANNING VARIANCE',
                value: CurrencyFormatter.format(
                  fin.remainingPlannedBudget.abs(),
                ),
                subtitle: fin.remainingPlannedBudget >= 0
                    ? 'Remaining budget to fund'
                    : 'Surplus capital mobilized',
                icon: Icons.tune_rounded,
              ),
            ),
          ],
        ),
        AppSpacing.gapH8,

        // Financial disclaimer note
        Container(
          padding: AppSpacing.insetAll12,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: AppRadius.brMedium,
            border: Border.all(color: colors.border, width: 1.0),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 16.0,
                color: colors.textSecondary,
              ),
              AppSpacing.gapW8,
              Expanded(
                child: Text(
                  'Note: Figures above reflect capital contributions and planning estimates only. Cash registers, sales, and operational expenses will activate in Stage 03.',
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                    fontSize: 11.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPartnershipSection(
    BuildContext context,
    BookFair fair,
    List<Partner> partners,
    List<dynamic> investments,
  ) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Stall Partners (${partners.length})',
              style: textTheme.titleLarge?.copyWith(
                fontFamily: 'Georgia',
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            AppButton.text(
              text: 'Manage Partners',
              onPressed: () => context.push('/book-fairs/${fair.id}/partners'),
              size: AppButtonSize.small,
            ),
          ],
        ),
        AppSpacing.gapH4,
        Text(
          'Capital contributors & operational organizers',
          style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
        ),
        AppSpacing.gapH12,
        if (partners.isEmpty)
          AppCard(
            padding: AppSpacing.insetAll20,
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.group_off_outlined,
                    size: 32.0,
                    color: colors.textSecondary,
                  ),
                  AppSpacing.gapH8,
                  Text(
                    'No Partners Listed',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  AppSpacing.gapH4,
                  Text(
                    'Add stall organizers and investors to track equity and capital.',
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  AppSpacing.gapH12,
                  AppButton(
                    text: 'Add Partner',
                    onPressed: () =>
                        context.push('/book-fairs/${fair.id}/partners/create'),
                    size: AppButtonSize.small,
                  ),
                ],
              ),
            ),
          )
        else
          AppCard(
            padding: EdgeInsets.zero,
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: partners.length,
              separatorBuilder: (context, index) =>
                  Divider(color: colors.divider, height: 1.0),
              itemBuilder: (context, index) {
                final partner = partners[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: colors.primary,
                    child: Text(
                      partner.fullName.isNotEmpty
                          ? partner.fullName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: colors.isDark
                            ? AppColors.c03071E
                            : AppColors.cFFFFFF,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  title: Text(
                    partner.fullName,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    partner.role.displayName,
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  trailing: partner.profitSharingPercentage != null
                      ? AppBadge(
                          label: '${partner.profitSharingPercentage}% EQUITY',
                          variant: AppBadgeVariant.neutral,
                        )
                      : null,
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildManagementActions(
    BuildContext context,
    WidgetRef ref,
    BookFair fair,
  ) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fair Controls',
          style: textTheme.titleLarge?.copyWith(
            fontFamily: 'Georgia',
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        AppSpacing.gapH12,
        Row(
          children: [
            Expanded(
              child: AppButton.outlined(
                text: 'Edit Specifications',
                icon: Icons.edit_outlined,
                onPressed: () => context.push('/book-fairs/${fair.id}/edit'),
              ),
            ),
            AppSpacing.gapW12,
            Expanded(
              child: AppButton.outlined(
                text: fair.isArchived ? 'Restore Fair' : 'Archive Fair',
                icon: fair.isArchived
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
                onPressed: () async {
                  final repo = ref.read(bookFairRepositoryProvider);
                  await repo.toggleArchiveBookFair(fair.id);
                  if (context.mounted) {
                    AppSnackbar.show(
                      context,
                      message: fair.isArchived
                          ? 'Fair restored to active catalog.'
                          : 'Fair archived.',
                    );
                  }
                },
              ),
            ),
          ],
        ),
        AppSpacing.gapH12,
        AppButton.destructive(
          text: 'Delete Book Fair Permanently',
          icon: Icons.delete_outline_rounded,
          isFullWidth: true,
          onPressed: () => _confirmDeleteFair(context, ref, fair),
        ),
      ],
    );
  }

  Widget _buildFutureModulesSection(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    final modules = [
      ('Book Inventory', Icons.menu_book_outlined, 'Batch & condition catalog'),
      (
        'Purchase Orders',
        Icons.receipt_long_outlined,
        'Vendor stock acquisition',
      ),
      (
        'Sales Point-of-Sale',
        Icons.point_of_sale_outlined,
        'Daily cash & UPI register',
      ),
      (
        'Stall Expenses',
        Icons.money_off_csred_outlined,
        'Rent, decor & overheads',
      ),
      (
        'Settlements & Reports',
        Icons.pie_chart_outline_rounded,
        'Partner P&L distribution',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Planned Modules',
              style: textTheme.titleLarge?.copyWith(
                fontFamily: 'Georgia',
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const AppBadge(
              label: 'STAGE 03+',
              variant: AppBadgeVariant.neutral,
            ),
          ],
        ),
        AppSpacing.gapH4,
        Text(
          'Operational business workflows scheduled for subsequent releases',
          style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
        ),
        AppSpacing.gapH12,
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: modules.map((m) {
              return ListTile(
                leading: Icon(m.$2, color: colors.disabled, size: 22.0),
                title: Text(
                  m.$1,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  m.$3,
                  style: textTheme.bodySmall?.copyWith(color: colors.disabled),
                ),
                trailing: const AppBadge(
                  label: 'PLANNED',
                  variant: AppBadgeVariant.neutral,
                ),
                onTap: () {
                  AppSnackbar.show(
                    context,
                    message:
                        '${m.$1} will be introduced in the next development stage.',
                  );
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  void _confirmDeleteFair(BuildContext context, WidgetRef ref, BookFair fair) {
    AppDialog.show(
      context: context,
      title: 'Delete Book Fair?',
      message:
          'Are you sure you want to permanently delete "${fair.name}"? All associated partners and investment records will be permanently deleted. This cannot be undone.',
      icon: Icons.warning_amber_rounded,
      isDestructive: true,
      primaryActionText: 'Delete Permanently',
      onPrimaryAction: () async {
        Navigator.of(context).pop();
        final repo = ref.read(bookFairRepositoryProvider);
        await repo.deleteBookFair(fair.id);
        if (context.mounted) {
          AppSnackbar.show(
            context,
            message: 'Book fair removed from database.',
          );
          context.go('/book-fairs');
        }
      },
      secondaryActionText: 'Cancel',
      onSecondaryAction: () => Navigator.of(context).pop(),
    );
  }

  Widget _buildBadge(BookFairStatus status) {
    switch (status) {
      case BookFairStatus.active:
        return const AppBadge(
          label: 'ACTIVE',
          variant: AppBadgeVariant.success,
          icon: Icons.circle,
        );
      case BookFairStatus.upcoming:
        return const AppBadge(
          label: 'UPCOMING',
          variant: AppBadgeVariant.warning,
          icon: Icons.access_time_rounded,
        );
      case BookFairStatus.completed:
        return const AppBadge(
          label: 'COMPLETED',
          variant: AppBadgeVariant.neutral,
          icon: Icons.done_all_rounded,
        );
      case BookFairStatus.archived:
        return const AppBadge(
          label: 'ARCHIVED',
          variant: AppBadgeVariant.neutral,
          icon: Icons.archive_outlined,
        );
    }
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    this.isHighlighted = false,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    return AppCard(
      padding: AppSpacing.insetAll16,
      borderColor: isHighlighted ? colors.primary : colors.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: textTheme.labelSmall?.copyWith(
                    color: colors.textSecondary,
                    fontSize: 9.0,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                icon,
                size: 16.0,
                color: isHighlighted ? colors.primary : colors.textSecondary,
              ),
            ],
          ),
          AppSpacing.gapH8,
          Text(
            value,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          AppSpacing.gapH4,
          Text(
            subtitle,
            style: textTheme.bodySmall?.copyWith(
              color: colors.textSecondary,
              fontSize: 11.0,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
