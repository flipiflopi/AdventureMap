// lib/features/profile/presentation/user_profile_screen.dart
// ACTUALIZADO CON SISTEMA DE AMIGOS, RANGO Y 3 VISTAS PARA SPOTS
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // 🆕 i18n
import '../../../models/spot_model.dart';
import '../../../models/adventure_rank.dart';
import '../../../services/friends_service.dart';
import '../../../providers/providers.dart';
import '../../spots/presentation/spot_detail_screen.dart';

// 🆕 Enum para los tipos de vista
enum UserSpotsViewType {
  list,    // Vista lista con detalles
  grid,    // Vista cuadrícula compacta
  compact, // Vista lista mini
}

class UserProfileScreen extends ConsumerStatefulWidget {
  final String userId;

  const UserProfileScreen({Key? key, required this.userId}) : super(key: key);

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  FriendshipStatus? _friendshipStatus;
  bool _isLoadingStatus = true;
  UserSpotsViewType _currentView = UserSpotsViewType.list;

  @override
  void initState() {
    super.initState();
    _loadFriendshipStatus();
    _loadViewPreference();
  }

  // 💾 Cargar preferencia de vista guardada
  Future<void> _loadViewPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final viewIndex = prefs.getInt('user_spots_view_type') ?? 0;
    setState(() {
      _currentView = UserSpotsViewType.values[viewIndex];
    });
  }

  // 💾 Guardar preferencia de vista
  Future<void> _saveViewPreference(UserSpotsViewType viewType) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('user_spots_view_type', viewType.index);
  }

  // 🔄 Cambiar tipo de vista
  void _cycleViewType() {
    setState(() {
      final currentIndex = _currentView.index;
      final nextIndex = (currentIndex + 1) % UserSpotsViewType.values.length;
      _currentView = UserSpotsViewType.values[nextIndex];
      _saveViewPreference(_currentView);
    });
  }

  // 🎨 Obtener icono según vista actual
  IconData _getViewIcon() {
    switch (_currentView) {
      case UserSpotsViewType.list:
        return Icons.grid_view;
      case UserSpotsViewType.grid:
        return Icons.view_list;
      case UserSpotsViewType.compact:
        return Icons.view_headline;
    }
  }

  // 📝 Obtener tooltip según vista actual
  String _getViewTooltip(AppLocalizations l10n) {
    switch (_currentView) {
      case UserSpotsViewType.list:
        return l10n.viewGridTooltip;
      case UserSpotsViewType.grid:
        return l10n.viewCompactTooltip;
      case UserSpotsViewType.compact:
        return l10n.viewListTooltip;
    }
  }

  Future<void> _loadFriendshipStatus() async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null || currentUser.uid == widget.userId) {
      setState(() {
        _isLoadingStatus = false;
      });
      return;
    }

    try {
      final status = await FriendsService().checkFriendshipStatus(
        currentUser.uid,
        widget.userId,
      );
      setState(() {
        _friendshipStatus = status;
        _isLoadingStatus = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingStatus = false;
      });
    }
  }

 Future<void> _sendFriendRequest() async {
    final l10n = AppLocalizations.of(context)!;
    
    // 1. Definimos currentUser una sola vez
    final currentUser = ref.read(currentUserProvider);
    
    // 2. Usamos esa variable para obtener el perfil (sin volver a declararla)
    final currentUserProfile = currentUser != null 
        ? ref.read(userProfileProvider(currentUser.uid)).value 
        : null;
    
    if (currentUser == null) return;

    try {
      await FriendsService().sendFriendRequest(
        currentUser.uid, 
        widget.userId,
        notifTitle: l10n.notifFriendRequestTitle, 
        notifBody: l10n.notifFriendRequestBody(
          currentUserProfile?.displayName ?? currentUser.email ?? 'User'
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.friendRequestSent),
            backgroundColor: Colors.green,
          ),
        );
        _loadFriendshipStatus();
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = e.toString();
        if (errorMessage.contains('errorRequestPending')) {
          errorMessage = l10n.errorRequestPending;
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    }
  }

  Future<void> _acceptFriendRequest() async {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    try {
      final request = await FriendsService().getReceivedRequestFrom(
        currentUser.uid,
        widget.userId,
      );

      if (request != null) {
        await FriendsService().acceptFriendRequest(request.id, currentUser.uid);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.nowFriends),
              backgroundColor: Colors.green,
            ),
          );
          _loadFriendshipStatus();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _removeFriend() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.removeFriend),
        content: Text(l10n.removeFriendConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    try {
      await FriendsService().removeFriend(currentUser.uid, widget.userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.friendRemoved),
            backgroundColor: Colors.orange,
          ),
        );
        _loadFriendshipStatus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Widget _buildFriendshipButton(AppLocalizations l10n) {
    final currentUser = ref.watch(currentUserProvider);

    if (currentUser == null || currentUser.uid == widget.userId) {
      return const SizedBox.shrink();
    }

    if (_isLoadingStatus) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    switch (_friendshipStatus) {
      case FriendshipStatus.none:
        return Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _sendFriendRequest,
            icon: const Icon(Icons.person_add),
            label: Text(l10n.addFriend),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        );

      case FriendshipStatus.requestSent:
        return Padding(
          padding: const EdgeInsets.all(16),
          child: OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.schedule),
            label: Text(l10n.requestSentStatus),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        );

      case FriendshipStatus.requestReceived:
        return Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _acceptFriendRequest,
            icon: const Icon(Icons.check_circle),
            label: Text(l10n.acceptRequest),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        );

      case FriendshipStatus.friends:
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green, width: 2),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(
                        l10n.friendsStatus,
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (context) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.person_remove, color: Colors.red),
                            title: Text(l10n.removeFriend),
                            onTap: () {
                              Navigator.pop(context);
                              _removeFriend();
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  // 🆕 Renderizar spots según el tipo de vista
  Widget _buildSpotsView(List<SpotModel> spots) {
    switch (_currentView) {
      case UserSpotsViewType.list:
        return _buildListView(spots);
      case UserSpotsViewType.grid:
        return _buildGridView(spots);
      case UserSpotsViewType.compact:
        return _buildCompactView(spots);
    }
  }

  // 📋 VISTA LISTA
  Widget _buildListView(List<SpotModel> spots) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: spots.length,
      itemBuilder: (context, index) {
        return _SpotListCard(spot: spots[index]);
      },
    );
  }

  // 🔲 VISTA CUADRÍCULA
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
        return _SpotGridCard(spot: spots[index]);
      },
    );
  }

  // 📝 VISTA COMPACTA
  Widget _buildCompactView(List<SpotModel> spots) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: spots.length,
      itemBuilder: (context, index) {
        return _SpotCompactCard(spot: spots[index]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.userProfile),
      ),
      body: FutureBuilder(
        future: ref.read(firestoreServiceProvider).getUserProfile(widget.userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(l10n.loadingProfile),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('${l10n.error}: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.back),
                  ),
                ],
              ),
            );
          }

          final userProfile = snapshot.data;

          if (userProfile == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(l10n.userNotFound),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.back),
                  ),
                ],
              ),
            );
          }

          final adventureScore = userProfile.adventureScore ?? 0;
