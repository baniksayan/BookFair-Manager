import 'dart:async';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_constants.dart';
import '../../../../core/database/database_exceptions.dart';
import '../models/activity_log_model.dart';
import '../models/book_fair_model.dart';
import '../models/investment_model.dart';
import '../models/partner_model.dart';

/// Local data source executing direct CRUD and streaming queries on Hive storage boxes.
abstract interface class BookFairLocalDataSource {
  // Book Fair operations
  Future<List<BookFairModel>> getAllBookFairs();
  Future<BookFairModel?> getBookFairById(String id);
  Future<void> createBookFair(BookFairModel model);
  Future<void> updateBookFair(BookFairModel model);
  Future<void> deleteBookFair(String id);
  Stream<List<BookFairModel>> watchBookFairs();

  // Partner operations
  Future<List<PartnerModel>> getPartnersForFair(String fairId);
  Future<PartnerModel?> getPartnerById(String id);
  Future<void> createPartner(PartnerModel model);
  Future<void> updatePartner(PartnerModel model);
  Future<void> deletePartner(String id, {bool force = false});
  Stream<List<PartnerModel>> watchPartnersForFair(String fairId);

  // Investment operations
  Future<List<InvestmentModel>> getInvestmentsForFair(String fairId);
  Future<List<InvestmentModel>> getInvestmentsForPartner(
    String fairId,
    String partnerId,
  );
  Future<InvestmentModel?> getInvestmentById(String id);
  Future<void> createInvestment(InvestmentModel model);
  Future<void> updateInvestment(InvestmentModel model);
  Future<void> deleteInvestment(String id);
  Stream<List<InvestmentModel>> watchInvestmentsForFair(String fairId);

  // Activity Log operations
  Future<List<ActivityLogModel>> getActivityLogs({int limit = 10});
  Future<void> logActivity(ActivityLogModel model);
  Stream<List<ActivityLogModel>> watchActivityLogs();

  // Draft operations
  Future<void> saveDraft(BookFairModel model);
  Future<BookFairModel?> getDraft();
  Future<void> clearDraft();
}

class BookFairLocalDataSourceImpl implements BookFairLocalDataSource {
  BookFairLocalDataSourceImpl(this._db);

  final AppDatabase _db;

  // --- Book Fair Operations ---

  @override
  Future<List<BookFairModel>> getAllBookFairs() async {
    return _db.bookFairs.values.toList();
  }

  @override
  Future<BookFairModel?> getBookFairById(String id) async {
    return _db.bookFairs.get(id);
  }

  @override
  Future<void> createBookFair(BookFairModel model) async {
    await _db.bookFairs.put(model.id, model);
  }

  @override
  Future<void> updateBookFair(BookFairModel model) async {
    if (!_db.bookFairs.containsKey(model.id)) {
      throw RecordNotFoundException('BookFair', model.id);
    }
    await _db.bookFairs.put(model.id, model);
  }

  @override
  Future<void> deleteBookFair(String id) async {
    if (!_db.bookFairs.containsKey(id)) {
      throw RecordNotFoundException('BookFair', id);
    }

    // Cascade deletion: Clean up related partners and investments to maintain referential integrity
    final partnerKeys = _db.partners.values
        .where((p) => p.fairId == id)
        .map((p) => p.id)
        .toList();
    for (final pId in partnerKeys) {
      await _db.partners.delete(pId);
    }

    final investmentKeys = _db.investments.values
        .where((inv) => inv.fairId == id)
        .map((inv) => inv.id)
        .toList();
    for (final invId in investmentKeys) {
      await _db.investments.delete(invId);
    }

    await _db.bookFairs.delete(id);
  }

  @override
  Stream<List<BookFairModel>> watchBookFairs() {
    // Emits initial state, then watches for updates
    final controller = StreamController<List<BookFairModel>>();
    controller.add(_db.bookFairs.values.toList());

    final sub = _db.bookFairs.watch().listen((_) {
      if (!controller.isClosed) {
        controller.add(_db.bookFairs.values.toList());
      }
    });

    controller.onCancel = () => sub.cancel();
    return controller.stream;
  }

  // --- Partner Operations ---

  @override
  Future<List<PartnerModel>> getPartnersForFair(String fairId) async {
    return _db.partners.values
        .where((p) => p.fairId == fairId && p.isActive)
        .toList();
  }

  @override
  Future<PartnerModel?> getPartnerById(String id) async {
    return _db.partners.get(id);
  }

  @override
  Future<void> createPartner(PartnerModel model) async {
    // Check for duplicate name in the same fair
    final existing = _db.partners.values.any(
      (p) =>
          p.fairId == model.fairId &&
          p.isActive &&
          p.fullName.trim().toLowerCase() ==
              model.fullName.trim().toLowerCase(),
    );
    if (existing) {
      throw DuplicateRecordException(
        'A partner named "${model.fullName}" is already registered for this book fair.',
      );
    }
    await _db.partners.put(model.id, model);
  }

  @override
  Future<void> updatePartner(PartnerModel model) async {
    if (!_db.partners.containsKey(model.id)) {
      throw RecordNotFoundException('Partner', model.id);
    }
    await _db.partners.put(model.id, model);
  }

