import 'package:flutter/material.dart';

/// Centralized border radius tokens.
abstract final class AppRadius {
  static const double small = 6.0;
  static const double medium = 10.0;
  static const double large = 16.0;
  static const double extraLarge = 24.0;
  static const double full = 999.0;

  // --- Radius instances ---
  static const Radius rSmall = Radius.circular(small);
  static const Radius rMedium = Radius.circular(medium);
  static const Radius rLarge = Radius.circular(large);
  static const Radius rExtraLarge = Radius.circular(extraLarge);
  static const Radius rFull = Radius.circular(full);

  // --- BorderRadius instances ---
  static const BorderRadius brSmall = BorderRadius.all(rSmall);
  static const BorderRadius brMedium = BorderRadius.all(rMedium);
  static const BorderRadius brLarge = BorderRadius.all(rLarge);
  static const BorderRadius brExtraLarge = BorderRadius.all(rExtraLarge);
  static const BorderRadius brFull = BorderRadius.all(rFull);

  // Convenience aliases
  static const BorderRadius allSmall = brSmall;
  static const BorderRadius allMedium = brMedium;
  static const BorderRadius allLarge = brLarge;
  static const BorderRadius allExtraLarge = brExtraLarge;
  static const BorderRadius allFull = brFull;

  // --- Top only / Bottom only for Bottom Sheets & Dialogs ---
  static const BorderRadius brTopLarge = BorderRadius.vertical(top: rLarge);
  static const BorderRadius brTopExtraLarge = BorderRadius.vertical(
    top: rExtraLarge,
  );
}
