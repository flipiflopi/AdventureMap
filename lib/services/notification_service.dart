// lib/services/notification_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/notification_models.dart';
import '../models/spot_model.dart';
import '../models/friend_request_model.dart';
import '../features/spots/presentation/spot_detail_screen.dart';
import '../features/friends/presentation/friends_screen.dart';
import '../features/moderation/presentation/suggestions_screen.dart';
import '../features/map/presentation/home_screen.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  GlobalKey<NavigatorState>? _navigatorKey;

  // ==========================================
  // INICIALIZACIÓN Y CONFIGURACIÓN
  // ==========================================

  Future<void> initialize(String userId, {GlobalKey<NavigatorState>? navigatorKey}) async {
    _navigatorKey = navigatorKey;

    print('🔔 Inicializando notificaciones para: $userId');

    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ Permisos concedidos');
      
      await _fcm.subscribeToTopic('global_notifications');
      
      String? token = await _fcm.getToken();
      if (token != null) {
        print('✅ Token FCM obtenido');
        await _saveTokenToFirestore(userId, token);
      }

      _fcm.onTokenRefresh.listen((newToken) {
        print('🔄 Token FCM actualizado');
        _saveTokenToFirestore(userId, newToken);
      });

      await _initializeLocalNotifications();

      // FOREGROUND: App abierta
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('📨 Notificación recibida (foreground)');
        _handleForegroundMessage(message);
      });

      // BACKGROUND: Usuario hace clic en notificación
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('🔔 Notificación clickeada (background)');
        _handleNotificationClick(message.data);
      });

      // TERMINATED: App estaba cerrada
      RemoteMessage? initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        print('🔔 App abierta desde notificación (terminated)');
        Future.delayed(const Duration(seconds: 2), () {
          _handleNotificationClick(initialMessage.data);
        });
      }

      print('✅ Sistema de notificaciones inicializado');
    } else {
      print('❌ Permisos de notificaciones denegados');
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    
    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: (details) {
        print('🔔 Notificación local clickeada');
        if (details.payload != null) {
          final data = jsonDecode(details.payload!);
          _handleNotificationClick(data);
        }
      },
    );
    print('✅ Notificaciones locales inicializadas');
  }

  Future<void> _saveTokenToFirestore(String userId, String token) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Token guardado en Firestore');
    } catch (e) {
      print('❌ Error guardando token: $e');
    }
  }

  // ==========================================
  // MANEJO DE CLICS Y NAVEGACIÓN
  // ==========================================

  void _handleForegroundMessage(RemoteMessage message) {
    _showLocalNotification(
      message.notification?.title ?? 'AdventureMap',
      message.notification?.body ?? '',
      message.data,
    );
  }

  void _handleNotificationClick(Map<String, dynamic> data) {
    print('🎯 Procesando clic en notificación');
    
    if (_navigatorKey?.currentState == null) {
      print('❌ NavigatorKey no disponible');
      return;
    }

    final type = data['type'] ?? '';
    final notificationId = data['notificationId'];
    
    if (notificationId != null) {
      markAsRead(notificationId);
    }

    print('   Tipo: $type');

    switch (type) {
      case 'favoriteAdded':
      case 'spotComment':
      case 'spotApproved':
      case 'suggestionReviewed':
        _navigateToSpotDetail(data['spotId']);
        break;
        
      case 'spotSuggestion':
        _navigatorKey!.currentState!.push(MaterialPageRoute(
          builder: (context) => const SuggestionsScreen(initialTab: 0),
        ));
        break;
        
      case 'friendRequest':
        _navigatorKey!.currentState!.push(MaterialPageRoute(
          builder: (context) => const FriendsScreen(),
        ));
        break;
        
      default:
        print('⚠️ Tipo de notificación desconocido: $type');
        _navigateToHome();
    }
  }

  void _navigateToSpotDetail(String? spotId) async {
    if (spotId == null) {
      print('❌ No hay spotId');
      _navigateToHome();
      return;
    }

    print('📍 Navegando a spot: $spotId');

    try {
      final doc = await _firestore.collection('spots').doc(spotId).get();
      
      if (!doc.exists) {
        print('❌ Spot no encontrado');
        _navigateToHome();
        return;
      }

      _navigatorKey!.currentState!.push(MaterialPageRoute(
        builder: (context) => SpotDetailScreen(spot: SpotModel.fromFirestore(doc)),
      ));
      
      print('✅ Navegación completada');
    } catch (e) {
      print('❌ Error navegando a spot: $e');
      _navigateToHome();
    }
  }

  void _navigateToHome() {
    print('🏠 Navegando a Home');
    _navigatorKey?.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (route) => false,
    );
  }

  Future<void> _showLocalNotification(
    String title,
    String body,
    Map<String, dynamic> data,
  ) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'adventuremap_channel',
        'AdventureMap Notifications',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _localNotifications.show(
      DateTime.now().millisecond,
      title,
      body,
      details,
      payload: jsonEncode(data),
    );
  }

  // ==========================================
  // ENVÍO DE NOTIFICACIONES (LOCALIZADAS)
  // ==========================================

  /// Método base para persistir notificaciones en Firestore
  Future<void> createNotification(AppNotification notification) async {
    try {
      await _firestore.collection('notifications').add(notification.toFirestore());
      print('✅ Notificación creada: ${notification.type}');
    } catch (e) {
      print('❌ Error creando notificación: $e');
    }
  }

  // 💬 COMENTARIO
