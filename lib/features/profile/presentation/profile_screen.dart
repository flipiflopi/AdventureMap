import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // 🆕 i18n
import '../../../providers/providers.dart';
import '../../../providers/auth_controller.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/locale_provider.dart';
import '../../../models/spot_suggestion_model.dart';
import '../../../models/spot_model.dart';
import '../../../models/adventure_rank.dart';
import '../../../widgets/rank_progress_widget.dart';
import '../../moderation/presentation/suggestions_screen.dart';
import '../../moderation/presentation/moderation_screen.dart';
import '../../moderation/presentation/all_spots_screen.dart';
import '../../admin/presentation/admin_panel_screen.dart';
import '../../spots/presentation/spot_detail_screen.dart';
import 'edit_profile_screen.dart';
import 'notification_settings_screen.dart';

enum ProfileSpotsViewType {
  list,
  grid,
  compact,
}

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  ProfileSpotsViewType _currentView = ProfileSpotsViewType.list;
  bool _showMySpots = false;
  final ScrollController _scrollController = ScrollController();
  Stream<dynamic>? _cachedProfileStream;
  Stream<dynamic>? _cachedSpotsStream;

  @override
  void initState() {
    super.initState();
    _loadViewPreference();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Stream<dynamic> _profileStream(String uid) {
    _cachedProfileStream ??= ref.read(firestoreServiceProvider).getUserProfileStream(uid);
    return _cachedProfileStream!;
  }

  Stream<dynamic> _spotsStream(String uid) {
    _cachedSpotsStream ??= ref.read(firestoreServiceProvider).getUserCreatedSpotsStream(uid);
    return _cachedSpotsStream!;
  }

  Future<void> _loadViewPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final viewIndex = prefs.getInt('profile_spots_view_type') ?? 0;
    setState(() {
      _currentView = ProfileSpotsViewType.values[viewIndex];
    });
  }

  Future<void> _saveViewPreference(ProfileSpotsViewType viewType) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('profile_spots_view_type', viewType.index);
  }

  void _cycleViewType() {
    setState(() {
      final currentIndex = _currentView.index;
      final nextIndex = (currentIndex + 1) % ProfileSpotsViewType.values.length;
      _currentView = ProfileSpotsViewType.values[nextIndex];
      _saveViewPreference(_currentView);
    });
  }

  IconData _getViewIcon() {
    switch (_currentView) {
      case ProfileSpotsViewType.list:
        return Icons.grid_view;
      case ProfileSpotsViewType.grid:
        return Icons.view_list;
      case ProfileSpotsViewType.compact:
        return Icons.view_headline;
    }
  }

  String _getViewTooltip(AppLocalizations l10n) {
    switch (_currentView) {
      case ProfileSpotsViewType.list:
        return l10n.viewGridTooltip;
      case ProfileSpotsViewType.grid:
        return l10n.viewCompactTooltip;
      case ProfileSpotsViewType.compact:
        return l10n.viewListTooltip;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final l10n = AppLocalizations.of(context)!;

    if (currentUser == null) {
      return _buildGuestProfile(context, l10n);
    }

    return _buildAuthenticatedProfile(context, ref, currentUser, l10n);
  }

  Widget _buildGuestProfile(BuildContext context, AppLocalizations l10n) {
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileTab),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_outline,
                    size: 60,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  l10n.guestMode,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.exploringAsGuest,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.loginTo,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildFeatureItem(Icons.add_location, l10n.featureCreateSpots),
                _buildFeatureItem(Icons.favorite, l10n.featureSaveFavorites),
                _buildFeatureItem(Icons.people, l10n.featureConnectFriends),
                _buildFeatureItem(Icons.emoji_events, l10n.featureEarnScore),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushNamed('/login');
                    },
                    icon: const Icon(Icons.login),
                    label: Text(
                      l10n.loginButton,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/register');
                  },
                  child: Text(
                    l10n.dontHaveAccount,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(height: 40),
                _buildDarkModeCard(l10n),
                const SizedBox(height: 8),
                _buildLanguageCard(l10n),
                const SizedBox(height: 20),
                _buildContactSupportText(l10n),
                const SizedBox(height: 16),
                _buildDisclaimerText(l10n),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthenticatedProfile(BuildContext context, WidgetRef ref, currentUser, AppLocalizations l10n) {
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileTitle),
        actions: [
          if (_showMySpots)
            IconButton(
              icon: Icon(_getViewIcon()),
              tooltip: _getViewTooltip(l10n),
              onPressed: _cycleViewType,
            ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EditProfileScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder(
        stream: _profileStream(currentUser.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final userProfile = snapshot.data;
          final adventureScore = userProfile?.adventureScore ?? 0;
          final currentRank = getRankFromScore(adventureScore, context);
          final isModerator = userProfile?.isModerator ?? false;

          return ListView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      currentRank.color.withOpacity(0.3),
                      currentRank.color.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: currentRank.color.withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: currentRank.color,
                              width: 3,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.grey[200],
                            backgroundImage: userProfile?.photoUrl != null
                                ? CachedNetworkImageProvider(userProfile!.photoUrl!)
                                : null,
                            child: userProfile?.photoUrl == null
                                ? const Icon(Icons.person, size: 50, color: Colors.grey)
                                : null,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: currentRank.color,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              currentRank.emoji,
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      userProfile?.displayNameOrEmail ?? currentUser.email ?? l10n.user,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: currentRank.color,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: currentRank.color.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            currentRank.emoji,
                            style: const TextStyle(fontSize: 20),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            currentRank.displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              RankProgressWidget(
                adventureScore: adventureScore,
                showDetails: true,
              ),
              const SizedBox(height: 20),

              Card(
                child: ListTile(
                  leading: const Icon(Icons.email),
                  title: const Text('Email'),
                  subtitle: Text(currentUser.email ?? '---'),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: Text(l10n.memberSince),
                  subtitle: Text(
                    currentUser.metadata.creationTime != null
                        ? DateFormat('dd/MM/yyyy').format(
                      currentUser.metadata.creationTime!,
                    )
                        : l10n.unknownDate,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: StreamBuilder<List<SpotModel>>(
                    stream: _spotsStream(currentUser.uid) as Stream<List<SpotModel>>,
                    builder: (context, spotsSnapshot) {
                      final spots = spotsSnapshot.data ?? [];
                      final spotsCount = spots.length;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                l10n.myStats,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (spotsCount > 0)
                                TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _showMySpots = !_showMySpots;
                                    });
                                  },
                                  icon: Icon(
                                    _showMySpots ? Icons.visibility_off : Icons.visibility,
                                    size: 18,
                                  ),
                                  label: Text(_showMySpots ? l10n.hide : l10n.viewSpots),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _StatItem(
                                icon: Icons.place,
                                label: l10n.createdSpots,
                                value: '$spotsCount',
                                color: Colors.blue,
                              ),
                              _StatItem(
                                icon: Icons.emoji_events,
                                label: 'Adventure Score',
                                value: '$adventureScore',
                                color: Colors.amber,
                              ),
                            ],
                          ),

                          if (_showMySpots && spotsCount > 0) ...[
                            const SizedBox(height: 24),
                            const Divider(),
                            const SizedBox(height: 16),
                            Text(
                              l10n.mySpots,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildSpotsView(spots, l10n),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Card(
                child: ListTile(
                  leading: const Icon(Icons.notifications, color: Colors.blue),
                  title: Text(l10n.notificationsTitle),
                  subtitle: Text(l10n.manageNotifSettings),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NotificationSettingsScreen(),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 8),
              _buildDarkModeCard(l10n),
              const SizedBox(height: 8),
              _buildLanguageCard(l10n),
              const SizedBox(height: 8),

              StreamBuilder<List<SpotSuggestion>>(
                stream: ref
                    .read(firestoreServiceProvider)
                    .getPendingSuggestionsForUser(currentUser.uid),
                builder: (context, snapshot) {
                  final pendingCount = snapshot.data?.length ?? 0;

                  return Card(
                    child: ListTile(
                      leading: Stack(
                        children: [
                          const Icon(Icons.rate_review, color: Colors.blue),
                          if (pendingCount > 0)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Text(
                                  '$pendingCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                      title: Text(l10n.suggestionsSpots),
                      subtitle: Text(pendingCount > 0
                          ? l10n.pendingSuggestionsCount(pendingCount)
                          : l10n.noPendingSuggestionsShort),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SuggestionsScreen(),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),

              if (isModerator) ...[
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.admin_panel_settings, color: Colors.orange),
                    title: Text(l10n.moderation),
                    subtitle: Text(l10n.moderationDesc),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ModerationScreen(),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.list_alt, color: Colors.purple),
                    title: Text(l10n.allSpots),
                    subtitle: Text(l10n.allSpotsDesc),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AllSpotsScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],

              if (currentUser.email == 'ivamm088@gmail.com')
                Column(
                  children: [
                    const SizedBox(height: 8),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.settings, color: Colors.deepPurple),
                        title: Text(l10n.adminPanel),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AdminPanelScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () async {
                  await ref.read(authControllerProvider.notifier).signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushReplacementNamed('/home');
                  }
                },
                icon: const Icon(Icons.logout),
                label: Text(l10n.signOut),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 40),
              _buildContactSupportText(l10n),
              const SizedBox(height: 16),
              _buildDisclaimerText(l10n),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDarkModeCard(AppLocalizations l10n) {
    return Card(
      child: Consumer(
        builder: (context, ref, _) {
          final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
          return SwitchListTile(
            secondary: Icon(
              isDark ? Icons.dark_mode : Icons.light_mode,
              color: Colors.blue,
            ),
            title: Text(l10n.darkMode),
            subtitle: Text(l10n.darkModeDesc),
            value: isDark,
            onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
          );
        },
      ),
    );
  }

  Widget _buildLanguageCard(AppLocalizations l10n) {
    return Card(
      child: Consumer(
        builder: (context, ref, _) {
          final currentLocale = ref.watch(localeProvider);
          final String currentLabel;
          if (currentLocale == null) {
            currentLabel = l10n.languageAuto;
          } else if (currentLocale.languageCode == 'es') {
            currentLabel = l10n.languageEs;
          } else if (currentLocale.languageCode == 'en') {
            currentLabel = l10n.languageEn;
          } else {
            currentLabel = currentLocale.languageCode.toUpperCase();
          }
          return ListTile(
            leading: const Icon(Icons.language, color: Colors.blue),
            title: Text(l10n.language),
            subtitle: Text(currentLabel),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _showLanguageDialog(context, ref, currentLocale, l10n),
          );
        },
      ),
    );
  }

  void _showLanguageDialog(
    BuildContext context,
    WidgetRef ref,
    Locale? currentLocale,
    AppLocalizations l10n,
  ) {
    final options = <(String, Locale?)>[
      (l10n.languageAuto, null),
      (l10n.languageEs, const Locale('es')),
      (l10n.languageEn, const Locale('en')),
    ];

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.language),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((option) {
              final (label, locale) = option;
              return RadioListTile<Locale?>(
                title: Text(label),
                value: locale,
                groupValue: currentLocale,
                onChanged: (value) {
                  ref.read(localeProvider.notifier).setLocale(value);
                  Navigator.of(dialogContext).pop();
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
          ],
        );
      },
    );
  }

  Widget _buildContactSupportText(AppLocalizations l10n) {
    return Column(
      children: [
        Text(
          l10n.contactSupport,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 4),
        const SelectableText(
          'adventuremap.help@gmail.com',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.blue,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildDisclaimerText(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        l10n.disclaimer,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 11,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildSpotsView(List<SpotModel> spots, AppLocalizations l10n) {
    switch (_currentView) {
      case ProfileSpotsViewType.list:
        return _buildListView(spots);
      case ProfileSpotsViewType.grid:
        return _buildGridView(spots);
      case ProfileSpotsViewType.compact:
        return _buildCompactView(spots);
    }
  }

  Widget _buildListView(List<SpotModel> spots) {
    return Column(
      children: spots.map((spot) => _buildListCard(context, spot)).toList(),
    );
  }

  Widget _buildGridView(List<SpotModel> spots) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: spots.length,
      itemBuilder: (context, index) {
        final spot = spots[index];
        return _buildGridCard(context, spot);
      },
    );
  }

  Widget _buildCompactView(List<SpotModel> spots) {
    return Column(
      children: spots.map((spot) => _buildCompactCard(context, spot)).toList(),
    );
  }

  Widget _buildListCard(BuildContext context, SpotModel spot) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _navigateToDetail(context, spot),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (spot.photoUrls.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                child: CachedNetworkImage(
                  imageUrl: spot.photoUrls.first,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 180,
                    color: Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 180,
                    color: Colors.grey[300],
                    child: const Icon(Icons.image_not_supported, size: 50),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(spot.category.icon, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          spot.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
spot.category.getLocalizedName(context),                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    spot.details,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridCard(BuildContext context, SpotModel spot) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToDetail(context, spot),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (spot.photoUrls.isNotEmpty)
              CachedNetworkImage(
                imageUrl: spot.photoUrls.first,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[200],
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.image_not_supported, size: 40),
                ),
              )
            else
              Container(
                color: Colors.grey[300],
                child: Icon(Icons.place, size: 60, color: Colors.grey[500]),
              ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          spot.category.icon,
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            spot.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
spot.category.getLocalizedName(context),                    style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactCard(BuildContext context, SpotModel spot) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _navigateToDetail(context, spot),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (spot.photoUrls.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: spot.photoUrls.first,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey[200],
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey[300],
                      child: const Icon(Icons.image_not_supported, size: 30),
                    ),
                  ),
                )
              else
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.place, color: Colors.grey[500]),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(spot.category.icon, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            spot.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
spot.category.getLocalizedName(context),                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToDetail(BuildContext context, SpotModel spot) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SpotDetailScreen(spot: spot),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 32, color: color),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}