final currentRank = getRankFromScore(adventureScore, context); // 👈 Añadir context
          return RefreshIndicator(
            onRefresh: () async {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => UserProfileScreen(userId: widget.userId),
                ),
              );
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  // Header con foto, rango y stats
                  Container(
                    width: double.infinity,
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
                                  width: 4,
                                ),
                              ),
                              child: Hero(
                                tag: 'profile_${widget.userId}',
                                child: CircleAvatar(
                                  radius: 60,
                                  backgroundColor: Colors.white,
                                  backgroundImage: userProfile.photoUrl != null
                                      ? CachedNetworkImageProvider(userProfile.photoUrl!)
                                      : null,
                                  child: userProfile.photoUrl == null
                                      ? const Icon(Icons.person, size: 60, color: Colors.grey)
                                      : null,
                                ),
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
                          userProfile.displayNameOrEmail,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
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
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.amber,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.emoji_events,
                                size: 18,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                l10n.points(adventureScore),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Colors.amber,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (userProfile.displayName == null)
                          Text(
                            userProfile.email,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              l10n.memberSinceDate(DateFormat('MMM yyyy').format(userProfile.createdAt)),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  _buildFriendshipButton(l10n),

                  // Stats cards
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: FutureBuilder<List<SpotModel>>(
                      future: ref
                          .read(firestoreServiceProvider)
                          .getUserCreatedSpots(widget.userId),
                      builder: (context, spotsSnapshot) {
                        final spotsCount = spotsSnapshot.data?.length ?? 0;

                        return Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                icon: Icons.place,
                                label: l10n.createdSpots,
                                value: spotsCount.toString(),
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                icon: Icons.people,
                                label: l10n.friendsTitle,
                                value: userProfile.friends.length.toString(),
                                color: Colors.green,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 🆕 Lista de spots con botón de cambio de vista
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              l10n.createdSpots,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: FutureBuilder<List<SpotModel>>(
                                future: ref
                                    .read(firestoreServiceProvider)
                                    .getUserCreatedSpots(widget.userId),
                                builder: (context, snapshot) {
                                  final count = snapshot.data?.length ?? 0;
                                  return Text(
                                    '$count',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  );
                                },
                              ),
                            ),
                            const Spacer(),
                            // 🆕 Botón de cambio de vista
                            IconButton(
                              icon: Icon(_getViewIcon()),
                              tooltip: _getViewTooltip(l10n),
                              onPressed: _cycleViewType,
                              color: Colors.blue,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        FutureBuilder<List<SpotModel>>(
                          future: ref
                              .read(firestoreServiceProvider)
                              .getUserCreatedSpots(widget.userId),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }

                            if (snapshot.hasError) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    children: [
                                      const Icon(Icons.error, color: Colors.red),
                                      const SizedBox(height: 8),
                                      Text('Error: ${snapshot.error}'),
                                    ],
                                  ),
                                ),
                              );
                            }

                            final spots = snapshot.data ?? [];

                            if (spots.isEmpty) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.explore_off,
                                        size: 64,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        l10n.userNoSpots,
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey[600],
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            // 🆕 Renderizar según la vista seleccionada
                            return _buildSpotsView(spots);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// WIDGETS DE STATS Y VISTAS

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
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
        ),
      ),
    );
  }
}

