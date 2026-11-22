import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'constants/app_constants.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

/// Root application widget initializing dynamic multi-color themes and GoRouter navigation.
class BookFairManagerApp extends ConsumerWidget {
  const BookFairManagerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeState = ref.watch(themeControllerProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.buildLightTheme(themeState.palette),
      darkTheme: AppTheme.buildDarkTheme(themeState.palette),
      themeMode: themeState.themeMode,
      routerConfig: router,
    );
  }
}
