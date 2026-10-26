// lib/providers/favorites_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'providers.dart';

final optimizedFavoritesProvider = StateNotifierProvider<OptimizedFavoritesNotifier, Set<String>>((ref) {
  return OptimizedFavoritesNotifier(ref);
});

class OptimizedFavoritesNotifier extends StateNotifier<Set<String>> {
  final Ref ref;
  String? _currentUserId;

  OptimizedFavoritesNotifier(this.ref) : super({}) {
    _initialize();
  }

  void _initialize() {
    ref.listen<User?>(currentUserProvider, (previous, next) {
      if (next?.uid != _currentUserId) {
        _currentUserId = next?.uid;
        if (_currentUserId != null) {
          _loadFavorites();
        } else {
          state = {};
        }
      }
    });

    final user = ref.read(currentUserProvider);
    if (user != null) {
      _currentUserId = user.uid;
      _loadFavorites();
    }
  }

  Future<void> _loadFavorites() async {
    if (_currentUserId == null) return;
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final favoriteIds = await firestoreService
          .getFavoriteSpotIds(_currentUserId!)
          .first;
      state = favoriteIds.toSet();
    } catch (e) {
      print('❌ Error cargando favoritos: $e');
    }
  }

  Future<void> toggle(String spotId) async {
    if (_currentUserId == null) return;

    final wasFavorite = state.contains(spotId);

    // 1️⃣ Actualización inmediata en UI
    if (wasFavorite) {
      state = {...state}..remove(spotId);
    } else {
      state = {...state, spotId};
    }

    // 2️⃣ Sincronizar con Firebase
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      await firestoreService.toggleFavorite(_currentUserId!, spotId);
    } catch (e) {
      print('❌ Error sincronizando favorito: $e');
      // 3️⃣ Revertir si falla
      if (wasFavorite) {
        state = {...state, spotId};
      } else {
        state = {...state}..remove(spotId);
      }
      rethrow;
    }
  }

  bool isFavorite(String spotId) => state.contains(spotId);

  void reset() {
    state = {};
    _currentUserId = null;
  }
}