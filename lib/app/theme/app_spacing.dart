import 'package:flutter/material.dart';

/// Centralized layout spacing tokens.
abstract final class AppSpacing {
  static const double s0 = 0.0;
  static const double s2 = 2.0;
  static const double s4 = 4.0;
  static const double s6 = 6.0;
  static const double s8 = 8.0;
  static const double s10 = 10.0;
  static const double s12 = 12.0;
  static const double s14 = 14.0;
  static const double s16 = 16.0;
  static const double s20 = 20.0;
  static const double s24 = 24.0;
  static const double s28 = 28.0;
  static const double s32 = 32.0;
  static const double s40 = 40.0;
  static const double s48 = 48.0;
  static const double s80 = 80.0;

  // --- Convenience EdgeInsets ---
  static const EdgeInsets insetZero = EdgeInsets.zero;
  static const EdgeInsets insetAll4 = EdgeInsets.all(s4);
  static const EdgeInsets insetAll8 = EdgeInsets.all(s8);
  static const EdgeInsets insetAll10 = EdgeInsets.all(s10);
  static const EdgeInsets insetAll12 = EdgeInsets.all(s12);
  static const EdgeInsets insetAll16 = EdgeInsets.all(s16);
  static const EdgeInsets insetAll20 = EdgeInsets.all(s20);
  static const EdgeInsets insetAll24 = EdgeInsets.all(s24);
  static const EdgeInsets insetAll32 = EdgeInsets.all(s32);

  static const EdgeInsets insetH8 = EdgeInsets.symmetric(horizontal: s8);
  static const EdgeInsets insetH16 = EdgeInsets.symmetric(horizontal: s16);
  static const EdgeInsets insetH20 = EdgeInsets.symmetric(horizontal: s20);
  static const EdgeInsets insetH24 = EdgeInsets.symmetric(horizontal: s24);

  static const EdgeInsets insetV8 = EdgeInsets.symmetric(vertical: s8);
  static const EdgeInsets insetV12 = EdgeInsets.symmetric(vertical: s12);
  static const EdgeInsets insetV16 = EdgeInsets.symmetric(vertical: s16);
  static const EdgeInsets insetV20 = EdgeInsets.symmetric(vertical: s20);
  static const EdgeInsets insetV24 = EdgeInsets.symmetric(vertical: s24);

  // --- Convenience Gaps / Spacers ---
  static const SizedBox gapW2 = SizedBox(width: s2);
  static const SizedBox gapW4 = SizedBox(width: s4);
  static const SizedBox gapW6 = SizedBox(width: s6);
  static const SizedBox gapW8 = SizedBox(width: s8);
  static const SizedBox gapW12 = SizedBox(width: s12);
  static const SizedBox gapW16 = SizedBox(width: s16);
  static const SizedBox gapW20 = SizedBox(width: s20);
  static const SizedBox gapW24 = SizedBox(width: s24);
  static const SizedBox gapW32 = SizedBox(width: s32);

  static const SizedBox gapH2 = SizedBox(height: s2);
  static const SizedBox gapH4 = SizedBox(height: s4);
  static const SizedBox gapH6 = SizedBox(height: s6);
  static const SizedBox gapH8 = SizedBox(height: s8);
  static const SizedBox gapH10 = SizedBox(height: s10);
  static const SizedBox gapH12 = SizedBox(height: s12);
  static const SizedBox gapH14 = SizedBox(height: s14);
  static const SizedBox gapH16 = SizedBox(height: s16);
  static const SizedBox gapH20 = SizedBox(height: s20);
  static const SizedBox gapH24 = SizedBox(height: s24);
  static const SizedBox gapH28 = SizedBox(height: s28);
  static const SizedBox gapH32 = SizedBox(height: s32);
  static const SizedBox gapH40 = SizedBox(height: s40);
  static const SizedBox gapH48 = SizedBox(height: s48);
  static const SizedBox gapH80 = SizedBox(height: s80);
}
