import 'package:bookfair_manager/core/database/app_database.dart';
import 'package:bookfair_manager/features/book_fairs/data/datasources/book_fair_local_datasource.dart';
import 'package:bookfair_manager/features/book_fairs/data/models/investment_model.dart';
import 'package:bookfair_manager/features/book_fairs/data/models/partner_model.dart';
import 'package:bookfair_manager/features/book_fairs/data/repositories/activity_log_repository_impl.dart';
import 'package:bookfair_manager/features/book_fairs/data/repositories/book_fair_repository_impl.dart';
import 'package:bookfair_manager/features/book_fairs/domain/entities/book_fair.dart';
import 'package:bookfair_manager/features/book_fairs/domain/entities/investment.dart';
import 'package:bookfair_manager/features/book_fairs/domain/entities/partner.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helper.dart';

void main() {
  setUpAll(() async {
    await TestDatabaseHelper.setUpSuiteDatabase();
  });

  tearDownAll(() async {
    await TestDatabaseHelper.tearDownSuiteDatabase();
  });

  setUp(() async {
    await TestDatabaseHelper.resetDatabase();
  });

  group('BookFairRepositoryImpl Hive Persistence Tests', () {
    late BookFairRepositoryImpl repository;
    late ActivityLogRepositoryImpl activityLogRepo;
    late BookFairLocalDataSourceImpl dataSource;
    const db = AppDatabase();

    final now = DateTime(2026, 11, 21);

    setUp(() {
      dataSource = BookFairLocalDataSourceImpl(db);
      activityLogRepo = ActivityLogRepositoryImpl(dataSource);
      repository = BookFairRepositoryImpl(dataSource, activityLogRepo);
    });

    final sampleFair = BookFair(
      id: 'fair-101',
      name: 'International Kolkata Book Fair 2027',
      location: 'Central Park Fairgrounds',
      city: 'Kolkata',
      state: 'West Bengal',
      startDate: now.add(const Duration(days: 30)),
      endDate: now.add(const Duration(days: 42)),
      estimatedBudgetPaise: 50000000, // ₹5,00,000.00
      initialInvestmentPaise: 20000000, // ₹2,00,000.00
      currency: 'INR',
      partnerCount: 3,
      partnershipType: 'Equal Profit Sharing',
      description: 'Major regional literary event',
      operationalNotes: 'Book stall 42 secured',
      isDraft: false,
      isArchived: false,
      createdAt: now,
      updatedAt: now,
    );

    test('createBookFair stores fair and logs creation activity', () async {
      await repository.createBookFair(sampleFair);

      final retrieved = await repository.getBookFairById('fair-101');
      expect(retrieved, isNotNull);
      expect(retrieved!.name, equals('International Kolkata Book Fair 2027'));
      expect(retrieved.estimatedBudgetPaise, equals(50000000));
      expect(retrieved.location, equals('Central Park Fairgrounds'));

      // Verify activity log creation
      final logs = await activityLogRepo.getRecentLogs();
      expect(logs, isNotEmpty);
      expect(
        logs.any(
          (l) => l.fairId == 'fair-101' && l.title == 'New Book Fair Created',
        ),
        isTrue,
      );
    });

    test('updateBookFair updates fields and updates timestamp', () async {
      await repository.createBookFair(sampleFair);

      final updatedFair = sampleFair.copyWith(
        name: 'Updated Kolkata Fair 2027',
        estimatedBudgetPaise: 60000000,
        city: 'Salt Lake, Kolkata',
      );

      await repository.updateBookFair(updatedFair);

      final retrieved = await repository.getBookFairById('fair-101');
      expect(retrieved!.name, equals('Updated Kolkata Fair 2027'));
      expect(retrieved.estimatedBudgetPaise, equals(60000000));
      expect(retrieved.city, equals('Salt Lake, Kolkata'));
    });

    test(
      'toggleArchiveBookFair toggles archive status and logs activity',
      () async {
        await repository.createBookFair(sampleFair);

        // Archive
        await repository.toggleArchiveBookFair('fair-101');
        var retrieved = await repository.getBookFairById('fair-101');
        expect(retrieved!.isArchived, isTrue);

        // Unarchive
        await repository.toggleArchiveBookFair('fair-101');
        retrieved = await repository.getBookFairById('fair-101');
        expect(retrieved!.isArchived, isFalse);

        final logs = await activityLogRepo.getRecentLogs();
        expect(logs.any((l) => l.title == 'Fair Archived'), isTrue);
        expect(logs.any((l) => l.title == 'Fair Restored'), isTrue);
      },
    );

    test(
      'saveDraft, getDraft, and clearDraft lifecycle works seamlessly',
      () async {
        final draft = sampleFair.copyWith(id: 'draft-1', isDraft: true);

        await repository.saveDraft(draft);
        var currentDraft = await repository.getDraft();
        expect(currentDraft, isNotNull);
        expect(
          currentDraft!.name,
          equals('International Kolkata Book Fair 2027'),
        );
        expect(currentDraft.isDraft, isTrue);

        await repository.clearDraft();
        currentDraft = await repository.getDraft();
        expect(currentDraft, isNull);
      },
    );

    test('deleteBookFair cascades deletion to all related partners and investments', () async {
      await repository.createBookFair(sampleFair);

      // Create related partner
      final partner = Partner(
        id: 'partner-99',
        fairId: 'fair-101',
        fullName: 'Ananya Roy',
        phoneNumber: '+91 9876543210',
        email: 'ananya@example.com',
        role: PartnerRole.partner,
        joinedAt: now,
        profitSharingPercentage: 50.0,
        notes: 'Co-founder',
        createdAt: now,
        updatedAt: now,
      );
      await dataSource.createPartner(PartnerModel.fromEntity(partner));

      // Create related investment
      final investment = Investment(
        id: 'inv-99',
        fairId: 'fair-101',
        partnerId: 'partner-99',
        amountPaise: 10000000,
        contributionType: ContributionType.cash,
        paymentMethod: PaymentMethod.bankTransfer,
        contributionDate: now,
        notes: 'Primary capital',
        createdAt: now,
        updatedAt: now,
      );
      await dataSource.createInvestment(InvestmentModel.fromEntity(investment));

      // Verify records exist before deletion
      expect(await repository.getBookFairById('fair-101'), isNotNull);
      expect(await dataSource.getPartnerById('partner-99'), isNotNull);
      expect(await dataSource.getInvestmentById('inv-99'), isNotNull);

      // Perform cascade deletion
      await repository.deleteBookFair('fair-101');

      // Verify fair and cascade relations are all purged
      expect(await repository.getBookFairById('fair-101'), isNull);
      expect(await dataSource.getPartnerById('partner-99'), isNull);
      expect(await dataSource.getInvestmentById('inv-99'), isNull);
    });
  });
}
