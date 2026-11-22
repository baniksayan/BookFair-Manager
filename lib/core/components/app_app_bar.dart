import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../extensions/context_extensions.dart';

/// Editorial AppBar component adhering strictly to brand color tokens.
class AppAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AppAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions,
    this.bottom,
    this.centerTitle = false,
    this.showBottomDivider = true,
    this.backgroundColor,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool centerTitle;
  final bool showBottomDivider;
  final Color? backgroundColor;

  @override
  Size get preferredSize => Size.fromHeight(
    kToolbarHeight +
        (bottom?.preferredSize.height ?? 0.0) +
        (showBottomDivider ? 1.0 : 0.0),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final effectiveBg = backgroundColor ?? colors.surface;

    return Container(
      decoration: BoxDecoration(
        color: effectiveBg,
        border: showBottomDivider
            ? Border(bottom: BorderSide(color: colors.divider, width: 1.0))
            : null,
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: kToolbarHeight,
              child: NavigationToolbar(
                leading: leading ?? _buildDefaultLeading(context, colors),
                middle: _buildTitle(context, colors),
                trailing: actions != null
                    ? Row(mainAxisSize: MainAxisSize.min, children: actions!)
                    : null,
                centerMiddle: centerTitle,
                middleSpacing: AppSpacing.s16,
              ),
            ),
            ?bottom,
          ],
        ),
      ),
    );
  }

  Widget? _buildDefaultLeading(BuildContext context, AppColorScheme colors) {
    final router = GoRouter.maybeOf(context);
    final bool canPop = router != null
        ? router.canPop()
        : (ModalRoute.of(context)?.canPop ?? false);

    if (!canPop) return null;

    return IconButton(
      icon: Icon(
        Icons.arrow_back_ios_new_rounded,
        size: 18.0,
        color: colors.textPrimary,
      ),
      tooltip: 'Back',
      onPressed: () {
        final router = GoRouter.maybeOf(context);
        if (router != null) {
          if (router.canPop()) {
            router.pop();
          }
        } else if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      },
    );
  }

  Widget _buildTitle(BuildContext context, AppColorScheme colors) {
    if (subtitle == null) {
      return Text(
        title,
        style: context.textTheme.titleLarge?.copyWith(
          color: colors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        overflow: TextOverflow.ellipsis,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: centerTitle
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: context.textTheme.titleMedium?.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          subtitle!,
          style: context.textTheme.labelSmall?.copyWith(
            color: colors.textSecondary,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
