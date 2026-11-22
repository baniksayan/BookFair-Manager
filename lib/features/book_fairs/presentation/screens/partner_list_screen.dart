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
import '../../../../core/utils/financial_calculator.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../domain/entities/partner.dart';
import '../view_models/book_fair_providers.dart';
import '../view_models/partner_management_view_model.dart';
import '../widgets/record_investment_sheet.dart';

/// Screen 04: Partner & Investor Management for a specific Book Fair.
class PartnerListScreen extends ConsumerWidget {
  const PartnerListScreen({super.key, required this.fairId});

  final String fairId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    final fairAsync = ref.watch(bookFairDetailsStreamProvider(fairId));
    final partnersAsync = ref.watch(partnersForFairStreamProvider(fairId));
    final investmentsAsync = ref.watch(
      investmentsForFairStreamProvider(fairId),
    );

    return Scaffold(
      appBar: AppAppBar(
        title: 'Partner Directory',
        subtitle: fairAsync.value?.name ?? 'Fair Exhibition',
        actions: [
          IconButton(
            tooltip: 'Add Partner',
            icon: Icon(
              Icons.person_add_alt_1_rounded,
              color: colors.textPrimary,
            ),
            onPressed: () =>
                context.push('/book-fairs/$fairId/partners/create'),
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveContentContainer(
          child: partnersAsync.when(
            loading: () => const Center(
              child: AppLoadingIndicator.large(
                message: 'Loading partner roster...',
              ),
            ),
            error: (err, _) => Center(
              child: Text('Error: $err', style: TextStyle(color: colors.error)),
            ),
            data: (partners) {
              final investments = investmentsAsync.value ?? [];
              final totalContributions =
                  FinancialCalculator.calculateTotalInvestment(investments);

              return Column(
                children: [
                  // --- Header Summary Bar ---
                  Padding(
                    padding: AppSpacing.insetAll16,
                    child: Row(
                      children: [
                        Expanded(
                          child: AppCard(
                            padding: AppSpacing.insetAll12,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'REGISTERED PARTNERS',
                                  style: textTheme.labelSmall?.copyWith(
                                    color: colors.textSecondary,
                                    fontSize: 9.0,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                AppSpacing.gapH4,
                                Text(
                                  '${partners.length}',
                                  style: textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        AppSpacing.gapW12,
                        Expanded(
                          child: AppCard(
                            padding: AppSpacing.insetAll12,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TOTAL MOBILIZED',
                                  style: textTheme.labelSmall?.copyWith(
                                    color: colors.textSecondary,
                                    fontSize: 9.0,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                AppSpacing.gapH4,
                                Text(
                                  CurrencyFormatter.format(totalContributions),
                                  style: textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: colors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // --- Partner Cards List / Empty State ---
                  Expanded(
                    child: partners.isEmpty
                        ? AppEmptyState(
                            icon: Icons.groups_outlined,
                            title: 'No Partners Registered',
                            description: 'Add investors and partners to track individual financial contributions and equity allocations.',
                            actionLabel: 'Add First Partner',
                            onAction: () => context.push(
                              '/book-fairs/$fairId/partners/create',
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.s16,
                              AppSpacing.s4,
                              AppSpacing.s16,
                              AppSpacing.s32,
                            ),
                            itemCount: partners.length,
                            separatorBuilder: (context, index) =>
                                AppSpacing.gapH12,
                            itemBuilder: (context, index) {
                              final partner = partners[index];
                              final partnerContribution =
                                  FinancialCalculator.calculatePartnerContribution(
                                    investments: investments,
                                    partnerId: partner.id,
                                  );

                              return _PartnerCard(
                                partner: partner,
                                totalContribution: partnerContribution,
                                onRecordContribution: () {
                                  RecordInvestmentSheet.show(
                                    context: context,
                                    fairId: fairId,
                                    preselectedPartnerId: partner.id,
                                  );
                                },
                                onEdit: () {
                                  context.push(
                                    '/book-fairs/$fairId/partners/create?partnerId=${partner.id}',
                                  );
                                },
                                onDelete: () => _confirmDeletePartner(
                                  context,
                                  ref,
                                  partner,
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: colors.primary,
        foregroundColor: colors.isDark ? AppColors.c03071E : AppColors.cFFFFFF,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Partner'),
        onPressed: () => context.push('/book-fairs/$fairId/partners/create'),
      ),
    );
  }

  void _confirmDeletePartner(
    BuildContext context,
    WidgetRef ref,
    Partner partner,
  ) {
    AppDialog.show(
      context: context,
      title: 'Remove Partner?',
      message:
          'Are you sure you want to remove "${partner.fullName}" from this book fair? If this partner has recorded investment contributions, they will also be permanently deleted.',
      icon: Icons.person_remove_rounded,
      isDestructive: true,
      primaryActionText: 'Remove Partner',
      onPrimaryAction: () async {
        Navigator.of(context).pop();
        final vm = ref.read(partnerFormViewModelProvider(fairId).notifier);
        final success = await vm.deletePartner(partner.id, force: true);
        if (context.mounted) {
          if (success) {
            AppSnackbar.show(
              context,
              message: 'Partner "${partner.fullName}" has been removed.',
            );
          } else {
            AppSnackbar.show(
              context,
              message: 'Could not remove partner.',
              variant: AppSnackbarVariant.error,
            );
          }
        }
      },
      secondaryActionText: 'Cancel',
      onSecondaryAction: () => Navigator.of(context).pop(),
    );
  }
}

class _PartnerCard extends StatelessWidget {
  const _PartnerCard({
    required this.partner,
    required this.totalContribution,
    required this.onRecordContribution,
    required this.onEdit,
    required this.onDelete,
  });

  final Partner partner;
  final double totalContribution;
  final VoidCallback onRecordContribution;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    return AppCard(
      padding: AppSpacing.insetAll16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22.0,
                backgroundColor: colors.primary,
                child: Text(
                  partner.fullName.isNotEmpty
                      ? partner.fullName[0].toUpperCase()
                      : 'P',
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.w700,
                    color: colors.isDark
                        ? AppColors.c03071E
                        : AppColors.cFFFFFF,
                  ),
                ),
              ),
              AppSpacing.gapW12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            partner.fullName,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: Icon(
                            Icons.more_vert_rounded,
                            size: 18.0,
                            color: colors.textSecondary,
                          ),
                          color: colors.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.brMedium,
                            side: BorderSide(color: colors.border, width: 1.0),
                          ),
                          onSelected: (val) {
                            if (val == 'edit') onEdit();
                            if (val == 'delete') onDelete();
                          },
                          itemBuilder: (ctx) => [
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.edit_outlined,
                                    size: 16.0,
                                    color: colors.textPrimary,
                                  ),
                                  AppSpacing.gapW8,
                                  Text(
                                    'Edit Partner',
                                    style: TextStyle(color: colors.textPrimary),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete_outline_rounded,
                                    size: 16.0,
                                    color: colors.error,
                                  ),
                                  AppSpacing.gapW8,
                                  Text(
                                    'Remove Partner',
                                    style: TextStyle(color: colors.error),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        AppBadge(
                          label: partner.role.displayName.toUpperCase(),
                          variant: partner.role == PartnerRole.owner
                              ? AppBadgeVariant.primary
                              : AppBadgeVariant.neutral,
                        ),
                        if (partner.profitSharingPercentage != null) ...[
                          AppSpacing.gapW8,
                          AppBadge(
                            label: '${partner.profitSharingPercentage}% EQUITY',
                            variant: AppBadgeVariant.success,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (partner.phoneNumber != null || partner.email != null) ...[
            AppSpacing.gapH12,
            Row(
              children: [
                if (partner.phoneNumber != null) ...[
                  Icon(
                    Icons.phone_outlined,
                    size: 14.0,
                    color: colors.textSecondary,
                  ),
                  AppSpacing.gapW4,
                  Text(
                    partner.phoneNumber!,
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  AppSpacing.gapW16,
                ],
                if (partner.email != null) ...[
                  Icon(
                    Icons.email_outlined,
                    size: 14.0,
                    color: colors.textSecondary,
                  ),
                  AppSpacing.gapW4,
                  Expanded(
                    child: Text(
                      partner.email!,
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ],
          AppSpacing.gapH12,
          Divider(color: colors.divider, height: 1.0),
          AppSpacing.gapH12,

          // Total Contribution & Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOTAL CAPITAL RECORDED',
                    style: textTheme.labelSmall?.copyWith(
                      color: colors.textSecondary,
                      fontSize: 9.0,
                      letterSpacing: 0.5,
                    ),
                  ),
                  AppSpacing.gapH4,
                  Text(
                    CurrencyFormatter.format(totalContribution),
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: totalContribution > 0
                          ? colors.primary
                          : colors.textSecondary,
                    ),
                  ),
                ],
              ),
              AppButton(
                text: '+ Add Capital',
                size: AppButtonSize.small,
                onPressed: onRecordContribution,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
