import 'package:bookfair_manager/core/localization/app_strings.dart';
import 'package:bookfair_manager/core/services/geocoding/geocoding_providers.dart';
import 'package:bookfair_manager/core/services/geocoding/photon_geocoding_service.dart';
import 'package:bookfair_manager/core/services/geocoding/photon_place.dart';
import 'package:bookfair_manager/features/book_fairs/presentation/screens/create_book_fair_screen.dart';
import 'package:bookfair_manager/features/book_fairs/presentation/view_models/create_book_fair_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helper.dart';

class MockPhotonGeocodingService implements PhotonGeocodingService {
  @override
  Future<List<PhotonPlace>> search({
    required String query,
    PhotonSearchType type = PhotonSearchType.venue,
    double? latitude,
    double? longitude,
    int limit = 8,
    String lang = 'en',
  }) async {
    final qLower = query.toLowerCase();

    if (type == PhotonSearchType.city && qLower.contains('kol')) {
      return [
        const PhotonPlace(
          name: 'Kolkata',
          city: 'Kolkata',
          state: 'West Bengal',
          country: 'India',
          countryCode: 'IN',
          type: 'city',
          latitude: 22.5726459,
          longitude: 88.3638953,
        ),
      ];
    }

    if (type == PhotonSearchType.state && qLower.contains('west')) {
      return [
        const PhotonPlace(
          name: 'West Bengal',
          state: 'West Bengal',
          country: 'India',
          countryCode: 'IN',
          type: 'state',
          latitude: 22.9964948,
          longitude: 87.6855882,
        ),
      ];
    }

    if (type == PhotonSearchType.venue && qLower.contains('milan')) {
      return [
        const PhotonPlace(
          name: 'Milan Mela Ground',
          street: 'EM Bypass',
          city: 'Kolkata',
          state: 'West Bengal',
          country: 'India',
          countryCode: 'IN',
          latitude: 22.5412,
          longitude: 88.3965,
        ),
      ];
    }

    return const [];
  }

  @override
  Future<PhotonPlace?> reverseGeocode({
    required double latitude,
    required double longitude,
    String lang = 'en',
  }) async => null;

  @override
  void clearCache() {}
}

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

  Widget buildTestApp({required WidgetRefCallback onRef}) {
    return ProviderScope(
      overrides: [
        photonGeocodingServiceProvider.overrideWithValue(
          MockPhotonGeocodingService(),
        ),
      ],
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, child) {
            onRef(ref);
            return const CreateBookFairScreen();
          },
        ),
      ),
    );
  }

  testWidgets(
    'Selecting a City suggestion automatically populates the State / Province field',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      late WidgetRef capturedRef;

      await tester.pumpWidget(buildTestApp(onRef: (ref) => capturedRef = ref));
      await tester.pumpAndSettle();

      // Find the City text field by its hint
      final cityTextField = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'e.g. Kolkata',
      );

      expect(cityTextField, findsOneWidget);

      // Type "Kol" into City field
      await tester.enterText(cityTextField, 'Kol');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Verify City suggestion is displayed with State and Country
      expect(find.text('Kolkata'), findsWidgets);
      expect(find.text('West Bengal, India'), findsWidgets);

      // Tap on Kolkata suggestion
      await tester.tap(find.text('Kolkata').last);
      await tester.pumpAndSettle();

      // Verify City state updated
      final state = capturedRef.read(createBookFairViewModelProvider);
      expect(state.city, equals('Kolkata'));

      // Verify State / Province field was AUTOMATICALLY POPULATED with West Bengal!
      expect(state.stateProvince, equals('West Bengal'));

      // Also verify the State textfield displays "West Bengal"
      final stateTextField = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'e.g. West Bengal',
      );
      expect(
        (tester.widget(stateTextField) as TextField).controller?.text,
        equals('West Bengal'),
      );
    },
  );

  testWidgets(
    'Selecting Location / Venue populates venue text and retains coordinates in ViewModel',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      late WidgetRef capturedRef;

      await tester.pumpWidget(buildTestApp(onRef: (ref) => capturedRef = ref));
      await tester.pumpAndSettle();

      // Find Location / Venue textfield by its hint
      final venueTextField = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.hintText == AppStrings.fieldLocationHint,
      );

      expect(venueTextField, findsOneWidget);

      // Type "Milan" into Location field
      await tester.enterText(venueTextField, 'Milan');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('Milan Mela Ground'), findsOneWidget);

      // Tap on Milan Mela Ground suggestion
      await tester.tap(find.text('Milan Mela Ground'));
      await tester.pumpAndSettle();

      final state = capturedRef.read(createBookFairViewModelProvider);
      expect(state.location, contains('Milan Mela Ground'));
      // Verify latitude and longitude are preserved!
      expect(state.latitude, equals(22.5412));
      expect(state.longitude, equals(88.3965));
      expect(state.selectedLocation, isNotNull);
    },
  );

  testWidgets('Manual entry without selecting suggestions is fully supported', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    late WidgetRef capturedRef;

    await tester.pumpWidget(buildTestApp(onRef: (ref) => capturedRef = ref));
    await tester.pumpAndSettle();

    final venueTextField = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          w.decoration?.hintText == AppStrings.fieldLocationHint,
    );

    // Type custom manual text
    await tester.enterText(venueTextField, 'Stall 42, Private Complex');
    await tester.pump(const Duration(milliseconds: 100));

    final state = capturedRef.read(createBookFairViewModelProvider);
    expect(state.location, equals('Stall 42, Private Complex'));
  });
}

typedef WidgetRefCallback = void Function(WidgetRef ref);
