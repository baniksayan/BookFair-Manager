import 'package:hive/hive.dart';

import '../../../../core/database/database_constants.dart';
import '../../domain/entities/purchase_batch.dart';
import '../../domain/entities/purchase_item.dart';

/// Hive database storage model for [PurchaseBatch].
class PurchaseBatchModel extends HiveObject {
  PurchaseBatchModel({
    required this.id,
    required this.fairId,
    this.supplierId,
    required this.purchaseDateEpoch,
    this.invoiceNumber,
    this.purchaseReference,
    required this.totalQuantity,
    required this.totalBookCostPaise,
    required this.additionalChargesPaise,
    required this.totalAcquisitionCostPaise,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.notes,
    required this.createdAtEpoch,
  });

  factory PurchaseBatchModel.fromEntity(PurchaseBatch entity) {
    return PurchaseBatchModel(
      id: entity.id,
      fairId: entity.fairId,
      supplierId: entity.supplierId,
      purchaseDateEpoch: entity.purchaseDate.millisecondsSinceEpoch,
      invoiceNumber: entity.invoiceNumber,
      purchaseReference: entity.purchaseReference,
      totalQuantity: entity.totalQuantity,
      totalBookCostPaise: entity.totalBookCostPaise,
      additionalChargesPaise: entity.additionalChargesPaise,
      totalAcquisitionCostPaise: entity.totalAcquisitionCostPaise,
      paymentStatus: entity.paymentStatus,
      paymentMethod: entity.paymentMethod,
      notes: entity.notes,
      createdAtEpoch: entity.createdAt.millisecondsSinceEpoch,
    );
  }

  final String id;
  final String fairId;
  final String? supplierId;
  final int purchaseDateEpoch;
  final String? invoiceNumber;
  final String? purchaseReference;
  final int totalQuantity;
  final int totalBookCostPaise;
  final int additionalChargesPaise;
  final int totalAcquisitionCostPaise;
  final String paymentStatus;
  final String paymentMethod;
  final String notes;
  final int createdAtEpoch;

  PurchaseBatch toEntity({List<PurchaseItem> items = const []}) {
    return PurchaseBatch(
      id: id,
      fairId: fairId,
      supplierId: supplierId,
      purchaseDate: DateTime.fromMillisecondsSinceEpoch(purchaseDateEpoch),
      invoiceNumber: invoiceNumber,
      purchaseReference: purchaseReference,
      totalQuantity: totalQuantity,
      totalBookCostPaise: totalBookCostPaise,
      additionalChargesPaise: additionalChargesPaise,
      totalAcquisitionCostPaise: totalAcquisitionCostPaise,
      paymentStatus: paymentStatus,
      paymentMethod: paymentMethod,
      notes: notes,
      items: items,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtEpoch),
    );
  }
}

/// Binary serializer and deserializer for [PurchaseBatchModel].
class PurchaseBatchAdapter extends TypeAdapter<PurchaseBatchModel> {
  @override
  final int typeId = DatabaseConstants.purchaseBatchTypeId;

  @override
  PurchaseBatchModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PurchaseBatchModel(
      id: fields[0] as String,
      fairId: fields[1] as String,
      supplierId: fields[2] as String?,
      purchaseDateEpoch: fields[3] as int,
      invoiceNumber: fields[4] as String?,
      purchaseReference: fields[5] as String?,
      totalQuantity: fields[6] as int? ?? 0,
      totalBookCostPaise: fields[7] as int? ?? 0,
      additionalChargesPaise: fields[8] as int? ?? 0,
      totalAcquisitionCostPaise: fields[9] as int? ?? 0,
      paymentStatus: fields[10] as String? ?? 'Paid',
      paymentMethod: fields[11] as String? ?? 'Bank Transfer',
      notes: fields[12] as String? ?? '',
      createdAtEpoch: fields[13] as int,
    );
  }

  @override
  void write(BinaryWriter writer, PurchaseBatchModel obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.fairId)
      ..writeByte(2)
      ..write(obj.supplierId)
      ..writeByte(3)
      ..write(obj.purchaseDateEpoch)
      ..writeByte(4)
      ..write(obj.invoiceNumber)
      ..writeByte(5)
      ..write(obj.purchaseReference)
      ..writeByte(6)
      ..write(obj.totalQuantity)
      ..writeByte(7)
      ..write(obj.totalBookCostPaise)
      ..writeByte(8)
      ..write(obj.additionalChargesPaise)
      ..writeByte(9)
      ..write(obj.totalAcquisitionCostPaise)
      ..writeByte(10)
      ..write(obj.paymentStatus)
      ..writeByte(11)
      ..write(obj.paymentMethod)
      ..writeByte(12)
      ..write(obj.notes)
      ..writeByte(13)
      ..write(obj.createdAtEpoch);
  }
}
