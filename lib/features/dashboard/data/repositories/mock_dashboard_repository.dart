import '../../../../core/localization/app_strings.dart';
import '../../domain/entities/activity_item.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/repositories/dashboard_repository.dart';

/// In-memory mock implementation of [DashboardRepository] for Stage 01.
class MockDashboardRepository implements DashboardRepository {
  const MockDashboardRepository();

  @override
  Future<DashboardSummary> getSummary() async {
    // Stage 01 offline instant sample data
    return const DashboardSummary(
      totalFairs: 1,
      activeFairs: 1,
      upcomingFairs: 0,
      totalRecordedInvestment: 185000.0,
      partnerCount: 3,
      isSampleData: true,
    );
  }

  @override
  Future<List<ActivityItem>> getRecentActivities() async {
    return const [
      ActivityItem(
        id: 'act-001',
        title: AppStrings.act1Title,
        timestamp: AppStrings.act1Time,
        amount: AppStrings.act1Amount,
        subtitle: AppStrings.act1Subtitle,
        type: ActivityType.inventoryBatch,
      ),
      ActivityItem(
        id: 'act-002',
        title: AppStrings.act2Title,
        timestamp: AppStrings.act2Time,
        amount: AppStrings.act2Amount,
        subtitle: AppStrings.act2Subtitle,
        type: ActivityType.expense,
      ),
      ActivityItem(
        id: 'act-003',
        title: AppStrings.act3Title,
        timestamp: AppStrings.act3Time,
        amount: AppStrings.act3Amount,
        subtitle: AppStrings.act3Subtitle,
        type: ActivityType.partnerContribution,
      ),
      ActivityItem(
        id: 'act-004',
        title: AppStrings.act4Title,
        timestamp: AppStrings.act4Time,
        amount: AppStrings.act4Amount,
        subtitle: AppStrings.act4Subtitle,
        type: ActivityType.sale,
      ),
    ];
  }
}
