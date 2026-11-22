import 'package:flutter/foundation.dart';

/// Domain entity representing a book vendor, distributor, or publisher supplier.
@immutable
class Supplier {
  const Supplier({
    required this.id,
    required this.name,
    this.contactNumber,
    this.email,
    this.address,
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String? contactNumber;
  final String? email;
  final String? address;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Supplier copyWith({
    String? id,
    String? name,
    String? contactNumber,
    String? email,
    String? address,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Supplier(
      id: id ?? this.id,
      name: name ?? this.name,
      contactNumber: contactNumber ?? this.contactNumber,
      email: email ?? this.email,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Supplier && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
