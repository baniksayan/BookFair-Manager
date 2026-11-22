import 'package:hive/hive.dart';

import '../../../../core/database/database_constants.dart';
import '../../domain/entities/expense_category.dart';

/// Hive database model for [ExpenseCategory].
class ExpenseCategoryModel extends HiveObject {
  ExpenseCategoryModel({
    required this.id,
    required this.name,
    this.iconName,
    required this.isCustom,
    required this.isSystem,
    required this.createdAtEpoch,
  });

  factory ExpenseCategoryModel.fromEntity(ExpenseCategory entity) {
    return ExpenseCategoryModel(
      id: entity.id,
      name: entity.name,
      iconName: entity.iconName,
      isCustom: entity.isCustom,
      isSystem: entity.isSystem,
      createdAtEpoch: entity.createdAt.millisecondsSinceEpoch,
    );
  }

  final String id;
  final String name;
  final String? iconName;
  final bool isCustom;
  final bool isSystem;
  final int createdAtEpoch;

  ExpenseCategory toEntity() {
    return ExpenseCategory(
      id: id,
      name: name,
      iconName: iconName,
      isCustom: isCustom,
      isSystem: isSystem,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtEpoch),
    );
  }
}

/// Manual binary serializer for [ExpenseCategoryModel] avoiding build_runner fragility.
class ExpenseCategoryAdapter extends TypeAdapter<ExpenseCategoryModel> {
  @override
  final int typeId = DatabaseConstants.expenseCategoryTypeId;

  @override
  ExpenseCategoryModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    return ExpenseCategoryModel(
      id: fields[0] as String,
      name: fields[1] as String,
      iconName: fields[2] as String?,
      isCustom: fields[3] as bool? ?? false,
      isSystem: fields[4] as bool? ?? true,
      createdAtEpoch: fields[5] as int,
    );
  }

  @override
  void write(BinaryWriter writer, ExpenseCategoryModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.iconName)
      ..writeByte(3)
      ..write(obj.isCustom)
      ..writeByte(4)
      ..write(obj.isSystem)
      ..writeByte(5)
      ..write(obj.createdAtEpoch);
  }
}
