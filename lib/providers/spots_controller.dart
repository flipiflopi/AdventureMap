// lib/providers/spots_controller.dart
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/spot_model.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import 'providers.dart';

class SpotsController extends StateNotifier<AsyncValue<void>> {
  final FirestoreService _firestoreService;
  final StorageService _storageService;
  final Ref _ref;

  SpotsController(this._firestoreService, this._storageService, this._ref)
      : super(const AsyncValue.data(null));

  // 🆕 MÉTODO ACTUALIZADO CON LOS 3 CAMPOS
  Future<bool> createSpot({
    required String name,
    required String details,      // 🆕 Renombrado de description
    String access = '',            // 🆕 Nuevo campo opcional
    String safety = '',            // 🆕 Nuevo campo opcional
    required SpotCategory category,
    required double latitude,
    required double longitude,
    required List<File> images,
    required String userId,
  }) async {
    state = const AsyncValue.loading();
    try {
      print('🔥 Iniciando creación de spot...');

      // Primero crear el spot en Firestore para obtener el ID real
      final tempSpot = SpotModel(
        id: '', // Firestore asignará el ID
        name: name,
        details: details,    // 🆕 Usar details
        access: access,      // 🆕 Nuevo campo
        safety: safety,      // 🆕 Nuevo campo
        category: category,
        latitude: latitude,
        longitude: longitude,
        photoUrls: [], // Vacío por ahora
        createdBy: userId,
        createdAt: DateTime.now(),
      );

      print('📝 Guardando spot en Firestore...');
      final spotId = await _firestoreService.createSpot(tempSpot);
      print('✅ Spot guardado con ID: $spotId');

      // Ahora subir las imágenes con el ID real
      print('📸 Subiendo ${images.length} imágenes...');
      List<String> photoUrls = [];
      for (var i = 0; i < images.length; i++) {
        print('📤 Subiendo imagen ${i + 1}/${images.length}...');
        final url = await _storageService.uploadSpotImage(images[i], spotId);
        photoUrls.add(url);
        print('✅ Imagen ${i + 1} subida: $url');
      }

      // Actualizar el spot con las URLs de las imágenes
      print('🔄 Actualizando spot con URLs de imágenes...');
      await _firestoreService.updateSpot(spotId, {
        'photoUrls': photoUrls,
      });

      print('🎉 Spot creado exitosamente!');
      state = const AsyncValue.data(null);

      // Refrescar la lista de spots
      _ref.invalidate(allSpotsProvider);

      return true;
    } catch (e, stack) {
      print('❌ Error al crear spot: $e');
      print('Stack trace: $stack');
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  Future<void> toggleFavorite(String userId, String spotId) async {
    try {
      print('💛 Iniciando toggle favorito...');
      print('   userId: $userId');
      print('   spotId: $spotId');

      await _firestoreService.toggleFavorite(userId, spotId);

      print('✅ Toggle favorito completado');

      // 🆕 Invalidar el provider de favoritos para forzar actualización
      _ref.invalidate(favoriteSpotsProvider(userId));

    } catch (e, stack) {
      print('❌ Error al alternar favorito: $e');
      print('Stack trace: $stack');
      rethrow; // Propagar el error para que se vea en la UI
    }
  }

  Future<List<SpotModel>> searchSpots(String query) async {
    try {
      return await _firestoreService.searchSpotsByName(query);
    } catch (e) {
      print('❌ Error buscando spots: $e');
      return [];
    }
  }
}

final spotsControllerProvider = StateNotifierProvider<SpotsController, AsyncValue<void>>((ref) {
  return SpotsController(
    ref.watch(firestoreServiceProvider),
    ref.watch(storageServiceProvider),
    ref,
  );
});