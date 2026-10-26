// lib/widgets/rank_progress_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // 🆕 Importar i18n
import '../models/adventure_rank.dart';

class RankProgressWidget extends StatelessWidget {
  final int adventureScore;
  final bool showDetails;

  const RankProgressWidget({
    Key? key,
    required this.adventureScore,
    this.showDetails = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!; // 🌍 Cargamos traducciones

    // 🎯 CORREGIDO: Usar funciones globales pasando el context
    final currentRank = getRankFromScore(adventureScore, context);
    final nextRank = getNextRank(adventureScore, context);
    final progress = getRankProgress(adventureScore, context);
    final pointsToNext = getPointsToNextRank(adventureScore, context);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              currentRank.color.withOpacity(0.1),
              currentRank.color.withOpacity(0.05),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- RANGO ACTUAL ---
            Row(
              children: [
                Text(
                  currentRank.emoji,
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentRank.displayName,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: currentRank.color,
                        ),
                      ),
                      Text(
                        l10n.points(adventureScore), // 🌍 Antes: '$adventureScore puntos'
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (showDetails && nextRank != null) ...[
              const SizedBox(height: 16),

              // --- BARRA DE PROGRESO ---
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.progressLabel, // 🌍 Antes: 'Progreso'
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: currentRank.color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(currentRank.color),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // --- MENSAJE MOTIVACIONAL ---
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: nextRank.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: nextRank.color.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      nextRank.emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        // 🌍 Usamos la llave con pluralización y nombre del rango
                        l10n.morePointsForRank(pointsToNext, nextRank.displayName),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (nextRank == null) ...[
              const SizedBox(height: 12),
              // --- RANGO MÁXIMO ALCANZADO ---
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.amber.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Text('✨', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.maxRankReached, // 🌍 Antes: '¡Has alcanzado el rango máximo!'
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}