// lib/models/folder_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // 🆕 Importar i18n

class FolderModel {
  final String id;
  final String name;
  final String userId;
  final List<String> spotIds;
  final String colorHex;
  final String iconName;
  final DateTime createdAt;

  FolderModel({
    required this.id,
    required this.name,
    required this.userId,
    this.spotIds = const [],
    this.colorHex = '#2196F3',
    this.iconName = 'folder',
    required this.createdAt,
  });

  // Convierte el string Hex de Firestore a un objeto Color de Flutter
  Color get color => Color(int.parse(colorHex.replaceFirst('#', '0xFF')));

  // Mapea el nombre guardado al icono real de Material Design
  IconData get icon {
    switch (iconName) {
      case 'beach':
        return Icons.beach_access;
      case 'mountain':
        return Icons.terrain;
      case 'favorite':
        return Icons.favorite;
      case 'star':
        return Icons.star;
      case 'trip':
        return Icons.flight;
      case 'explore':
        return Icons.explore;
      case 'map':
        return Icons.map;
      default:
        return Icons.folder;
    }
  }

  // 🌍 Obtiene la etiqueta traducida para el icono actual
  String getIconLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (iconName) {
      case 'beach': return l10n.iconBeach;
      case 'mountain': return l10n.iconMountain;
      case 'favorite': return l10n.iconFavorite;
      case 'star': return l10n.iconStar;
      case 'trip': return l10n.iconTrip;
      case 'explore': return l10n.iconExplore;
      case 'map': return l10n.iconMap;
      default: return l10n.iconFolder;
    }
  }

  factory FolderModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return FolderModel(
      id: doc.id,
      name: data['name'] ?? '',
      userId: data['userId'] ?? '',
      spotIds: List<String>.from(data['spotIds'] ?? []),
      colorHex: data['colorHex'] ?? '#2196F3',
      iconName: data['iconName'] ?? 'folder',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'userId': userId,
      'spotIds': spotIds,
      'colorHex': colorHex,
      'iconName': iconName,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  FolderModel copyWith({
    String? id,
    String? name,
    String? userId,
    List<String>? spotIds,
    String? colorHex,
    String? iconName,
    DateTime? createdAt,
  }) {
    return FolderModel(
      id: id ?? this.id,
      name: name ?? this.name,
      userId: userId ?? this.userId,
      spotIds: spotIds ?? this.spotIds,
      colorHex: colorHex ?? this.colorHex,
      iconName: iconName ?? this.iconName,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}