// lib/providers/providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../services/location_service.dart';
import '../services/folder_service.dart';
import '../services/friends_service.dart';

// Modelos
// ⬇️ OCULTAMOS la versión vieja para que no choque con la oficial
import '../models/spot_model.dart' hide UserProfileModel; 
import '../models/user_profile_model.dart'; // ⬅️ IMPORTAMOS LA VERSIÓN OFICIAL
import '../models/folder_model.dart';
import '../models/spot_suggestion_model.dart';
import '../models/friend_request_model.dart';

// 🆕 EXPORT del provider optimizado
export 'favorites_provider.dart';

// ============================================
// AUTH PROVIDERS
// ============================================
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).value;
});

// ============================================
// SERVICE PROVIDERS
// ============================================
final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

final folderServiceProvider = Provider<FolderService>((ref) {
  return FolderService();
});

final friendsServiceProvider = Provider<FriendsService>((ref) {
  return FriendsService();
});

// ============================================
// SPOTS PROVIDERS
// ============================================
final allSpotsProvider = StreamProvider<List<SpotModel>>((ref) {
  return ref.watch(firestoreServiceProvider).getAllSpots();
});

final spotsByCategoryProvider = StreamProvider.family<List<SpotModel>, SpotCategory>((ref, category) {
  return ref.watch(firestoreServiceProvider).getSpotsByCategory(category);
});

final userCreatedSpotsProvider = StreamProvider.family<List<SpotModel>, String>((ref, userId) {
  return ref.watch(firestoreServiceProvider).getUserCreatedSpotsStream(userId);
});

final archivedSpotsProvider = StreamProvider<List<SpotModel>>((ref) {
  return ref.watch(firestoreServiceProvider).getArchivedSpots();
});

// ============================================
// FAVORITES PROVIDERS
// ============================================
final favoriteSpotsProvider = StreamProvider.family<List<String>, String>((ref, userId) {
  return ref.watch(firestoreServiceProvider).getFavoriteSpotIds(userId);
});

// ============================================
// FOLDERS PROVIDERS
// ============================================
final userFoldersProvider = StreamProvider.family<List<FolderModel>, String>((ref, userId) {
  return ref.watch(folderServiceProvider).getUserFolders(userId);
});

final folderSpotsProvider = StreamProvider.family<List<SpotModel>, String>((ref, folderId) {
  return ref.watch(folderServiceProvider).getFolderSpotsStream(folderId);
});

// ============================================
// MODERATION PROVIDERS
// ============================================
final pendingSpotsProvider = StreamProvider<List<PendingSpot>>((ref) {
  return ref.watch(firestoreServiceProvider).getPendingSpots();
});

final pendingSuggestionsForUserProvider = StreamProvider.family<List<SpotSuggestion>, String>((ref, userId) {
  return ref.watch(firestoreServiceProvider).getPendingSuggestionsForUser(userId);
});

// ============================================
// ROUTES PROVIDERS
// ============================================
final userRoutesProvider = StreamProvider.family<List<RouteModel>, String>((ref, userId) {
  return ref.watch(firestoreServiceProvider).getUserRoutes(userId);
});

// ============================================
// USER PROFILE PROVIDER (CORREGIDO)
// ============================================
final userProfileProvider = StreamProvider.family<UserProfileModel?, String>((ref, userId) {
  return ref.watch(firestoreServiceProvider).getUserProfileStream(userId);
});

// ============================================
// LOCATION SERVICE PROVIDER
// ============================================
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

// ============================================
// FRIEND REQUESTS PROVIDERS (CORREGIDO)
// ============================================
final receivedFriendRequestsProvider = StreamProvider.family<List<FriendRequest>, String>((ref, userId) {
  return ref.watch(friendsServiceProvider).getReceivedRequests(userId);
});

final sentFriendRequestsProvider = StreamProvider.family<List<FriendRequest>, String>((ref, userId) {
  return ref.watch(friendsServiceProvider).getSentRequests(userId);
});

final friendsListProvider = FutureProvider.family<List<UserProfileModel>, String>((ref, userId) {
  return ref.watch(friendsServiceProvider).getFriendsProfiles(userId);
});

final friendshipStatusProvider = FutureProvider.family<FriendshipStatus, ({String userId, String otherUserId})>((ref, params) {
  return ref.watch(friendsServiceProvider).checkFriendshipStatus(params.userId, params.otherUserId);
});

// ============================================
// MAP & FILTER PROVIDERS
// ============================================
final navigationIndexProvider = StateProvider<int>((ref) => 0);

final filteredSpotsProvider = StateProvider<SpotCategory?>((ref) => null);

final displayedSpotsProvider = Provider<List<SpotModel>>((ref) {
  final allSpots = ref.watch(allSpotsProvider).value ?? [];
  final filter = ref.watch(filteredSpotsProvider);

  if (filter == null) {
    return allSpots;
  }

  return allSpots.where((spot) => spot.category == filter).toList();
});