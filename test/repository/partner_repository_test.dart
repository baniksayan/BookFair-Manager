import 'package:bookfair_manager/core/database/app_database.dart';
import 'package:bookfair_manager/core/database/database_exceptions.dart';
import 'package:bookfair_manager/features/book_fairs/data/datasources/book_fair_local_datasource.dart';
import 'package:bookfair_manager/features/book_fairs/data/models/investment_model.dart';
import 'package:bookfair_manager/features/book_fairs/data/repositories/activity_log_repository_impl.dart';
import 'package:bookfair_manager/features/book_fairs/data/repositories/partner_repository_impl.dart';
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

  group('PartnerRepositoryImpl Hive Persistence Tests', () {
    late PartnerRepositoryImpl repository;
    late ActivityLogRepositoryImpl activityLogRepo;
    late BookFairLocalDataSourceImpl dataSource;
    const db = AppDatabase();

    final now = DateTime(2026, 11, 21);

    setUp(() {
      dataSource = BookFairLocalDataSourceImpl(db);
      activityLogRepo = ActivityLogRepositoryImpl(dataSource);
      repository = PartnerRepositoryImpl(dataSource, activityLogRepo);
    });

    final samplePartner = Partner(
      id: 'partner-001',
      fairId: 'fair-100',
      fullName: 'Vikramaditya Sharma',
      phoneNumber: '+91 9123456780',
      email: 'vikram@example.com',
      role: PartnerRole.partner,
      joinedAt: now,
      profitSharingPercentage: 40.0,
      notes: 'Literary partner',
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );

    test(
      'addPartner persists partner and logs join event in audit trail',
      () async {
        await repository.addPartner(samplePartner);

        final retrieved = await repository.getPartnerById('partner-001');
        expect(retrieved, isNotNull);
        expect(retrieved!.fullName, equals('Vikramaditya Sharma'));
        expect(retrieved.profitSharingPercentage, equals(40.0));

        final logs = await activityLogRepo.getRecentLogs();
        expect(
          logs.any(
            (l) => l.fairId == 'fair-100' && l.title == 'Partner Joined Stall',
          ),
          isTrue,
        );
      },
    );

    test('addPartner throws DuplicateRecordException when name is duplicated in the same fair', () async {
      await repository.addPartner(samplePartner);

      final duplicatePartner = Partner(
        id: 'partner-002',
        fairId: 'fair-100',
        fullName: '  vikramaditya sharma  ', // Test trimmed case-insensitive collision
        phoneNumber: '+91 9999999999',
        email: 'another@example.com',
        role: PartnerRole.investor,
        joinedAt: now,
        profitSharingPercentage: 20.0,
        createdAt: now,
        updatedAt: now,
      );

      expect(
        () async => await repository.addPartner(duplicatePartner),
        throwsA(isA<DuplicateRecordException>()),
      );
    });

    test(
      'addPartner allows identical partner name across different fairs',
      () async {
        await repository.addPartner(samplePartner);

        final differentFairPartner = Partner(
          id: 'partner-003',
          fairId: 'fair-200', // Different fair
          fullName: 'Vikramaditya Sharma',
          phoneNumber: '+91 9123456780',
          role: PartnerRole.partner,
          joinedAt: now,
          profitSharingPercentage: 50.0,
          createdAt: now,
          updatedAt: now,
        );

        // Should succeed without error
        await repository.addPartner(differentFairPartner);
        final retrieved = await repository.getPartnerById('partner-003');
        expect(retrieved, isNotNull);
        expect(retrieved!.fairId, equals('fair-200'));
      },
    );

    test('updatePartner correctly persists edited partner data', () async {
      await repository.addPartner(samplePartner);

      final updatedPartner = samplePartner.copyWith(
        phoneNumber: '+91 9888877777',
        profitSharingPercentage: 45.0,
        notes: 'Senior managing partner',
      );

      await repository.updatePartner(updatedPartner);

      final retrieved = await repository.getPartnerById('partner-001');
      expect(retrieved!.phoneNumber, equals('+91 9888877777'));
      expect(retrieved.profitSharingPercentage, equals(45.0));
      expect(retrieved.notes, equals('Senior managing partner'));
    });

    test(
      'deletePartner enforces referential integrity against active investments',
      () async {
        await repository.addPartner(samplePartner);

        // Register an investment for this partner
        final investment = Investment(
          id: 'inv-001',
          fairId: 'fair-100',
          partnerId: 'partner-001',
          amountPaise: 5000000,
          contributionType: ContributionType.cash,
          paymentMethod: PaymentMethod.bankTransfer,
          contributionDate: now,
          createdAt: now,
          updatedAt: now,
        );
        await dataSource.createInvestment(
          InvestmentModel.fromEntity(investment),
        );

        // Attempting to delete without force must fail due to referential integrity
        expect(
          () async =>
              await repository.deletePartner('partner-001', force: false),
          throwsA(isA<ReferentialIntegrityException>()),
        );

        // Partner and investment should still exist
        expect(await repository.getPartnerById('partner-001'), isNotNull);
        expect(await dataSource.getInvestmentById('inv-001'), isNotNull);

        // Force deleting should succeed and clean up related investment
        await repository.deletePartner('partner-001', force: true);
        expect(await repository.getPartnerById('partner-001'), isNull);
        expect(await dataSource.getInvestmentById('inv-001'), isNull);
      },
    );
  });
}
