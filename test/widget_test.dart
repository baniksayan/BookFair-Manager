import 'package:bookfair_manager/app/app.dart';
import 'package:bookfair_manager/core/localization/app_strings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helper.dart';

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

  testWidgets('BookFair Manager app loads dashboard smoke test', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BookFairManagerApp()));

    // Wait for the asynchronous microtask and router to settle
    await tester.pumpAndSettle();

    // Verify app brand is rendered
    expect(find.text(AppStrings.appName), findsWidgets);
    expect(find.text(AppStrings.dashboardHeroAction), findsOneWidget);
  });
}
