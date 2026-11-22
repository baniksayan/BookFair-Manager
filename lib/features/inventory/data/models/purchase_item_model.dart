import 'package:hive/hive.dart';

import '../../../../core/database/database_constants.dart';
import '../../domain/entities/book.dart';
import '../../domain/entities/purchase_item.dart';

/// Hive database storage model for [PurchaseItem].
class PurchaseItemModel extends HiveObject {
  PurchaseItemModel({
    required this.id,
    required this.batchId,
    required this.bookId,
    required this.quantity,
    required this.unitPurchaseCostPaise,
    required this.lineTotalPaise,
    required this.condition,
    required this.notes,
  });

  factory PurchaseItemModel.fromEntity(PurchaseItem entity) {
    return PurchaseItemModel(
      id: entity.id,
      batchId: entity.batchId,
      bookId: entity.bookId,
      quantity: entity.quantity,
      unitPurchaseCostPaise: entity.unitPurchaseCostPaise,
      lineTotalPaise: entity.lineTotalPaise,
      condition: entity.condition.name,
      notes: entity.notes,
    );
  }

  final String id;
  final String batchId;
  final String bookId;
  final int quantity;
  final int unitPurchaseCostPaise;
  final int lineTotalPaise;
  final String condition;
  final String notes;

  PurchaseItem toEntity() {
    return PurchaseItem(
      id: id,
      batchId: batchId,
      bookId: bookId,
      quantity: quantity,
      unitPurchaseCostPaise: unitPurchaseCostPaise,
      lineTotalPaise: lineTotalPaise,
      condition: BookCondition.fromString(condition),
      notes: notes,
    );
  }
}

/// Binary serializer and deserializer for [PurchaseItemModel].
class PurchaseItemAdapter extends TypeAdapter<PurchaseItemModel> {
  @override
  final int typeId = DatabaseConstants.purchaseItemTypeId;

  @override
  PurchaseItemModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PurchaseItemModel(
      id: fields[0] as String,
      batchId: fields[1] as String,
      bookId: fields[2] as String,
      quantity: fields[3] as int? ?? 1,
      unitPurchaseCostPaise: fields[4] as int? ?? 0,
      lineTotalPaise: fields[5] as int? ?? 0,
      condition: fields[6] as String? ?? 'brandNew',
      notes: fields[7] as String? ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, PurchaseItemModel obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.batchId)
      ..writeByte(2)
      ..write(obj.bookId)
      ..writeByte(3)
      ..write(obj.quantity)
      ..writeByte(4)
      ..write(obj.unitPurchaseCostPaise)
      ..writeByte(5)
      ..write(obj.lineTotalPaise)
      ..writeByte(6)
      ..write(obj.condition)
      ..writeByte(7)
      ..write(obj.notes);
  }
}
