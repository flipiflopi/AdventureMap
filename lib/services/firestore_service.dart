// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/spot_model.dart' hide UserProfileModel; // ⬅️ OCULTAMOS la versión vieja aquí
import '../models/spot_suggestion_model.dart';
import '../models/spot_report_model.dart';
import 'notification_service.dart';
import '../models/comment_report_model.dart';
import '../models/folder_model.dart';
import '../models/user_profile_model.dart'; // ⬅️ Usamos ESTA versión como la oficial

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  // ============================================
  // SPOTS
  // ============================================

  Future<String> createSpot(SpotModel spot) async {
    final batch = _firestore.batch();
    final spotRef = _firestore.collection('spots').doc();
    batch.set(spotRef, spot.toFirestore());

    final userRef = _firestore.collection('users').doc(spot.createdBy);
    batch.update(userRef, {
      'adventureScore': FieldValue.increment(5),
    });

    await batch.commit();
    return spotRef.id;
  }

  Future<String> createPendingSpot(PendingSpot pendingSpot) async {
    final docRef = await _firestore
        .collection('pending_spots')
        .add(pendingSpot.toFirestore());
    return docRef.id;
  }

  Future<void> updateSpot(String spotId, Map<String, dynamic> data) async {
    await _firestore.collection('spots').doc(spotId).update(data);
  }

  Future<void> deleteSpot(String spotId) async {
    final spot = await getSpotById(spotId);
    if (spot != null) {
      await _firestore.collection('users').doc(spot.createdBy).update({
        'adventureScore': FieldValue.increment(-5),
      });
    }
    await _firestore.collection('spots').doc(spotId).delete();
  }

  Stream<List<SpotModel>> getAllSpots() {
    return _firestore
        .collection('spots')
        .where('isArchived', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => SpotModel.fromFirestore(doc)).toList());
  }

  Future<void> archiveSpot(String spotId, String userId) async {
    final userProfile = await getUserProfile(userId);
    if (userProfile?.isModerator != true) {
      throw Exception('errorOnlyModerators');
    }
    await _firestore.collection('spots').doc(spotId).update({'isArchived': true});
  }

  Future<void> unarchiveSpot(String spotId, String userId) async {
    final userProfile = await getUserProfile(userId);
    if (userProfile?.isModerator != true) {
      throw Exception('errorOnlyModerators');
    }
    await _firestore.collection('spots').doc(spotId).update({
      'isArchived': false,
    });
  }

  Future<void> permanentlyDeleteSpot(String spotId) async {
    await _firestore.collection('spots').doc(spotId).delete();
  }

  Stream<List<SpotModel>> getArchivedSpots() {
    return _firestore
        .collection('spots')
        .where('isArchived', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => SpotModel.fromFirestore(doc)).toList());
  }

  Future<SpotModel?> getSpotById(String spotId) async {
    final doc = await _firestore.collection('spots').doc(spotId).get();
    if (doc.exists) {
      return SpotModel.fromFirestore(doc);
    }
    return null;
  }

  Stream<List<SpotModel>> getSpotsByCategory(SpotCategory category) {
    return _firestore
        .collection('spots')
        .where('category', isEqualTo: category.name)
        .where('isArchived', isEqualTo: false)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => SpotModel.fromFirestore(doc)).toList());
  }

  Future<List<SpotModel>> searchSpotsByName(String query) async {
    final snapshot = await _firestore
        .collection('spots')
        .where('isArchived', isEqualTo: false)
        .orderBy('name')
        .startAt([query])
        .endAt([query + '\uf8ff'])
        .get();

    return snapshot.docs.map((doc) => SpotModel.fromFirestore(doc)).toList();
  }

  Future<List<SpotModel>> getUserCreatedSpots(String userId) async {
    final snapshot = await _firestore
        .collection('spots')
        .where('createdBy', isEqualTo: userId)
        .where('isArchived', isEqualTo: false)
        .get();

    final spots = snapshot.docs.map((doc) => SpotModel.fromFirestore(doc)).toList();
    spots.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return spots;
  }

  Stream<List<SpotModel>> getUserCreatedSpotsStream(String userId) {
    return _firestore
        .collection('spots')
        .where('createdBy', isEqualTo: userId)
        .where('isArchived', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
      final spots = snapshot.docs.map((doc) => SpotModel.fromFirestore(doc)).toList();
      spots.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return spots;
    });
  }

  Future<void> updateSpotComplete(String spotId, SpotModel spot) async {
    await _firestore
        .collection('spots')
        .doc(spotId)
        .update(spot.toFirestore());
  }

  // ============================================
  // SUGGESTIONS
  // ============================================

  Future<String> createSuggestion(
  SpotSuggestion suggestion, {
  String? notifTitle,
  String? notifBody,
}) async {
  final docRef = await _firestore.collection('spot_suggestions').add(suggestion.toFirestore());
  final spot = await getSpotById(suggestion.spotId);

  if (spot != null && suggestion.suggestedBy != spot.createdBy) {
    final userProfile = await getUserProfile(suggestion.suggestedBy);
    final userName = userProfile?.displayNameOrEmail ?? 'Un usuario';

    // 🌍 Enviar notificación SIN title/body (Cloud Function los generará)
    await _notificationService.sendSuggestionNotification(
      spotOwnerId: spot.createdBy,
      spotId: suggestion.spotId,
      spotName: spot.name,
      suggestionId: docRef.id,
      userWhoSuggestedId: suggestion.suggestedBy,
      userWhoSuggestedName: userName,
      title: '', // ← Vacío, Cloud Function lo genera
      body: '', // ← Vacío, Cloud Function lo genera
    );
  }
  return docRef.id;
}

  Stream<List<SpotSuggestion>> getSuggestionsMadeByUser(String userId) {
    return _firestore
        .collection('spot_suggestions')
        .where('suggestedBy', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SpotSuggestion.fromFirestore(doc))
            .toList());
  }

  Stream<List<SpotSuggestion>> getSuggestionsForSpot(String spotId) {
    return _firestore
        .collection('spot_suggestions')
        .where('spotId', isEqualTo: spotId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SpotSuggestion.fromFirestore(doc))
            .toList());
  }

  Stream<List<SpotSuggestion>> getPendingSuggestionsForUser(String userId) {
    return _firestore
        .collection('spot_suggestions')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .asyncMap((snapshot) async {
      final suggestions = <SpotSuggestion>[];
      for (var doc in snapshot.docs) {
        final suggestion = SpotSuggestion.fromFirestore(doc);
        final spot = await getSpotById(suggestion.spotId);
        if (spot != null && spot.createdBy == userId) {
          suggestions.add(suggestion);
        }
      }
      return suggestions;
    });
  }

  Future<void> approveSuggestion(
  String suggestionId,
  String reviewerId,
  String spotId,
  Map<String, dynamic> updates, {
  String? notifTitle,
  String? notifBody,
}) async {
  final batch = _firestore.batch();
  final suggestionDoc = await _firestore.collection('spot_suggestions').doc(suggestionId).get();
  final suggestion = SpotSuggestion.fromFirestore(suggestionDoc);
  final spot = await getSpotById(spotId);

  batch.update(_firestore.collection('spot_suggestions').doc(suggestionId), {
    'status': 'approved',
    'reviewedBy': reviewerId,
    'reviewedAt': FieldValue.serverTimestamp(),
  });

  batch.update(_firestore.collection('spots').doc(spotId), updates);
  await batch.commit();

  if (spot != null && suggestion.suggestedBy != reviewerId) {
    // 🌍 Enviar notificación SIN title/body
    await _notificationService.sendSuggestionReviewedNotification(
      userId: suggestion.suggestedBy,
      spotId: spotId,
      spotName: spot.name,
      isApproved: true,
      title: '',
      body: '',
    );
  }
}

