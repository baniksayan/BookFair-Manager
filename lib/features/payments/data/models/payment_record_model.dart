import 'package:hive/hive.dart';

import '../../../../core/database/database_constants.dart';
import '../../domain/entities/payment_record.dart';

/// Hive database model for [PaymentRecord] (TypeId 13).
///
/// Links payment records to cashbook transactions and business entities (such as expenses,
/// purchase batches, or partner reimbursements).
///
/// Note: This represents an operational cashbook and disbursement tracking system,
/// not a traditional double-entry general ledger with a chart of accounts.
class PaymentRecordModel extends HiveObject {
  PaymentRecordModel({
    required this.id,
    required this.fairId,
    required this.amountPaise,
    required this.paymentMethod,
    required this.paymentDateEpoch,
    this.accountId,
    this.payerPartnerId,
    this.recipientPartnerId,
    this.supplierId,
    this.referenceNumber,
    required this.relatedEntityType,
    required this.relatedEntityId,
    required this.notes,
    required this.createdAtEpoch,
  });

  factory PaymentRecordModel.fromEntity(PaymentRecord entity) {
    return PaymentRecordModel(
      id: entity.id,
      fairId: entity.fairId,
      amountPaise: entity.amountPaise,
      paymentMethod: entity.paymentMethod,
      paymentDateEpoch: entity.paymentDate.millisecondsSinceEpoch,
      accountId: entity.accountId,
      payerPartnerId: entity.payerPartnerId,
      recipientPartnerId: entity.recipientPartnerId,
      supplierId: entity.supplierId,
      referenceNumber: entity.referenceNumber,
      relatedEntityType: entity.relatedEntityType,
      relatedEntityId: entity.relatedEntityId,
      notes: entity.notes,
      createdAtEpoch: entity.createdAt.millisecondsSinceEpoch,
    );
  }

  final String id;
  final String fairId;
  final int amountPaise;
  final String paymentMethod;
  final int paymentDateEpoch;
  final String? accountId;
  final String? payerPartnerId;
  final String? recipientPartnerId;
  final String? supplierId;
  final String? referenceNumber;
  final String relatedEntityType;
  final String relatedEntityId;
  final String notes;
  final int createdAtEpoch;

  PaymentRecord toEntity() {
    return PaymentRecord(
      id: id,
      fairId: fairId,
      amountPaise: amountPaise,
      paymentMethod: paymentMethod,
      paymentDate: DateTime.fromMillisecondsSinceEpoch(paymentDateEpoch),
      accountId: accountId,
      payerPartnerId: payerPartnerId,
      recipientPartnerId: recipientPartnerId,
      supplierId: supplierId,
      referenceNumber: referenceNumber,
      relatedEntityType: relatedEntityType,
      relatedEntityId: relatedEntityId,
      notes: notes,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtEpoch),
    );
  }
}

/// Manual binary serializer for [PaymentRecordModel] avoiding build_runner fragility.
class PaymentRecordAdapter extends TypeAdapter<PaymentRecordModel> {
  @override
  final int typeId = DatabaseConstants.paymentRecordTypeId;

  @override
  PaymentRecordModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    return PaymentRecordModel(
      id: fields[0] as String,
      fairId: fields[1] as String,
      amountPaise: fields[2] as int,
      paymentMethod: fields[3] as String,
      paymentDateEpoch: fields[4] as int,
      accountId: fields[5] as String?,
      payerPartnerId: fields[6] as String?,
      recipientPartnerId: fields[7] as String?,
      supplierId: fields[8] as String?,
      referenceNumber: fields[9] as String?,
      relatedEntityType: fields[10] as String,
      relatedEntityId: fields[11] as String,
      notes: fields[12] as String? ?? '',
      createdAtEpoch: fields[13] as int,
    );
  }

  @override
  void write(BinaryWriter writer, PaymentRecordModel obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.fairId)
      ..writeByte(2)
      ..write(obj.amountPaise)
      ..writeByte(3)
      ..write(obj.paymentMethod)
      ..writeByte(4)
      ..write(obj.paymentDateEpoch)
      ..writeByte(5)
      ..write(obj.accountId)
      ..writeByte(6)
      ..write(obj.payerPartnerId)
      ..writeByte(7)
      ..write(obj.recipientPartnerId)
      ..writeByte(8)
      ..write(obj.supplierId)
      ..writeByte(9)
      ..write(obj.referenceNumber)
      ..writeByte(10)
      ..write(obj.relatedEntityType)
      ..writeByte(11)
      ..write(obj.relatedEntityId)
      ..writeByte(12)
      ..write(obj.notes)
      ..writeByte(13)
      ..write(obj.createdAtEpoch);
  }
}
