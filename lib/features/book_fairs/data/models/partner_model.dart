import 'package:hive/hive.dart';

import '../../../../core/database/database_constants.dart';
import '../../domain/entities/partner.dart';

/// Hive database storage model for [Partner].
class PartnerModel extends HiveObject {
  PartnerModel({
    required this.id,
    required this.fairId,
    required this.fullName,
    this.phoneNumber,
    this.email,
    required this.role,
    required this.joinedAtEpoch,
    this.profitSharingPercentage,
    required this.notes,
    required this.isActive,
    required this.createdAtEpoch,
    required this.updatedAtEpoch,
  });

  factory PartnerModel.fromEntity(Partner entity) {
    return PartnerModel(
      id: entity.id,
      fairId: entity.fairId,
      fullName: entity.fullName,
      phoneNumber: entity.phoneNumber,
      email: entity.email,
      role: entity.role.name,
      joinedAtEpoch: entity.joinedAt.millisecondsSinceEpoch,
      profitSharingPercentage: entity.profitSharingPercentage,
      notes: entity.notes,
      isActive: entity.isActive,
      createdAtEpoch: entity.createdAt.millisecondsSinceEpoch,
      updatedAtEpoch: entity.updatedAt.millisecondsSinceEpoch,
    );
  }

  final String id;
  final String fairId;
  final String fullName;
  final String? phoneNumber;
  final String? email;
  final String role;
  final int joinedAtEpoch;
  final double? profitSharingPercentage;
  final String notes;
  final bool isActive;
  final int createdAtEpoch;
  final int updatedAtEpoch;

  Partner toEntity() {
    return Partner(
      id: id,
      fairId: fairId,
      fullName: fullName,
      phoneNumber: phoneNumber,
      email: email,
      role: PartnerRole.fromString(role),
      joinedAt: DateTime.fromMillisecondsSinceEpoch(joinedAtEpoch),
      profitSharingPercentage: profitSharingPercentage,
      notes: notes,
      isActive: isActive,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtEpoch),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAtEpoch),
    );
  }
}

/// Binary serializer and deserializer for [PartnerModel].
class PartnerAdapter extends TypeAdapter<PartnerModel> {
  @override
  final int typeId = DatabaseConstants.partnerTypeId;

  @override
  PartnerModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PartnerModel(
      id: fields[0] as String,
      fairId: fields[1] as String,
      fullName: fields[2] as String,
      phoneNumber: fields[3] as String?,
      email: fields[4] as String?,
      role: fields[5] as String? ?? 'partner',
      joinedAtEpoch: fields[6] as int,
      profitSharingPercentage: fields[7] as double?,
      notes: fields[8] as String? ?? '',
      isActive: fields[9] as bool? ?? true,
      createdAtEpoch: fields[10] as int,
      updatedAtEpoch: fields[11] as int? ?? fields[10] as int,
    );
  }

  @override
  void write(BinaryWriter writer, PartnerModel obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.fairId)
      ..writeByte(2)
      ..write(obj.fullName)
      ..writeByte(3)
      ..write(obj.phoneNumber)
      ..writeByte(4)
      ..write(obj.email)
      ..writeByte(5)
      ..write(obj.role)
      ..writeByte(6)
      ..write(obj.joinedAtEpoch)
      ..writeByte(7)
      ..write(obj.profitSharingPercentage)
      ..writeByte(8)
      ..write(obj.notes)
      ..writeByte(9)
      ..write(obj.isActive)
      ..writeByte(10)
      ..write(obj.createdAtEpoch)
      ..writeByte(11)
      ..write(obj.updatedAtEpoch);
  }
}
