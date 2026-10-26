// lib/features/profile/presentation/notification_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // 🆕 i18n
import '../../../models/notification_models.dart';
import '../../../services/notification_service.dart';
import '../../../providers/providers.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  final NotificationService _notificationService = NotificationService();
  NotificationPreferences? _preferences;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    final prefs =
    await _notificationService.getNotificationPreferences(currentUser.uid);
    setState(() {
      _preferences = prefs;
      _isLoading = false;
    });
  }

  Future<void> _updatePreference(NotificationPreferences newPrefs) async {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    setState(() {
      _preferences = newPrefs;
    });

    try {
      await _notificationService.updateNotificationPreferences(
        currentUser.uid,
        newPrefs,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.prefsUpdated),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.error}: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notificationsTitle),
        backgroundColor: Colors.blue,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _preferences == null
          ? Center(child: Text(l10n.favoritesLoadError)) // Reutilizamos llave de error
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Encabezado
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.notifications_active,
                    color: Colors.blue, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.manageNotifications,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.chooseNotifications,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // FAVORITOS
          _buildNotificationTile(
            icon: Icons.favorite,
            iconColor: Colors.red,
            title: l10n.notifFavoritesTitle,
            subtitle: l10n.notifFavoritesDesc,
            value: _preferences!.favoriteAdded,
            onChanged: (value) {
              _updatePreference(
                  _preferences!.copyWith(favoriteAdded: value));
            },
          ),
          const Divider(height: 32),

          // SUGERENCIAS
          _buildNotificationTile(
            icon: Icons.edit_note,
            iconColor: Colors.blue,
            title: l10n.notifSuggestionsTitle,
            subtitle: l10n.notifSuggestionsDesc,
            value: _preferences!.spotSuggestion,
            onChanged: (value) {
              _updatePreference(
                  _preferences!.copyWith(spotSuggestion: value));
            },
          ),
          const Divider(height: 32),

          // SOLICITUDES DE AMISTAD
          _buildNotificationTile(
            icon: Icons.people,
            iconColor: Colors.green,
            title: l10n.notifFriendRequestsTitle,
            subtitle: l10n.notifFriendRequestsDesc,
            value: _preferences!.friendRequest,
            onChanged: (value) {
              _updatePreference(
                  _preferences!.copyWith(friendRequest: value));
            },
          ),
          const Divider(height: 32),

          // SPOTS APROBADOS
          _buildNotificationTile(
            icon: Icons.check_circle,
            iconColor: Colors.orange,
            title: l10n.notifSpotsApprovedTitle,
            subtitle: l10n.notifSpotsApprovedDesc,
            value: _preferences!.spotApproved,
            onChanged: (value) {
              _updatePreference(
                  _preferences!.copyWith(spotApproved: value));
            },
          ),
          const Divider(height: 32),

          // SUGERENCIAS REVISADAS
          _buildNotificationTile(
            icon: Icons.rate_review,
            iconColor: Colors.purple,
            title: l10n.notifSuggestionsReviewedTitle,
            subtitle: l10n.notifSuggestionsReviewedDesc,
            value: _preferences!.suggestionReviewed,
            onChanged: (value) {
              _updatePreference(
                  _preferences!.copyWith(suggestionReviewed: value));
            },
          ),

          const Divider(height: 32),

          // COMENTARIOS EN MIS SPOTS
          _buildNotificationTile(
            icon: Icons.comment,
            iconColor: Colors.blue,
            title: l10n.notifCommentsTitle,
            subtitle: l10n.notifCommentsDesc,
            value: _preferences!.spotComment,
            onChanged: (value) {
              _updatePreference(
                  _preferences!.copyWith(spotComment: value));
            },
          ),
          const SizedBox(height: 32),

          // Botones de acción rápida
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _updatePreference(NotificationPreferences(
                      favoriteAdded: false,
                      spotSuggestion: false,
                      friendRequest: false,
                      spotApproved: false,
                      suggestionReviewed: false,
                      spotComment: false,
                    ));
                  },
                  icon: const Icon(Icons.notifications_off, size: 18),
                  label: Text(l10n.deactivateAll),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    _updatePreference(NotificationPreferences(
                      favoriteAdded: true,
                      spotSuggestion: true,
                      friendRequest: true,
                      spotApproved: true,
                      suggestionReviewed: true,
                      spotComment: true,
                    ));
                  },
                  icon: const Icon(Icons.notifications_active, size: 18),
                  label: Text(l10n.activateAll),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Información adicional
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 20, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      l10n.aboutNotifications,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${l10n.notifInfoBullet1}\n'
                      '${l10n.notifInfoBullet2}\n'
                      '${l10n.notifInfoBullet3}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: iconColor,
            ),
          ],
        ),
      ),
    );
  }
}