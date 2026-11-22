import 'package:flutter/foundation.dart';

enum ActivityType { inventoryBatch, expense, partnerContribution, sale }

/// Domain entity representing a transaction or log entry in the fair activity feed.
@immutable
class ActivityItem {
  const ActivityItem({
    required this.id,
    required this.title,
    required this.timestamp,
    required this.amount,
    required this.subtitle,
    required this.type,
    this.isSample = true,
  });

  final String id;
  final String title;
  final String timestamp;
  final String amount;
  final String subtitle;
  final ActivityType type;
  final bool isSample;
}