  @override
  Future<void> deletePartner(String id, {bool force = false}) async {
    final partner = _db.partners.get(id);
    if (partner == null) {
      throw RecordNotFoundException('Partner', id);
    }

    // Check if partner has recorded investments
    final hasInvestments = _db.investments.values.any(
      (inv) => inv.partnerId == id,
    );
    if (hasInvestments && !force) {
      throw ReferentialIntegrityException(
        'Cannot remove partner "${partner.fullName}" because active financial contributions are registered to their account. Please reassign or remove their investments first.',
      );
    }

    if (force) {
      // Remove all investments by this partner
      final relatedInv = _db.investments.values
          .where((inv) => inv.partnerId == id)
          .map((inv) => inv.id)
          .toList();
      for (final invId in relatedInv) {
        await _db.investments.delete(invId);
      }
    }

    await _db.partners.delete(id);
  }

  @override
  Stream<List<PartnerModel>> watchPartnersForFair(String fairId) {
    final controller = StreamController<List<PartnerModel>>();
    controller.add(
      _db.partners.values
          .where((p) => p.fairId == fairId && p.isActive)
          .toList(),
    );

    final sub = _db.partners.watch().listen((_) {
      if (!controller.isClosed) {
        controller.add(
          _db.partners.values
              .where((p) => p.fairId == fairId && p.isActive)
              .toList(),
        );
      }
    });

    controller.onCancel = () => sub.cancel();
    return controller.stream;
  }

  // --- Investment Operations ---

  @override
  Future<List<InvestmentModel>> getInvestmentsForFair(String fairId) async {
    return _db.investments.values.where((inv) => inv.fairId == fairId).toList();
  }

  @override
  Future<List<InvestmentModel>> getInvestmentsForPartner(
    String fairId,
    String partnerId,
  ) async {
    return _db.investments.values
        .where((inv) => inv.fairId == fairId && inv.partnerId == partnerId)
        .toList();
  }

  @override
  Future<InvestmentModel?> getInvestmentById(String id) async {
    return _db.investments.get(id);
  }

  @override
  Future<void> createInvestment(InvestmentModel model) async {
    // Validate partner exists
    if (!_db.partners.containsKey(model.partnerId)) {
      throw ReferentialIntegrityException(
        'Referenced partner "${model.partnerId}" does not exist.',
      );
    }
    await _db.investments.put(model.id, model);
  }

  @override
  Future<void> updateInvestment(InvestmentModel model) async {
    if (!_db.investments.containsKey(model.id)) {
      throw RecordNotFoundException('Investment', model.id);
    }
    await _db.investments.put(model.id, model);
  }

  @override
  Future<void> deleteInvestment(String id) async {
    if (!_db.investments.containsKey(id)) {
      throw RecordNotFoundException('Investment', id);
    }
    await _db.investments.delete(id);
  }

  @override
  Stream<List<InvestmentModel>> watchInvestmentsForFair(String fairId) {
    final controller = StreamController<List<InvestmentModel>>();
    controller.add(
      _db.investments.values.where((inv) => inv.fairId == fairId).toList(),
    );

    final sub = _db.investments.watch().listen((_) {
      if (!controller.isClosed) {
        controller.add(
          _db.investments.values.where((inv) => inv.fairId == fairId).toList(),
        );
      }
    });

    controller.onCancel = () => sub.cancel();
    return controller.stream;
  }

  // --- Activity Log Operations ---

  @override
  Future<List<ActivityLogModel>> getActivityLogs({int limit = 10}) async {
    final all = _db.activityLogs.values.toList()
      ..sort((a, b) => b.timestampEpoch.compareTo(a.timestampEpoch));
    return all.take(limit).toList();
  }

  @override
  Future<void> logActivity(ActivityLogModel model) async {
    await _db.activityLogs.put(model.id, model);
  }

  @override
  Stream<List<ActivityLogModel>> watchActivityLogs() {
    final controller = StreamController<List<ActivityLogModel>>();
    controller.add(
      _db.activityLogs.values.toList()
        ..sort((a, b) => b.timestampEpoch.compareTo(a.timestampEpoch)),
    );

    final sub = _db.activityLogs.watch().listen((_) {
      if (!controller.isClosed) {
        final sorted = _db.activityLogs.values.toList()
          ..sort((a, b) => b.timestampEpoch.compareTo(a.timestampEpoch));
        controller.add(sorted);
      }
    });

    controller.onCancel = () => sub.cancel();
    return controller.stream;
  }

  // --- Draft Operations ---

  @override
  Future<void> saveDraft(BookFairModel model) async {
    await _db.metadata.put(DatabaseConstants.draftFairKey, model);
  }

  @override
  Future<BookFairModel?> getDraft() async {
    final draft = _db.metadata.get(DatabaseConstants.draftFairKey);
    return draft is BookFairModel ? draft : null;
  }

  @override
  Future<void> clearDraft() async {
    await _db.metadata.delete(DatabaseConstants.draftFairKey);
  }
}
