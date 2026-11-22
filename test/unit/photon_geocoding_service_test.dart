import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bookfair_manager/core/services/geocoding/photon_geocoding_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test Fake for [HttpClientResponse]
class FakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  FakeHttpClientResponse(this.body, {this.statusCode = 200});

  final String body;
  @override
  final int statusCode;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream.value(utf8.encode(body)).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  HttpHeaders get headers => throw UnimplementedError();

  @override
  int get contentLength => utf8.encode(body).length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  String get reasonPhrase => 'OK';

  @override
  bool get isRedirect => false;

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  Future<HttpClientResponse> redirect([
    String? method,
    Uri? url,
    bool? followLoops,
  ]) => throw UnimplementedError();

  @override
  bool get persistentConnection => true;

  @override
  X509Certificate? get certificate => null;

  @override
  HttpConnectionInfo? get connectionInfo => null;

  @override
  List<Cookie> get cookies => const [];

  @override
  Future<Socket> detachSocket() => throw UnimplementedError();
}

/// Test Fake for [HttpClientRequest]
class FakeHttpClientRequest implements HttpClientRequest {
  FakeHttpClientRequest(this.response);

  final HttpClientResponse response;
  final HttpHeaders _headers = _FakeHttpHeaders();

  @override
  HttpHeaders get headers => _headers;

  @override
  Future<HttpClientResponse> close() async => response;

  @override
  void add(List<int> data) {}

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<List<int>> stream) async {}

  @override
  Encoding get encoding => utf8;
  @override
  set encoding(Encoding value) {}

  @override
  Future<void> flush() async {}

  @override
  void write(Object? object) {}

  @override
  void writeAll(Iterable objects, [String separator = ""]) {}

  @override
  void writeCharCode(int charCode) {}

  @override
  void writeln([Object? object = ""]) {}

  @override
  bool get bufferOutput => true;
  @override
  set bufferOutput(bool value) {}

  @override
  int get contentLength => 0;
  @override
  set contentLength(int value) {}

  @override
  bool get followRedirects => true;
  @override
  set followRedirects(bool value) {}

  @override
  int get maxRedirects => 5;
  @override
  set maxRedirects(int value) {}

  @override
  bool get persistentConnection => true;
  @override
  set persistentConnection(bool value) {}

  @override
  Future<HttpClientResponse> get done async => response;

  @override
  HttpConnectionInfo? get connectionInfo => null;

  @override
  List<Cookie> get cookies => const [];

  @override
  String get method => 'GET';

  @override
  Uri get uri => Uri.parse('https://photon.komoot.io/api/');

  @override
  void abort([Object? exception, StackTrace? stackTrace]) {}
}

class _FakeHttpHeaders implements HttpHeaders {
  final Map<String, List<String>> _data = {};

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _data[name] = [value.toString()];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Test Fake for [HttpClient]
class FakeHttpClient implements HttpClient {
  FakeHttpClient({required this.handler});

  final Future<HttpClientResponse> Function(Uri uri) handler;
  int requestCount = 0;
  Uri? lastRequestedUri;

  @override
  Duration? connectionTimeout;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    requestCount++;
    lastRequestedUri = url;
    final res = await handler(url);
    return FakeHttpClientRequest(res);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('PhotonGeocodingService Unit Tests', () {
    test(
      'Short query under 2 characters returns empty list without network call',
      () async {
        final fakeClient = FakeHttpClient(
          handler: (uri) async => FakeHttpClientResponse('{"features": []}'),
        );
        final service = PhotonGeocodingServiceImpl(httpClient: fakeClient);

        final results = await service.search(query: 'a');

        expect(results, isEmpty);
        expect(fakeClient.requestCount, equals(0));
      },
    );

    test('Parses GeoJSON features and respects limit', () async {
      final sampleResponse = json.encode({
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [88.3638, 22.5726],
            },
            'properties': {
              'osm_id': 101,
              'osm_type': 'R',
              'name': 'Kolkata',
              'type': 'city',
              'state': 'West Bengal',
              'country': 'India',
            },
          },
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [88.4156, 22.5904],
            },
            'properties': {
              'osm_id': 102,
              'osm_type': 'N',
              'name': 'Central Park',
              'street': '4th Cross Road',
              'city': 'Bidhannagar',
              'state': 'West Bengal',
              'country': 'India',
            },
          },
        ],
      });

      final fakeClient = FakeHttpClient(
        handler: (uri) async => FakeHttpClientResponse(sampleResponse),
      );
      final service = PhotonGeocodingServiceImpl(httpClient: fakeClient);

      final results = await service.search(
        query: 'Kolkata',
        type: PhotonSearchType.venue,
        limit: 8,
      );

