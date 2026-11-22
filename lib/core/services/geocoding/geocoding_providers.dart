import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'photon_geocoding_service.dart';

/// Riverpod provider for the [PhotonGeocodingService].
final photonGeocodingServiceProvider = Provider<PhotonGeocodingService>((ref) {
  return PhotonGeocodingServiceImpl();
});
