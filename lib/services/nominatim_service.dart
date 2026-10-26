// lib/services/nominatim_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class LocationSuggestion {
  final String displayName;
  final double latitude;
  final double longitude;
  final String type;

  LocationSuggestion({
    required this.displayName,
    required this.latitude,
    required this.longitude,
    required this.type,
  });

  factory LocationSuggestion.fromJson(Map<String, dynamic> json) {
    return LocationSuggestion(
      displayName: json['display_name'] ?? '',
      latitude: double.parse(json['lat'] ?? '0'),
      longitude: double.parse(json['lon'] ?? '0'),
      type: json['type'] ?? 'place',
    );
  }
}

class NominatimService {
  static const String _baseUrl = 'https://nominatim.openstreetmap.org';

  static const Map<String, String> _headers = {
    'User-Agent': 'AdventureMapApp/1.0',
  };

  /// Buscar ubicaciones por texto
  /// 🌍 Se añade [languageCode] (ej: 'es', 'en') para recibir resultados localizados
  Future<List<LocationSuggestion>> searchLocation(String query, {String languageCode = 'en'}) async {
    if (query.length < 3) return [];

    try {
      final url = Uri.parse(
        '$_baseUrl/search?q=$query&format=json&addressdetails=1&limit=5&accept-language=$languageCode',
      );

      final response = await http.get(url, headers: _headers);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data
            .map((item) => LocationSuggestion.fromJson(item))
            .toList();
      } else {
        print('Error Nominatim: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error buscando ubicación: $e');
      return [];
    }
  }

  /// Obtener dirección desde coordenadas (geocodificación inversa)
  /// 🌍 Se añade [languageCode] para que la dirección venga en el idioma correcto
  Future<String?> getAddressFromCoordinates(double lat, double lng, {String languageCode = 'en'}) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/reverse?lat=$lat&lon=$lng&format=json&accept-language=$languageCode',
      );

      final response = await http.get(url, headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['display_name'];
      }
      return null;
    } catch (e) {
      print('Error obteniendo dirección: $e');
      return null;
    }
  }
}