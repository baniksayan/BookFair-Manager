import 'package:bookfair_manager/core/services/geocoding/photon_place.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PhotonPlace GeoJSON & Domain Entity Tests', () {
    test(
      'Correctly extracts coordinates with longitude at 0 and latitude at 1',
      () {
        // GeoJSON Point: [lon, lat]
        final geoJson = {
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': [88.3638953, 22.5726459],
          },
          'properties': {
            'osm_type': 'R',
            'osm_id': 9381363,
            'osm_key': 'place',
            'osm_value': 'city',
            'type': 'city',
            'name': 'Kolkata',
            'state': 'West Bengal',
            'country': 'India',
            'countrycode': 'IN',
          },
        };

        final place = PhotonPlace.fromJson(geoJson);

        // Verify that longitude and latitude are NOT reversed!
        expect(place.longitude, equals(88.3638953));
        expect(place.latitude, equals(22.5726459));
        expect(place.name, equals('Kolkata'));
        expect(place.state, equals('West Bengal'));
        expect(place.country, equals('India'));
        expect(place.countryCode, equals('IN'));
        expect(place.osmId, equals(9381363));
        expect(place.osmType, equals('R'));
        expect(place.osmKey, equals('place'));
        expect(place.osmValue, equals('city'));
        expect(place.type, equals('city'));
        expect(place.isCity, isTrue);
        expect(place.isState, isFalse);
      },
    );

    test('Correctly extracts all properties for a venue/landmark', () {
      final geoJson = {
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [88.3958472, 22.5400604],
        },
        'properties': {
          'osm_type': 'W',
          'osm_id': 187721429,
          'osm_key': 'tourism',
          'osm_value': 'museum',
          'type': 'house',
          'name': 'Science City',
          'street': 'J.B.S. Haldane Avenue',
          'housenumber': '10',
          'district': 'Park Circus',
          'city': 'Kolkata',
          'state': 'West Bengal',
          'country': 'India',
          'postcode': '700046',
          'countrycode': 'IN',
        },
      };

      final place = PhotonPlace.fromJson(geoJson);

      expect(place.name, equals('Science City'));
      expect(place.street, equals('J.B.S. Haldane Avenue'));
      expect(place.housenumber, equals('10'));
      expect(place.district, equals('Park Circus'));
      expect(place.city, equals('Kolkata'));
      expect(place.state, equals('West Bengal'));
      expect(place.country, equals('India'));
      expect(place.postcode, equals('700046'));
      expect(place.latitude, equals(22.5400604));
      expect(place.longitude, equals(88.3958472));

      // Display titles and formatting
      expect(place.primaryTitle, equals('Science City'));
      expect(
        place.secondarySubtitle,
        equals(
          '10 J.B.S. Haldane Avenue, Park Circus, Kolkata, West Bengal, India',
        ),
      );
      expect(
        place.venueFormattedName,
        equals('Science City, 10 J.B.S. Haldane Avenue'),
      );
      expect(
        place.formattedAddress,
        equals(
          'Science City, 10 J.B.S. Haldane Avenue, Park Circus, Kolkata, West Bengal, 700046, India',
        ),
      );
    });

    test('Correctly identifies and formats state/province candidate', () {
      final geoJson = {
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [-118.755997, 36.7014631],
        },
        'properties': {
          'osm_type': 'R',
          'osm_id': 165475,
          'osm_key': 'place',
          'osm_value': 'state',
          'type': 'state',
          'name': 'California',
          'country': 'United States',
          'countrycode': 'US',
        },
      };

      final place = PhotonPlace.fromJson(geoJson);

      expect(place.isState, isTrue);
      expect(place.isCity, isFalse);
      expect(place.primaryTitle, equals('California'));
      expect(place.secondarySubtitle, equals('United States'));
      expect(place.stateFormattedName, equals('California'));
    });

    test('Correctly handles Canadian province with place:province', () {
      final geoJson = {
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [-86.000977, 50.000678],
        },
        'properties': {
          'osm_type': 'R',
          'osm_id': 68841,
          'osm_key': 'place',
          'osm_value': 'province',
          'type': 'state',
          'name': 'Ontario',
          'country': 'Canada',
          'countrycode': 'CA',
        },
      };

      final place = PhotonPlace.fromJson(geoJson);

      expect(place.isState, isTrue);
      expect(place.primaryTitle, equals('Ontario'));
      expect(place.stateFormattedName, equals('Ontario'));
      expect(place.country, equals('Canada'));
    });

    test('Gracefully handles missing, null, or empty fields', () {
      final geoJson = {
        'type': 'Feature',
        'geometry': {'type': 'Point', 'coordinates': []},
        'properties': <String, dynamic>{},
      };

      final place = PhotonPlace.fromJson(geoJson);

      expect(place.name, isEmpty);
      expect(place.latitude, equals(0.0));
      expect(place.longitude, equals(0.0));
      expect(place.street, isNull);
      expect(place.city, isNull);
      expect(place.state, isNull);
      expect(place.country, isNull);
      expect(place.primaryTitle, isEmpty);
      expect(place.secondarySubtitle, isEmpty);
      expect(place.formattedAddress, isEmpty);
    });
  });
}