Future<void> rejectSuggestion(
  String suggestionId,
  String reviewerId,
  String comment, {
  String? notifTitle,
  String? notifBody,
}) async {
  final suggestionDoc = await _firestore.collection('spot_suggestions').doc(suggestionId).get();
  final suggestion = SpotSuggestion.fromFirestore(suggestionDoc);
  final spot = await getSpotById(suggestion.spotId);

  await _firestore.collection('spot_suggestions').doc(suggestionId).update({
    'status': 'rejected',
    'reviewedBy': reviewerId,
    'reviewedAt': FieldValue.serverTimestamp(),
    'reviewComment': comment,
  });

  if (spot != null && suggestion.suggestedBy != reviewerId) {
    // 🌍 Enviar notificación SIN title/body
    await _notificationService.sendSuggestionReviewedNotification(
      userId: suggestion.suggestedBy,
      spotId: suggestion.spotId,
      spotName: spot.name,
      isApproved: false,
      title: '',
      body: '',
    );
  }
}


  // ============================================
  // MODERATION
  // ============================================

  Stream<List<PendingSpot>> getPendingSpots() {
    return _firestore
        .collection('pending_spots')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => PendingSpot.fromFirestore(doc)).toList());
  }

  Future<void> approvePendingSpot(
  String pendingSpotId,
  String moderatorId, {
  String? notifTitle,
  String? notifBody,
}) async {
  final pendingDoc = await _firestore.collection('pending_spots').doc(pendingSpotId).get();
  if (!pendingDoc.exists) throw Exception('errorSpotNotFound');

  final pendingSpot = PendingSpot.fromFirestore(pendingDoc);
  final spot = SpotModel(
    id: '',
    name: pendingSpot.name,
    details: pendingSpot.description,
    access: pendingSpot.access,
    safety: pendingSpot.safety,
    category: SpotCategory.values.firstWhere(
      (e) => e.name == pendingSpot.category,
      orElse: () => SpotCategory.other,
    ),
    latitude: pendingSpot.latitude,
    longitude: pendingSpot.longitude,
    photoUrls: pendingSpot.photoUrls,
    createdBy: pendingSpot.createdBy,
    createdAt: pendingSpot.createdAt,
  );

  final batch = _firestore.batch();
  final spotRef = _firestore.collection('spots').doc();
  batch.set(spotRef, spot.toFirestore());

  final userRef = _firestore.collection('users').doc(pendingSpot.createdBy);
  batch.update(userRef, {'adventureScore': FieldValue.increment(5)});

  batch.update(_firestore.collection('pending_spots').doc(pendingSpotId), {
    'status': 'approved',
    'reviewedBy': moderatorId,
    'reviewedAt': FieldValue.serverTimestamp(),
  });

  await batch.commit();

  // 🌍 Enviar notificación SIN title/body
  await _notificationService.sendSpotApprovedNotification(
    userId: pendingSpot.createdBy,
    spotId: spotRef.id,
    spotName: pendingSpot.name,
    title: '',
    body: '',
  );
}

  Future<void> rejectPendingSpot(String pendingSpotId, String moderatorId, String reason) async {
    await _firestore.collection('pending_spots').doc(pendingSpotId).update({
      'status': 'rejected',
      'reviewedBy': moderatorId,
      'reviewedAt': FieldValue.serverTimestamp(),
      'rejectionReason': reason,
    });
  }

  // ============================================
  // COMMENT REPORTS
  // ============================================

  Future<void> createCommentReport(CommentReport report) async {
    await _firestore.collection('comment_reports').add(report.toMap());
  }

  Stream<List<CommentReport>> getPendingCommentReports() {
    return _firestore
        .collection('comment_reports')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CommentReport.fromMap(doc.id, doc.data()))
            .toList());
  }

  Future<void> resolveCommentReport(String reportId, String moderatorId, String moderatorComment) async {
    await _firestore.collection('comment_reports').doc(reportId).update({
      'status': 'resolved',
      'resolvedBy': moderatorId,
      'resolvedAt': FieldValue.serverTimestamp(),
      'moderatorComment': moderatorComment,
    });
  }

  Future<void> dismissCommentReport(String reportId, String moderatorId, String moderatorComment) async {
    await _firestore.collection('comment_reports').doc(reportId).update({
      'status': 'dismissed',
      'resolvedBy': moderatorId,
      'resolvedAt': FieldValue.serverTimestamp(),
      'moderatorComment': moderatorComment,
    });
  }

  Future<SpotComment?> getCommentById(String commentId) async {
    final doc = await _firestore.collection('spot_comments').doc(commentId).get();
    if (!doc.exists) return null;
    return SpotComment.fromFirestore(doc);
  }

  // ============================================
  // FAVORITES
  // ============================================

  Future<void> toggleFavorite(
  String userId,
  String spotId, {
  String? notifTitle,
  String? notifBody,
}) async {
  final batch = _firestore.batch();
  final userDoc = _firestore.collection('users').doc(userId);
  final userData = await userDoc.get();

  List<String> favorites = List<String>.from(userData.data()?['favoriteSpots'] ?? []);
  final spot = await getSpotById(spotId);
  if (spot == null) return;

  final userProfile = await getUserProfile(userId);
  final userName = userProfile?.displayNameOrEmail ?? 'Un usuario';

  if (favorites.contains(spotId)) {
    // Quitar de favoritos
    favorites.remove(spotId);
    batch.update(_firestore.collection('spots').doc(spotId), {'favoriteCount': FieldValue.increment(-1)});
    batch.update(_firestore.collection('users').doc(spot.createdBy), {'adventureScore': FieldValue.increment(-2)});
  } else {
    // Añadir a favoritos
    favorites.add(spotId);
    batch.update(_firestore.collection('spots').doc(spotId), {'favoriteCount': FieldValue.increment(1)});
    batch.update(_firestore.collection('users').doc(spot.createdBy), {'adventureScore': FieldValue.increment(2)});

    // 🌍 Enviar notificación SIN title/body
    if (userId != spot.createdBy) {
      await _notificationService.sendFavoriteNotification(
        spotOwnerId: spot.createdBy,
        spotId: spotId,
        spotName: spot.name,
        userWhoLikedId: userId,
        userWhoLikedName: userName,
        title: '',
        body: '',
      );
    }
  }
  
  batch.update(userDoc, {'favoriteSpots': favorites});
  await batch.commit();
}

  Stream<List<String>> getFavoriteSpotIds(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) => List<String>.from(doc.data()?['favoriteSpots'] ?? []));
  }

  Future<List<SpotModel>> getFavoriteSpots(String userId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    final favoriteIds = List<String>.from(userDoc.data()?['favoriteSpots'] ?? []);
    if (favoriteIds.isEmpty) return [];
    final spots = await Future.wait(favoriteIds.map((id) => getSpotById(id)));
    return spots.whereType<SpotModel>().toList();
  }

  // ============================================
  // ROUTES
  // ============================================

  Future<String> createRoute(RouteModel route) async {
    final docRef = await _firestore.collection('routes').add(route.toFirestore());
    return docRef.id;
  }

  Future<void> updateRoute(String routeId, Map<String, dynamic> data) async {
    await _firestore.collection('routes').doc(routeId).update(data);
  }

  Future<void> deleteRoute(String routeId) async {
    await _firestore.collection('routes').doc(routeId).delete();
  }

  Stream<List<RouteModel>> getUserRoutes(String userId) {
    return _firestore
        .collection('routes')
        .where('createdBy', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => RouteModel.fromFirestore(doc)).toList());
  }

  Future<RouteModel?> getRouteById(String routeId) async {
    final doc = await _firestore.collection('routes').doc(routeId).get();
    return doc.exists ? RouteModel.fromFirestore(doc) : null;
  }

  // ============================================
  // USER PROFILE
  // ============================================

  Future<UserProfileModel?> getUserProfile(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    return doc.exists ? UserProfileModel.fromFirestore(doc) : null;
  }

  Stream<UserProfileModel?> getUserProfileStream(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      return doc.exists ? UserProfileModel.fromFirestore(doc) : null;
    });
  }

  Future<void> updateUserProfile(String userId, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(userId).update(data);
  }

  Future<void> setUserModerator(String userId, bool isModerator) async {
    await _firestore.collection('users').doc(userId).update({'isModerator': isModerator});
  }

  Future<void> updateAdventureScore(String userId, int scoreToAdd) async {
    await _firestore.collection('users').doc(userId).update({'adventureScore': FieldValue.increment(scoreToAdd)});
  }

  // ============================================
  // SPOT REPORTS
  // ============================================

  Future<String> createSpotReport(SpotReport report) async {
    final docRef = await _firestore.collection('spot_reports').add(report.toFirestore());
    return docRef.id;
  }

  Stream<List<SpotReport>> getPendingReports() {
    return _firestore
        .collection('spot_reports')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => SpotReport.fromFirestore(doc)).toList());
  }

  Future<SpotReport?> getReportById(String reportId) async {
    final doc = await _firestore.collection('spot_reports').doc(reportId).get();
    return doc.exists ? SpotReport.fromFirestore(doc) : null;
  }

  Future<void> resolveReport(String reportId, String moderatorId, String comment) async {
    await _firestore.collection('spot_reports').doc(reportId).update({
      'status': 'resolved',
      'reviewedBy': moderatorId,
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewComment': comment,
    });
  }

  Future<void> dismissReport(String reportId, String moderatorId, String comment) async {
    await _firestore.collection('spot_reports').doc(reportId).update({
      'status': 'dismissed',
      'reviewedBy': moderatorId,
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewComment': comment,
    });
  }

  Future<List<SpotReport>> getReportsForSpot(String spotId) async {
    final snapshot = await _firestore
        .collection('spot_reports')
        .where('spotId', isEqualTo: spotId)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((doc) => SpotReport.fromFirestore(doc)).toList();
  }

  // ============================================
  // RATINGS
  // ============================================

  Future<SpotRating?> getUserRatingForSpot(String userId, String spotId) async {
    final snapshot = await _firestore
        .collection('spot_ratings')
        .where('userId', isEqualTo: userId)
        .where('spotId', isEqualTo: spotId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return SpotRating.fromFirestore(snapshot.docs.first);
  }

  Future<void> rateSpot({required String spotId, required String userId, required int rating}) async {
    if (rating < 1 || rating > 5) throw Exception('errorRatingRange');
    final existingRating = await getUserRatingForSpot(userId, spotId);
    if (existingRating != null) {
      await _firestore.collection('spot_ratings').doc(existingRating.id).update({
        'rating': rating,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      final newRating = SpotRating(id: '', spotId: spotId, userId: userId, rating: rating, createdAt: DateTime.now());
      await _firestore.collection('spot_ratings').add(newRating.toFirestore());
    }
    await _recalculateSpotRating(spotId);
  }

  Future<void> _recalculateSpotRating(String spotId) async {
    final snapshot = await _firestore.collection('spot_ratings').where('spotId', isEqualTo: spotId).get();
    if (snapshot.docs.isEmpty) {
      await _firestore.collection('spots').doc(spotId).update({'ratingAverage': 0.0, 'ratingCount': 0});
      return;
    }
    int totalRating = 0;
    for (var doc in snapshot.docs) {
      totalRating += (doc.data()['rating'] as int);
    }
    await _firestore.collection('spots').doc(spotId).update({
      'ratingAverage': totalRating / snapshot.docs.length,
      'ratingCount': snapshot.docs.length,
    });
  }

  // ============================================
  // COMMENTS
  // ============================================

  Stream<List<SpotComment>> getSpotComments(String spotId, {int limit = 10}) {
    return _firestore
        .collection('spot_comments')
        .where('spotId', isEqualTo: spotId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => SpotComment.fromFirestore(doc)).toList());
  }

  Future<List<SpotComment>> getMoreComments(String spotId, DateTime lastCommentDate, int limit) async {
    final snapshot = await _firestore
        .collection('spot_comments')
        .where('spotId', isEqualTo: spotId)
        .orderBy('createdAt', descending: true)
        .startAfter([Timestamp.fromDate(lastCommentDate)])
        .limit(limit)
        .get();
    return snapshot.docs.map((doc) => SpotComment.fromFirestore(doc)).toList();
  }

  Future<String> createComment({
  required String spotId,
  required String userId,
  required String userName,
  String? userPhoto,
  required String comment,
  String? notifTitle,
  String? notifBody,
}) async {
  if (comment.trim().isEmpty) throw Exception('errorCommentEmpty');
  if (comment.length > 500) throw Exception('errorCommentTooLong');

  final newComment = SpotComment(
    id: '',
    spotId: spotId,
    userId: userId,
    userName: userName,
    userPhoto: userPhoto,
    comment: comment.trim(),
    createdAt: DateTime.now(),
  );

  final docRef = await _firestore.collection('spot_comments').add(newComment.toFirestore());
  final spot = await getSpotById(spotId);

  if (spot != null && spot.createdBy != userId) {
    final preview = comment.length > 50 ? comment.substring(0, 50) + '...' : comment;
    
    // 🌍 Enviar notificación CON commentPreview pero SIN title/body
    await _notificationService.sendCommentNotification(
      spotOwnerId: spot.createdBy,
      spotId: spotId,
      spotName: spot.name,
      userWhoCommentedId: userId,
      userWhoCommentedName: userName,
      commentPreview: preview,
      title: '',
      body: '',
    );
  }
  
  return docRef.id;
}

  Future<void> updateComment(String commentId, String newComment) async {
    if (newComment.trim().isEmpty) throw Exception('errorCommentEmpty');
    await _firestore.collection('spot_comments').doc(commentId).update({
      'comment': newComment.trim(),
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteComment(String commentId) async {
    await _firestore.collection('spot_comments').doc(commentId).delete();
  }

  Stream<SpotModel?> getSpotStream(String spotId) {
    return _firestore.collection('spots').doc(spotId).snapshots().map((doc) {
      return doc.exists ? SpotModel.fromFirestore(doc) : null;
    });
  }

  Future<int> getCommentCount(String spotId) async {
    final snapshot = await _firestore.collection('spot_comments').where('spotId', isEqualTo: spotId).count().get();
    return snapshot.count ?? 0;
  }
}