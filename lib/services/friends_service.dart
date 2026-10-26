// lib/services/friends_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../models/friend_request_model.dart';
import '../models/user_profile_model.dart'; 
import 'notification_service.dart';

class FriendsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  // 🔄 CORREGIDO: Ahora acepta notifTitle y notifBody obligatorios
  Future<void> sendFriendRequest(
    String fromUserId, 
    String toUserId, {
    required String notifTitle, // 🆕 Título localizado
    required String notifBody,  // 🆕 Cuerpo localizado
  }) async {
    // Verificar que no exista ya una solicitud
    final existingRequest = await _firestore
        .collection('friend_requests')
        .where('fromUserId', isEqualTo: fromUserId)
        .where('toUserId', isEqualTo: toUserId)
        .where('status', isEqualTo: 'pending')
        .get();

    if (existingRequest.docs.isNotEmpty) {
      throw Exception('errorRequestPending');
    }

    // Verificar si ya son amigos
    final userDoc = await _firestore.collection('users').doc(fromUserId).get();
    final friends = List<String>.from(userDoc.data()?['friends'] ?? []);

    if (friends.contains(toUserId)) {
      throw Exception('errorAlreadyFriends');
    }

    final fromUserData = userDoc.data();
    final fromUserName = fromUserData?['displayName'] ?? fromUserData?['email'] ?? 'anonymousUser';

    // Crear solicitud
    final request = FriendRequest(
      id: '',
      fromUserId: fromUserId,
      toUserId: toUserId,
      status: FriendRequestStatus.pending,
      createdAt: DateTime.now(),
    );

    await _firestore.collection('friend_requests').add(request.toFirestore());

    // 🎯 ENVIAR NOTIFICACIÓN CON TEXTOS LOCALIZADOS
    await _notificationService.sendFriendRequestNotification(
      toUserId: toUserId,
      fromUserId: fromUserId,
      fromUserName: fromUserName,
      title: notifTitle, // ✅ Fix: parámetro añadido
      body: notifBody,   // ✅ Fix: parámetro añadido
    );

    print('✅ Solicitud de amistad enviada con notificación');
  }

  // Aceptar solicitud de amistad
  Future<void> acceptFriendRequest(String requestId, String currentUserId) async {
    final batch = _firestore.batch();

    final requestRef = _firestore.collection('friend_requests').doc(requestId);
    batch.update(requestRef, {
      'status': 'accepted',
      'respondedAt': FieldValue.serverTimestamp(),
    });

    final requestDoc = await requestRef.get();
    final request = FriendRequest.fromFirestore(requestDoc);

    final user1Ref = _firestore.collection('users').doc(request.fromUserId);
    final user2Ref = _firestore.collection('users').doc(request.toUserId);

    batch.update(user1Ref, {
      'friends': FieldValue.arrayUnion([request.toUserId]),
    });

    batch.update(user2Ref, {
      'friends': FieldValue.arrayUnion([request.fromUserId]),
    });

    await batch.commit();
  }

  // Rechazar solicitud de amistad
  Future<void> rejectFriendRequest(String requestId) async {
    await _firestore.collection('friend_requests').doc(requestId).update({
      'status': 'rejected',
      'respondedAt': FieldValue.serverTimestamp(),
    });
  }

  // Cancelar solicitud enviada
  Future<void> cancelFriendRequest(String requestId) async {
    await _firestore.collection('friend_requests').doc(requestId).delete();
  }

  // Eliminar amigo
  Future<void> removeFriend(String userId, String friendId) async {
    final batch = _firestore.batch();

    final user1Ref = _firestore.collection('users').doc(userId);
    final user2Ref = _firestore.collection('users').doc(friendId);

    batch.update(user1Ref, {
      'friends': FieldValue.arrayRemove([friendId]),
    });

    batch.update(user2Ref, {
      'friends': FieldValue.arrayRemove([userId]),
    });

    await batch.commit();
  }

  // Obtener solicitudes recibidas pendientes
  Stream<List<FriendRequest>> getReceivedRequests(String userId) {
    return _firestore
        .collection('friend_requests')
        .where('toUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => FriendRequest.fromFirestore(doc))
        .toList());
  }

  // Obtener solicitudes enviadas pendientes
  Stream<List<FriendRequest>> getSentRequests(String userId) {
    return _firestore
        .collection('friend_requests')
        .where('fromUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => FriendRequest.fromFirestore(doc))
        .toList());
  }

  // Verificar estado de amistad entre dos usuarios
  Future<FriendshipStatus> checkFriendshipStatus(
      String userId, String otherUserId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    final friends = List<String>.from(userDoc.data()?['friends'] ?? []);

    if (friends.contains(otherUserId)) {
      return FriendshipStatus.friends;
    }

    final sentRequest = await _firestore
        .collection('friend_requests')
        .where('fromUserId', isEqualTo: userId)
        .where('toUserId', isEqualTo: otherUserId)
        .where('status', isEqualTo: 'pending')
        .get();

    if (sentRequest.docs.isNotEmpty) {
      return FriendshipStatus.requestSent;
    }

    final receivedRequest = await _firestore
        .collection('friend_requests')
        .where('fromUserId', isEqualTo: otherUserId)
        .where('toUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .get();

    if (receivedRequest.docs.isNotEmpty) {
      return FriendshipStatus.requestReceived;
    }

    return FriendshipStatus.none;
  }

  // Obtener solicitud recibida de un usuario específico
  Future<FriendRequest?> getReceivedRequestFrom(
      String currentUserId, String fromUserId) async {
    final query = await _firestore
        .collection('friend_requests')
        .where('fromUserId', isEqualTo: fromUserId)
        .where('toUserId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    return FriendRequest.fromFirestore(query.docs.first);
  }

  // Obtener lista de amigos con sus perfiles
  Future<List<UserProfileModel>> getFriendsProfiles(String userId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    final friendIds = List<String>.from(userDoc.data()?['friends'] ?? []);

    if (friendIds.isEmpty) return [];

    final profiles = await Future.wait(
      friendIds.map((id) async {
        final doc = await _firestore.collection('users').doc(id).get();
        if (doc.exists) {
          return UserProfileModel.fromFirestore(doc);
        }
        return null;
      }),
    );

    return profiles.whereType<UserProfileModel>().toList();
  }

  // Buscar usuarios por nombre o email
  Future<List<UserProfileModel>> searchUsers(String query) async {
    if (query.isEmpty) return [];
    final lowerQuery = query.toLowerCase();

    try {
      final snapshot = await _firestore
          .collection('users')
          .limit(100)
          .get();

      final allUsers = snapshot.docs
          .map((doc) => UserProfileModel.fromFirestore(doc))
          .toList();

      return allUsers.where((user) {
        final displayName = (user.displayName ?? '').toLowerCase();
        final email = user.email.toLowerCase();
        return displayName.contains(lowerQuery) || email.contains(lowerQuery);
      }).toList();

    } catch (e) {
      print('❌ Error buscando usuarios: $e');
      return [];
    }
  }

  // Contar amigos en común
  Future<int> countMutualFriends(String userId1, String userId2) async {
    final user1Doc = await _firestore.collection('users').doc(userId1).get();
    final user2Doc = await _firestore.collection('users').doc(userId2).get();

    final friends1 = List<String>.from(user1Doc.data()?['friends'] ?? []);
    final friends2 = List<String>.from(user2Doc.data()?['friends'] ?? []);

    return friends1.where((id) => friends2.contains(id)).length;
  }
}

enum FriendshipStatus {
  none,
  requestSent,
  requestReceived,
  friends;

  String getLocalizedName(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      case FriendshipStatus.none:
        return l10n.statusNone;
      case FriendshipStatus.requestSent:
        return l10n.statusRequestSent;
      case FriendshipStatus.requestReceived:
        return l10n.statusRequestReceived;
      case FriendshipStatus.friends:
        return l10n.statusFriends;
    }
  }
}