import 'package:flutter/foundation.dart';

enum BookFairStatus {
  active,
  upcoming,
  completed,
  archived;

  String get displayName {
    switch (this) {
      case BookFairStatus.active:
        return 'Active';
      case BookFairStatus.upcoming:
        return 'Upcoming';
      case BookFairStatus.completed:
        return 'Completed';
      case BookFairStatus.archived:
        return 'Archived';
    }
  }

  static BookFairStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'active':
        return BookFairStatus.active;
      case 'upcoming':
        return BookFairStatus.upcoming;
      case 'completed':
        return BookFairStatus.completed;
      case 'archived':
        return BookFairStatus.archived;
      default:
        return BookFairStatus.upcoming;
    }
  }
}

/// Domain entity representing a distinct book stall fair exhibition.
@immutable
class BookFair {
  const BookFair({
    required this.id,
    required this.name,
    required this.location,
    this.city = '',
    this.state = '',
    required this.startDate,
    required this.endDate,
    this.setupDate,
    this.closingDate,
    required this.estimatedBudgetPaise,
    required this.initialInvestmentPaise,
    this.currency = 'INR',
    this.partnerCount = 1,
    this.partnershipType = 'Sole Proprietorship',
    this.initialPartnerSetup = '',
    this.description = '',
    this.operationalNotes = '',
    this.isDraft = false,
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Factory constructor for backward compatibility with existing Stage 01 callers
  factory BookFair.fromDouble({
    required String id,
    required String name,
    required String location,
    String city = '',
    String state = '',
    required DateTime startDate,
    required DateTime endDate,
    DateTime? setupDate,
    DateTime? closingDate,
    required double estimatedBudget,
    required double initialInvestment,
    String currency = 'INR',
    int partnerCount = 1,
    String partnershipType = 'Sole Proprietorship',
    String initialPartnerSetup = '',
    String description = '',
    String operationalNotes = '',
    bool isDraft = false,
    bool isArchived = false,
    required DateTime createdAt,
    DateTime? updatedAt,
  }) {
    return BookFair(
      id: id,
      name: name,
      location: location,
      city: city,
      state: state,
      startDate: startDate,
      endDate: endDate,
      setupDate: setupDate,
      closingDate: closingDate,
      estimatedBudgetPaise: (estimatedBudget * 100).round(),
      initialInvestmentPaise: (initialInvestment * 100).round(),
      currency: currency,
      partnerCount: partnerCount,
      partnershipType: partnershipType,
      initialPartnerSetup: initialPartnerSetup,
      description: description,
      operationalNotes: operationalNotes,
      isDraft: isDraft,
      isArchived: isArchived,
      createdAt: createdAt,
      updatedAt: updatedAt ?? createdAt,
    );
  }

  final String id;
  final String name;
  final String location;
  final String city;
  final String state;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime? setupDate;
  final DateTime? closingDate;

  /// Stored as exact integer paise (1 INR = 100 paise) to prevent float inaccuracies.
  final int estimatedBudgetPaise;
  final int initialInvestmentPaise;

  /// Convenience double getters in rupee units
  double get estimatedBudget => estimatedBudgetPaise / 100.0;
  double get initialInvestment => initialInvestmentPaise / 100.0;

  final String currency;
  final int partnerCount;
  final String partnershipType;
  final String initialPartnerSetup;
  final String description;
  final String operationalNotes;
  final bool isDraft;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Dynamically computes the active business status based on current date and archive state
  BookFairStatus get status {
    if (isArchived) return BookFairStatus.archived;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final fairStart = DateTime(startDate.year, startDate.month, startDate.day);
    final fairEnd = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
      23,
      59,
      59,
    );

    if (todayStart.isBefore(fairStart)) {
      return BookFairStatus.upcoming;
    } else if (todayStart.isAfter(fairEnd)) {
      return BookFairStatus.completed;
    } else {
      return BookFairStatus.active;
    }
  }

  /// Days remaining until the fair ends (if active or upcoming)
  int get daysRemaining {
    final now = DateTime.now();
    final fairEnd = DateTime(endDate.year, endDate.month, endDate.day);
    final diff = fairEnd
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    return diff < 0 ? 0 : diff;
  }

  BookFair copyWith({
    String? id,
    String? name,
    String? location,
    String? city,
    String? state,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? setupDate,
    DateTime? closingDate,
    int? estimatedBudgetPaise,
    int? initialInvestmentPaise,
    String? currency,
    int? partnerCount,
    String? partnershipType,
    String? initialPartnerSetup,
    String? description,
    String? operationalNotes,
    bool? isDraft,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BookFair(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      city: city ?? this.city,
      state: state ?? this.state,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      setupDate: setupDate ?? this.setupDate,
      closingDate: closingDate ?? this.closingDate,
      estimatedBudgetPaise: estimatedBudgetPaise ?? this.estimatedBudgetPaise,
      initialInvestmentPaise:
          initialInvestmentPaise ?? this.initialInvestmentPaise,
      currency: currency ?? this.currency,
      partnerCount: partnerCount ?? this.partnerCount,
      partnershipType: partnershipType ?? this.partnershipType,
      initialPartnerSetup: initialPartnerSetup ?? this.initialPartnerSetup,
      description: description ?? this.description,
      operationalNotes: operationalNotes ?? this.operationalNotes,
      isDraft: isDraft ?? this.isDraft,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
