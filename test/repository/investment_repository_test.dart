import 'package:bookfair_manager/core/database/app_database.dart';
import 'package:bookfair_manager/core/utils/financial_calculator.dart';
import 'package:bookfair_manager/features/book_fairs/data/datasources/book_fair_local_datasource.dart';
import 'package:bookfair_manager/features/book_fairs/data/models/partner_model.dart';
import 'package:bookfair_manager/features/book_fairs/data/repositories/activity_log_repository_impl.dart';
import 'package:bookfair_manager/features/book_fairs/data/repositories/investment_repository_impl.dart';
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

  group('InvestmentRepositoryImpl Hive Persistence Tests', () {
    late InvestmentRepositoryImpl repository;
    late ActivityLogRepositoryImpl activityLogRepo;
    late BookFairLocalDataSourceImpl dataSource;
    const db = AppDatabase();

    final now = DateTime(2026, 11, 21);

    setUp(() async {
      dataSource = BookFairLocalDataSourceImpl(db);
      activityLogRepo = ActivityLogRepositoryImpl(dataSource);
      repository = InvestmentRepositoryImpl(dataSource, activityLogRepo);

      // Pre-populate partners
      final partner1 = Partner(
        id: 'p-1',
        fairId: 'fair-1',
        fullName: 'Arjun Das',
        role: PartnerRole.partner,
        joinedAt: now,
        createdAt: now,
        updatedAt: now,
      );
      final partner2 = Partner(
        id: 'p-2',
        fairId: 'fair-1',
        fullName: 'Bhavna Sen',
        role: PartnerRole.investor,
        joinedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      await dataSource.createPartner(PartnerModel.fromEntity(partner1));
      await dataSource.createPartner(PartnerModel.fromEntity(partner2));
    });

    test('addInvestment records transaction and logs audit event with partner attribution', () async {
      final inv = Investment(
        id: 'inv-01',
        fairId: 'fair-1',
        partnerId: 'p-1',
        amountPaise: 7500000, // ₹75,000.00
        contributionType: ContributionType.cash,
        paymentMethod: PaymentMethod.bankTransfer,
        contributionDate: now,
        referenceNumber: 'TXN-98765',
        notes: 'Initial stall booking tranche',
        createdAt: now,
        updatedAt: now,
      );

      await repository.addInvestment(inv);

      final retrieved = await repository.getInvestmentById('inv-01');
      expect(retrieved, isNotNull);
      expect(retrieved!.amountPaise, equals(7500000));
      expect(retrieved.referenceNumber, equals('TXN-98765'));

      // Check audit log
      final logs = await activityLogRepo.getRecentLogs();
      expect(logs, isNotEmpty);
      final log = logs.firstWhere((l) => l.fairId == 'fair-1');
      expect(log.title, equals('Capital Contribution Recorded'));
      expect(log.subtitle, contains('Arjun Das'));
      expect(log.amount, contains('75,000'));
    });

    test('getInvestmentsForFair returns all fair transactions sorted chronologically', () async {
      final inv1 = Investment(
        id: 'inv-10',
        fairId: 'fair-1',
        partnerId: 'p-1',
        amountPaise: 2000000,
        contributionType: ContributionType.cash,
        paymentMethod: PaymentMethod.upi,
        contributionDate: now.subtract(const Duration(days: 2)),
        createdAt: now,
        updatedAt: now,
      );
      final inv2 = Investment(
        id: 'inv-11',
        fairId: 'fair-1',
        partnerId: 'p-2',
        amountPaise: 3000000,
        contributionType: ContributionType.cash,
        paymentMethod: PaymentMethod.bankTransfer,
        contributionDate: now, // newer
        createdAt: now,
        updatedAt: now,
      );

      await repository.addInvestment(inv1);
      await repository.addInvestment(inv2);

      final results = await repository.getInvestmentsForFair('fair-1');
      expect(results.length, equals(2));
      // First item should be the newer contributionDate
      expect(results.first.id, equals('inv-11'));
      expect(results.last.id, equals('inv-10'));
    });

    test('getInvestmentsForPartner isolates contributions and aggregates accurate totals', () async {
      final inv1 = Investment(
        id: 'inv-20',
        fairId: 'fair-1',
        partnerId: 'p-1',
        amountPaise: 4000000, // ₹40,000
        contributionType: ContributionType.cash,
        paymentMethod: PaymentMethod.bankTransfer,
        contributionDate: now,
        createdAt: now,
        updatedAt: now,
      );
      final inv2 = Investment(
        id: 'inv-21',
        fairId: 'fair-1',
        partnerId: 'p-1',
        amountPaise: 1500000, // ₹15,000
        contributionType: ContributionType.cash,
        paymentMethod: PaymentMethod.cash,
        contributionDate: now,
        createdAt: now,
        updatedAt: now,
      );
      final inv3 = Investment(
        id: 'inv-22',
        fairId: 'fair-1',
        partnerId: 'p-2',
        amountPaise: 5000000, // ₹50,000 (Partner 2)
        contributionType: ContributionType.cash,
        paymentMethod: PaymentMethod.upi,
        contributionDate: now,
        createdAt: now,
        updatedAt: now,
      );

      await repository.addInvestment(inv1);
      await repository.addInvestment(inv2);
      await repository.addInvestment(inv3);

      final p1Investments = await repository.getInvestmentsForPartner(
        'fair-1',
        'p-1',
      );
      expect(p1Investments.length, equals(2));

      final p1TotalPaise =
          FinancialCalculator.calculatePartnerContributionPaise(
            investments: p1Investments,
            partnerId: 'p-1',
          );
      expect(p1TotalPaise, equals(5500000)); // ₹55,000 in paise
      expect(p1TotalPaise / 100.0, equals(55000.0));
    });

    test('deleteInvestment removes contribution from database', () async {
      final inv = Investment(
        id: 'inv-30',
        fairId: 'fair-1',
        partnerId: 'p-1',
        amountPaise: 1000000,
        contributionType: ContributionType.cash,
        paymentMethod: PaymentMethod.cash,
        contributionDate: now,
        createdAt: now,
        updatedAt: now,
      );

      await repository.addInvestment(inv);
      expect(await repository.getInvestmentById('inv-30'), isNotNull);

      await repository.deleteInvestment('inv-30');
      expect(await repository.getInvestmentById('inv-30'), isNull);
    });
  });
}
