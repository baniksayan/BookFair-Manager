import 'package:flutter/foundation.dart';

/// Structured domain model representing a geocoded location candidate returned by
/// the Photon Geocoding API (Komoot / OpenStreetMap).
///
/// Encapsulates GeoJSON feature properties and point coordinates.
///
/// IMPORTANT: OpenStreetMap GeoJSON coordinates are ordered as:
/// - index 0: Longitude
/// - index 1: Latitude
@immutable
class PhotonPlace {
  const PhotonPlace({
    required this.name,
    this.street,
    this.housenumber,
    this.postcode,
    this.district,
    this.locality,
    this.city,
    this.state,
    this.country,
    this.countryCode,
    this.osmId,
    this.osmType,
    this.osmKey,
    this.osmValue,
    this.type,
    required this.latitude,
    required this.longitude,
  });

  /// Factory constructor to parse a GeoJSON Feature object.
  factory PhotonPlace.fromJson(Map<String, dynamic> json) {
    final properties = json['properties'] as Map<String, dynamic>? ?? {};
    final geometry = json['geometry'] as Map<String, dynamic>? ?? {};
    final coordinates =
        geometry['coordinates'] as List<dynamic>? ?? const [0.0, 0.0];

    // GeoJSON specification: coordinates = [longitude, latitude]
    final double lon = coordinates.isNotEmpty
        ? (coordinates[0] as num).toDouble()
        : 0.0;
    final double lat = coordinates.length > 1
        ? (coordinates[1] as num).toDouble()
        : 0.0;

    int? parsedOsmId;
    final rawOsmId = properties['osm_id'];
    if (rawOsmId is int) {
      parsedOsmId = rawOsmId;
    } else if (rawOsmId != null) {
      parsedOsmId = int.tryParse(rawOsmId.toString());
    }

    return PhotonPlace(
      name:
          (properties['name'] as String?)?.trim() ??
          (properties['street'] as String?)?.trim() ??
          '',
      street: (properties['street'] as String?)?.trim(),
      housenumber: (properties['housenumber'] as String?)?.trim(),
      postcode: (properties['postcode'] as String?)?.trim(),
      district:
          (properties['district'] as String?)?.trim() ??
          (properties['locality'] as String?)?.trim(),
      locality: (properties['locality'] as String?)?.trim(),
      city: (properties['city'] as String?)?.trim(),
      state: (properties['state'] as String?)?.trim(),
      country: (properties['country'] as String?)?.trim(),
      countryCode: (properties['countrycode'] as String?)?.trim().toUpperCase(),
      osmId: parsedOsmId,
      osmType: (properties['osm_type'] as String?)?.trim(),
      osmKey: (properties['osm_key'] as String?)?.trim(),
      osmValue: (properties['osm_value'] as String?)?.trim(),
      type: (properties['type'] as String?)?.trim(),
      latitude: lat,
      longitude: lon,
    );
  }

  final String name;
  final String? street;
  final String? housenumber;
  final String? postcode;
  final String? district;
  final String? locality;
  final String? city;
  final String? state;
  final String? country;
  final String? countryCode;
  final int? osmId;
  final String? osmType;
  final String? osmKey;
  final String? osmValue;
  final String? type;

  /// Latitude coordinate (Y-axis / North-South).
  final double latitude;

  /// Longitude coordinate (X-axis / East-West).
  final double longitude;

  /// Primary display label for autocomplete suggestion rows.
  String get primaryTitle {
    if (name.isNotEmpty) return name;
    if (street != null && street!.isNotEmpty) {
      if (housenumber != null && housenumber!.isNotEmpty) {
        return '$housenumber $street';
      }
      return street!;
    }
    if (city != null && city!.isNotEmpty) return city!;
    if (state != null && state!.isNotEmpty) return state!;
    return country ?? '';
  }

