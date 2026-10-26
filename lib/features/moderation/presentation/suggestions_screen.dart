// lib/features/moderation/presentation/suggestions_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // 🆕 i18n
import '../../../models/spot_suggestion_model.dart';
import '../../../models/spot_model.dart';
import '../../../providers/providers.dart';
import '../../spots/presentation/spot_detail_screen.dart';

class SuggestionsScreen extends ConsumerStatefulWidget {
  final int initialTab;

  const SuggestionsScreen({
    Key? key,
    this.initialTab = 0,
  }) : super(key: key);

  @override
  ConsumerState<SuggestionsScreen> createState() => _SuggestionsScreenState();
}

class _SuggestionsScreenState extends ConsumerState<SuggestionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final l10n = AppLocalizations.of(context)!; // 🆕 Atajo

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.suggestions)),
        body: Center(child: Text(l10n.mustLoginError)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.suggestionsSpots),
        backgroundColor: Colors.blue,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.incomingSuggestions, icon: const Icon(Icons.inventory)),
            Tab(text: l10n.mySuggestions, icon: const Icon(Icons.edit_note)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildIncomingSuggestionsTab(context, currentUser.uid, l10n),
          _buildMySuggestionsTab(context, currentUser.uid, l10n),
        ],
      ),
    );
  }

  Widget _buildIncomingSuggestionsTab(BuildContext context, String userId, AppLocalizations l10n) {
    final firestoreService = ref.watch(firestoreServiceProvider);

    return StreamBuilder<List<SpotSuggestion>>(
      stream: firestoreService.getPendingSuggestionsForUser(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('${l10n.error}: ${snapshot.error}'));
        }

        final suggestions = snapshot.data ?? [];

        if (suggestions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, size: 80, color: Colors.green),
                const SizedBox(height: 16),
                Text(
                  l10n.noPendingSuggestions,
                  style: const TextStyle(fontSize: 18),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: suggestions.length,
          itemBuilder: (context, index) {
            final suggestion = suggestions[index];
            return _buildIncomingSuggestionCard(context, suggestion, userId, l10n);
          },
        );
      },
    );
  }

  Widget _buildIncomingSuggestionCard(
      BuildContext context,
      SpotSuggestion suggestion,
      String userId,
      AppLocalizations l10n
      ) {
    final firestoreService = ref.watch(firestoreServiceProvider);

    return FutureBuilder<SpotModel?>(
      future: firestoreService.getSpotById(suggestion.spotId),
      builder: (context, spotSnapshot) {
        if (!spotSnapshot.hasData) {
          return const Card(
            margin: EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final spot = spotSnapshot.data!;

        return FutureBuilder(
          future: firestoreService.getUserProfile(suggestion.suggestedBy),
          builder: (context, userSnapshot) {
            final suggestedByName = userSnapshot.data?.displayNameOrEmail ??
                suggestion.suggestedBy.substring(0, 8) + '...';

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.edit, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.suggestionFor(spot.name),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.person, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          l10n.suggestedBy(suggestedByName),
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('dd/MM/yyyy HH:mm').format(suggestion.createdAt),
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    if (suggestion.newDescription != null) ...[
                      Text(
                        l10n.proposedDescription,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.withOpacity(0.2)),
                        ),
                        child: Text(suggestion.newDescription!),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (suggestion.newPhotoUrls.isNotEmpty) ...[
                      Text(
                        l10n.proposedPhotos,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: suggestion.newPhotoUrls.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: suggestion.newPhotoUrls[index],
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: Colors.grey[300],
                                    child: const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SpotDetailScreen(spot: spot),
                          ),
                        );
                      },
                      icon: const Icon(Icons.visibility, size: 18),
                      label: Text(l10n.viewFullSpot),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 40),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _approveSuggestion(context, suggestion, spot, l10n),
                            icon: const Icon(Icons.check, size: 18),
                            label: Text(l10n.approve),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _rejectSuggestion(context, suggestion.id, l10n),
                            icon: const Icon(Icons.close, size: 18),
                            label: Text(l10n.reject),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMySuggestionsTab(BuildContext context, String userId, AppLocalizations l10n) {
    final firestoreService = ref.watch(firestoreServiceProvider);

    return StreamBuilder<List<SpotSuggestion>>(
      stream: firestoreService.getSuggestionsMadeByUser(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('${l10n.error}: ${snapshot.error}'));
        }

        final suggestions = snapshot.data ?? [];

        if (suggestions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.edit_off, size: 80, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  l10n.noSuggestionsMade,
                  style: const TextStyle(fontSize: 18),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: suggestions.length,
          itemBuilder: (context, index) {
            final suggestion = suggestions[index];
            return _buildMySuggestionCard(context, suggestion, l10n);
          },
        );
      },
    );
  }

  Widget _buildMySuggestionCard(BuildContext context, SpotSuggestion suggestion, AppLocalizations l10n) {
    final firestoreService = ref.watch(firestoreServiceProvider);

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (suggestion.status) {
      case SuggestionStatus.pending:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        statusText = l10n.statusPending;
        break;
      case SuggestionStatus.approved:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = l10n.statusApproved;
        break;
      case SuggestionStatus.rejected:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = l10n.statusRejected;
        break;
    }

    return FutureBuilder<SpotModel?>(
      future: firestoreService.getSpotById(suggestion.spotId),
      builder: (context, spotSnapshot) {
        if (!spotSnapshot.hasData) {
          return const Card(
            margin: EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final spot = spotSnapshot.data!;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        spot.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 14, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Enviada: ${DateFormat('dd/MM/yyyy HH:mm').format(suggestion.createdAt)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                if (suggestion.reviewedAt != null) ...[
                  Text(
                    'Revisada: ${DateFormat('dd/MM/yyyy HH:mm').format(suggestion.reviewedAt!)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                if (suggestion.newDescription != null) ...[
                  Text(
                    l10n.proposedDescriptionLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    suggestion.newDescription!,
                    style: const TextStyle(fontSize: 14),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                ],
                if (suggestion.newPhotoUrls.isNotEmpty) ...[
                  Text(
                    l10n.newPhotosCount(suggestion.newPhotoUrls.length),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                ],
                if (suggestion.reviewComment != null && suggestion.reviewComment!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.comment, size: 14, color: statusColor),
                            const SizedBox(width: 6),
                            Text(
                              l10n.reviewerComment,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          suggestion.reviewComment!,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SpotDetailScreen(spot: spot),
                      ),
                    );
                  },
                  icon: const Icon(Icons.visibility, size: 18),
                  label: Text(l10n.viewFullSpot),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 40),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _approveSuggestion(
      BuildContext context,
      SpotSuggestion suggestion,
      SpotModel spot,
      AppLocalizations l10n
      ) async {
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final currentUser = ref.read(currentUserProvider);

      if (currentUser == null) return;

      final updates = <String, dynamic>{};

      if (suggestion.newDescription != null && suggestion.newDescription!.isNotEmpty) {
        final description = suggestion.newDescription!;

        if (description.contains('DETALLES:') &&
            description.contains('ACCESO:') &&
            description.contains('SEGURIDAD:')) {

          final parts = description.split('\n\n');

          String details = '';
          String access = '';
          String safety = '';

          for (var part in parts) {
            if (part.startsWith('DETALLES:')) {
              details = part.replaceFirst('DETALLES:', '').trim();
            } else if (part.startsWith('ACCESO:')) {
              access = part.replaceFirst('ACCESO:', '').trim();
            } else if (part.startsWith('SEGURIDAD:')) {
              safety = part.replaceFirst('SEGURIDAD:', '').trim();
            }
          }

          if (details.isNotEmpty) updates['details'] = details;
          if (access.isNotEmpty) updates['access'] = access;
          if (safety.isNotEmpty) updates['safety'] = safety;

        } else {
          updates['details'] = description;
        }
      }

      if (suggestion.newPhotoUrls.isNotEmpty) {
        final currentPhotos = List<String>.from(spot.photoUrls);
        currentPhotos.addAll(suggestion.newPhotoUrls);
        updates['photoUrls'] = currentPhotos;
      }

      if (updates.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.noChangesToApply),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      await firestoreService.approveSuggestion(
        suggestion.id,
        currentUser.uid,
        suggestion.spotId,
        updates,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.suggestionApproved),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.error}: $e')),
        );
      }
    }
  }

  Future<void> _rejectSuggestion(BuildContext context, String suggestionId, AppLocalizations l10n) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.rejectSuggestion),
        content: TextField(
          controller: reasonController,
          decoration: InputDecoration(
            labelText: l10n.rejectionCommentLabel,
            hintText: l10n.rejectionCommentHint,
            border: const OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.reject),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final firestoreService = ref.read(firestoreServiceProvider);
        final currentUser = ref.read(currentUserProvider);

        if (currentUser == null) return;

        await firestoreService.rejectSuggestion(
          suggestionId,
          currentUser.uid,
          reasonController.text.trim(),
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.suggestionRejected),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${l10n.error}: $e')),
          );
        }
      }
    }

    reasonController.dispose();
  }
}