import 'package:hive/hive.dart';

import '../../../../core/database/database_constants.dart';
import '../../domain/entities/sale_item.dart';

/// Hive database model for [SaleItem] (TypeId 16).
class SaleItemModel extends HiveObject {
  SaleItemModel({
    required this.id,
    required this.receiptId,
    required this.bookId,
    required this.bookTitle,
    required this.bookAuthor,
    this.isbn,
    required this.condition,
    required this.quantity,
    required this.unitMrpPaise,
    required this.unitSellingPricePaise,
    required this.itemDiscountPaise,
    required this.allocatedReceiptDiscountPaise,
    required this.lineTotalPaise,
    required this.unitCostPaise,
    required this.lineCogsPaise,
    required this.lineGrossProfitPaise,
    required this.isUnverifiedStock,
    required this.isCostProvisional,
    this.overrideAuthorizerId,
    this.overrideReason,
    required this.returnedQuantity,
    required this.createdAtEpoch,
  });

  final String id;
  final String receiptId;
  final String bookId;
  final String bookTitle;
  final String bookAuthor;
  final String? isbn;
  final String condition;
  final int quantity;
  final int unitMrpPaise;
  final int unitSellingPricePaise;
  final int itemDiscountPaise;
  final int allocatedReceiptDiscountPaise;
  final int lineTotalPaise;
  final int unitCostPaise;
  final int lineCogsPaise;
  final int lineGrossProfitPaise;
  final bool isUnverifiedStock;
  final bool isCostProvisional;
  final String? overrideAuthorizerId;
  final String? overrideReason;
  final int returnedQuantity;
  final int createdAtEpoch;

  factory SaleItemModel.fromEntity(SaleItem entity) {
    return SaleItemModel(
      id: entity.id,
      receiptId: entity.receiptId,
      bookId: entity.bookId,
      bookTitle: entity.bookTitle,
      bookAuthor: entity.bookAuthor,
      isbn: entity.isbn,
      condition: entity.condition,
      quantity: entity.quantity,
      unitMrpPaise: entity.unitMrpPaise,
      unitSellingPricePaise: entity.unitSellingPricePaise,
      itemDiscountPaise: entity.itemDiscountPaise,
      allocatedReceiptDiscountPaise: entity.allocatedReceiptDiscountPaise,
      lineTotalPaise: entity.lineTotalPaise,
      unitCostPaise: entity.unitCostPaise,
      lineCogsPaise: entity.lineCogsPaise,
      lineGrossProfitPaise: entity.lineGrossProfitPaise,
      isUnverifiedStock: entity.isUnverifiedStock,
      isCostProvisional: entity.isCostProvisional,
      overrideAuthorizerId: entity.overrideAuthorizerId,
      overrideReason: entity.overrideReason,
      returnedQuantity: entity.returnedQuantity,
      createdAtEpoch: entity.createdAt.millisecondsSinceEpoch,
    );
  }

  SaleItem toEntity() {
    return SaleItem(
      id: id,
      receiptId: receiptId,
      bookId: bookId,
      bookTitle: bookTitle,
      bookAuthor: bookAuthor,
      isbn: isbn,
      condition: condition,
      quantity: quantity,
      unitMrpPaise: unitMrpPaise,
      unitSellingPricePaise: unitSellingPricePaise,
      itemDiscountPaise: itemDiscountPaise,
      allocatedReceiptDiscountPaise: allocatedReceiptDiscountPaise,
      lineTotalPaise: lineTotalPaise,
      unitCostPaise: unitCostPaise,
      lineCogsPaise: lineCogsPaise,
      lineGrossProfitPaise: lineGrossProfitPaise,
      isUnverifiedStock: isUnverifiedStock,
      isCostProvisional: isCostProvisional,
      overrideAuthorizerId: overrideAuthorizerId,
      overrideReason: overrideReason,
      returnedQuantity: returnedQuantity,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtEpoch),
    );
  }
}

/// Hive TypeAdapter for [SaleItemModel].
class SaleItemAdapter extends TypeAdapter<SaleItemModel> {
  @override
  final int typeId = DatabaseConstants.saleItemTypeId;

  @override
  SaleItemModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SaleItemModel(
      id: fields[0] as String,
      receiptId: fields[1] as String,
      bookId: fields[2] as String,
      bookTitle: fields[3] as String,
      bookAuthor: fields[4] as String? ?? '',
      isbn: fields[5] as String?,
      condition: fields[6] as String? ?? 'Brand New',
      quantity: fields[7] as int,
      unitMrpPaise: fields[8] as int,
      unitSellingPricePaise: fields[9] as int,
      itemDiscountPaise: fields[10] as int? ?? 0,
      allocatedReceiptDiscountPaise: fields[11] as int? ?? 0,
      lineTotalPaise: fields[12] as int,
      unitCostPaise: fields[13] as int,
      lineCogsPaise: fields[14] as int,
      lineGrossProfitPaise: fields[15] as int,
      isUnverifiedStock: fields[16] as bool? ?? false,
      isCostProvisional: fields[17] as bool? ?? false,
      overrideAuthorizerId: fields[18] as String?,
      overrideReason: fields[19] as String?,
      returnedQuantity: fields[20] as int? ?? 0,
      createdAtEpoch: fields[21] as int,
    );
  }

  @override
  void write(BinaryWriter writer, SaleItemModel obj) {
    writer
      ..writeByte(22)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.receiptId)
      ..writeByte(2)
      ..write(obj.bookId)
      ..writeByte(3)
      ..write(obj.bookTitle)
      ..writeByte(4)
      ..write(obj.bookAuthor)
      ..writeByte(5)
      ..write(obj.isbn)
      ..writeByte(6)
      ..write(obj.condition)
      ..writeByte(7)
      ..write(obj.quantity)
      ..writeByte(8)
      ..write(obj.unitMrpPaise)
      ..writeByte(9)
      ..write(obj.unitSellingPricePaise)
      ..writeByte(10)
      ..write(obj.itemDiscountPaise)
      ..writeByte(11)
      ..write(obj.allocatedReceiptDiscountPaise)
      ..writeByte(12)
      ..write(obj.lineTotalPaise)
      ..writeByte(13)
      ..write(obj.unitCostPaise)
      ..writeByte(14)
      ..write(obj.lineCogsPaise)
      ..writeByte(15)
      ..write(obj.lineGrossProfitPaise)
      ..writeByte(16)
      ..write(obj.isUnverifiedStock)
      ..writeByte(17)
      ..write(obj.isCostProvisional)
      ..writeByte(18)
      ..write(obj.overrideAuthorizerId)
      ..writeByte(19)
      ..write(obj.overrideReason)
      ..writeByte(20)
      ..write(obj.returnedQuantity)
      ..writeByte(21)
      ..write(obj.createdAtEpoch);
  }
}