  /// Secondary subtitle with contextual administrative hierarchy
  /// (e.g. "J.B.S. Haldane Avenue, Park Circus, Kolkata, West Bengal, India").
  String get secondarySubtitle {
    final parts = <String>[];

    // Include street/address if distinct from primary title
    if (street != null && street!.isNotEmpty && street != name) {
      if (housenumber != null && housenumber!.isNotEmpty) {
        parts.add('$housenumber $street');
      } else {
        parts.add(street!);
      }
    }

    if (district != null && district!.isNotEmpty && district != name) {
      parts.add(district!);
    }

    if (city != null && city!.isNotEmpty && city != name) {
      parts.add(city!);
    }

    if (state != null && state!.isNotEmpty && state != name) {
      parts.add(state!);
    }

    if (country != null && country!.isNotEmpty && country != name) {
      parts.add(country!);
    }

    return parts.join(', ');
  }

  /// Full formatted address string composed of all available place details.
  String get formattedAddress {
    final parts = <String>[];

    if (name.isNotEmpty) {
      parts.add(name);
    }

    if (street != null && street!.isNotEmpty && street != name) {
      if (housenumber != null && housenumber!.isNotEmpty) {
        parts.add('$housenumber $street');
      } else {
        parts.add(street!);
      }
    }

    if (district != null && district!.isNotEmpty && !parts.contains(district)) {
      parts.add(district!);
    }

    if (city != null && city!.isNotEmpty && !parts.contains(city)) {
      parts.add(city!);
    }

    if (state != null && state!.isNotEmpty && !parts.contains(state)) {
      parts.add(state!);
    }

    if (postcode != null && postcode!.isNotEmpty && !parts.contains(postcode)) {
      parts.add(postcode!);
    }

    if (country != null && country!.isNotEmpty && !parts.contains(country)) {
      parts.add(country!);
    }

    return parts.join(', ');
  }

  /// Formatted text specifically when populating the Location / Venue field.
  /// Combines place name and street/address for clarity.
  String get venueFormattedName {
    if (name.isEmpty) return formattedAddress;
    if (street != null && street!.isNotEmpty && street != name) {
      if (housenumber != null && housenumber!.isNotEmpty) {
        return '$name, $housenumber $street';
      }
      return '$name, $street';
    }
    return name;
  }

  /// Formatted text specifically when populating the City field.
  String get cityFormattedName {
    if (city != null && city!.isNotEmpty) return city!;
    if (isCity) return name;
    return name;
  }

  /// Formatted text specifically when populating the State / Province field.
  String get stateFormattedName {
    if (state != null && state!.isNotEmpty) return state!;
    if (isState) return name;
    return name;
  }

  /// Whether this result represents a settlement (city, town, village, municipality, or hamlet).
  bool get isCity {
    if (type == 'city') return true;
    final val = osmValue?.toLowerCase();
    if (val == 'city' ||
        val == 'town' ||
        val == 'village' ||
        val == 'municipality' ||
        val == 'hamlet') {
      return true;
    }
    return false;
  }

  /// Whether this result represents an administrative region (state, province, region, or canton).
  bool get isState {
    if (type == 'state') return true;
    final val = osmValue?.toLowerCase();
    if (val == 'state' ||
        val == 'province' ||
        val == 'region' ||
        val == 'canton') {
      return true;
    }
    return false;
  }

  Map<String, dynamic> toJson() {
    return {
      'type': 'Feature',
      'geometry': {
        'type': 'Point',
        'coordinates': [longitude, latitude],
      },
      'properties': {
        'name': name,
        'street': street,
        'housenumber': housenumber,
        'postcode': postcode,
        'district': district,
        'locality': locality,
        'city': city,
        'state': state,
        'country': country,
        'countrycode': countryCode,
        'osm_id': osmId,
        'osm_type': osmType,
        'osm_key': osmKey,
        'osm_value': osmValue,
        'type': type,
      },
    };
  }

  @override
  String toString() =>
      'PhotonPlace(name: $name, city: $city, state: $state, lat: $latitude, lon: $longitude)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhotonPlace &&
          runtimeType == other.runtimeType &&
          osmId == other.osmId &&
          name == other.name &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => Object.hash(osmId, name, latitude, longitude);
}
