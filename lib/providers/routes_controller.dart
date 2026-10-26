// lib/providers/routes_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/spot_model.dart';
import '../services/firestore_service.dart';
import 'providers.dart';

class RoutesController extends StateNotifier<AsyncValue<void>> {
  final FirestoreService _firestoreService;
  final Ref _ref;

  RoutesController(this._firestoreService, this._ref)
      : super(const AsyncValue.data(null));

  Future<bool> createRoute({
    required String name,
    required String description,
    required List<String> spotIds,
    required String userId,
  }) async {
    state = const AsyncValue.loading();
    try {
      final route = RouteModel(
        id: '',
        name: name,
        description: description,
        spotIds: spotIds,
        createdBy: userId,
        createdAt: DateTime.now(),
      );

      await _firestoreService.createRoute(route);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }

  Future<void> updateRoute(String routeId, List<String> spotIds) async {
    await _firestoreService.updateRoute(routeId, {'spotIds': spotIds});
  }

  Future<void> deleteRoute(String routeId) async {
    await _firestoreService.deleteRoute(routeId);
  }
}

final routesControllerProvider = StateNotifierProvider<RoutesController, AsyncValue<void>>((ref) {
  return RoutesController(
    ref.watch(firestoreServiceProvider),
    ref,
  );
});