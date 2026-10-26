// lib/models/user_profile_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfileModel {
  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final List<String> friends;
  final List<String> favoriteSpots;
  final int adventureScore;
  final bool isModerator;
  final DateTime createdAt;

  UserProfileModel({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
    required this.friends,
    required this.favoriteSpots,
    required this.adventureScore,
    required this.isModerator,
    required this.createdAt,
  });

  // Getter para mostrar nombre o email si el nombre es nulo
  String get displayNameOrEmail => displayName ?? email;

  factory UserProfileModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserProfileModel(
      uid: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'],
      photoUrl: data['photoUrl'],
      friends: List<String>.from(data['friends'] ?? []),
      favoriteSpots: List<String>.from(data['favoriteSpots'] ?? []),
      adventureScore: data['adventureScore'] ?? 0,
      isModerator: data['isModerator'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'friends': friends,
      'favoriteSpots': favoriteSpots,
      'adventureScore': adventureScore,
      'isModerator': isModerator,
      'createdAt': createdAt,
    };
  }
}