import 'package:flutter/foundation.dart';

/// Domain entity representing an expense categorization bucket.
@immutable
class ExpenseCategory {
  const ExpenseCategory({
    required this.id,
    required this.name,
    this.iconName,
    this.isCustom = false,
    this.isSystem = true,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String? iconName;
  final bool isCustom;
  final bool isSystem;
  final DateTime createdAt;

  ExpenseCategory copyWith({
    String? id,
    String? name,
    String? iconName,
    bool? isCustom,
    bool? isSystem,
    DateTime? createdAt,
  }) {
    return ExpenseCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      iconName: iconName ?? this.iconName,
      isCustom: isCustom ?? this.isCustom,
      isSystem: isSystem ?? this.isSystem,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// System default categories available globally across all Book Fairs.
  static List<ExpenseCategory> get defaultCategories {
    final now = DateTime(2026, 1, 1);
    const defaults = [
      ('cat_stall_rent', 'Stall Rent', 'storefront'),
      ('cat_stall_advance', 'Stall Advance', 'payments'),
      ('cat_transportation', 'Transportation', 'local_shipping'),
      ('cat_food_refreshments', 'Food & Refreshments', 'restaurant'),
      ('cat_banner_flex', 'Banner & Flex', 'aspect_ratio'),
      ('cat_printing', 'Printing', 'print'),
      ('cat_packaging', 'Packaging', 'inventory_2'),
      ('cat_table_rental', 'Table Rental', 'table_restaurant'),
      ('cat_chair_rental', 'Chair Rental', 'chair'),
      ('cat_lighting', 'Lighting', 'lightbulb'),
      ('cat_electricity', 'Electricity', 'bolt'),
      ('cat_decoration', 'Decoration', 'celebration'),
      ('cat_loading_unloading', 'Loading & Unloading', 'forklift'),
      ('cat_labour', 'Labour', 'groups'),
      ('cat_equipment', 'Equipment', 'build'),
      ('cat_stationery', 'Stationery', 'draw'),
      ('cat_communication', 'Communication', 'phone'),
      ('cat_maintenance', 'Maintenance', 'handyman'),
      ('cat_other', 'Other', 'category'),
    ];

    return defaults
        .map(
          (d) => ExpenseCategory(
            id: d.$1,
            name: d.$2,
            iconName: d.$3,
            isCustom: false,
            isSystem: true,
            createdAt: now,
          ),
        )
        .toList();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpenseCategory &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
