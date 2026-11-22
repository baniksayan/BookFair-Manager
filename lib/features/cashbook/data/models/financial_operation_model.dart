import 'dart:convert';

import 'package:hive/hive.dart';

import '../../../../core/database/database_constants.dart';

/// Hive database model representing a write-ahead financial journal entry (TypeId 14).
class FinancialOperationModel extends HiveObject {
  FinancialOperationModel({
    required this.id,
    required this.fairId,
    required this.idempotencyKey,
    required this.requestFingerprint,
    required this.operationType,
    required this.status,
    required this.amountPaise,
    required this.primaryEntityId,
    this.secondaryEntityId,
    this.sourceAccountId,
    this.targetAccountId,
    required this.payloadJson,
    this.attemptNumber = 1,
    this.parentOperationId,
    required this.createdAtEpoch,
    required this.updatedAtEpoch,
  });

  final String id;
  final String fairId;
  final String idempotencyKey;
  final String requestFingerprint;
  final String operationType;
  final String status;
  final int amountPaise;
  final String primaryEntityId;
  final String? secondaryEntityId;
  final String? sourceAccountId;
  final String? targetAccountId;
  final String payloadJson;
  final int attemptNumber;
  final String? parentOperationId;
  final int createdAtEpoch;
  final int updatedAtEpoch;

  Map<String, dynamic> get payload {
    try {
      return jsonDecode(payloadJson) as Map<String, dynamic>;
    } catch (_) {
      return const {};
    }
  }

  bool get isPrepared => status == 'prepared';
  bool get isProcessing => status == 'processing';
  bool get isCommitted => status == 'committed';
  bool get isRolledBack => status == 'rolled_back';
  bool get isRecoveryFailed => status == 'recovery_failed';

  FinancialOperationModel copyWith({
    String? id,
    String? fairId,
    String? idempotencyKey,
    String? requestFingerprint,
    String? operationType,
    String? status,
    int? amountPaise,
    String? primaryEntityId,
    String? secondaryEntityId,
    String? sourceAccountId,
    String? targetAccountId,
    String? payloadJson,
    int? attemptNumber,
    String? parentOperationId,
    int? createdAtEpoch,
    int? updatedAtEpoch,
  }) {
    return FinancialOperationModel(
      id: id ?? this.id,
      fairId: fairId ?? this.fairId,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      requestFingerprint: requestFingerprint ?? this.requestFingerprint,
      operationType: operationType ?? this.operationType,
      status: status ?? this.status,
      amountPaise: amountPaise ?? this.amountPaise,
      primaryEntityId: primaryEntityId ?? this.primaryEntityId,
      secondaryEntityId: secondaryEntityId ?? this.secondaryEntityId,
      sourceAccountId: sourceAccountId ?? this.sourceAccountId,
      targetAccountId: targetAccountId ?? this.targetAccountId,
      payloadJson: payloadJson ?? this.payloadJson,
      attemptNumber: attemptNumber ?? this.attemptNumber,
      parentOperationId: parentOperationId ?? this.parentOperationId,
      createdAtEpoch: createdAtEpoch ?? this.createdAtEpoch,
      updatedAtEpoch: updatedAtEpoch ?? this.updatedAtEpoch,
    );
  }
}

/// Manual binary serializer for [FinancialOperationModel] avoiding build_runner fragility.
class FinancialOperationAdapter extends TypeAdapter<FinancialOperationModel> {
  @override
  final int typeId = DatabaseConstants.financialOperationTypeId;

  @override
  FinancialOperationModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    return FinancialOperationModel(
      id: fields[0] as String,
      fairId: fields[1] as String,
      idempotencyKey: fields[2] as String,
      requestFingerprint: fields[3] as String,
      operationType: fields[4] as String,
      status: fields[5] as String,
      amountPaise: fields[6] as int,
      primaryEntityId: fields[7] as String,
      secondaryEntityId: fields[8] as String?,
      sourceAccountId: fields[9] as String?,
      targetAccountId: fields[10] as String?,
      payloadJson: fields[11] as String,
      attemptNumber: fields[12] as int? ?? 1,
      parentOperationId: fields[13] as String?,
      createdAtEpoch: fields[14] as int,
      updatedAtEpoch: fields[15] as int,
    );
  }

  @override
  void write(BinaryWriter writer, FinancialOperationModel obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.fairId)
      ..writeByte(2)
      ..write(obj.idempotencyKey)
      ..writeByte(3)
      ..write(obj.requestFingerprint)
      ..writeByte(4)
      ..write(obj.operationType)
      ..writeByte(5)
      ..write(obj.status)
      ..writeByte(6)
      ..write(obj.amountPaise)
      ..writeByte(7)
      ..write(obj.primaryEntityId)
      ..writeByte(8)
      ..write(obj.secondaryEntityId)
      ..writeByte(9)
      ..write(obj.sourceAccountId)
      ..writeByte(10)
      ..write(obj.targetAccountId)
      ..writeByte(11)
      ..write(obj.payloadJson)
      ..writeByte(12)
      ..write(obj.attemptNumber)
      ..writeByte(13)
      ..write(obj.parentOperationId)
      ..writeByte(14)
      ..write(obj.createdAtEpoch)
      ..writeByte(15)
      ..write(obj.updatedAtEpoch);
  }
}