Future<void> sendCommentNotification({
  required String spotOwnerId,
  required String spotId,
  required String spotName,
  required String userWhoCommentedId,
  required String userWhoCommentedName,
  required String commentPreview,
  String title = '', // ← Ahora opcional con valor por defecto
  String body = '',  // ← Ahora opcional con valor por defecto
}) async {
  print('💬 Enviando notificación de comentario');
  
  final prefs = await getNotificationPreferences(spotOwnerId);
  if (!prefs.spotComment) {
    print('⏭️ Usuario tiene desactivadas notificaciones de comentarios');
    return;
  }

  // Guardar en Firestore (Cloud Function generará title/body)
  await _firestore.collection('notifications').add({
    'userId': spotOwnerId,
    'type': 'spotComment',
    'actionUserId': userWhoCommentedId,
    'actionUserName': userWhoCommentedName,
    'spotId': spotId,
    'spotName': spotName,
    'commentPreview': commentPreview,
    'createdAt': FieldValue.serverTimestamp(),
    'isRead': false,
  });
  
  print('✅ Notificación de comentario guardada');
}


  // ❤️ FAVORITO
Future<void> sendFavoriteNotification({
  required String spotOwnerId,
  required String spotId,
  required String spotName,
  required String userWhoLikedId,
  required String userWhoLikedName,
  String title = '',
  String body = '',
}) async {
  print('❤️ Enviando notificación de favorito');
  
  final prefs = await getNotificationPreferences(spotOwnerId);
  if (!prefs.favoriteAdded) {
    print('⏭️ Usuario tiene desactivadas notificaciones de favoritos');
    return;
  }

  await _firestore.collection('notifications').add({
    'userId': spotOwnerId,
    'type': 'favoriteAdded',
    'actionUserId': userWhoLikedId,
    'actionUserName': userWhoLikedName,
    'spotId': spotId,
    'spotName': spotName,
    'createdAt': FieldValue.serverTimestamp(),
    'isRead': false,
  });
  
  print('✅ Notificación de favorito guardada');
}

  // ✏️ SUGERENCIA
