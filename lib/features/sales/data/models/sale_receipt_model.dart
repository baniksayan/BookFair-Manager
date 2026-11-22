import 'package:hive/hive.dart';

import '../../../../core/database/database_constants.dart';
import '../../domain/entities/sale_item.dart';
import '../../domain/entities/sale_receipt.dart';

/// Hive database model for [SaleReceipt] (TypeId 15).
class SaleReceiptModel extends HiveObject {
  SaleReceiptModel({
    required this.id,
    required this.receiptNumber,
    required this.fairId,
    this.cashierId,
    required this.cashierName,
    required this.subtotalAmountPaise,
    required this.discountAmountPaise,
    required this.totalAmountPaise,
    this.tenderedAmountPaise,
    this.changeAmountPaise,
    required this.paymentStatus,
    required this.refundedAmountPaise,
    this.customerName,
    this.customerPhone,
    required this.notes,
    required this.isUnverifiedStockSale,
    required this.isCostProvisional,
    required this.returnsJson,
    required this.createdAtEpoch,
  });

  final String id;
  final String receiptNumber;
  final String fairId;
  final String? cashierId;
  final String cashierName;
  final int subtotalAmountPaise;
  final int discountAmountPaise;
  final int totalAmountPaise;
  final int? tenderedAmountPaise;
  final int? changeAmountPaise;
  final String paymentStatus;
  final int refundedAmountPaise;
  final String? customerName;
  final String? customerPhone;
  final String notes;
  final bool isUnverifiedStockSale;
  final bool isCostProvisional;
  final String returnsJson;
  final int createdAtEpoch;

  factory SaleReceiptModel.fromEntity(SaleReceipt entity) {
    return SaleReceiptModel(
      id: entity.id,
      receiptNumber: entity.receiptNumber,
      fairId: entity.fairId,
      cashierId: entity.cashierId,
      cashierName: entity.cashierName,
      subtotalAmountPaise: entity.subtotalAmountPaise,
      discountAmountPaise: entity.discountAmountPaise,
      totalAmountPaise: entity.totalAmountPaise,
      tenderedAmountPaise: entity.tenderedAmountPaise,
      changeAmountPaise: entity.changeAmountPaise,
      paymentStatus: entity.paymentStatus,
      refundedAmountPaise: entity.refundedAmountPaise,
      customerName: entity.customerName,
      customerPhone: entity.customerPhone,
      notes: entity.notes,
      isUnverifiedStockSale: entity.isUnverifiedStockSale,
      isCostProvisional: entity.isCostProvisional,
      returnsJson: entity.returnsJson,
      createdAtEpoch: entity.createdAt.millisecondsSinceEpoch,
    );
  }

  SaleReceipt toEntity({List<SaleItem> items = const []}) {
    return SaleReceipt(
      id: id,
      receiptNumber: receiptNumber,
      fairId: fairId,
      cashierId: cashierId,
      cashierName: cashierName,
      subtotalAmountPaise: subtotalAmountPaise,
      discountAmountPaise: discountAmountPaise,
      totalAmountPaise: totalAmountPaise,
      tenderedAmountPaise: tenderedAmountPaise,
      changeAmountPaise: changeAmountPaise,
      paymentStatus: paymentStatus,
      refundedAmountPaise: refundedAmountPaise,
      customerName: customerName,
      customerPhone: customerPhone,
      notes: notes,
      isUnverifiedStockSale: isUnverifiedStockSale,
      isCostProvisional: isCostProvisional,
      returnsJson: returnsJson,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtEpoch),
      items: items,
    );
  }
}

/// Hive TypeAdapter for [SaleReceiptModel].
class SaleReceiptAdapter extends TypeAdapter<SaleReceiptModel> {
  @override
  final int typeId = DatabaseConstants.saleReceiptTypeId;

  @override
  SaleReceiptModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SaleReceiptModel(
      id: fields[0] as String,
      receiptNumber: fields[1] as String,
      fairId: fields[2] as String,
      cashierId: fields[3] as String?,
      cashierName: fields[4] as String? ?? 'Stall Volunteer',
      subtotalAmountPaise: fields[5] as int,
      discountAmountPaise: fields[6] as int? ?? 0,
      totalAmountPaise: fields[7] as int,
      tenderedAmountPaise: fields[8] as int?,
      changeAmountPaise: fields[9] as int?,
      paymentStatus: fields[10] as String? ?? 'paid',
      refundedAmountPaise: fields[11] as int? ?? 0,
      customerName: fields[12] as String?,
      customerPhone: fields[13] as String?,
      notes: fields[14] as String? ?? '',
      isUnverifiedStockSale: fields[15] as bool? ?? false,
      isCostProvisional: fields[16] as bool? ?? false,
      returnsJson: fields[17] as String? ?? '[]',
      createdAtEpoch: fields[18] as int,
    );
  }

  @override
  void write(BinaryWriter writer, SaleReceiptModel obj) {
    writer
      ..writeByte(19)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.receiptNumber)
      ..writeByte(2)
      ..write(obj.fairId)
      ..writeByte(3)
      ..write(obj.cashierId)
      ..writeByte(4)
      ..write(obj.cashierName)
      ..writeByte(5)
      ..write(obj.subtotalAmountPaise)
      ..writeByte(6)
      ..write(obj.discountAmountPaise)
      ..writeByte(7)
      ..write(obj.totalAmountPaise)
      ..writeByte(8)
      ..write(obj.tenderedAmountPaise)
      ..writeByte(9)
      ..write(obj.changeAmountPaise)
      ..writeByte(10)
      ..write(obj.paymentStatus)
      ..writeByte(11)
      ..write(obj.refundedAmountPaise)
      ..writeByte(12)
      ..write(obj.customerName)
      ..writeByte(13)
      ..write(obj.customerPhone)
      ..writeByte(14)
      ..write(obj.notes)
      ..writeByte(15)
      ..write(obj.isUnverifiedStockSale)
      ..writeByte(16)
      ..write(obj.isCostProvisional)
      ..writeByte(17)
      ..write(obj.returnsJson)
      ..writeByte(18)
      ..write(obj.createdAtEpoch);
  }
}
