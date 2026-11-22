import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/localization/app_strings.dart';

/// Navigation shell wrapping top-level tab destinations with a persistent bottom navigation bar.
class MainShellScreen extends StatelessWidget {
  const MainShellScreen({super.key, required this.child});

  final Widget child;

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith(RoutePaths.bookFairs)) return 1;
    if (location.startsWith(RoutePaths.inventory)) return 2;
    if (location.startsWith(RoutePaths.more)) return 3;
    return 0; // Default to Dashboard
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.goNamed(RouteNames.dashboard);
        break;
      case 1:
        context.goNamed(RouteNames.bookFairs);
        break;
      case 2:
        context.goNamed(RouteNames.inventory);
        break;
      case 3:
        context.goNamed(RouteNames.more);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final selectedIndex = _calculateSelectedIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(top: BorderSide(color: colors.divider, width: 1.0)),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: colors.surface,
            indicatorColor: colors.primary,
            iconTheme: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return IconThemeData(
                  color: colors.isDark ? AppColors.c03071E : AppColors.cFFFFFF,
                  size: 22.0,
                );
              }
              return IconThemeData(color: colors.textSecondary, size: 22.0);
            }),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w700,
                  color: colors.primary,
                );
              }
              return TextStyle(
                fontSize: 12.0,
                fontWeight: FontWeight.w500,
                color: colors.textSecondary,
              );
            }),
          ),
          child: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: (idx) => _onItemTapped(idx, context),
            height: 64.0,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard_rounded),
                label: AppStrings.navDashboard,
              ),
              NavigationDestination(
                icon: Icon(Icons.storefront_outlined),
                selectedIcon: Icon(Icons.storefront_rounded),
                label: AppStrings.navBookFairs,
              ),
              NavigationDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2_rounded),
                label: AppStrings.navInventory,
              ),
              NavigationDestination(
                icon: Icon(Icons.more_horiz_outlined),
                selectedIcon: Icon(Icons.more_horiz_rounded),
                label: AppStrings.navMore,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
