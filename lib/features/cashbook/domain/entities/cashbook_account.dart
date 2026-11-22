import 'package:flutter/foundation.dart';

/// Supported types of business cashbook accounts.
enum AccountType {
  cash,
  upi,
  bank,
  other;

  String get displayName {
    switch (this) {
      case AccountType.cash:
        return 'Physical Cash';
      case AccountType.upi:
        return 'UPI / Online';
      case AccountType.bank:
        return 'Bank Account';
      case AccountType.other:
        return 'Other Payment Account';
    }
  }

  static AccountType fromString(String? val) {
    switch (val?.toLowerCase().trim()) {
      case 'cash':
      case 'physical_cash':
        return AccountType.cash;
      case 'upi':
      case 'upi_online':
      case 'online':
        return AccountType.upi;
      case 'bank':
      case 'bank_account':
        return AccountType.bank;
      default:
        return AccountType.other;
    }
  }
}

/// Domain entity representing a liquid business financial holding account.
@immutable
class CashbookAccount {
  const CashbookAccount({
    required this.id,
    required this.fairId,
    required this.accountName,
    required this.accountType,
    required this.openingBalancePaise,
    required this.currentBalancePaise,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String fairId;
  final String accountName;
  final String accountType;

  /// Stored as exact integer paise.
  final int openingBalancePaise;
  final int currentBalancePaise;

  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Convenience currency getters in INR units
  double get openingBalance => openingBalancePaise / 100.0;
  double get currentBalance => currentBalancePaise / 100.0;

  bool get isCash => accountType.toLowerCase().contains('cash');
  bool get isUpi => accountType.toLowerCase().contains('upi');
  bool get isBank => accountType.toLowerCase().contains('bank');

  CashbookAccount copyWith({
    String? id,
    String? fairId,
    String? accountName,
    String? accountType,
    int? openingBalancePaise,
    int? currentBalancePaise,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CashbookAccount(
      id: id ?? this.id,
      fairId: fairId ?? this.fairId,
      accountName: accountName ?? this.accountName,
      accountType: accountType ?? this.accountType,
      openingBalancePaise: openingBalancePaise ?? this.openingBalancePaise,
      currentBalancePaise: currentBalancePaise ?? this.currentBalancePaise,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CashbookAccount &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
