import '../entities/activity_item.dart';
import '../entities/dashboard_summary.dart';

/// Abstract domain repository interface for dashboard business metrics.
///
/// Designed to be implemented by [MockDashboardRepository] in Stage 01,
/// and backed by local Hive storage in subsequent stages.
abstract interface class DashboardRepository {
  Future<DashboardSummary> getSummary();
  Future<List<ActivityItem>> getRecentActivities();
}