// 📋 CARD VISTA LISTA
class _SpotListCard extends StatelessWidget {
  final SpotModel spot;

  const _SpotListCard({required this.spot});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SpotDetailScreen(spot: spot),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (spot.photoUrls.isNotEmpty)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: CachedNetworkImage(
                  imageUrl: spot.photoUrls.first,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[300],
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.error),
                  ),
                ),
              )
            else
              Container(
                height: 150,
                color: Colors.grey[300],
                child: Center(
                  child: Icon(
                    Icons.image_not_supported,
                    size: 48,
                    color: Colors.grey[600],
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
                      Text(
                        spot.category.icon,
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          spot.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
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
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (spot.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      spot.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.favorite, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${spot.favoriteCount}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('dd/MM/yyyy').format(spot.createdAt),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 🔲 CARD VISTA CUADRÍCULA
class _SpotGridCard extends StatelessWidget {
  final SpotModel spot;

  const _SpotGridCard({required this.spot});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SpotDetailScreen(spot: spot),
            ),
          );
        },
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
spot.category.getLocalizedName(context),                      style: TextStyle(
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
}

// 📝 CARD VISTA COMPACTA
class _SpotCompactCard extends StatelessWidget {
  final SpotModel spot;

  const _SpotCompactCard({required this.spot});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SpotDetailScreen(spot: spot),
            ),
          );
        },
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
}