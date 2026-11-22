import 'package:uuid/uuid.dart';

import '../database/app_database.dart';

/// Centralized manager for persistent draft identifiers and client request IDs.
///
/// Ensures financial operations retain a stable `clientRequestId` in Hive
/// [metadataBox] that survives app crashes, restarts, and ViewModel disposals.
abstract final class FinancialDraftManager {
  static const _uuid = Uuid();

  /// Retrieves an existing persistent `clientRequestId` or generates and stores a new one.
  static String getOrCreateClientRequestId({
    required String operationType,
    required String entityId,
  }) {
    final keySuffix = entityId.trim().isNotEmpty ? entityId.trim() : 'default';
    final draftKey = 'draft_${operationType}_$keySuffix';
    final metadataBox = const AppDatabase().metadata;
    final existingDraft = metadataBox.get(draftKey);

    if (existingDraft is Map && existingDraft['clientRequestId'] is String) {
      return existingDraft['clientRequestId'] as String;
    }

    final newId = _uuid.v4();
    metadataBox.put(draftKey, {
      'clientRequestId': newId,
      'createdAtEpoch': DateTime.now().millisecondsSinceEpoch,
    });
    return newId;
  }

  /// Removes the persistent draft entry upon successful transaction commit.
  static Future<void> clearDraft({
    required String operationType,
    required String entityId,
  }) async {
    final keySuffix = entityId.trim().isNotEmpty ? entityId.trim() : 'default';
    final draftKey = 'draft_${operationType}_$keySuffix';
    await const AppDatabase().metadata.delete(draftKey);
  }
}
