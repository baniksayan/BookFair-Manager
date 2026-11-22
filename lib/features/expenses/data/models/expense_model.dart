import 'package:hive/hive.dart';

import '../../../../core/database/database_constants.dart';
import '../../domain/entities/expense.dart';

/// Hive database model for [Expense].
class ExpenseModel extends HiveObject {
  ExpenseModel({
    required this.id,
    required this.fairId,
    required this.title,
    required this.description,
    required this.categoryId,
    required this.amountPaise,
    required this.expenseDateEpoch,
    required this.paymentStatus,
    required this.paidAmountPaise,
    required this.outstandingAmountPaise,
    required this.paymentMethod,
    this.paidByPartnerId,
    this.paidFromAccountId,
    this.supplierId,
    this.receiptImagePath,
    this.referenceNumber,
    required this.notes,
    required this.createdAtEpoch,
    required this.updatedAtEpoch,
  });

  factory ExpenseModel.fromEntity(Expense entity) {
    return ExpenseModel(
      id: entity.id,
      fairId: entity.fairId,
      title: entity.title,
      description: entity.description,
      categoryId: entity.categoryId,
      amountPaise: entity.amountPaise,
      expenseDateEpoch: entity.expenseDate.millisecondsSinceEpoch,
      paymentStatus: entity.paymentStatus,
      paidAmountPaise: entity.paidAmountPaise,
      outstandingAmountPaise: entity.outstandingAmountPaise,
      paymentMethod: entity.paymentMethod,
      paidByPartnerId: entity.paidByPartnerId,
      paidFromAccountId: entity.paidFromAccountId,
      supplierId: entity.supplierId,
      receiptImagePath: entity.receiptImagePath,
      referenceNumber: entity.referenceNumber,
      notes: entity.notes,
      createdAtEpoch: entity.createdAt.millisecondsSinceEpoch,
      updatedAtEpoch: entity.updatedAt.millisecondsSinceEpoch,
    );
  }

  final String id;
  final String fairId;
  final String title;
  final String description;
  final String categoryId;
  final int amountPaise;
  final int expenseDateEpoch;
  final String paymentStatus;
  final int paidAmountPaise;
  final int outstandingAmountPaise;
  final String paymentMethod;
  final String? paidByPartnerId;
  final String? paidFromAccountId;
  final String? supplierId;
  final String? receiptImagePath;
  final String? referenceNumber;
  final String notes;
  final int createdAtEpoch;
  final int updatedAtEpoch;

  bool get isCancelled =>
      paymentStatus.toLowerCase().startsWith('cancelled') ||
      paymentStatus.toLowerCase() == 'written off';

  Expense toEntity() {
    return Expense(
      id: id,
      fairId: fairId,
      title: title,
      description: description,
      categoryId: categoryId,
      amountPaise: amountPaise,
      expenseDate: DateTime.fromMillisecondsSinceEpoch(expenseDateEpoch),
      paymentStatus: paymentStatus,
      paidAmountPaise: paidAmountPaise,
      outstandingAmountPaise: outstandingAmountPaise,
      paymentMethod: paymentMethod,
      paidByPartnerId: paidByPartnerId,
      paidFromAccountId: paidFromAccountId,
      supplierId: supplierId,
      receiptImagePath: receiptImagePath,
      referenceNumber: referenceNumber,
      notes: notes,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtEpoch),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAtEpoch),
    );
  }
}

/// Manual binary serializer for [ExpenseModel] avoiding build_runner fragility.
class ExpenseAdapter extends TypeAdapter<ExpenseModel> {
  @override
  final int typeId = DatabaseConstants.expenseTypeId;

  @override
  ExpenseModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    return ExpenseModel(
      id: fields[0] as String,
      fairId: fields[1] as String,
      title: fields[2] as String,
      description: fields[3] as String? ?? '',
      categoryId: fields[4] as String,
      amountPaise: fields[5] as int,
      expenseDateEpoch: fields[6] as int,
      paymentStatus: fields[7] as String? ?? 'Unpaid',
      paidAmountPaise: fields[8] as int? ?? 0,
      outstandingAmountPaise: fields[9] as int? ?? 0,
      paymentMethod: fields[10] as String? ?? 'Cash',
      paidByPartnerId: fields[11] as String?,
      paidFromAccountId: fields[12] as String?,
      supplierId: fields[13] as String?,
      receiptImagePath: fields[14] as String?,
      referenceNumber: fields[15] as String?,
      notes: fields[16] as String? ?? '',
      createdAtEpoch: fields[17] as int,
      updatedAtEpoch: fields[18] as int? ?? fields[17] as int,
    );
  }

  @override
  void write(BinaryWriter writer, ExpenseModel obj) {
    writer
      ..writeByte(19)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.fairId)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.categoryId)
      ..writeByte(5)
      ..write(obj.amountPaise)
      ..writeByte(6)
      ..write(obj.expenseDateEpoch)
      ..writeByte(7)
      ..write(obj.paymentStatus)
      ..writeByte(8)
      ..write(obj.paidAmountPaise)
      ..writeByte(9)
      ..write(obj.outstandingAmountPaise)
      ..writeByte(10)
      ..write(obj.paymentMethod)
      ..writeByte(11)
      ..write(obj.paidByPartnerId)
      ..writeByte(12)
      ..write(obj.paidFromAccountId)
      ..writeByte(13)
      ..write(obj.supplierId)
      ..writeByte(14)
      ..write(obj.receiptImagePath)
      ..writeByte(15)
      ..write(obj.referenceNumber)
      ..writeByte(16)
      ..write(obj.notes)
      ..writeByte(17)
      ..write(obj.createdAtEpoch)
      ..writeByte(18)
      ..write(obj.updatedAtEpoch);
  }
}