Future<void> sendSuggestionNotification({
  required String spotOwnerId,
  required String spotId,
  required String spotName,
  required String suggestionId,
  required String userWhoSuggestedId,
  required String userWhoSuggestedName,
  String title = '',
  String body = '',
}) async {
  print('✏️ Enviando notificación de sugerencia');
  
  final prefs = await getNotificationPreferences(spotOwnerId);
  if (!prefs.spotSuggestion) {
    print('⏭️ Usuario tiene desactivadas notificaciones de sugerencias');
    return;
  }

  await _firestore.collection('notifications').add({
    'userId': spotOwnerId,
    'type': 'spotSuggestion',
    'actionUserId': userWhoSuggestedId,
    'actionUserName': userWhoSuggestedName,
    'spotId': spotId,
    'spotName': spotName,
    'suggestionId': suggestionId,
    'createdAt': FieldValue.serverTimestamp(),
    'isRead': false,
  });
  
  print('✅ Notificación de sugerencia guardada');
}
  // 👥 SOLICITUD DE AMISTAD
  Future<void> sendFriendRequestNotification({
    required String toUserId,
    required String fromUserId,
    required String fromUserName,
    required String title,
    required String body,
  }) async {
    print('👥 Enviando notificación de amistad');
    
    final prefs = await getNotificationPreferences(toUserId);
    if (!prefs.friendRequest) {
      print('⏭️ Usuario tiene desactivadas notificaciones de amistad');
      return;
    }

    await createNotification(AppNotification(
      id: '',
      userId: toUserId,
      type: NotificationType.friendRequest,
      title: title,
      body: body,
      actionUserId: fromUserId,
      actionUserName: fromUserName,
      createdAt: DateTime.now(),
    ));
  }

  // ✅ SPOT APROBADO
Future<void> sendSpotApprovedNotification({
  required String userId,
  required String spotId,
  required String spotName,
  String title = '',
  String body = '',
}) async {
  print('✅ Enviando notificación de aprobación');
  
  final prefs = await getNotificationPreferences(userId);
  if (!prefs.spotApproved) {
    print('⏭️ Usuario tiene desactivadas notificaciones de aprobación');
    return;
  }

  await _firestore.collection('notifications').add({
    'userId': userId,
    'type': 'spotApproved',
    'spotId': spotId,
    'spotName': spotName,
    'createdAt': FieldValue.serverTimestamp(),
    'isRead': false,
  });
  
  print('✅ Notificación de aprobación guardada');
}

  // 📋 SUGERENCIA REVISADA
Future<void> sendSuggestionReviewedNotification({
  required String userId,
  required String spotId,
  required String spotName,
  required bool isApproved,
  String title = '',
  String body = '',
}) async {
  print('📋 Enviando notificación de revisión');
  print('   SpotId: $spotId');
  print('   Aprobada: $isApproved');
  
  final prefs = await getNotificationPreferences(userId);
  if (!prefs.suggestionReviewed) {
    print('⏭️ Usuario tiene desactivadas notificaciones de revisión');
    return;
  }

  await _firestore.collection('notifications').add({
    'userId': userId,
    'type': 'suggestionReviewed',
    'spotId': spotId,
    'spotName': spotName,
    'isApproved': isApproved,
    'createdAt': FieldValue.serverTimestamp(),
    'isRead': false,
  });
  
  print('✅ Notificación de revisión guardada');
}

  // ==========================================
  // PREFERENCIAS Y GESTIÓN
  // ==========================================

  Future<NotificationPreferences> getNotificationPreferences(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists && doc.data()?['notificationPreferences'] != null) {
        return NotificationPreferences.fromFirestore(
          doc.data()!['notificationPreferences'] as Map<String, dynamic>,
        );
      }
    } catch (e) {
      print('❌ Error obteniendo preferencias: $e');
    }
    return NotificationPreferences();
  }

  Future<void> updateNotificationPreferences(
    String userId,
    NotificationPreferences preferences,
  ) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'notificationPreferences': preferences.toFirestore(),
      });
      print('✅ Preferencias actualizadas para: $userId');
    } catch (e) {
      print('❌ Error actualizando preferencias: $e');
      rethrow;
    }
  }

  Stream<List<AppNotification>> getUserNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => AppNotification.fromFirestore(doc))
            .toList());
  }

  Future<int> getUnreadCount(String userId) async {
    final snapshot = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();
    return snapshot.docs.length;
  }

  Future<void> markAsRead(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).update({
      'isRead': true,
    });
    print('✅ Notificación marcada como leída');
  }

  Future<void> markAllAsRead(String userId) async {
    final snapshot = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
    print('✅ Todas las notificaciones marcadas como leídas');
  }

  Future<void> deleteNotification(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).delete();
    print('✅ Notificación eliminada');
  }
}