import 'package:hive/hive.dart';

import '../../../../core/database/database_constants.dart';
import '../../domain/entities/activity_log.dart';

/// Hive database storage model for [ActivityLog].
class ActivityLogModel extends HiveObject {
  ActivityLogModel({
    required this.id,
    this.fairId,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.type,
    required this.timestampEpoch,
  });

  factory ActivityLogModel.fromEntity(ActivityLog entity) {
    return ActivityLogModel(
      id: entity.id,
      fairId: entity.fairId,
      title: entity.title,
      subtitle: entity.subtitle,
      amount: entity.amount,
      type: entity.type.name,
      timestampEpoch: entity.timestamp.millisecondsSinceEpoch,
    );
  }

  final String id;
  final String? fairId;
  final String title;
  final String subtitle;
  final String amount;
  final String type;
  final int timestampEpoch;

  ActivityLog toEntity() {
    return ActivityLog(
      id: id,
      fairId: fairId,
      title: title,
      subtitle: subtitle,
      amount: amount,
      type: ActivityLogType.fromString(type),
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestampEpoch),
    );
  }
}

/// Binary serializer and deserializer for [ActivityLogModel].
class ActivityLogAdapter extends TypeAdapter<ActivityLogModel> {
  @override
  final int typeId = DatabaseConstants.activityLogTypeId;

  @override
  ActivityLogModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ActivityLogModel(
      id: fields[0] as String,
      fairId: fields[1] as String?,
      title: fields[2] as String,
      subtitle: fields[3] as String? ?? '',
      amount: fields[4] as String? ?? '',
      type: fields[5] as String? ?? 'investmentRecorded',
      timestampEpoch: fields[6] as int,
    );
  }

  @override
  void write(BinaryWriter writer, ActivityLogModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.fairId)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.subtitle)
      ..writeByte(4)
      ..write(obj.amount)
      ..writeByte(5)
      ..write(obj.type)
      ..writeByte(6)
      ..write(obj.timestampEpoch);
  }
}
