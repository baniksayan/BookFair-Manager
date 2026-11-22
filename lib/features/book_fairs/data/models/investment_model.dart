import 'package:hive/hive.dart';

import '../../../../core/database/database_constants.dart';
import '../../domain/entities/investment.dart';

/// Hive database storage model for [Investment].
class InvestmentModel extends HiveObject {
  InvestmentModel({
    required this.id,
    required this.fairId,
    required this.partnerId,
    required this.amountPaise,
    required this.contributionType,
    required this.paymentMethod,
    required this.contributionDateEpoch,
    this.referenceNumber,
    required this.notes,
    required this.createdAtEpoch,
    required this.updatedAtEpoch,
  });

  factory InvestmentModel.fromEntity(Investment entity) {
    return InvestmentModel(
      id: entity.id,
      fairId: entity.fairId,
      partnerId: entity.partnerId,
      amountPaise: entity.amountPaise,
      contributionType: entity.contributionType.name,
      paymentMethod: entity.paymentMethod.name,
      contributionDateEpoch: entity.contributionDate.millisecondsSinceEpoch,
      referenceNumber: entity.referenceNumber,
      notes: entity.notes,
      createdAtEpoch: entity.createdAt.millisecondsSinceEpoch,
      updatedAtEpoch: entity.updatedAt.millisecondsSinceEpoch,
    );
  }

  final String id;
  final String fairId;
  final String partnerId;
  final int amountPaise;
  final String contributionType;
  final String paymentMethod;
  final int contributionDateEpoch;
  final String? referenceNumber;
  final String notes;
  final int createdAtEpoch;
  final int updatedAtEpoch;

  Investment toEntity() {
    return Investment(
      id: id,
      fairId: fairId,
      partnerId: partnerId,
      amountPaise: amountPaise,
      contributionType: ContributionType.fromString(contributionType),
      paymentMethod: PaymentMethod.fromString(paymentMethod),
      contributionDate: DateTime.fromMillisecondsSinceEpoch(
        contributionDateEpoch,
      ),
      referenceNumber: referenceNumber,
      notes: notes,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtEpoch),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAtEpoch),
    );
  }
}

/// Binary serializer and deserializer for [InvestmentModel].
class InvestmentAdapter extends TypeAdapter<InvestmentModel> {
  @override
  final int typeId = DatabaseConstants.investmentTypeId;

  @override
  InvestmentModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return InvestmentModel(
      id: fields[0] as String,
      fairId: fields[1] as String,
      partnerId: fields[2] as String,
      amountPaise: fields[3] as int,
      contributionType: fields[4] as String? ?? 'cash',
      paymentMethod: fields[5] as String? ?? 'cash',
      contributionDateEpoch: fields[6] as int,
      referenceNumber: fields[7] as String?,
      notes: fields[8] as String? ?? '',
      createdAtEpoch: fields[9] as int,
      updatedAtEpoch: fields[10] as int? ?? fields[9] as int,
    );
  }

  @override
  void write(BinaryWriter writer, InvestmentModel obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.fairId)
      ..writeByte(2)
      ..write(obj.partnerId)
      ..writeByte(3)
      ..write(obj.amountPaise)
      ..writeByte(4)
      ..write(obj.contributionType)
      ..writeByte(5)
      ..write(obj.paymentMethod)
      ..writeByte(6)
      ..write(obj.contributionDateEpoch)
      ..writeByte(7)
      ..write(obj.referenceNumber)
      ..writeByte(8)
      ..write(obj.notes)
      ..writeByte(9)
      ..write(obj.createdAtEpoch)
      ..writeByte(10)
      ..write(obj.updatedAtEpoch);
  }
}
