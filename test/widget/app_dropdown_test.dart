import 'package:bookfair_manager/app/theme/app_theme.dart';
import 'package:bookfair_manager/core/components/app_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildTestableDropdown<T>({
    required List<DropdownMenuItem<T>> items,
    T? value,
    ValueChanged<T?>? onChanged,
    String? label,
    String? hint,
    String? Function(T?)? validator,
    Widget? prefixIcon,
    String? sheetTitle,
    String? sheetSubtitle,
    Widget? sheetIcon,
    bool? searchable,
    String? actionButtonText,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Form(
                child: AppDropdown<T>(
                  items: items,
                  value: value,
                  onChanged: (val) {
                    setState(() => value = val);
                    onChanged?.call(val);
                  },
                  label: label,
                  hint: hint,
                  validator: validator,
                  prefixIcon: prefixIcon,
                  sheetTitle: sheetTitle,
                  sheetSubtitle: sheetSubtitle,
                  sheetIcon: sheetIcon,
                  searchable: searchable,
                  actionButtonText: actionButtonText,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  group('AppDropdown & AppDropdownSheet Comprehensive Widget Tests', () {
    testWidgets('Renders label, hint, and arrow down icon when unselected', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableDropdown<String>(
          label: 'Payment Method',
          hint: 'Select payment method',
          items: const [
            DropdownMenuItem(value: 'Cash', child: Text('Cash')),
            DropdownMenuItem(value: 'UPI', child: Text('UPI')),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Payment Method'), findsOneWidget);
      expect(find.text('Select payment method'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
    });

    testWidgets('Renders selected value text when initial value is provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestableDropdown<String>(
          label: 'Payment Method',
          value: 'Cash',
          items: const [
            DropdownMenuItem(value: 'Cash', child: Text('Cash')),
            DropdownMenuItem(value: 'UPI', child: Text('UPI')),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cash'), findsOneWidget);
    });

    testWidgets(
      'Tapping field opens AppDropdownSheet with header, icons, subtitles, and action button',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        String? selectedResult;

        await tester.pumpWidget(
          buildTestableDropdown<String>(
            label: 'Payment Method',
            value: 'Cash',
            onChanged: (val) => selectedResult = val,
            items: const [
              DropdownMenuItem(value: 'Cash', child: Text('Cash')),
              DropdownMenuItem(value: 'UPI', child: Text('UPI')),
              DropdownMenuItem(
                value: 'Bank Transfer',
                child: Text('Bank Transfer'),
              ),
              DropdownMenuItem(value: 'Other', child: Text('Other')),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Tap field to open sheet
        await tester.tap(find.text('Cash'));
        await tester.pumpAndSettle();

        // Verify bottom sheet opened
        expect(find.byType(AppDropdownSheet<String>), findsOneWidget);

        // Verify header elements
        expect(find.text('Payment Method'), findsWidgets);
        expect(
          find.text('Choose how this contribution was paid.'),
          findsOneWidget,
        );

        // Verify inferred subtitles match screenshot 2
        expect(find.text('Physical cash payment'), findsOneWidget);
        expect(find.text('Google Pay, PhonePe, Paytm etc.'), findsOneWidget);
        expect(
          find.text('Direct bank transaction (NEFT/IMPS/RTGS)'),
          findsOneWidget,
        );
        expect(find.text('Any other payment method'), findsOneWidget);

        // Verify checked icon on Cash and action button
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
        expect(find.text('Select Payment Method'), findsOneWidget);

        // Select UPI
        await tester.tap(find.text('UPI'));
        await tester.pumpAndSettle();

        // Tap confirmation button
        await tester.tap(find.text('Select Payment Method'));
        await tester.pumpAndSettle();

        // Sheet closed and form field updated
        expect(find.byType(AppDropdownSheet<String>), findsNothing);
        expect(selectedResult, equals('UPI'));
        expect(find.text('UPI'), findsOneWidget);
      },
    );

    testWidgets(
      'Number of Partners / Investors sheet matches screenshot 4 layout and action button',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        int? chosenCount;

        await tester.pumpWidget(
          buildTestableDropdown<int>(
            label: 'Number of Partners / Investors',
            value: 1,
            onChanged: (val) => chosenCount = val,
            items: const [
              DropdownMenuItem(
                value: 1,
                child: Text('Sole Proprietor (1 Organizer)'),
              ),
              DropdownMenuItem(value: 2, child: Text('2 Partners')),
              DropdownMenuItem(value: 3, child: Text('3 Partners')),
              DropdownMenuItem(value: 4, child: Text('4 Partners')),
              DropdownMenuItem(
                value: 5,
                child: Text('5+ Partners / Syndicate'),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Sole Proprietor (1 Organizer)'));
        await tester.pumpAndSettle();

        // Verify header title and subtitle
        expect(
          find.text('Select the business ownership structure'),
          findsOneWidget,
        );

        // Verify action button says 'Select'
        expect(find.text('Select'), findsOneWidget);

        // Verify inferred subtitles
        expect(find.text('Run and manage the fair alone'), findsOneWidget);
        expect(find.text('A business with two partners.'), findsOneWidget);

        // Tap 3 Partners and confirm
        await tester.tap(find.text('3 Partners'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Select'));
        await tester.pumpAndSettle();

        expect(chosenCount, equals(3));
      },
    );

    testWidgets(
      'Expense Category sheet includes real-time search bar matching screenshot 7',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        String? chosenCategory;

        final categories = [
          'Banner & Flex',
          'Chair Rental',
          'Communication',
          'Decoration',
          'Electricity',
          'Equipment',
          'Food & Refreshments',
          'Labour',
          'Lighting',
          'Loading & Unloading',
          'Maintenance',
          'Packaging',
          'Printing',
          'Stall Advance',
          'Stall Rent',
          'Stationery',
          'Other',
        ];

        await tester.pumpWidget(
          buildTestableDropdown<String>(
            label: 'Expense Category *',
            hint: 'Select category',
            onChanged: (val) => chosenCategory = val,
            items: categories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
          ),
        );
        await tester.pumpAndSettle();

        // Tap to open sheet
        await tester.tap(find.text('Select category'));
        await tester.pumpAndSettle();

        // Verify Search bar is present
        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('Search expense category...'), findsOneWidget);

        // Search for 'Rent'
        await tester.enterText(find.byType(TextField), 'Rent');
        await tester.pumpAndSettle();

        // Matching items visible
        expect(find.text('Chair Rental'), findsOneWidget);
        expect(find.text('Stall Rent'), findsOneWidget);

        // Non-matching items filtered out
        expect(find.text('Food & Refreshments'), findsNothing);

        // Tap Stall Rent and confirm
        await tester.tap(find.text('Stall Rent'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Select Category'));
        await tester.pumpAndSettle();

        expect(chosenCategory, equals('Stall Rent'));
      },
    );

    testWidgets('Custom AppDropdownItem attributes override inferred values', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        buildTestableDropdown<String>(
          label: 'Custom Options',
          value: 'opt1',
          items: const [
            AppDropdownItem(
              value: 'opt1',
              label: 'Custom Title 1',
              subtitle: 'Custom Subtitle 1',
              iconData: Icons.star_rounded,
              child: Text('Custom Title 1'),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Custom Title 1'));
      await tester.pumpAndSettle();

      expect(find.text('Custom Title 1'), findsWidgets);
      expect(find.text('Custom Subtitle 1'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppDropdownSheet<String>),
          matching: find.byIcon(Icons.star_rounded),
        ),
        findsOneWidget,
      );
    });
  });
}
