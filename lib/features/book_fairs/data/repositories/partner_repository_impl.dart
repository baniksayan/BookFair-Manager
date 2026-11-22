import 'package:uuid/uuid.dart';

import '../../domain/entities/activity_log.dart';
import '../../domain/entities/partner.dart';
import '../../domain/repositories/activity_log_repository.dart';
import '../../domain/repositories/partner_repository.dart';
import '../datasources/book_fair_local_datasource.dart';
import '../models/partner_model.dart';

/// Concrete implementation of [PartnerRepository] backed by Hive local storage.
class PartnerRepositoryImpl implements PartnerRepository {
  PartnerRepositoryImpl(this._dataSource, this._activityLogRepo);

  final BookFairLocalDataSource _dataSource;
  final ActivityLogRepository _activityLogRepo;
  final _uuid = const Uuid();

  @override
  Future<List<Partner>> getPartnersForFair(String fairId) async {
    final models = await _dataSource.getPartnersForFair(fairId);
    final entities = models.map((m) => m.toEntity()).toList()
      ..sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
    return entities;
  }

  @override
  Future<Partner?> getPartnerById(String id) async {
    final model = await _dataSource.getPartnerById(id);
    return model?.toEntity();
  }

  @override
  Future<void> addPartner(Partner partner) async {
    final model = PartnerModel.fromEntity(partner);
    await _dataSource.createPartner(model);

    await _activityLogRepo.logEvent(
      ActivityLog(
        id: _uuid.v4(),
        fairId: partner.fairId,
        title: 'Partner Joined Stall',
        subtitle: '${partner.fullName} (${partner.role.displayName})',
        amount: partner.profitSharingPercentage != null
            ? '${partner.profitSharingPercentage}% Equity'
            : partner.role.displayName,
        type: ActivityLogType.partnerAdded,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> updatePartner(Partner partner) async {
    final updated = partner.copyWith(updatedAt: DateTime.now());
    await _dataSource.updatePartner(PartnerModel.fromEntity(updated));
  }

  @override
  Future<void> deletePartner(String id, {bool force = false}) async {
    await _dataSource.deletePartner(id, force: force);
  }

  @override
  Stream<List<Partner>> watchPartnersForFair(String fairId) {
    return _dataSource.watchPartnersForFair(fairId).map((models) {
      final list = models.map((m) => m.toEntity()).toList()
        ..sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
      return list;
    });
  }
}
