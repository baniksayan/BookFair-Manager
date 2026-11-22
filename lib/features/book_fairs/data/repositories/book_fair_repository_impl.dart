import 'package:uuid/uuid.dart';

import '../../domain/entities/activity_log.dart';
import '../../domain/entities/book_fair.dart';
import '../../domain/repositories/activity_log_repository.dart';
import '../../domain/repositories/book_fair_repository.dart';
import '../datasources/book_fair_local_datasource.dart';
import '../models/book_fair_model.dart';

/// Concrete implementation of [BookFairRepository] backed by Hive local storage.
class BookFairRepositoryImpl implements BookFairRepository {
  BookFairRepositoryImpl(this._dataSource, this._activityLogRepo);

  final BookFairLocalDataSource _dataSource;
  final ActivityLogRepository _activityLogRepo;
  final _uuid = const Uuid();

  @override
  Future<List<BookFair>> getAllBookFairs() async {
    final models = await _dataSource.getAllBookFairs();
    final entities = models.map((m) => m.toEntity()).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entities;
  }

  @override
  Future<BookFair?> getBookFairById(String id) async {
    final model = await _dataSource.getBookFairById(id);
    return model?.toEntity();
  }

  @override
  Future<void> createBookFair(BookFair bookFair) async {
    final model = BookFairModel.fromEntity(bookFair);
    await _dataSource.createBookFair(model);

    // Record persistent activity log
    await _activityLogRepo.logEvent(
      ActivityLog(
        id: _uuid.v4(),
        fairId: bookFair.id,
        title: 'New Book Fair Created',
        subtitle: '${bookFair.name} (${bookFair.location})',
        amount: bookFair.currency == 'INR'
            ? '₹ ${bookFair.estimatedBudget.toInt()}'
            : '${bookFair.estimatedBudget.toInt()}',
        type: ActivityLogType.fairCreated,
        timestamp: DateTime.now(),
      ),
    );

    // If an in-memory or persisted draft matches, clear it
    final draft = await _dataSource.getDraft();
    if (draft != null &&
        (draft.id == bookFair.id || draft.name == bookFair.name)) {
      await _dataSource.clearDraft();
    }
  }

  @override
  Future<void> updateBookFair(BookFair bookFair) async {
    final updated = bookFair.copyWith(updatedAt: DateTime.now());
    final model = BookFairModel.fromEntity(updated);
    await _dataSource.updateBookFair(model);

    await _activityLogRepo.logEvent(
      ActivityLog(
        id: _uuid.v4(),
        fairId: bookFair.id,
        title: 'Book Fair Updated',
        subtitle: '${bookFair.name} specifications updated',
        amount: '₹ ${bookFair.estimatedBudget.toInt()}',
        type: ActivityLogType.fairUpdated,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> deleteBookFair(String id) async {
    final fair = await getBookFairById(id);
    await _dataSource.deleteBookFair(id);

    if (fair != null) {
      await _activityLogRepo.logEvent(
        ActivityLog(
          id: _uuid.v4(),
          fairId: id,
          title: 'Book Fair Removed',
          subtitle: '${fair.name} workspace and associated ledger purged',
          amount: 'Purged',
          type: ActivityLogType.fairArchived,
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  @override
  Future<void> toggleArchiveBookFair(String id) async {
    final fair = await getBookFairById(id);
    if (fair == null) return;

    final updated = fair.copyWith(
      isArchived: !fair.isArchived,
      updatedAt: DateTime.now(),
    );
    await _dataSource.updateBookFair(BookFairModel.fromEntity(updated));

    await _activityLogRepo.logEvent(
      ActivityLog(
        id: _uuid.v4(),
        fairId: id,
        title: updated.isArchived ? 'Fair Archived' : 'Fair Restored',
        subtitle:
            '${fair.name} moved to ${updated.isArchived ? 'archives' : 'active listings'}',
        amount: updated.isArchived ? 'Archived' : 'Active',
        type: ActivityLogType.fairArchived,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> saveDraft(BookFair bookFair) async {
    final model = BookFairModel.fromEntity(bookFair);
    await _dataSource.saveDraft(model);
  }

  @override
  Future<BookFair?> getDraft() async {
    final model = await _dataSource.getDraft();
    return model?.toEntity();
  }

  @override
  Future<void> clearDraft() async {
    await _dataSource.clearDraft();
  }

  @override
  Stream<List<BookFair>> watchBookFairs() {
    return _dataSource.watchBookFairs().map((models) {
      final list = models.map((m) => m.toEntity()).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }
}
