// lib/models/spot_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // 🆕 i18n
import 'notification_models.dart';

// ============================================
// SPOT MODEL
// ============================================
class SpotModel {
  final String id;
  final String name;

  // DESCRIPCIÓN DIVIDIDA EN 3 CAMPOS
  final String details;      // Descripción general
  final String access;       // Cómo llegar
  final String safety;       // Seguridad y precauciones

  final SpotCategory category;
  final double latitude;
  final double longitude;
  final List<String> photoUrls;
  final String createdBy;
  final DateTime createdAt;
  final int favoriteCount;
  final bool isArchived;

  // RATING
  final double ratingAverage;  // Promedio de valoraciones
  final int ratingCount;       // Número de valoraciones

  SpotModel({
    required this.id,
    required this.name,
    required this.details,
    this.access = '',
    this.safety = '',
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.photoUrls,
    required this.createdBy,
    required this.createdAt,
    this.favoriteCount = 0,
    this.isArchived = false,
    this.ratingAverage = 0.0,
    this.ratingCount = 0,
  });

  // Getter para compatibilidad con código viejo
  String get description => details;

  factory SpotModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // MIGRACIÓN: Si existe 'description' viejo, usarlo en 'details'
    final oldDescription = data['description'] as String?;
    final newDetails = data['details'] as String?;

    return SpotModel(
      id: doc.id,
      name: data['name'] ?? '',
      details: newDetails ?? oldDescription ?? '',
      access: data['access'] ?? '',
      safety: data['safety'] ?? '',
      category: SpotCategory.values.firstWhere(
            (e) => e.name == data['category'],
        orElse: () => SpotCategory.other,
      ),
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      photoUrls: List<String>.from(data['photoUrls'] ?? []),
      createdBy: data['createdBy'] ?? '',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      favoriteCount: data['favoriteCount'] ?? 0,
      isArchived: data['isArchived'] ?? false,
      ratingAverage: (data['ratingAverage'] ?? 0.0).toDouble(),
      ratingCount: data['ratingCount'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'details': details,
      'access': access,
      'safety': safety,
      'category': category.name,
      'latitude': latitude,
      'longitude': longitude,
      'photoUrls': photoUrls,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'favoriteCount': favoriteCount,
      'isArchived': isArchived,
      'ratingAverage': ratingAverage,
      'ratingCount': ratingCount,
    };
  }

  SpotModel copyWith({
    String? id,
    String? name,
    String? details,
    String? access,
    String? safety,
    SpotCategory? category,
    double? latitude,
    double? longitude,
    List<String>? photoUrls,
    String? createdBy,
    DateTime? createdAt,
    int? favoriteCount,
    bool? isArchived,
    double? ratingAverage,
    int? ratingCount,
  }) {
    return SpotModel(
      id: id ?? this.id,
      name: name ?? this.name,
      details: details ?? this.details,
      access: access ?? this.access,
      safety: safety ?? this.safety,
      category: category ?? this.category,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      photoUrls: photoUrls ?? this.photoUrls,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      favoriteCount: favoriteCount ?? this.favoriteCount,
      isArchived: isArchived ?? this.isArchived,
      ratingAverage: ratingAverage ?? this.ratingAverage,
      ratingCount: ratingCount ?? this.ratingCount,
    );
  }
}

// ============================================
// RATING MODEL
// ============================================
class SpotRating {
  final String id;
  final String spotId;
  final String userId;
  final int rating;           // 1-5 estrellas
  final DateTime createdAt;

  SpotRating({
    required this.id,
    required this.spotId,
    required this.userId,
    required this.rating,
    required this.createdAt,
  });

