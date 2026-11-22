import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/components/app_error_state.dart';
import '../../../../core/components/app_loading.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../view_models/dashboard_view_model.dart';
import '../widgets/business_overview_card.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/dashboard_hero_card.dart';
import '../widgets/financial_accounting_section.dart';
import '../widgets/quick_actions_section.dart';
import '../widgets/recent_activity_section.dart';

/// Primary Dashboard screen for BookFair Manager.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardViewModelProvider);

    return Scaffold(
      body: SafeArea(
        child: ResponsiveContentContainer(
          child: _buildBody(context, ref, state),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, DashboardState state) {
    if (state.isLoading) {
      return const Center(
        child: AppLoadingIndicator.large(message: 'Loading stall ledger...'),
      );
    }

    if (state.errorMessage != null) {
      return AppErrorState(
        title: 'Unable to Load Dashboard',
        description: state.errorMessage!,
        onRetry: () =>
            ref.read(dashboardViewModelProvider.notifier).loadDashboardData(),
      );
    }

    final summary = state.summary;
    if (summary == null) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DashboardHeader(),
          AppSpacing.gapH8,
          DashboardHeroCard(
            onStartNewBookFair: () =>
                context.pushNamed(RouteNames.createBookFair),
          ),
          AppSpacing.gapH24,
          BusinessOverviewSection(summary: summary),
          AppSpacing.gapH24,
          const FinancialAccountingSection(),
          AppSpacing.gapH24,
          QuickActionsSection(
            onNavigateToCreateFair: () =>
                context.pushNamed(RouteNames.createBookFair),
          ),
          AppSpacing.gapH24,
          RecentActivitySection(activities: state.activities),
          AppSpacing.gapH32,
        ],
      ),
    );
  }
}
