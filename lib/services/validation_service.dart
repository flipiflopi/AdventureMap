// lib/services/validation_service.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/spot_model.dart';

class ValidationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const double MIN_DISTANCE_METERS = 10.0;

  double calculateDistance(
      double lat1,
      double lon1,
      double lat2,
      double lon2,
      ) {
    const double earthRadius = 6371000;

    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * pi / 180;
  }

  // NUEVO: Separar spots del mismo usuario de los de otros
  Future<ValidationResult> findNearbyOrSimilarSpots({
    required double latitude,
    required double longitude,
    required String name,
    required String currentUserId,
  }) async {
    try {
      print('🔍 Buscando spots cercanos...');

      // ✅ FILTRAR SPOTS NO ARCHIVADOS
      final snapshot = await _firestore
          .collection('spots')
          .where('isArchived', isEqualTo: false)
          .get();

      print('📊 Total spots activos en BD: ${snapshot.docs.length}');

      final ownSpots = <SpotModel>[];
      final otherSpots = <SpotModel>[];

      for (var doc in snapshot.docs) {
        try {
          final spot = SpotModel.fromFirestore(doc);

          if (spot.name.isEmpty || spot.latitude == 0.0 || spot.longitude == 0.0) {
            print('⚠️ Spot ${doc.id} tiene datos incompletos, ignorando...');
            continue;
          }

          final distance = calculateDistance(
            latitude,
            longitude,
            spot.latitude,
            spot.longitude,
          );

          print('📍 Distancia a "${spot.name}": ${distance.toStringAsFixed(2)}m');

          final isNearby = distance <= MIN_DISTANCE_METERS;

if (isNearby) {
            // Separar por creador
            if (spot.createdBy == currentUserId) {
              print('✅ Spot propio encontrado: ${spot.name}');
              ownSpots.add(spot);
            } else {
              print('✅ Spot de otro usuario encontrado: ${spot.name}');
              otherSpots.add(spot);
            }
          }
        } catch (e) {
          print('⚠️ Error al procesar spot ${doc.id}: $e');
          continue;
        }
      }

      print('✅ Spots propios: ${ownSpots.length}');
      print('✅ Spots de otros: ${otherSpots.length}');

      return ValidationResult(
        ownSpots: ownSpots,
        otherUserSpots: otherSpots,
      );
    } catch (e) {
      print('❌ Error en findNearbyOrSimilarSpots: $e');
      return ValidationResult(ownSpots: [], otherUserSpots: []);
    }
  }

  bool _isSimilarName(String name1, String name2) {
    final n1 = name1.toLowerCase().trim();
    final n2 = name2.toLowerCase().trim();

    if (n1 == n2) return true;
    if (n1.contains(n2) || n2.contains(n1)) return true;

    final similarity = _levenshteinSimilarity(n1, n2);
    return similarity > 0.7;
  }

  double _levenshteinSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    final distance = _levenshteinDistance(s1, s2);
    final maxLength = max(s1.length, s2.length);

    return 1.0 - (distance / maxLength);
  }

  int _levenshteinDistance(String s1, String s2) {
    final len1 = s1.length;
    final len2 = s2.length;

    final matrix = List.generate(
      len1 + 1,
          (i) => List.filled(len2 + 1, 0),
    );

    for (var i = 0; i <= len1; i++) {
      matrix[i][0] = i;
    }

    for (var j = 0; j <= len2; j++) {
      matrix[0][j] = j;
    }

    for (var i = 1; i <= len1; i++) {
      for (var j = 1; j <= len2; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = min(
          min(matrix[i - 1][j] + 1, matrix[i][j - 1] + 1),
          matrix[i - 1][j - 1] + cost,
        );
      }
    }

    return matrix[len1][len2];
  }

  bool hasExactLocation(
      List<SpotModel> nearbySpots,
      double latitude,
      double longitude,
      ) {
    for (var spot in nearbySpots) {
      final distance = calculateDistance(
        latitude,
        longitude,
        spot.latitude,
        spot.longitude,
      );

      if (distance < 5.0) {
        return true;
      }
    }
    return false;
  }

  Future<bool> isUserModerator(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      return userDoc.data()?['isModerator'] == true;
    } catch (e) {
      return false;
    }
  }
}

// Clase para devolver resultados separados
class ValidationResult {
  final List<SpotModel> ownSpots;
  final List<SpotModel> otherUserSpots;

  ValidationResult({
    required this.ownSpots,
    required this.otherUserSpots,
  });

  bool get hasOwnSpots => ownSpots.isNotEmpty;
  bool get hasOtherUserSpots => otherUserSpots.isNotEmpty;
  bool get hasAnySpots => hasOwnSpots || hasOtherUserSpots;
}