  factory SpotRating.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return SpotRating(
      id: doc.id,
      spotId: data['spotId'] ?? '',
      userId: data['userId'] ?? '',
      rating: data['rating'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'spotId': spotId,
      'userId': userId,
      'rating': rating,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

// ============================================
// COMMENT MODEL
// ============================================
class SpotComment {
  final String id;
  final String spotId;
  final String userId;
  final String userName;
  final String? userPhoto;
  final String comment;
  final DateTime createdAt;
  final DateTime? editedAt;

  SpotComment({
    required this.id,
    required this.spotId,
    required this.userId,
    required this.userName,
    this.userPhoto,
    required this.comment,
    required this.createdAt,
    this.editedAt,
  });

  factory SpotComment.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return SpotComment(
      id: doc.id,
      spotId: data['spotId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userPhoto: data['userPhoto'],
      comment: data['comment'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      editedAt: data['editedAt'] != null
          ? (data['editedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'spotId': spotId,
      'userId': userId,
      'userName': userName,
      'userPhoto': userPhoto,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
      'editedAt': editedAt != null ? Timestamp.fromDate(editedAt!) : null,
    };
  }
}

// ============================================
// ENUMS INTERNACIONALIZADOS
// ============================================
enum SpotCategory {
  surf,
  snorkel,
  cliffJumping,
  caves,
  naturalPool,
  viewpoint,
  sunset,
  other;

  // 🌍 Obtiene el nombre según el idioma del dispositivo
  String getLocalizedName(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      case SpotCategory.surf: return l10n.catSurf;
      case SpotCategory.snorkel: return l10n.catSnorkel;
      case SpotCategory.cliffJumping: return l10n.catCliffJumping;
      case SpotCategory.caves: return l10n.catCaves;
      case SpotCategory.naturalPool: return l10n.catNaturalPool;
      case SpotCategory.viewpoint: return l10n.catViewpoint;
      case SpotCategory.sunset: return l10n.catSunset;
      case SpotCategory.other: return l10n.catOther;
    }
  }

  String get icon {
    switch (this) {
      case SpotCategory.surf: return '🏄';
      case SpotCategory.snorkel: return '🤿';
      case SpotCategory.cliffJumping: return '🤸';
      case SpotCategory.caves: return '🕳️';
      case SpotCategory.naturalPool: return '💧';
      case SpotCategory.viewpoint: return '🏔️';
      case SpotCategory.sunset: return '🌅';
      case SpotCategory.other: return '📍';
    }
  }
}

// ============================================
// USER PROFILE MODEL
// ============================================
class UserProfileModel {
  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final List<String> favoriteSpots;
  final DateTime createdAt;
  final bool isModerator;
  final int adventureScore;
  final List<String> friends;
  final String? fcmToken;
  final DateTime? fcmTokenUpdatedAt;
  final NotificationPreferences? notificationPreferences;

  UserProfileModel({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.favoriteSpots = const [],
    required this.createdAt,
    this.isModerator = false,
    this.adventureScore = 0,
    this.friends = const [],
    this.fcmToken,
    this.fcmTokenUpdatedAt,
    this.notificationPreferences,
  });

  factory UserProfileModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserProfileModel(
      uid: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'],
      photoUrl: data['photoUrl'],
      favoriteSpots: List<String>.from(data['favoriteSpots'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isModerator: data['isModerator'] ?? false,
      adventureScore: data['adventureScore'] ?? 0,
      friends: List<String>.from(data['friends'] ?? []),
      fcmToken: data['fcmToken'] as String?,
      fcmTokenUpdatedAt: (data['fcmTokenUpdatedAt'] as Timestamp?)?.toDate(),
      notificationPreferences: data['notificationPreferences'] != null
          ? NotificationPreferences.fromFirestore(
          data['notificationPreferences'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'favoriteSpots': favoriteSpots,
      'createdAt': Timestamp.fromDate(createdAt),
      'isModerator': isModerator,
      'adventureScore': adventureScore,
      'friends': friends,
      'fcmToken': fcmToken,
      'fcmTokenUpdatedAt': fcmTokenUpdatedAt != null
          ? Timestamp.fromDate(fcmTokenUpdatedAt!)
          : null,
      'notificationPreferences': notificationPreferences?.toFirestore(),
    };
  }

  UserProfileModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    List<String>? favoriteSpots,
    DateTime? createdAt,
    bool? isModerator,
    int? adventureScore,
    List<String>? friends,
    String? fcmToken,
    DateTime? fcmTokenUpdatedAt,
    NotificationPreferences? notificationPreferences,
  }) {
    return UserProfileModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      favoriteSpots: favoriteSpots ?? this.favoriteSpots,
      createdAt: createdAt ?? this.createdAt,
      isModerator: isModerator ?? this.isModerator,
      adventureScore: adventureScore ?? this.adventureScore,
      friends: friends ?? this.friends,
      fcmToken: fcmToken ?? this.fcmToken,
      fcmTokenUpdatedAt: fcmTokenUpdatedAt ?? this.fcmTokenUpdatedAt,
      notificationPreferences: notificationPreferences ?? this.notificationPreferences,
    );
  }

  String get displayNameOrEmail => displayName ?? email.split('@')[0];
}

// ============================================
// ROUTE MODEL
// ============================================
class RouteModel {
  final String id;
  final String name;
  final String description;
  final List<String> spotIds;
  final String createdBy;
  final DateTime createdAt;
  final String? imageUrl;

  RouteModel({
    required this.id,
    required this.name,
    required this.description,
    required this.spotIds,
    required this.createdBy,
    required this.createdAt,
    this.imageUrl,
  });

  factory RouteModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return RouteModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      spotIds: List<String>.from(data['spotIds'] ?? []),
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      imageUrl: data['imageUrl'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'spotIds': spotIds,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'imageUrl': imageUrl,
    };
  }

  RouteModel copyWith({
    String? id,
    String? name,
    String? description,
    List<String>? spotIds,
    String? createdBy,
    DateTime? createdAt,
    String? imageUrl,
  }) {
    return RouteModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      spotIds: spotIds ?? this.spotIds,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}