      expect(results.length, equals(2));
      expect(results[0].name, equals('Kolkata'));
      expect(results[0].longitude, equals(88.3638));
      expect(results[0].latitude, equals(22.5726));
      expect(results[1].name, equals('Central Park'));
      expect(fakeClient.requestCount, equals(1));
    });

    test(
      'In-memory cache returns cached response without duplicate HTTP calls',
      () async {
        final sampleResponse = json.encode({
          'type': 'FeatureCollection',
          'features': [
            {
              'type': 'Feature',
              'geometry': {
                'type': 'Point',
                'coordinates': [88.3638, 22.5726],
              },
              'properties': {
                'osm_id': 101,
                'name': 'Kolkata',
                'type': 'city',
                'state': 'West Bengal',
                'country': 'India',
              },
            },
          ],
        });

        final fakeClient = FakeHttpClient(
          handler: (uri) async => FakeHttpClientResponse(sampleResponse),
        );
        final service = PhotonGeocodingServiceImpl(httpClient: fakeClient);

        // First query triggers HTTP request
        final first = await service.search(query: 'Kolkata');
        expect(first.length, equals(1));
        expect(fakeClient.requestCount, equals(1));

        // Second identical query uses in-memory cache
        final second = await service.search(query: 'Kolkata');
        expect(second.length, equals(1));
        expect(second[0].name, equals('Kolkata'));
        expect(fakeClient.requestCount, equals(1)); // Count remains 1!
      },
    );

    test(
      'City search prioritizes settlement/city entities above POIs',
      () async {
        final mixedResponse = json.encode({
          'type': 'FeatureCollection',
          'features': [
            // POI / Railway Station appearing first in raw response
            {
              'type': 'Feature',
              'geometry': {
                'type': 'Point',
                'coordinates': [88.3841, 22.6012],
              },
              'properties': {
                'osm_id': 501,
                'name': 'Kolkata Railway Station',
                'osm_key': 'railway',
                'osm_value': 'station',
                'type': 'house',
                'city': 'Kolkata',
                'state': 'West Bengal',
                'country': 'India',
              },
            },
            // Actual City settlement appearing second in raw response
            {
              'type': 'Feature',
              'geometry': {
                'type': 'Point',
                'coordinates': [88.3638, 22.5726],
              },
              'properties': {
                'osm_id': 502,
                'name': 'Kolkata',
                'osm_key': 'place',
                'osm_value': 'city',
                'type': 'city',
                'city': 'Kolkata',
                'state': 'West Bengal',
                'country': 'India',
              },
            },
          ],
        });

        final fakeClient = FakeHttpClient(
          handler: (uri) async => FakeHttpClientResponse(mixedResponse),
        );
        final service = PhotonGeocodingServiceImpl(httpClient: fakeClient);

        final results = await service.search(
          query: 'Kolkata',
          type: PhotonSearchType.city,
        );

        expect(results.length, equals(2));
        // Actual city settlement MUST be prioritized to the top!
        expect(results[0].name, equals('Kolkata'));
        expect(results[0].isCity, isTrue);
        expect(results[1].name, equals('Kolkata Railway Station'));
      },
    );

    test('State search prioritizes administrative states/provinces', () async {
      final mixedResponse = json.encode({
        'type': 'FeatureCollection',
        'features': [
          // University appearing first
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [88.4104, 22.5609],
            },
            'properties': {
              'osm_id': 601,
              'name': 'West Bengal National University of Juridical Sciences',
              'osm_key': 'amenity',
              'osm_value': 'university',
              'type': 'house',
              'state': 'West Bengal',
              'country': 'India',
            },
          },
          // State region appearing second
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [87.6855, 22.9964],
            },
            'properties': {
              'osm_id': 602,
              'name': 'West Bengal',
              'osm_key': 'place',
              'osm_value': 'state',
              'type': 'state',
              'country': 'India',
            },
          },
        ],
      });

      final fakeClient = FakeHttpClient(
        handler: (uri) async => FakeHttpClientResponse(mixedResponse),
      );
      final service = PhotonGeocodingServiceImpl(httpClient: fakeClient);

      final results = await service.search(
        query: 'West Bengal',
        type: PhotonSearchType.state,
      );

      expect(results.length, equals(2));
      // Actual state MUST be prioritized first
      expect(results[0].name, equals('West Bengal'));
      expect(results[0].isState, isTrue);
      expect(
        results[1].name,
        contains('West Bengal National University of Juridical Sciences'),
      );
    });

    test('Geographic coordinates are correctly attached as lat/lon bias query parameters', () async {
      final fakeClient = FakeHttpClient(
        handler: (uri) async => FakeHttpClientResponse('{"features": []}'),
      );
      final service = PhotonGeocodingServiceImpl(httpClient: fakeClient);

      await service.search(
        query: 'Central Park',
        latitude: 22.5867,
        longitude: 88.4178,
      );

      expect(fakeClient.lastRequestedUri, isNotNull);
      final uri = fakeClient.lastRequestedUri!;
      expect(uri.queryParameters['q'], equals('Central Park'));
      expect(uri.queryParameters['lat'], equals('22.5867'));
      expect(uri.queryParameters['lon'], equals('88.4178'));
    });

    test('Network failures or non-200 responses return empty list gracefully without throwing', () async {
      final errorClient = FakeHttpClient(
        handler: (uri) async =>
            FakeHttpClientResponse('Server Error', statusCode: 500),
      );
      final service = PhotonGeocodingServiceImpl(httpClient: errorClient);

      final results = await service.search(query: 'Kolkata');
      expect(results, isEmpty);
    });

    test('SocketException returns empty list gracefully', () async {
      final socketErrorClient = FakeHttpClient(
        handler: (uri) async => throw const SocketException('Network offline'),
      );
      final service = PhotonGeocodingServiceImpl(httpClient: socketErrorClient);

      final results = await service.search(query: 'Kolkata');
      expect(results, isEmpty);
    });
  });
}
