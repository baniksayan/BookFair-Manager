import 'package:hive/hive.dart';

import '../../../../core/database/database_constants.dart';
import '../../domain/entities/book.dart';

/// Hive database storage model for [Book].
class BookModel extends HiveObject {
  BookModel({
    required this.id,
    required this.fairId,
    required this.title,
    this.subtitle,
    required this.author,
    this.additionalAuthors = const [],
    required this.publisher,
    this.isbn10,
    this.isbn13,
    required this.genre,
    required this.language,
    required this.description,
    this.coverImagePath,
    this.coverImageSource,
    required this.mrpPaise,
    required this.defaultSellingPricePaise,
    required this.condition,
    required this.conditionNotes,
    required this.isPreviousStock,
    required this.openingStockQuantity,
    this.estimatedCostPaise,
    required this.isActive,
    required this.createdAtEpoch,
    required this.updatedAtEpoch,
  });

  factory BookModel.fromEntity(Book entity) {
    return BookModel(
      id: entity.id,
      fairId: entity.fairId,
      title: entity.title,
      subtitle: entity.subtitle,
      author: entity.author,
      additionalAuthors: entity.additionalAuthors,
      publisher: entity.publisher,
      isbn10: entity.isbn10,
      isbn13: entity.isbn13,
      genre: entity.genre,
      language: entity.language,
      description: entity.description,
      coverImagePath: entity.coverImagePath,
      coverImageSource: entity.coverImageSource,
      mrpPaise: entity.mrpPaise,
      defaultSellingPricePaise: entity.defaultSellingPricePaise,
      condition: entity.condition.name,
      conditionNotes: entity.conditionNotes,
      isPreviousStock: entity.isPreviousStock,
      openingStockQuantity: entity.openingStockQuantity,
      estimatedCostPaise: entity.estimatedCostPaise,
      isActive: entity.isActive,
      createdAtEpoch: entity.createdAt.millisecondsSinceEpoch,
      updatedAtEpoch: entity.updatedAt.millisecondsSinceEpoch,
    );
  }

  final String id;
  final String fairId;
  final String title;
  final String? subtitle;
  final String author;
  final List<String> additionalAuthors;
  final String publisher;
  final String? isbn10;
  final String? isbn13;
  final String genre;
  final String language;
  final String description;
  final String? coverImagePath;
  final String? coverImageSource;
  final int mrpPaise;
  final int defaultSellingPricePaise;
  final String condition;
  final String conditionNotes;
  final bool isPreviousStock;
  final int openingStockQuantity;
  final int? estimatedCostPaise;
  final bool isActive;
  final int createdAtEpoch;
  final int updatedAtEpoch;

  Book toEntity() {
    return Book(
      id: id,
      fairId: fairId,
      title: title,
      subtitle: subtitle,
      author: author,
      additionalAuthors: additionalAuthors,
      publisher: publisher,
      isbn10: isbn10,
      isbn13: isbn13,
      genre: genre,
      language: language,
      description: description,
      coverImagePath: coverImagePath,
      coverImageSource: coverImageSource,
      mrpPaise: mrpPaise,
      defaultSellingPricePaise: defaultSellingPricePaise,
      condition: BookCondition.fromString(condition),
      conditionNotes: conditionNotes,
      isPreviousStock: isPreviousStock,
      openingStockQuantity: openingStockQuantity,
      estimatedCostPaise: estimatedCostPaise,
      isActive: isActive,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtEpoch),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAtEpoch),
    );
  }
}

/// Binary serializer and deserializer for [BookModel] without code generation.
class BookAdapter extends TypeAdapter<BookModel> {
  @override
  final int typeId = DatabaseConstants.bookTypeId;

  @override
  BookModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BookModel(
      id: fields[0] as String,
      fairId: fields[1] as String,
      title: fields[2] as String,
      subtitle: fields[3] as String?,
      author: fields[4] as String,
      additionalAuthors: (fields[5] as List<dynamic>?)?.cast<String>() ?? [],
      publisher: fields[6] as String? ?? '',
      isbn10: fields[7] as String?,
      isbn13: fields[8] as String?,
      genre: fields[9] as String? ?? 'General',
      language: fields[10] as String? ?? 'English',
      description: fields[11] as String? ?? '',
      coverImagePath: fields[12] as String?,
      coverImageSource: fields[13] as String?,
      mrpPaise: fields[14] as int? ?? 0,
      defaultSellingPricePaise: fields[15] as int? ?? 0,
      condition: fields[16] as String? ?? 'brandNew',
      conditionNotes: fields[17] as String? ?? '',
      isPreviousStock: fields[18] as bool? ?? false,
      openingStockQuantity: fields[19] as int? ?? 0,
      estimatedCostPaise: fields[20] as int?,
      isActive: fields[21] as bool? ?? true,
      createdAtEpoch: fields[22] as int,
      updatedAtEpoch: fields[23] as int? ?? fields[22] as int,
    );
  }

  @override
  void write(BinaryWriter writer, BookModel obj) {
    writer
      ..writeByte(24)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.fairId)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.subtitle)
      ..writeByte(4)
      ..write(obj.author)
      ..writeByte(5)
      ..write(obj.additionalAuthors)
      ..writeByte(6)
      ..write(obj.publisher)
      ..writeByte(7)
      ..write(obj.isbn10)
      ..writeByte(8)
      ..write(obj.isbn13)
      ..writeByte(9)
      ..write(obj.genre)
      ..writeByte(10)
      ..write(obj.language)
      ..writeByte(11)
      ..write(obj.description)
      ..writeByte(12)
      ..write(obj.coverImagePath)
      ..writeByte(13)
      ..write(obj.coverImageSource)
      ..writeByte(14)
      ..write(obj.mrpPaise)
      ..writeByte(15)
      ..write(obj.defaultSellingPricePaise)
      ..writeByte(16)
      ..write(obj.condition)
      ..writeByte(17)
      ..write(obj.conditionNotes)
      ..writeByte(18)
      ..write(obj.isPreviousStock)
      ..writeByte(19)
      ..write(obj.openingStockQuantity)
      ..writeByte(20)
      ..write(obj.estimatedCostPaise)
      ..writeByte(21)
      ..write(obj.isActive)
      ..writeByte(22)
      ..write(obj.createdAtEpoch)
      ..writeByte(23)
      ..write(obj.updatedAtEpoch);
  }
}
