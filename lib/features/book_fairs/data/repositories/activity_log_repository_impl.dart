import '../../domain/entities/activity_log.dart';
import '../../domain/repositories/activity_log_repository.dart';
import '../datasources/book_fair_local_datasource.dart';
import '../models/activity_log_model.dart';

/// Concrete implementation of [ActivityLogRepository] backed by Hive local storage.
class ActivityLogRepositoryImpl implements ActivityLogRepository {
  ActivityLogRepositoryImpl(this._dataSource);

  final BookFairLocalDataSource _dataSource;

  @override
  Future<List<ActivityLog>> getRecentLogs({int limit = 10}) async {
    final models = await _dataSource.getActivityLogs(limit: limit);
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<void> logEvent(ActivityLog log) async {
    await _dataSource.logActivity(ActivityLogModel.fromEntity(log));
  }

  @override
  Stream<List<ActivityLog>> watchRecentLogs({int limit = 10}) {
    return _dataSource.watchActivityLogs().map((models) {
      return models.take(limit).map((m) => m.toEntity()).toList();
    });
  }
}
