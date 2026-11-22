import 'package:hive/hive.dart';

import '../../../../core/database/database_constants.dart';
import '../../domain/entities/cashbook_account.dart';

/// Hive database model for [CashbookAccount].
class CashbookAccountModel extends HiveObject {
  CashbookAccountModel({
    required this.id,
    required this.fairId,
    required this.accountName,
    required this.accountType,
    required this.openingBalancePaise,
    required this.currentBalancePaise,
    required this.isActive,
    required this.createdAtEpoch,
    required this.updatedAtEpoch,
  });

  factory CashbookAccountModel.fromEntity(CashbookAccount entity) {
    return CashbookAccountModel(
      id: entity.id,
      fairId: entity.fairId,
      accountName: entity.accountName,
      accountType: entity.accountType,
      openingBalancePaise: entity.openingBalancePaise,
      currentBalancePaise: entity.currentBalancePaise,
      isActive: entity.isActive,
      createdAtEpoch: entity.createdAt.millisecondsSinceEpoch,
      updatedAtEpoch: entity.updatedAt.millisecondsSinceEpoch,
    );
  }

  final String id;
  final String fairId;
  final String accountName;
  final String accountType;
  final int openingBalancePaise;
  final int currentBalancePaise;
  final bool isActive;
  final int createdAtEpoch;
  final int updatedAtEpoch;

  CashbookAccount toEntity() {
    return CashbookAccount(
      id: id,
      fairId: fairId,
      accountName: accountName,
      accountType: accountType,
      openingBalancePaise: openingBalancePaise,
      currentBalancePaise: currentBalancePaise,
      isActive: isActive,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtEpoch),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAtEpoch),
    );
  }
}

/// Manual binary serializer for [CashbookAccountModel] avoiding build_runner fragility.
class CashbookAccountAdapter extends TypeAdapter<CashbookAccountModel> {
  @override
  final int typeId = DatabaseConstants.cashbookAccountTypeId;

  @override
  CashbookAccountModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    return CashbookAccountModel(
      id: fields[0] as String,
      fairId: fields[1] as String,
      accountName: fields[2] as String,
      accountType: fields[3] as String,
      openingBalancePaise: fields[4] as int,
      currentBalancePaise: fields[5] as int,
      isActive: fields[6] as bool? ?? true,
      createdAtEpoch: fields[7] as int,
      updatedAtEpoch: fields[8] as int? ?? fields[7] as int,
    );
  }

  @override
  void write(BinaryWriter writer, CashbookAccountModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.fairId)
      ..writeByte(2)
      ..write(obj.accountName)
      ..writeByte(3)
      ..write(obj.accountType)
      ..writeByte(4)
      ..write(obj.openingBalancePaise)
      ..writeByte(5)
      ..write(obj.currentBalancePaise)
      ..writeByte(6)
      ..write(obj.isActive)
      ..writeByte(7)
      ..write(obj.createdAtEpoch)
      ..writeByte(8)
      ..write(obj.updatedAtEpoch);
  }
}
