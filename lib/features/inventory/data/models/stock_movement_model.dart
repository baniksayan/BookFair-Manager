import 'package:hive/hive.dart';

import '../../../../core/database/database_constants.dart';
import '../../domain/entities/stock_movement.dart';

/// Hive database storage model for [StockMovement].
class StockMovementModel extends HiveObject {
  StockMovementModel({
    required this.id,
    required this.fairId,
    required this.bookId,
    required this.quantity,
    required this.movementType,
    this.referenceId,
    required this.movementDateEpoch,
    required this.notes,
    required this.createdAtEpoch,
  });

  factory StockMovementModel.fromEntity(StockMovement entity) {
    return StockMovementModel(
      id: entity.id,
      fairId: entity.fairId,
      bookId: entity.bookId,
      quantity: entity.quantity,
      movementType: entity.movementType.name,
      referenceId: entity.referenceId,
      movementDateEpoch: entity.movementDate.millisecondsSinceEpoch,
      notes: entity.notes,
      createdAtEpoch: entity.createdAt.millisecondsSinceEpoch,
    );
  }

  final String id;
  final String fairId;
  final String bookId;
  final int quantity;
  final String movementType;
  final String? referenceId;
  final int movementDateEpoch;
  final String notes;
  final int createdAtEpoch;

  StockMovement toEntity() {
    return StockMovement(
      id: id,
      fairId: fairId,
      bookId: bookId,
      quantity: quantity,
      movementType: StockMovementType.fromString(movementType),
      referenceId: referenceId,
      movementDate: DateTime.fromMillisecondsSinceEpoch(movementDateEpoch),
      notes: notes,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtEpoch),
    );
  }
}

/// Binary serializer and deserializer for [StockMovementModel].
class StockMovementAdapter extends TypeAdapter<StockMovementModel> {
  @override
  final int typeId = DatabaseConstants.stockMovementTypeId;

  @override
  StockMovementModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StockMovementModel(
      id: fields[0] as String,
      fairId: fields[1] as String,
      bookId: fields[2] as String,
      quantity: fields[3] as int? ?? 0,
      movementType: fields[4] as String? ?? 'manualAdjustment',
      referenceId: fields[5] as String?,
      movementDateEpoch: fields[6] as int,
      notes: fields[7] as String? ?? '',
      createdAtEpoch: fields[8] as int,
    );
  }

  @override
  void write(BinaryWriter writer, StockMovementModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.fairId)
      ..writeByte(2)
      ..write(obj.bookId)
      ..writeByte(3)
      ..write(obj.quantity)
      ..writeByte(4)
      ..write(obj.movementType)
      ..writeByte(5)
      ..write(obj.referenceId)
      ..writeByte(6)
      ..write(obj.movementDateEpoch)
      ..writeByte(7)
      ..write(obj.notes)
      ..writeByte(8)
      ..write(obj.createdAtEpoch);
  }
}
