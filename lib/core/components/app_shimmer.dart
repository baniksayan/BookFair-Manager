import 'package:flutter/material.dart';

import '../../app/theme/app_radius.dart';
import '../extensions/context_extensions.dart';

/// Lightweight skeleton shimmer loader adhering strictly to approved palette colors.
class AppShimmer extends StatefulWidget {
  const AppShimmer({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  const AppShimmer.card({
    super.key,
    this.width = double.infinity,
    this.height = 120.0,
    this.borderRadius = AppRadius.brLarge,
  });

  const AppShimmer.textLine({
    super.key,
    this.width = 160.0,
    this.height = 14.0,
    this.borderRadius = AppRadius.brSmall,
  });

  final double width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final baseColor = colors.surface;
    final highlightColor = colors.isDark
        ? colors.surfaceSecondary
        : colors.border;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? AppRadius.brMedium,
            gradient: LinearGradient(
              begin: Alignment(-1.5 + (_controller.value * 3), 0.0),
              end: Alignment(-0.5 + (_controller.value * 3), 0.0),
              colors: [baseColor, highlightColor, baseColor],
            ),
            border: Border.all(color: colors.border, width: 0.5),
          ),
        );
      },
    );
  }
}
