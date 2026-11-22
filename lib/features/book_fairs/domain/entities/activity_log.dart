import 'package:flutter/foundation.dart';

enum ActivityLogType {
  fairCreated,
  fairUpdated,
  fairArchived,
  partnerAdded,
  investmentRecorded,
  bookAdded,
  bookUpdated,
  purchaseBatchCreated,
  stockAdded,
  stockAdjusted,
  previousStockRegistered,
  supplierAdded,
  themeChanged,
  expenseRecorded,
  paymentRecorded,
  fundsTransferred,
  reimbursementSettled;

  String get displayName {
    switch (this) {
      case ActivityLogType.fairCreated:
        return 'Fair Created';
      case ActivityLogType.fairUpdated:
        return 'Fair Updated';
      case ActivityLogType.fairArchived:
        return 'Fair Archived';
      case ActivityLogType.partnerAdded:
        return 'Partner Added';
      case ActivityLogType.investmentRecorded:
        return 'Investment Recorded';
      case ActivityLogType.bookAdded:
        return 'Book Added';
      case ActivityLogType.bookUpdated:
        return 'Book Updated';
      case ActivityLogType.purchaseBatchCreated:
        return 'Purchase Batch Created';
      case ActivityLogType.stockAdded:
        return 'Stock Added';
      case ActivityLogType.stockAdjusted:
        return 'Stock Adjusted';
      case ActivityLogType.previousStockRegistered:
        return 'Previous Stock Registered';
      case ActivityLogType.supplierAdded:
        return 'Supplier Added';
      case ActivityLogType.themeChanged:
        return 'Theme Changed';
      case ActivityLogType.expenseRecorded:
        return 'Expense Recorded';
      case ActivityLogType.paymentRecorded:
        return 'Payment Recorded';
      case ActivityLogType.fundsTransferred:
        return 'Funds Transferred';
      case ActivityLogType.reimbursementSettled:
        return 'Reimbursement Settled';
    }
  }

  static ActivityLogType fromString(String? val) {
    switch (val?.toLowerCase().trim()) {
      case 'faircreated':
      case 'fair created':
        return ActivityLogType.fairCreated;
      case 'fairupdated':
      case 'fair updated':
        return ActivityLogType.fairUpdated;
      case 'fairarchived':
      case 'fair archived':
        return ActivityLogType.fairArchived;
      case 'partneradded':
      case 'partner added':
        return ActivityLogType.partnerAdded;
      case 'investmentrecorded':
      case 'investment recorded':
        return ActivityLogType.investmentRecorded;
      case 'bookadded':
      case 'book added':
        return ActivityLogType.bookAdded;
      case 'bookupdated':
      case 'book updated':
        return ActivityLogType.bookUpdated;
      case 'purchasebatchcreated':
      case 'purchase batch created':
        return ActivityLogType.purchaseBatchCreated;
      case 'stockadded':
      case 'stock added':
        return ActivityLogType.stockAdded;
      case 'stockadjusted':
      case 'stock adjusted':
        return ActivityLogType.stockAdjusted;
      case 'previousstockregistered':
      case 'previous stock registered':
        return ActivityLogType.previousStockRegistered;
      case 'supplieradded':
      case 'supplier added':
        return ActivityLogType.supplierAdded;
      case 'themechanged':
      case 'theme changed':
        return ActivityLogType.themeChanged;
      case 'expenserecorded':
      case 'expense recorded':
        return ActivityLogType.expenseRecorded;
      case 'paymentrecorded':
      case 'payment recorded':
        return ActivityLogType.paymentRecorded;
      case 'fundstransferred':
      case 'funds transferred':
        return ActivityLogType.fundsTransferred;
      case 'reimbursementsettled':
      case 'reimbursement settled':
        return ActivityLogType.reimbursementSettled;
      default:
        return ActivityLogType.investmentRecorded;
    }
  }
}

/// Domain entity representing a persistent audit trail / activity log entry.
@immutable
class ActivityLog {
  const ActivityLog({
    required this.id,
    this.fairId,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.type,
    required this.timestamp,
  });

  final String id;
  final String? fairId;
  final String title;
  final String subtitle;
  final String amount;
  final ActivityLogType type;
  final DateTime timestamp;
}
