// lib/models/comment_report_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

enum CommentReportReason {
  spam('📧'),
  offensive('😡'),
  harassment('👊'),
  misinformation('❌'),
  inappropriate('🚫'),
  other('❓');

  final String icon;
  const CommentReportReason(this.icon);

  // 🌍 Método para obtener el nombre traducido
  String getDisplayName(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      case CommentReportReason.spam:
        return l10n.reportReasonSpam;
      case CommentReportReason.offensive:
        return l10n.reportReasonOffensive;
      case CommentReportReason.harassment:
        return l10n.reportReasonHarassment;
      case CommentReportReason.misinformation:
        return l10n.reportReasonMisinformation;
      case CommentReportReason.inappropriate:
        return l10n.reportReasonInappropriate;
      case CommentReportReason.other:
        return l10n.reportReasonOther;
    }
  }
}

class CommentReport {
  final String id;
  final String commentId;
  final String spotId;
  final String reportedBy;
  final List<CommentReportReason> reasons;
  final String description;
  final DateTime createdAt;
  final String status;
  final String? resolvedBy;
  final DateTime? resolvedAt;
  final String? moderatorComment;

  CommentReport({
    required this.id,
    required this.commentId,
    required this.spotId,
    required this.reportedBy,
    required this.reasons,
    required this.description,
    required this.createdAt,
    this.status = 'pending',
    this.resolvedBy,
    this.resolvedAt,
    this.moderatorComment,
  });

  Map<String, dynamic> toMap() {
    return {
      'commentId': commentId,
      'spotId': spotId,
      'reportedBy': reportedBy,
      'reasons': reasons.map((r) => r.name).toList(),
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status,
      'resolvedBy': resolvedBy,
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'moderatorComment': moderatorComment,
    };
  }

  factory CommentReport.fromMap(String id, Map<String, dynamic> map) {
    return CommentReport(
      id: id,
      commentId: map['commentId'] ?? '',
      spotId: map['spotId'] ?? '',
      reportedBy: map['reportedBy'] ?? '',
      reasons: (map['reasons'] as List<dynamic>?)
              ?.map((r) => CommentReportReason.values.firstWhere(
                    (reason) => reason.name == r,
                    orElse: () => CommentReportReason.other,
                  ))
              .toList() ??
          [],
      description: map['description'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      status: map['status'] ?? 'pending',
      resolvedBy: map['resolvedBy'],
      resolvedAt: map['resolvedAt'] != null
          ? (map['resolvedAt'] as Timestamp).toDate()
          : null,
      moderatorComment: map['moderatorComment'],
    );
  }
  
  // copyWith se mantiene igual...
}