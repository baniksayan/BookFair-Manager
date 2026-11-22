import 'package:flutter/foundation.dart';

/// Status of payment for a recorded fair expense.
enum ExpensePaymentStatus {
  unpaid,
  partiallyPaid,
  paid,
  cancelled;

  String get displayName {
    switch (this) {
      case ExpensePaymentStatus.unpaid:
        return 'Unpaid';
      case ExpensePaymentStatus.partiallyPaid:
        return 'Partially Paid';
      case ExpensePaymentStatus.paid:
        return 'Paid';
      case ExpensePaymentStatus.cancelled:
        return 'Cancelled';
    }
  }

  static ExpensePaymentStatus fromString(String? val) {
    switch (val?.toLowerCase().replaceAll(' ', '_')) {
      case 'unpaid':
        return ExpensePaymentStatus.unpaid;
      case 'partially_paid':
      case 'partiallypaid':
      case 'partial':
        return ExpensePaymentStatus.partiallyPaid;
      case 'paid':
        return ExpensePaymentStatus.paid;
      case 'cancelled':
      case 'canceled':
        return ExpensePaymentStatus.cancelled;
      default:
        return ExpensePaymentStatus.unpaid;
    }
  }
}

/// Domain entity representing a business operational expense incurred for a Book Fair stall.
@immutable
class Expense {
  const Expense({
    required this.id,
    required this.fairId,
    required this.title,
    this.description = '',
    required this.categoryId,
    required this.amountPaise,
    required this.expenseDate,
    this.paymentStatus = 'Unpaid',
    this.paidAmountPaise = 0,
    required this.outstandingAmountPaise,
    this.paymentMethod = 'Cash',
    this.paidByPartnerId,
    this.paidFromAccountId,
    this.supplierId,
    this.receiptImagePath,
    this.referenceNumber,
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String fairId;
  final String title;
  final String description;
  final String categoryId;

  /// Overall total obligation amount in integer paise.
  final int amountPaise;
  final DateTime expenseDate;

  /// Status: 'Paid', 'Partially Paid', 'Unpaid', 'Cancelled'
  final String paymentStatus;

  /// Cumulative amount paid in integer paise.
  final int paidAmountPaise;

  /// Remaining outstanding balance in integer paise (amountPaise - paidAmountPaise).
  final int outstandingAmountPaise;

  final String paymentMethod;
  final String? paidByPartnerId;
  final String? paidFromAccountId;
  final String? supplierId;
  final String? receiptImagePath;
  final String? referenceNumber;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Convenience currency getters in INR units
  double get amount => amountPaise / 100.0;
  double get paidAmount => paidAmountPaise / 100.0;
  double get outstandingAmount => outstandingAmountPaise / 100.0;

  bool get isPaid =>
      (paidAmountPaise >= amountPaise && amountPaise > 0) ||
      paymentStatus.toLowerCase() == 'paid';
  bool get isUnpaid =>
      paidAmountPaise == 0 || paymentStatus.toLowerCase() == 'unpaid';
  bool get isPartiallyPaid =>
      paymentStatus.toLowerCase() == 'partially paid' ||
      paymentStatus.toLowerCase() == 'partially refunded' ||
      paymentStatus.toLowerCase() == 'partially paid (written off)' ||
      (paidAmountPaise > 0 && paidAmountPaise < amountPaise && !isCancelled);
  bool get isCancelled =>
      paymentStatus.toLowerCase().startsWith('cancelled') ||
      paymentStatus.toLowerCase() == 'written off';

  Expense copyWith({
    String? id,
    String? fairId,
    String? title,
    String? description,
    String? categoryId,
    int? amountPaise,
    DateTime? expenseDate,
    String? paymentStatus,
    int? paidAmountPaise,
    int? outstandingAmountPaise,
    String? paymentMethod,
    String? paidByPartnerId,
    String? paidFromAccountId,
    String? supplierId,
    String? receiptImagePath,
    String? referenceNumber,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Expense(
      id: id ?? this.id,
      fairId: fairId ?? this.fairId,
      title: title ?? this.title,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      amountPaise: amountPaise ?? this.amountPaise,
      expenseDate: expenseDate ?? this.expenseDate,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paidAmountPaise: paidAmountPaise ?? this.paidAmountPaise,
      outstandingAmountPaise:
          outstandingAmountPaise ?? this.outstandingAmountPaise,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paidByPartnerId: paidByPartnerId ?? this.paidByPartnerId,
      paidFromAccountId: paidFromAccountId ?? this.paidFromAccountId,
      supplierId: supplierId ?? this.supplierId,
      receiptImagePath: receiptImagePath ?? this.receiptImagePath,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Expense && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
