import 'package:bookfair_manager/app/theme/app_theme.dart';
import 'package:bookfair_manager/features/inventory/presentation/screens/create_purchase_batch_screen.dart';
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

  Widget buildTestableWidget() {
    return ProviderScope(
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const CreatePurchaseBatchScreen(),
      ),
    );
  }

  group('CreatePurchaseBatchScreen Widget Tests', () {
    testWidgets('Renders all procurement form sections and line items UI', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      // App bar
      expect(find.text('New Purchase Batch'), findsOneWidget);

      // Section titles
      expect(find.text('Batch Header & Vendor Details'), findsOneWidget);

      // Line item action button
      expect(find.text('Add Title'), findsOneWidget);

      // Submit action button
      expect(find.text('Confirm & Store Purchase Batch'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  });
}
