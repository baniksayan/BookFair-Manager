import 'package:flutter/foundation.dart';

/// Direction of funds relative to a business financial holding account.
enum TransactionDirection {
  inflow,
  outflow;

  bool get isInflow => this == TransactionDirection.inflow;
  bool get isOutflow => this == TransactionDirection.outflow;

  String get displayName =>
      this == TransactionDirection.inflow ? 'Credit (+)' : 'Debit (-)';

  static TransactionDirection fromString(String? val) {
    switch (val?.toLowerCase().trim()) {
      case 'inflow':
      case 'credit':
      case 'in':
        return TransactionDirection.inflow;
      default:
        return TransactionDirection.outflow;
    }
  }
}

/// Immutable ledger entry representing an exact financial movement within an account.
@immutable
class AccountTransaction {
  const AccountTransaction({
    required this.id,
    required this.fairId,
    required this.accountId,
    required this.transactionType,
    required this.direction,
    required this.amountPaise,
    required this.transactionDate,
    required this.referenceType,
    this.referenceId,
    required this.description,
    required this.createdAt,
  });

  final String id;
  final String fairId;
  final String accountId;

  /// Transaction type: 'opening_balance', 'investment_received', 'expense_payment',
  /// 'purchase_payment', 'supplier_payment', 'partner_withdrawal', 'partner_reimbursement',
  /// 'transfer_in', 'transfer_out', 'refund_received', 'manual_adjustment'
  final String transactionType;

  /// Direction: 'inflow' or 'outflow'
  final String direction;

  /// Exact monetary value in integer paise.
  final int amountPaise;
  final DateTime transactionDate;

  /// Reference category: 'expense', 'purchase_batch', 'investment', 'partner_reimbursement', 'transfer', 'manual'
  final String referenceType;

  /// Foreign identifier of the referenced business obligation/event.
  final String? referenceId;

  final String description;
  final DateTime createdAt;

  // Convenience currency getters in INR units
  double get amount => amountPaise / 100.0;

  bool get isInflow =>
      direction.toLowerCase() == 'inflow' ||
      direction.toLowerCase() == 'credit';
  bool get isOutflow => !isInflow;

  AccountTransaction copyWith({
    String? id,
    String? fairId,
    String? accountId,
    String? transactionType,
    String? direction,
    int? amountPaise,
    DateTime? transactionDate,
    String? referenceType,
    String? referenceId,
    String? description,
    DateTime? createdAt,
  }) {
    return AccountTransaction(
      id: id ?? this.id,
      fairId: fairId ?? this.fairId,
      accountId: accountId ?? this.accountId,
      transactionType: transactionType ?? this.transactionType,
      direction: direction ?? this.direction,
      amountPaise: amountPaise ?? this.amountPaise,
      transactionDate: transactionDate ?? this.transactionDate,
      referenceType: referenceType ?? this.referenceType,
      referenceId: referenceId ?? this.referenceId,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccountTransaction &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
