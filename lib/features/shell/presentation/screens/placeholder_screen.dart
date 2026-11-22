import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/components/app_app_bar.dart';
import '../../../../core/components/app_empty_state.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/utils/responsive_layout.dart';

/// Reusable coming-soon placeholder screen for destinations slated for later stages.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.description,
    this.icon = Icons.construction_rounded,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppAppBar(title: title, showBottomDivider: true),
      body: SafeArea(
        child: ResponsiveContentContainer(
          child: AppEmptyState(
            icon: icon,
            title: title,
            description: description,
            actionLabel: 'Return to ${AppStrings.navDashboard}',
            onAction: () => context.goNamed(RouteNames.dashboard),
          ),
        ),
      ),
    );
  }
}
