import '../entities/activity_log.dart';

/// Abstract domain repository interface for system ledger audit trails.
abstract interface class ActivityLogRepository {
  Future<List<ActivityLog>> getRecentLogs({int limit = 10});
  Future<void> logEvent(ActivityLog log);
  Stream<List<ActivityLog>> watchRecentLogs({int limit = 10});
}
