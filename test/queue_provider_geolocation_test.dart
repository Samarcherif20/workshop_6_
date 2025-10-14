import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../lib/queue_provider.dart';
import '../lib/geolocation_service.dart';
import 'queue_provider_geolocation_test.mocks.dart';

/// Génère un mock pour GeolocationService
@GenerateMocks([GeolocationService])
void main() {
  group('QueueProvider - Geolocation tests', () {
    test('addClient saves client with geolocation', () async {
      // Arrange
      final mockGeo = MockGeolocationService();

      // Créer un mock de position
      final mockPos = Position(
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        floor: null,
        isMocked: false,
      );

      // Simuler la position récupérée
      when(mockGeo.getCurrentPosition()).thenAnswer((_) async => mockPos);

      // Injecter le mock dans le provider
      final provider = QueueProvider(geoService: mockGeo);

      // Act
      await provider.addClient('Test User');

      // Assert
      final client = provider.clients.last;
      expect(client['name'], 'Test User');
      expect(client['lat'], 37.7749);
      expect(client['lng'], -122.4194);
      expect(client['is_synced'], 0);

      // Vérifier que la méthode de géolocalisation a été appelée
      verify(mockGeo.getCurrentPosition()).called(1);
    });

    test('addClient handles missing geolocation', () async {
      // Arrange
      final mockGeo = MockGeolocationService();

      // Simuler qu'on ne peut pas obtenir la position
      when(mockGeo.getCurrentPosition()).thenAnswer((_) async => null);

      final provider = QueueProvider(geoService: mockGeo);

      // Act
      await provider.addClient('User Sans GPS');

      // Assert
      final client = provider.clients.last;
      expect(client['name'], 'User Sans GPS');
      expect(client['lat'], null);
      expect(client['lng'], null);

      verify(mockGeo.getCurrentPosition()).called(1);
    });
  });
}
