import 'package:hive/hive.dart';

import '../../../../core/database/database_constants.dart';
import '../../domain/entities/account_transaction.dart';

/// Hive database model for [AccountTransaction].
class AccountTransactionModel extends HiveObject {
  AccountTransactionModel({
    required this.id,
    required this.fairId,
    required this.accountId,
    required this.transactionType,
    required this.direction,
    required this.amountPaise,
    required this.transactionDateEpoch,
    required this.referenceType,
    this.referenceId,
    required this.description,
    required this.createdAtEpoch,
  });

  factory AccountTransactionModel.fromEntity(AccountTransaction entity) {
    return AccountTransactionModel(
      id: entity.id,
      fairId: entity.fairId,
      accountId: entity.accountId,
      transactionType: entity.transactionType,
      direction: entity.direction,
      amountPaise: entity.amountPaise,
      transactionDateEpoch: entity.transactionDate.millisecondsSinceEpoch,
      referenceType: entity.referenceType,
      referenceId: entity.referenceId,
      description: entity.description,
      createdAtEpoch: entity.createdAt.millisecondsSinceEpoch,
    );
  }

  final String id;
  final String fairId;
  final String accountId;
  final String transactionType;
  final String direction;
  final int amountPaise;
  final int transactionDateEpoch;
  final String referenceType;
  final String? referenceId;
  final String description;
  final int createdAtEpoch;

  AccountTransaction toEntity() {
    return AccountTransaction(
      id: id,
      fairId: fairId,
      accountId: accountId,
      transactionType: transactionType,
      direction: direction,
      amountPaise: amountPaise,
      transactionDate: DateTime.fromMillisecondsSinceEpoch(
        transactionDateEpoch,
      ),
      referenceType: referenceType,
      referenceId: referenceId,
      description: description,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtEpoch),
    );
  }
}

/// Manual binary serializer for [AccountTransactionModel] avoiding build_runner fragility.
class AccountTransactionAdapter extends TypeAdapter<AccountTransactionModel> {
  @override
  final int typeId = DatabaseConstants.accountTransactionTypeId;

  @override
  AccountTransactionModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    return AccountTransactionModel(
      id: fields[0] as String,
      fairId: fields[1] as String,
      accountId: fields[2] as String,
      transactionType: fields[3] as String,
      direction: fields[4] as String,
      amountPaise: fields[5] as int,
      transactionDateEpoch: fields[6] as int,
      referenceType: fields[7] as String,
      referenceId: fields[8] as String?,
      description: fields[9] as String? ?? '',
      createdAtEpoch: fields[10] as int,
    );
  }

  @override
  void write(BinaryWriter writer, AccountTransactionModel obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.fairId)
      ..writeByte(2)
      ..write(obj.accountId)
      ..writeByte(3)
      ..write(obj.transactionType)
      ..writeByte(4)
      ..write(obj.direction)
      ..writeByte(5)
      ..write(obj.amountPaise)
      ..writeByte(6)
      ..write(obj.transactionDateEpoch)
      ..writeByte(7)
      ..write(obj.referenceType)
      ..writeByte(8)
      ..write(obj.referenceId)
      ..writeByte(9)
      ..write(obj.description)
      ..writeByte(10)
      ..write(obj.createdAtEpoch);
  }
}
