import 'package:bookfair_manager/core/components/app_photon_autocomplete_field.dart';
import 'package:bookfair_manager/core/services/geocoding/geocoding_providers.dart';
import 'package:bookfair_manager/core/services/geocoding/photon_geocoding_service.dart';
import 'package:bookfair_manager/core/services/geocoding/photon_place.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class MockPhotonGeocodingService implements PhotonGeocodingService {
  MockPhotonGeocodingService({this.delay = Duration.zero, this.mockResults});

  final Duration delay;
  final List<PhotonPlace>? mockResults;
  int callCount = 0;
  String? lastQuery;
  PhotonSearchType? lastType;

  @override
  Future<List<PhotonPlace>> search({
    required String query,
    PhotonSearchType type = PhotonSearchType.venue,
    double? latitude,
    double? longitude,
    int limit = 8,
    String lang = 'en',
  }) async {
    callCount++;
    lastQuery = query;
    lastType = type;

    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }

    if (mockResults != null) return mockResults!;

    if (query.toLowerCase() == 'empty') {
      return const [];
    }

    return [
      const PhotonPlace(
        name: 'Science City',
        street: 'J.B.S. Haldane Avenue',
        city: 'Kolkata',
        state: 'West Bengal',
        country: 'India',
        countryCode: 'IN',
        latitude: 22.5400604,
        longitude: 88.3958472,
      ),
      const PhotonPlace(
        name: 'Milan Mela',
        street: 'EM Bypass',
        city: 'Kolkata',
        state: 'West Bengal',
        country: 'India',
        countryCode: 'IN',
        latitude: 22.5410,
        longitude: 88.3970,
      ),
    ];
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
  Widget buildTestableWidget({
    required Widget child,
    required PhotonGeocodingService mockService,
  }) {
    return ProviderScope(
      overrides: [
        photonGeocodingServiceProvider.overrideWithValue(mockService),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Padding(padding: const EdgeInsets.all(20.0), child: child),
        ),
      ),
    );
  }

  group('AppPhotonAutocompleteField Widget Tests', () {
    testWidgets(
      'Typing >= 2 characters triggers debounced search and shows overlay',
      (tester) async {
        final mockService = MockPhotonGeocodingService();
        final controller = TextEditingController();

        await tester.pumpWidget(
          buildTestableWidget(
            mockService: mockService,
            child: AppPhotonAutocompleteField(
              controller: controller,
              label: 'Location / Venue',
              hint: 'Search venue',
              debounceDuration: const Duration(milliseconds: 100),
            ),
          ),
        );

        // Typing only 1 char should NOT trigger search
        await tester.enterText(find.byType(TextField), 'S');
        await tester.pump(const Duration(milliseconds: 150));
        expect(mockService.callCount, equals(0));
        expect(find.text('Science City'), findsNothing);

        // Typing second char triggers search after debounce
        await tester.enterText(find.byType(TextField), 'Sc');
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pumpAndSettle();

        expect(mockService.callCount, equals(1));
        expect(find.text('Science City'), findsOneWidget);
        expect(find.text('Milan Mela'), findsOneWidget);
      },
    );

    testWidgets(
      'Selecting a suggestion populates field and triggers callback',
      (tester) async {
        final mockService = MockPhotonGeocodingService();
        final controller = TextEditingController();
        PhotonPlace? selectedPlace;

        await tester.pumpWidget(
          buildTestableWidget(
            mockService: mockService,
            child: AppPhotonAutocompleteField(
              controller: controller,
              label: 'Location / Venue',
              debounceDuration: const Duration(milliseconds: 50),
              onPlaceSelected: (place) {
                selectedPlace = place;
                controller.text = place.venueFormattedName;
              },
            ),
          ),
        );

        await tester.enterText(find.byType(TextField), 'Sci');
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        final scienceCityTile = find.text('Science City');
        expect(scienceCityTile, findsOneWidget);

        // Tap on Science City suggestion
        await tester.tap(scienceCityTile);
        await tester.pumpAndSettle();

        expect(selectedPlace, isNotNull);
        expect(selectedPlace!.name, equals('Science City'));
        expect(selectedPlace!.latitude, equals(22.5400604));
        expect(selectedPlace!.longitude, equals(88.3958472));
        expect(controller.text, contains('Science City'));

        // Suggestion overlay should now be dismissed
        expect(find.text('Milan Mela'), findsNothing);
      },
    );

    testWidgets('Manual text entry without selecting suggestion is preserved', (
      tester,
    ) async {
      final mockService = MockPhotonGeocodingService();
      final controller = TextEditingController();
      String lastChangedValue = '';

      await tester.pumpWidget(
        buildTestableWidget(
          mockService: mockService,
          child: AppPhotonAutocompleteField(
            controller: controller,
            label: 'City',
            debounceDuration: const Duration(milliseconds: 50),
            onChanged: (val) => lastChangedValue = val,
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Custom Stall Ground');
      await tester.pump(const Duration(milliseconds: 100));

      expect(lastChangedValue, equals('Custom Stall Ground'));
      expect(controller.text, equals('Custom Stall Ground'));
    });

    testWidgets(
      'Displays friendly empty state when no matching results are found',
      (tester) async {
        final mockService = MockPhotonGeocodingService();
        final controller = TextEditingController();

        await tester.pumpWidget(
          buildTestableWidget(
            mockService: mockService,
            child: AppPhotonAutocompleteField(
              controller: controller,
              label: 'Location',
              debounceDuration: const Duration(milliseconds: 50),
            ),
          ),
        );

        await tester.enterText(find.byType(TextField), 'empty');
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        expect(find.text('No matching locations found.'), findsOneWidget);
      },
    );

    testWidgets('Clear button clears text and hides dropdown overlay', (
      tester,
    ) async {
      final mockService = MockPhotonGeocodingService();
      final controller = TextEditingController();

      await tester.pumpWidget(
        buildTestableWidget(
          mockService: mockService,
          child: AppPhotonAutocompleteField(
            controller: controller,
            label: 'Location',
            debounceDuration: const Duration(milliseconds: 50),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Sci');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text('Science City'), findsOneWidget);

      final clearButton = find.byIcon(Icons.clear_rounded);
      expect(clearButton, findsOneWidget);

      await tester.tap(clearButton);
      await tester.pumpAndSettle();

      expect(controller.text, isEmpty);
      expect(find.text('Science City'), findsNothing);
    });
  });
}
