import 'package:hive/hive.dart';

import '../../../../core/database/database_constants.dart';
import '../../domain/entities/supplier.dart';

/// Hive database storage model for [Supplier].
class SupplierModel extends HiveObject {
  SupplierModel({
    required this.id,
    required this.name,
    this.contactNumber,
    this.email,
    this.address,
    required this.notes,
    required this.createdAtEpoch,
    required this.updatedAtEpoch,
  });

  factory SupplierModel.fromEntity(Supplier entity) {
    return SupplierModel(
      id: entity.id,
      name: entity.name,
      contactNumber: entity.contactNumber,
      email: entity.email,
      address: entity.address,
      notes: entity.notes,
      createdAtEpoch: entity.createdAt.millisecondsSinceEpoch,
      updatedAtEpoch: entity.updatedAt.millisecondsSinceEpoch,
    );
  }

  final String id;
  final String name;
  final String? contactNumber;
  final String? email;
  final String? address;
  final String notes;
  final int createdAtEpoch;
  final int updatedAtEpoch;

  Supplier toEntity() {
    return Supplier(
      id: id,
      name: name,
      contactNumber: contactNumber,
      email: email,
      address: address,
      notes: notes,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtEpoch),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAtEpoch),
    );
  }
}

/// Binary serializer and deserializer for [SupplierModel].
class SupplierAdapter extends TypeAdapter<SupplierModel> {
  @override
  final int typeId = DatabaseConstants.supplierTypeId;

  @override
  SupplierModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SupplierModel(
      id: fields[0] as String,
      name: fields[1] as String,
      contactNumber: fields[2] as String?,
      email: fields[3] as String?,
      address: fields[4] as String?,
      notes: fields[5] as String? ?? '',
      createdAtEpoch: fields[6] as int,
      updatedAtEpoch: fields[7] as int? ?? fields[6] as int,
    );
  }

  @override
  void write(BinaryWriter writer, SupplierModel obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.contactNumber)
      ..writeByte(3)
      ..write(obj.email)
      ..writeByte(4)
      ..write(obj.address)
      ..writeByte(5)
      ..write(obj.notes)
      ..writeByte(6)
      ..write(obj.createdAtEpoch)
      ..writeByte(7)
      ..write(obj.updatedAtEpoch);
  }
}
