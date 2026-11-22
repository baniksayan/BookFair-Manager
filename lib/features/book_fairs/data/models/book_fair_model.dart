import 'package:hive/hive.dart';

import '../../../../core/database/database_constants.dart';
import '../../domain/entities/book_fair.dart';

/// Hive database storage model for [BookFair].
class BookFairModel extends HiveObject {
  BookFairModel({
    required this.id,
    required this.name,
    required this.location,
    required this.city,
    required this.state,
    required this.startDateEpoch,
    required this.endDateEpoch,
    this.setupDateEpoch,
    this.closingDateEpoch,
    required this.estimatedBudgetPaise,
    required this.initialInvestmentPaise,
    required this.currency,
    required this.partnerCount,
    required this.partnershipType,
    required this.initialPartnerSetup,
    required this.description,
    required this.operationalNotes,
    required this.isDraft,
    required this.isArchived,
    required this.createdAtEpoch,
    required this.updatedAtEpoch,
  });

  factory BookFairModel.fromEntity(BookFair entity) {
    return BookFairModel(
      id: entity.id,
      name: entity.name,
      location: entity.location,
      city: entity.city,
      state: entity.state,
      startDateEpoch: entity.startDate.millisecondsSinceEpoch,
      endDateEpoch: entity.endDate.millisecondsSinceEpoch,
      setupDateEpoch: entity.setupDate?.millisecondsSinceEpoch,
      closingDateEpoch: entity.closingDate?.millisecondsSinceEpoch,
      estimatedBudgetPaise: entity.estimatedBudgetPaise,
      initialInvestmentPaise: entity.initialInvestmentPaise,
      currency: entity.currency,
      partnerCount: entity.partnerCount,
      partnershipType: entity.partnershipType,
      initialPartnerSetup: entity.initialPartnerSetup,
      description: entity.description,
      operationalNotes: entity.operationalNotes,
      isDraft: entity.isDraft,
      isArchived: entity.isArchived,
      createdAtEpoch: entity.createdAt.millisecondsSinceEpoch,
      updatedAtEpoch: entity.updatedAt.millisecondsSinceEpoch,
    );
  }

  final String id;
  final String name;
  final String location;
  final String city;
  final String state;
  final int startDateEpoch;
  final int endDateEpoch;
  final int? setupDateEpoch;
  final int? closingDateEpoch;
  final int estimatedBudgetPaise;
  final int initialInvestmentPaise;
  final String currency;
  final int partnerCount;
  final String partnershipType;
  final String initialPartnerSetup;
  final String description;
  final String operationalNotes;
  final bool isDraft;
  final bool isArchived;
  final int createdAtEpoch;
  final int updatedAtEpoch;

  BookFair toEntity() {
    return BookFair(
      id: id,
      name: name,
      location: location,
      city: city,
      state: state,
      startDate: DateTime.fromMillisecondsSinceEpoch(startDateEpoch),
      endDate: DateTime.fromMillisecondsSinceEpoch(endDateEpoch),
      setupDate: setupDateEpoch != null
          ? DateTime.fromMillisecondsSinceEpoch(setupDateEpoch!)
          : null,
      closingDate: closingDateEpoch != null
          ? DateTime.fromMillisecondsSinceEpoch(closingDateEpoch!)
          : null,
      estimatedBudgetPaise: estimatedBudgetPaise,
      initialInvestmentPaise: initialInvestmentPaise,
      currency: currency,
      partnerCount: partnerCount,
      partnershipType: partnershipType,
      initialPartnerSetup: initialPartnerSetup,
      description: description,
      operationalNotes: operationalNotes,
      isDraft: isDraft,
      isArchived: isArchived,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtEpoch),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAtEpoch),
    );
  }
}

/// Binary serializer and deserializer for [BookFairModel] without code-generation fragility.
class BookFairAdapter extends TypeAdapter<BookFairModel> {
  @override
  final int typeId = DatabaseConstants.bookFairTypeId;

  @override
  BookFairModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BookFairModel(
      id: fields[0] as String,
      name: fields[1] as String,
      location: fields[2] as String,
      city: fields[3] as String? ?? '',
      state: fields[4] as String? ?? '',
      startDateEpoch: fields[5] as int,
      endDateEpoch: fields[6] as int,
      setupDateEpoch: fields[7] as int?,
      closingDateEpoch: fields[8] as int?,
      estimatedBudgetPaise: fields[9] as int? ?? 0,
      initialInvestmentPaise: fields[10] as int? ?? 0,
      currency: fields[11] as String? ?? 'INR',
      partnerCount: fields[12] as int? ?? 1,
      partnershipType: fields[13] as String? ?? 'Sole Proprietorship',
      initialPartnerSetup: fields[14] as String? ?? '',
      description: fields[15] as String? ?? '',
      operationalNotes: fields[16] as String? ?? '',
      isDraft: fields[17] as bool? ?? false,
      isArchived: fields[18] as bool? ?? false,
      createdAtEpoch: fields[19] as int,
      updatedAtEpoch: fields[20] as int? ?? fields[19] as int,
    );
  }

  @override
  void write(BinaryWriter writer, BookFairModel obj) {
    writer
      ..writeByte(21)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.location)
      ..writeByte(3)
      ..write(obj.city)
      ..writeByte(4)
      ..write(obj.state)
      ..writeByte(5)
      ..write(obj.startDateEpoch)
      ..writeByte(6)
      ..write(obj.endDateEpoch)
      ..writeByte(7)
      ..write(obj.setupDateEpoch)
      ..writeByte(8)
      ..write(obj.closingDateEpoch)
      ..writeByte(9)
      ..write(obj.estimatedBudgetPaise)
      ..writeByte(10)
      ..write(obj.initialInvestmentPaise)
      ..writeByte(11)
      ..write(obj.currency)
      ..writeByte(12)
      ..write(obj.partnerCount)
      ..writeByte(13)
      ..write(obj.partnershipType)
      ..writeByte(14)
      ..write(obj.initialPartnerSetup)
      ..writeByte(15)
      ..write(obj.description)
      ..writeByte(16)
      ..write(obj.operationalNotes)
      ..writeByte(17)
      ..write(obj.isDraft)
      ..writeByte(18)
      ..write(obj.isArchived)
      ..writeByte(19)
      ..write(obj.createdAtEpoch)
      ..writeByte(20)
      ..write(obj.updatedAtEpoch);
  }
}
