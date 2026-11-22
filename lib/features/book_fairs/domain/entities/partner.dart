import 'package:flutter/foundation.dart';

enum PartnerRole {
  owner,
  investor,
  partner;

  String get displayName {
    switch (this) {
      case PartnerRole.owner:
        return 'Owner / Organizer';
      case PartnerRole.investor:
        return 'Investor';
      case PartnerRole.partner:
        return 'Business Partner';
    }
  }

  static PartnerRole fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'owner':
        return PartnerRole.owner;
      case 'investor':
        return PartnerRole.investor;
      case 'partner':
      case 'business partner':
      default:
        return PartnerRole.partner;
    }
  }
}

/// Domain entity representing a business partner or investor in a specific book fair.
@immutable
class Partner {
  const Partner({
    required this.id,
    required this.fairId,
    required this.fullName,
    this.phoneNumber,
    this.email,
    required this.role,
    required this.joinedAt,
    this.profitSharingPercentage,
    this.notes = '',
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String fairId;
  final String fullName;
  final String? phoneNumber;
  final String? email;
  final PartnerRole role;
  final DateTime joinedAt;
  final double? profitSharingPercentage;
  final String notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Partner copyWith({
    String? id,
    String? fairId,
    String? fullName,
    String? phoneNumber,
    String? email,
    PartnerRole? role,
    DateTime? joinedAt,
    double? profitSharingPercentage,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Partner(
      id: id ?? this.id,
      fairId: fairId ?? this.fairId,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      profitSharingPercentage:
          profitSharingPercentage ?? this.profitSharingPercentage,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
