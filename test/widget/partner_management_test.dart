import 'package:bookfair_manager/core/database/app_database.dart';
import 'package:bookfair_manager/features/book_fairs/data/datasources/book_fair_local_datasource.dart';
import 'package:bookfair_manager/features/book_fairs/data/models/book_fair_model.dart';
import 'package:bookfair_manager/features/book_fairs/data/models/partner_model.dart';
import 'package:bookfair_manager/features/book_fairs/domain/entities/book_fair.dart';
import 'package:bookfair_manager/features/book_fairs/domain/entities/partner.dart';
import 'package:bookfair_manager/features/book_fairs/presentation/screens/add_partner_screen.dart';
import 'package:bookfair_manager/features/book_fairs/presentation/screens/partner_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  group('Partner Management Widget Tests', () {
    const fairId = 'fair-test-42';
    final now = DateTime.now();

    final testFair = BookFair(
      id: fairId,
      name: 'Bengaluru Book Festival',
      location: 'Palace Grounds',
      city: 'Bengaluru',
      state: 'Karnataka',
      startDate: now.add(const Duration(days: 5)),
      endDate: now.add(const Duration(days: 12)),
      estimatedBudgetPaise: 20000000,
      initialInvestmentPaise: 10000000,
      createdAt: now,
      updatedAt: now,
    );

    final samplePartner = Partner(
      id: 'partner-007',
      fairId: fairId,
      fullName: 'Sayan Banik',
      phoneNumber: '+91 9876543210',
      email: 'sayan@example.com',
      role: PartnerRole.owner,
      joinedAt: now,
      profitSharingPercentage: 50.0,
      notes: 'Managing Lead',
      createdAt: now,
      updatedAt: now,
    );

    testWidgets(
      'PartnerListScreen displays empty roster state when no partners exist',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.runAsync(() async {
          const db = AppDatabase();
          final ds = BookFairLocalDataSourceImpl(db);
          await ds.createBookFair(BookFairModel.fromEntity(testFair));
        });

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: PartnerListScreen(fairId: fairId)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('No Partners Registered'), findsOneWidget);
        expect(find.text('Add Partner'), findsWidgets);
      },
    );

    testWidgets(
      'PartnerListScreen renders partner cards with role and equity info',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.runAsync(() async {
          const db = AppDatabase();
          final ds = BookFairLocalDataSourceImpl(db);
          await ds.createBookFair(BookFairModel.fromEntity(testFair));
          await ds.createPartner(PartnerModel.fromEntity(samplePartner));
        });

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: PartnerListScreen(fairId: fairId)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Sayan Banik'), findsOneWidget);
        expect(find.text('OWNER / ORGANIZER'), findsWidgets);
        expect(find.text('50.0% EQUITY'), findsOneWidget);
      },
    );

    testWidgets(
      'AddPartnerScreen renders all form fields for personal, contact, and equity info',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: AddPartnerScreen(fairId: fairId)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Add New Partner'), findsOneWidget);
        expect(find.text('Full Legal Name'), findsOneWidget);
        expect(find.text('Phone Number (Optional)'), findsOneWidget);
        expect(find.text('Email Address (Optional)'), findsOneWidget);
        expect(find.text('Profit Sharing % (Optional)'), findsOneWidget);
        expect(find.text('Operational Notes'), findsOneWidget);
        expect(find.text('Register Partner'), findsOneWidget);
      },
    );

    testWidgets(
      'AddPartnerScreen valid submission adds partner with equity into database',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.runAsync(() async {
          const db = AppDatabase();
          final ds = BookFairLocalDataSourceImpl(db);
          await ds.createBookFair(BookFairModel.fromEntity(testFair));
        });

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: AddPartnerScreen(fairId: fairId)),
          ),
        );
        await tester.pumpAndSettle();

        // Enter partner details
        final textFields = find.byType(TextField);
        // Name
        await tester.enterText(textFields.at(0), 'Aditi Sen');
        // Phone
        await tester.enterText(textFields.at(1), '+91 9830012345');
        // Email
        await tester.enterText(textFields.at(2), 'aditi@example.com');
        // Equity %
        await tester.enterText(textFields.at(3), '33.5');
        // Notes
        await tester.enterText(
          textFields.at(4),
          'Inventory and POS operations manager',
        );
        await tester.pumpAndSettle();

        // Submit form
        final submitBtn = find.text('Register Partner');
        await tester.ensureVisible(submitBtn);

        await tester.runAsync(() async {
          await tester.tap(submitBtn);
          await Future.delayed(const Duration(milliseconds: 300));
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Verify in Hive database
        const db = AppDatabase();
        final ds = BookFairLocalDataSourceImpl(db);
        final partners = await ds.getPartnersForFair(fairId);
        expect(partners.length, equals(1));
        expect(partners.first.fullName, equals('Aditi Sen'));
        expect(partners.first.profitSharingPercentage, equals(33.5));
        expect(partners.first.notes, contains('Inventory and POS operations'));

        // Dismiss snackbar timer before test teardown
        await tester.pump(const Duration(seconds: 4));
      },
    );
  });
}
