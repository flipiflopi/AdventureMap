// lib/models/notification_models.dart
import 'package:cloud_firestore/cloud_firestore.dart';

// ==========================================
// PREFERENCIAS DE NOTIFICACIONES
// ==========================================

class NotificationPreferences {
  final bool favoriteAdded;        // Cuando alguien marca tu spot como favorito
  final bool spotSuggestion;       // Cuando alguien sugiere cambios a tu spot
  final bool friendRequest;        // Cuando alguien te envía solicitud de amistad
  final bool spotApproved;         // Cuando aprueban tu spot pendiente
  final bool suggestionReviewed;   // Cuando revisan tu sugerencia
  final bool spotComment;  // 🆕 NUEVO


  NotificationPreferences({
    this.favoriteAdded = true,
    this.spotSuggestion = true,
    this.friendRequest = true,
    this.spotApproved = true,
    this.suggestionReviewed = true,
    this.spotComment = true,  // 🆕 NUEVO

  });

  Map<String, dynamic> toFirestore() {
    return {
      'favoriteAdded': favoriteAdded,
      'spotSuggestion': spotSuggestion,
      'friendRequest': friendRequest,
      'spotApproved': spotApproved,
      'suggestionReviewed': suggestionReviewed,
      'spotComment': spotComment,  // 🆕

    };
  }

  factory NotificationPreferences.fromFirestore(Map<String, dynamic> data) {
    return NotificationPreferences(
      favoriteAdded: data['favoriteAdded'] ?? true,
      spotSuggestion: data['spotSuggestion'] ?? true,
      friendRequest: data['friendRequest'] ?? true,
      spotApproved: data['spotApproved'] ?? true,
      suggestionReviewed: data['suggestionReviewed'] ?? true,
      spotComment: data['spotComment'] ?? true,  // 🆕

    );
  }

  NotificationPreferences copyWith({
    bool? favoriteAdded,
    bool? spotSuggestion,
    bool? friendRequest,
    bool? spotApproved,
    bool? suggestionReviewed,
    bool? spotComment,  // 🆕

  }) {
    return NotificationPreferences(
      favoriteAdded: favoriteAdded ?? this.favoriteAdded,
      spotSuggestion: spotSuggestion ?? this.spotSuggestion,
      friendRequest: friendRequest ?? this.friendRequest,
      spotApproved: spotApproved ?? this.spotApproved,
      suggestionReviewed: suggestionReviewed ?? this.suggestionReviewed,
      spotComment: spotComment ?? this.spotComment,  // 🆕

    );
  }
}

// ==========================================
// NOTIFICACIÓN
// ==========================================

enum NotificationType {
  favoriteAdded,
  spotSuggestion,
  friendRequest,
  spotApproved,
  suggestionReviewed,
  spotComment,  // 🆕 NUEVO
}

class AppNotification {
  final String id;
  final String userId;              // Destinatario
  final NotificationType type;
  final String title;
  final String body;
  final String? actionUserId;       // Usuario que realizó la acción
  final String? actionUserName;     // Nombre del usuario que realizó la acción
  final String? spotId;             // ID del spot relacionado (si aplica)
  final String? spotName;           // Nombre del spot relacionado
  final String? suggestionId;       // ID de la sugerencia (si aplica)
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.actionUserId,
    this.actionUserName,
    this.spotId,
    this.spotName,
    this.suggestionId,
    this.isRead = false,
    required this.createdAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'type': type.name,
      'title': title,
      'body': body,
      'actionUserId': actionUserId,
      'actionUserName': actionUserName,
      'spotId': spotId,
      'spotName': spotName,
      'suggestionId': suggestionId,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppNotification(
      id: doc.id,
      userId: data['userId'] ?? '',
      type: NotificationType.values.firstWhere(
            (e) => e.name == data['type'],
        orElse: () => NotificationType.favoriteAdded,
      ),
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      actionUserId: data['actionUserId'],
      actionUserName: data['actionUserName'],
      spotId: data['spotId'],
      spotName: data['spotName'],
      suggestionId: data['suggestionId'],
      isRead: data['isRead'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  String get icon {
    switch (type) {
      case NotificationType.favoriteAdded:
        return '❤️';
      case NotificationType.spotSuggestion:
        return '✏️';
      case NotificationType.friendRequest:
        return '👥';
      case NotificationType.spotApproved:
        return '✅';
      case NotificationType.suggestionReviewed:
        return '📋';
      case NotificationType.spotComment:  // 🆕
        return '💬';
    }
  }

  // 🎯 Convertir a formato para FCM / payload de notificación
  Map<String, String> toNotificationData() {
    return {
      'notificationId': id,
      'type': type.name,
      'userId': userId,
      if (actionUserId != null) 'actionUserId': actionUserId!,
      if (actionUserName != null) 'actionUserName': actionUserName!,
      if (spotId != null) 'spotId': spotId!,
      if (spotName != null) 'spotName': spotName!,
      if (suggestionId != null) 'suggestionId': suggestionId!,
    };
  }
}

// ==========================================
// SOLICITUD DE AMISTAD
// ==========================================

enum FriendRequestStatus {
  pending,
  accepted,
  rejected,
}

class FriendRequest {
  final String id;
  final String fromUserId;
  final String fromUserName;
  final String? fromUserPhoto;
  final String toUserId;
  final FriendRequestStatus status;
  final DateTime createdAt;
  final DateTime? respondedAt;

  FriendRequest({
    required this.id,
    required this.fromUserId,
    required this.fromUserName,
    this.fromUserPhoto,
    required this.toUserId,
    this.status = FriendRequestStatus.pending,
    required this.createdAt,
    this.respondedAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'fromUserId': fromUserId,
      'fromUserName': fromUserName,
      'fromUserPhoto': fromUserPhoto,
      'toUserId': toUserId,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'respondedAt': respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
    };
  }

  factory FriendRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FriendRequest(
      id: doc.id,
      fromUserId: data['fromUserId'] ?? '',
      fromUserName: data['fromUserName'] ?? '',
      fromUserPhoto: data['fromUserPhoto'],
      toUserId: data['toUserId'] ?? '',
      status: FriendRequestStatus.values.firstWhere(
            (e) => e.name == data['status'],
        orElse: () => FriendRequestStatus.pending,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      respondedAt: (data['respondedAt'] as Timestamp?)?.toDate(),
    );
  }
}