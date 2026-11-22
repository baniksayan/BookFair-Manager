import 'dart:convert';
import 'dart:io';

import 'photon_place.dart';

/// Filter category to contextualize autocomplete queries across form fields.
enum PhotonSearchType {
  /// General venues, buildings, landmarks, exhibition grounds, streets.
  venue,

  /// Cities, towns, villages, and municipalities worldwide.
  city,

  /// States, provinces, administrative regions, and cantons.
  state,
}

/// Abstract contract for Photon Geocoding operations.
abstract class PhotonGeocodingService {
  /// Fetches place suggestions for [query] matching [type].
  ///
  /// [latitude] and [longitude] provide optional geographic biasing.
  /// [limit] caps maximum returned results (default 8).
  Future<List<PhotonPlace>> search({
    required String query,
    PhotonSearchType type = PhotonSearchType.venue,
    double? latitude,
    double? longitude,
    int limit = 8,
    String lang = 'en',
  });

  /// Optional reverse geocoding to resolve coordinates to a [PhotonPlace].
  Future<PhotonPlace?> reverseGeocode({
    required double latitude,
    required double longitude,
    String lang = 'en',
  });

  /// Clears in-memory cache.
  void clearCache();
}

/// Production implementation of [PhotonGeocodingService] querying the official
/// Komoot Photon OpenStreetMap API endpoint (`https://photon.komoot.io/api/`).
///
/// Features:
/// - In-memory LRU query cache to avoid redundant network calls.
/// - Graceful offline and network failure handling.
/// - Type-specific result prioritization for city and state/province lookups.
/// - Coordinate ordering preservation (lon = 0, lat = 1).
class PhotonGeocodingServiceImpl implements PhotonGeocodingService {
  PhotonGeocodingServiceImpl({HttpClient? httpClient})
    : _client = httpClient ?? HttpClient() {
    _client.connectionTimeout = const Duration(seconds: 4);
  }

  final HttpClient _client;

  static const String _authority = 'photon.komoot.io';
  static const String _apiPath = '/api/';
  static const String _reversePath = '/reverse';
  static const String _userAgent =
      'BookFairManager/1.0 (Komoot Photon Geocoding Client)';

  /// In-memory LRU cache storing recent search results.
  final Map<String, List<PhotonPlace>> _cache = {};
  static const int _maxCacheEntries = 60;

  @override
  void clearCache() {
    _cache.clear();
  }

  @override
  Future<List<PhotonPlace>> search({
    required String query,
    PhotonSearchType type = PhotonSearchType.venue,
    double? latitude,
    double? longitude,
    int limit = 8,
    String lang = 'en',
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const [];

    final cacheKey = _buildCacheKey(
      query: trimmed,
      type: type,
      latitude: latitude,
      longitude: longitude,
      limit: limit,
      lang: lang,
    );

    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    // For city and state searches, request a slightly larger pool from Photon (up to 12)
    // so we can reliably prioritize city/state administrative entities client-side.
    final requestLimit = (type == PhotonSearchType.venue) ? limit : 12;

    final queryParams = <String, String>{
      'q': trimmed,
      'limit': requestLimit.toString(),
      'lang': lang,
    };

    if (latitude != null && longitude != null) {
      queryParams['lat'] = latitude.toString();
      queryParams['lon'] = longitude.toString();
    }

    try {
      final uri = Uri.https(_authority, _apiPath, queryParams);
      final request = await _client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader, _userAgent);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');

      final response = await request.close().timeout(
        const Duration(seconds: 5),
      );

      if (response.statusCode != 200) {
        return const [];
      }

      final responseBody = await response.transform(utf8.decoder).join();
      final data = json.decode(responseBody) as Map<String, dynamic>;
      final rawFeatures = data['features'] as List<dynamic>? ?? const [];

      final places = <PhotonPlace>[];
      for (final item in rawFeatures) {
        if (item is Map<String, dynamic>) {
          try {
            places.add(PhotonPlace.fromJson(item));
          } catch (_) {
            // Skip malformed individual features
          }
        }
      }

      final prioritized = _prioritizeResults(places, type, trimmed, limit);

      // Store in memory cache
      _putInCache(cacheKey, prioritized);

      return prioritized;
    } catch (_) {
      // Gracefully return empty list on any socket, timeout, or parsing error
      return const [];
    }
  }

  @override
  Future<PhotonPlace?> reverseGeocode({
    required double latitude,
    required double longitude,
    String lang = 'en',
  }) async {
    final queryParams = <String, String>{
      'lat': latitude.toString(),
      'lon': longitude.toString(),
      'lang': lang,
    };

    try {
      final uri = Uri.https(_authority, _reversePath, queryParams);
      final request = await _client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader, _userAgent);

      final response = await request.close().timeout(
        const Duration(seconds: 5),
      );

      if (response.statusCode != 200) return null;

      final responseBody = await response.transform(utf8.decoder).join();
      final data = json.decode(responseBody) as Map<String, dynamic>;
      final rawFeatures = data['features'] as List<dynamic>? ?? const [];

      if (rawFeatures.isNotEmpty && rawFeatures.first is Map<String, dynamic>) {
        return PhotonPlace.fromJson(rawFeatures.first as Map<String, dynamic>);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Prioritizes candidates according to the targeted search type.
  List<PhotonPlace> _prioritizeResults(
    List<PhotonPlace> places,
    PhotonSearchType type,
    String query,
    int limit,
  ) {
    if (places.isEmpty) return const [];

    switch (type) {
      case PhotonSearchType.city:
        final qLower = query.toLowerCase();

        int scoreCity(PhotonPlace p) {
          final isExactSettlement =
              p.isCity &&
              (p.name.toLowerCase() == qLower ||
                  p.city?.toLowerCase() == qLower);
          if (isExactSettlement) return 100;
          if (p.isCity) return 80;
          if (p.name.toLowerCase() == qLower) return 60;
          if (p.city?.toLowerCase() == qLower) return 40;
          return 10;
        }

        final sorted = List<PhotonPlace>.from(places);
        sorted.sort((a, b) => scoreCity(b).compareTo(scoreCity(a)));
        return sorted.take(limit).toList();

      case PhotonSearchType.state:
        final qLower = query.toLowerCase();

        int scoreState(PhotonPlace p) {
          final isExactState =
              p.isState &&
              (p.name.toLowerCase() == qLower ||
                  p.state?.toLowerCase() == qLower);
          if (isExactState) return 100;
          if (p.isState) return 80;
          if (p.name.toLowerCase() == qLower) return 60;
          if (p.state?.toLowerCase() == qLower) return 40;
          return 10;
        }

        final sorted = List<PhotonPlace>.from(places);
        sorted.sort((a, b) => scoreState(b).compareTo(scoreState(a)));
        return sorted.take(limit).toList();

      case PhotonSearchType.venue:
        return places.take(limit).toList();
    }
  }

  String _buildCacheKey({
    required String query,
    required PhotonSearchType type,
    double? latitude,
    double? longitude,
    required int limit,
    required String lang,
  }) {
    final latStr = latitude != null ? latitude.toStringAsFixed(2) : '';
    final lonStr = longitude != null ? longitude.toStringAsFixed(2) : '';
    return '${type.name}:$query:$latStr:$lonStr:$limit:$lang';
  }

  void _putInCache(String key, List<PhotonPlace> results) {
    if (_cache.length >= _maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = results;
  }
}
