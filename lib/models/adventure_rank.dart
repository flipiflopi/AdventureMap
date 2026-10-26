// lib/models/adventure_rank.dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // Importa tus traducciones generadas

class AdventureRank {
  final String name;
  final String displayName;
  final String emoji;
  final int minScore;
  final int maxScore;
  final Color color;
  final String description;

  const AdventureRank({
    required this.name,
    required this.displayName,
    required this.emoji,
    required this.minScore,
    required this.maxScore,
    required this.color,
    required this.description,
  });
}

// 🌍 Generador de rangos traducidos
List<AdventureRank> getTranslatedRanks(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;

  return [
    AdventureRank(
      name: 'newbie',
      displayName: l10n.rankNewbieName,
      emoji: '🌱',
      minScore: 0,
      maxScore: 24,
      color: const Color(0xFF90EE90),
      description: l10n.rankNewbieDesc,
    ),
    AdventureRank(
      name: 'apprentice',
      displayName: l10n.rankApprenticeName,
      emoji: '🎒',
      minScore: 25,
      maxScore: 49,
      color: const Color(0xFF87CEEB),
      description: l10n.rankApprenticeDesc,
    ),
    AdventureRank(
      name: 'explorer',
      displayName: l10n.rankExplorerName,
      emoji: '🧭',
      minScore: 50,
      maxScore: 99,
      color: const Color(0xFF4169E1),
      description: l10n.rankExplorerDesc,
    ),
    AdventureRank(
      name: 'adventurer',
      displayName: l10n.rankAdventurerName,
      emoji: '⛰️',
      minScore: 100,
      maxScore: 199,
      color: const Color(0xFF32CD32),
      description: l10n.rankAdventurerDesc,
    ),
    AdventureRank(
      name: 'traveler',
      displayName: l10n.rankTravelerName,
      emoji: '🗺️',
      minScore: 200,
      maxScore: 299,
      color: const Color(0xFFFFD700),
      description: l10n.rankTravelerDesc,
    ),
    AdventureRank(
      name: 'veteran',
      displayName: l10n.rankVeteranName,
      emoji: '🏔️',
      minScore: 300,
      maxScore: 449,
      color: const Color(0xFFFF8C00),
      description: l10n.rankVeteranDesc,
    ),
    AdventureRank(
      name: 'expert',
      displayName: l10n.rankExpertName,
      emoji: '⭐',
      minScore: 450,
      maxScore: 599,
      color: const Color(0xFFFF4500),
      description: l10n.rankExpertDesc,
    ),
    AdventureRank(
      name: 'master',
      displayName: l10n.rankMasterName,
      emoji: '💎',
      minScore: 600,
      maxScore: 799,
      color: const Color(0xFF8B008B),
      description: l10n.rankMasterDesc,
    ),
    AdventureRank(
      name: 'legend',
      displayName: l10n.rankLegendName,
      emoji: '👑',
      minScore: 800,
      maxScore: 999,
      color: const Color(0xFFFF1493),
      description: l10n.rankLegendDesc,
    ),
    AdventureRank(
      name: 'mythic',
      displayName: l10n.rankMythicName,
      emoji: '🌟',
      minScore: 1000,
      maxScore: 999999,
      color: const Color(0xFFFFD700),
      description: l10n.rankMythicDesc,
    ),
  ];
}

// 🔍 Actualizamos las funciones auxiliares para que usen la lista traducida
AdventureRank getRankFromScore(int score, BuildContext context) {
  final ranks = getTranslatedRanks(context);
  for (final rank in ranks) {
    if (score >= rank.minScore && score <= rank.maxScore) {
      return rank;
    }
  }
  return ranks.last;
}

// 🎯 Función actualizada para obtener el siguiente rango
AdventureRank? getNextRank(int currentScore, BuildContext context) {
  final ranks = getTranslatedRanks(context);
  final currentRank = getRankFromScore(currentScore, context);
  final currentIndex = ranks.indexWhere((r) => r.name == currentRank.name);

  if (currentIndex < ranks.length - 1) {
    return ranks[currentIndex + 1];
  }
  return null;
}

// 📊 Nueva función global para progreso
double getRankProgress(int score, BuildContext context) {
  final currentRank = getRankFromScore(score, context);
  final ranks = getTranslatedRanks(context);
  
  if (currentRank.name == ranks.last.name) return 1.0;

  final rangeSize = currentRank.maxScore - currentRank.minScore + 1;
  final progressInRange = score - currentRank.minScore;
  return progressInRange / rangeSize;
}

// 🎁 Nueva función global para puntos restantes
int getPointsToNextRank(int score, BuildContext context) {
  final currentRank = getRankFromScore(score, context);
  final ranks = getTranslatedRanks(context);

  if (currentRank.name == ranks.last.name) return 0;
  return currentRank.maxScore - score + 1;
}