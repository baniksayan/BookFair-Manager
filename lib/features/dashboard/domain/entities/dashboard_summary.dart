import 'package:flutter/foundation.dart';

import '../../../book_fairs/domain/entities/book_fair.dart';

/// Domain entity representing high-level executive metrics for book fair operations.
@immutable
class DashboardSummary {
  const DashboardSummary({
    required this.totalFairs,
    required this.activeFairs,
    required this.upcomingFairs,
    required this.totalRecordedInvestment,
    this.activeFair,
    this.partnerCount = 0,
    this.isSampleData = false,
  });

  final int totalFairs;
  final int activeFairs;
  final int upcomingFairs;
  final double totalRecordedInvestment;
  final BookFair? activeFair;
  final int partnerCount;
  final bool isSampleData;

  bool get hasFairs => totalFairs > 0;
}
