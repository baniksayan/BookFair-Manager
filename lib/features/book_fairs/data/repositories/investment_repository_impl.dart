import 'package:uuid/uuid.dart';

import '../../../../core/database/database_exceptions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/activity_log.dart';
import '../../domain/entities/investment.dart';
import '../../domain/repositories/activity_log_repository.dart';
import '../../domain/repositories/investment_repository.dart';
import '../datasources/book_fair_local_datasource.dart';
import '../models/investment_model.dart';

/// Concrete implementation of [InvestmentRepository] backed by Hive local storage.
class InvestmentRepositoryImpl implements InvestmentRepository {
  InvestmentRepositoryImpl(this._dataSource, this._activityLogRepo);

  final BookFairLocalDataSource _dataSource;
  final ActivityLogRepository _activityLogRepo;
  final _uuid = const Uuid();

  @override
  Future<List<Investment>> getInvestmentsForFair(String fairId) async {
    final models = await _dataSource.getInvestmentsForFair(fairId);
    final entities = models.map((m) => m.toEntity()).toList()
      ..sort((a, b) => b.contributionDate.compareTo(a.contributionDate));
    return entities;
  }

  @override
  Future<List<Investment>> getInvestmentsForPartner(
    String fairId,
    String partnerId,
  ) async {
    final models = await _dataSource.getInvestmentsForPartner(
      fairId,
      partnerId,
    );
    final entities = models.map((m) => m.toEntity()).toList()
      ..sort((a, b) => b.contributionDate.compareTo(a.contributionDate));
    return entities;
  }

  @override
  Future<Investment?> getInvestmentById(String id) async {
    final model = await _dataSource.getInvestmentById(id);
    return model?.toEntity();
  }

  @override
  Future<void> addInvestment(Investment investment) async {
    if (investment.amountPaise <= 0) {
      throw const ValidationException(
        'Investment amount must be greater than zero',
      );
    }

    final model = InvestmentModel.fromEntity(investment);
    await _dataSource.createInvestment(model);

    // Fetch partner name for rich audit log
    final partner = await _dataSource.getPartnerById(investment.partnerId);
    final partnerName = partner?.fullName ?? 'Partner';

    await _activityLogRepo.logEvent(
      ActivityLog(
        id: _uuid.v4(),
        fairId: investment.fairId,
        title: 'Capital Contribution Recorded',
        subtitle: '$partnerName (${investment.contributionType.displayName})',
        amount: '+${CurrencyFormatter.format(investment.amount)}',
        type: ActivityLogType.investmentRecorded,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> updateInvestment(Investment investment) async {
    if (investment.amountPaise <= 0) {
      throw const ValidationException(
        'Investment amount must be greater than zero',
      );
    }

    final updated = investment.copyWith(updatedAt: DateTime.now());
    await _dataSource.updateInvestment(InvestmentModel.fromEntity(updated));
  }

  @override
  Future<void> deleteInvestment(String id) async {
    await _dataSource.deleteInvestment(id);
  }

  @override
  Stream<List<Investment>> watchInvestmentsForFair(String fairId) {
    return _dataSource.watchInvestmentsForFair(fairId).map((models) {
      final list = models.map((m) => m.toEntity()).toList()
        ..sort((a, b) => b.contributionDate.compareTo(a.contributionDate));
      return list;
    });
  }
}
