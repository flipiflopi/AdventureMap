// lib/models/spot_suggestion_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // 🆕 Necesario para BuildContext
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // 🆕 i18n

class SpotSuggestion {
  final String id;
  final String spotId;
  final String suggestedBy;
  final String? newDescription;
  final List<String> newPhotoUrls;
  final SuggestionStatus status;
  final DateTime createdAt;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? reviewComment;

  SpotSuggestion({
    required this.id,
    required this.spotId,
    required this.suggestedBy,
    this.newDescription,
    this.newPhotoUrls = const [],
    this.status = SuggestionStatus.pending,
    required this.createdAt,
    this.reviewedBy,
    this.reviewedAt,
    this.reviewComment,
  });

  factory SpotSuggestion.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return SpotSuggestion(
      id: doc.id,
      spotId: data['spotId'] ?? '',
      suggestedBy: data['suggestedBy'] ?? '',
      newDescription: data['newDescription'],
      newPhotoUrls: List<String>.from(data['newPhotoUrls'] ?? []),
      status: SuggestionStatus.values.firstWhere(
            (e) => e.name == data['status'],
        orElse: () => SuggestionStatus.pending,
      ),
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      reviewedBy: data['reviewedBy'],
      reviewedAt: data['reviewedAt'] != null
          ? (data['reviewedAt'] as Timestamp).toDate()
          : null,
      reviewComment: data['reviewComment'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'spotId': spotId,
      'suggestedBy': suggestedBy,
      'newDescription': newDescription,
      'newPhotoUrls': newPhotoUrls,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'reviewedBy': reviewedBy,
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'reviewComment': reviewComment,
    };
  }
}

enum SuggestionStatus {
  pending,
  approved,
  rejected;

  // 🌍 Obtiene el estado de la sugerencia traducido
  String getLocalizedName(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      case SuggestionStatus.pending: return l10n.statusPending;
      case SuggestionStatus.approved: return l10n.statusApproved;
      case SuggestionStatus.rejected: return l10n.statusRejected;
    }
  }
}

// Modelo para spots pendientes de moderación
class PendingSpot {
  final String id;
  final String name;
  final String description;
  final String access;
  final String safety;
  final String category;
  final double latitude;
  final double longitude;
  final List<String> photoUrls;
  final String createdBy;
  final DateTime createdAt;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final ModerationStatus status;
  final String? rejectionReason;

  PendingSpot({
    required this.id,
    required this.name,
    required this.description,
    required this.access,
    required this.safety,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.photoUrls,
    required this.createdBy,
    required this.createdAt,
    this.reviewedBy,
    this.reviewedAt,
    this.status = ModerationStatus.pending,
    this.rejectionReason,
  });

  factory PendingSpot.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return PendingSpot(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      access: data['access'] ?? '',
      safety: data['safety'] ?? '',
      category: data['category'] ?? '',
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      photoUrls: List<String>.from(data['photoUrls'] ?? []),
      createdBy: data['createdBy'] ?? '',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      reviewedBy: data['reviewedBy'],
      reviewedAt: data['reviewedAt'] != null
          ? (data['reviewedAt'] as Timestamp).toDate()
          : null,
      status: ModerationStatus.values.firstWhere(
            (e) => e.name == (data['status'] ?? 'pending'),
        orElse: () => ModerationStatus.pending,
      ),
      rejectionReason: data['rejectionReason'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'access': access,
      'safety': safety,
      'category': category,
      'latitude': latitude,
      'longitude': longitude,
      'photoUrls': photoUrls,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'reviewedBy': reviewedBy,
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'status': status.name,
      'rejectionReason': rejectionReason,
    };
  }
}

enum ModerationStatus {
  pending,
  approved,
  rejected;

  // 🌍 Obtiene el estado de moderación traducido
  String getLocalizedName(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      case ModerationStatus.pending: return l10n.moderationPending;
      case ModerationStatus.approved: return l10n.moderationApproved;
      case ModerationStatus.rejected: return l10n.moderationRejected;
    }
  }
}