// lib/services/notification_helper.dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'notification_service.dart';

/// 🎯 Helper para enviar notificaciones localizadas sin repetir código
class NotificationHelper {
  final NotificationService _service;

  NotificationHelper(this._service);

  // ❤️ FAVORITO
  Future<void> sendFavorite({
    required BuildContext context,
    required String spotOwnerId,
    required String spotId,
    required String spotName,
    required String userWhoLikedId,
    required String userWhoLikedName,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    
    await _service.sendFavoriteNotification(
      spotOwnerId: spotOwnerId,
      spotId: spotId,
      spotName: spotName,
      userWhoLikedId: userWhoLikedId,
      userWhoLikedName: userWhoLikedName,
      title: l10n.notifFavTitle,
      body: l10n.notifFavBody(userWhoLikedName, spotName),
    );
  }

  // 💬 COMENTARIO
  Future<void> sendComment({
    required BuildContext context,
    required String spotOwnerId,
    required String spotId,
    required String spotName,
    required String userWhoCommentedId,
    required String userWhoCommentedName,
    required String commentPreview,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    
    await _service.sendCommentNotification(
    spotOwnerId: spotOwnerId,
    spotId: spotId,
    spotName: spotName,
    userWhoCommentedId: userWhoCommentedId,
    userWhoCommentedName: userWhoCommentedName,
    commentPreview: commentPreview, 
    title: l10n.notifCommentTitle,
    body: l10n.notifCommentBody(userWhoCommentedName, spotName, commentPreview),
  );
  }

  // ✏️ SUGERENCIA
  Future<void> sendSuggestion({
    required BuildContext context,
    required String spotOwnerId,
    required String spotId,
    required String spotName,
    required String suggestionId,
    required String userWhoSuggestedId,
    required String userWhoSuggestedName,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    
    await _service.sendSuggestionNotification(
      spotOwnerId: spotOwnerId,
      spotId: spotId,
      spotName: spotName,
      suggestionId: suggestionId,
      userWhoSuggestedId: userWhoSuggestedId,
      userWhoSuggestedName: userWhoSuggestedName,
      title: l10n.notifSuggestionTitle,
      body: l10n.notifSuggestionBody(userWhoSuggestedName, spotName),
    );
  }

  // 👥 SOLICITUD DE AMISTAD
  Future<void> sendFriendRequest({
    required BuildContext context,
    required String toUserId,
    required String fromUserId,
    required String fromUserName,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    
    await _service.sendFriendRequestNotification(
      toUserId: toUserId,
      fromUserId: fromUserId,
      fromUserName: fromUserName,
      title: l10n.notifFriendRequestTitle,
      body: l10n.notifFriendRequestBody(fromUserName),
    );
  }

  // ✅ SPOT APROBADO (llamado desde moderación)
  Future<void> sendSpotApproved({
    required BuildContext context,
    required String userId,
    required String spotId,
    required String spotName,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    
    await _service.sendSpotApprovedNotification(
      userId: userId,
      spotId: spotId,
      spotName: spotName,
      title: l10n.notifSpotApprovedTitle,
      body: l10n.notifSpotApprovedBody(spotName),
    );
  }

  // 📋 SUGERENCIA REVISADA
  Future<void> sendSuggestionReviewed({
    required BuildContext context,
    required String userId,
    required String spotId,
    required String spotName,
    required bool isApproved,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    
    final title = isApproved 
        ? l10n.notifSuggestionApprovedTitle 
        : l10n.notifSuggestionRejectedTitle;
        
    final body = isApproved
        ? l10n.notifSuggestionApprovedBody(spotName)
        : l10n.notifSuggestionRejectedBody(spotName);
    
    await _service.sendSuggestionReviewedNotification(
      userId: userId,
      spotId: spotId,
      spotName: spotName,
      isApproved: isApproved,
      title: title,
      body: body,
    );
  }
}