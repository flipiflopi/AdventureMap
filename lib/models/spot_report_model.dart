// lib/models/spot_report_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // 🆕 Necesario para BuildContext
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // 🆕 i18n

class SpotReport {
  final String id;
  final String spotId;
  final String reportedBy;
  final List<ReportReason> reasons;
  final String description;
  final DateTime createdAt;
  final ReportStatus status;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? reviewComment;

  SpotReport({
    required this.id,
    required this.spotId,
    required this.reportedBy,
    required this.reasons,
    required this.description,
    required this.createdAt,
    this.status = ReportStatus.pending,
    this.reviewedBy,
    this.reviewedAt,
    this.reviewComment,
  });

  factory SpotReport.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    List<ReportReason> reasons = [];
    if (data['reasons'] != null) {
      reasons = (data['reasons'] as List)
          .map((r) => ReportReason.values.firstWhere(
            (e) => e.name == r,
            orElse: () => ReportReason.other,
          ))
          .toList();
    }

    return SpotReport(
      id: doc.id,
      spotId: data['spotId'] ?? '',
      reportedBy: data['reportedBy'] ?? '',
      reasons: reasons,
      description: data['description'] ?? '',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      status: ReportStatus.values.firstWhere(
            (e) => e.name == (data['status'] ?? 'pending'),
        orElse: () => ReportStatus.pending,
      ),
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
      'reportedBy': reportedBy,
      'reasons': reasons.map((r) => r.name).toList(),
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status.name,
      'reviewedBy': reviewedBy,
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'reviewComment': reviewComment,
    };
  }
}

enum ReportReason {
  wrongPhotos,
  wrongTitle,
  wrongDescription,
  wrongLocation,
  inappropriate,
  duplicate,
  other;

  // 🌍 Obtiene el nombre traducido según el contexto
  String getLocalizedName(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      case ReportReason.wrongPhotos: return l10n.reasonWrongPhotos;
      case ReportReason.wrongTitle: return l10n.reasonWrongTitle;
      case ReportReason.wrongDescription: return l10n.reasonWrongDescription;
      case ReportReason.wrongLocation: return l10n.reasonWrongLocation;
      case ReportReason.inappropriate: return l10n.reasonInappropriate;
      case ReportReason.duplicate: return l10n.reasonDuplicate;
      case ReportReason.other: return l10n.reasonOther;
    }
  }

  String get icon {
    switch (this) {
      case ReportReason.wrongPhotos: return '📷';
      case ReportReason.wrongTitle: return '✏️';
      case ReportReason.wrongDescription: return '📝';
      case ReportReason.wrongLocation: return '📍';
      case ReportReason.inappropriate: return '⚠️';
      case ReportReason.duplicate: return '📋';
      case ReportReason.other: return '❓';
    }
  }
}

enum ReportStatus {
  pending,
  reviewed,
  resolved,
  dismissed;

  // 🌍 Obtiene el estado traducido según el contexto
  String getLocalizedName(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      case ReportStatus.pending: return l10n.statusPending;
      case ReportStatus.reviewed: return l10n.statusReviewed;
      case ReportStatus.resolved: return l10n.statusResolved;
      case ReportStatus.dismissed: return l10n.statusDismissed;
    }
  }
}