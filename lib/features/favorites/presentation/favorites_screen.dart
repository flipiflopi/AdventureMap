// lib/features/favorites/presentation/favorites_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../models/spot_model.dart';
import '../../../models/folder_model.dart';
import '../../../providers/providers.dart';
import '../../spots/presentation/spot_detail_screen.dart';
import 'create_folder_dialog.dart';
import 'folder_detail_screen.dart';

enum FavoritesViewType {
  list,
  grid,
  compact,
}

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  FavoritesViewType _currentView = FavoritesViewType.list;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadViewPreference();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadViewPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final viewIndex = prefs.getInt('favorites_view_type') ?? 0;
    if (mounted) {
      setState(() {
        _currentView = FavoritesViewType.values[viewIndex];
      });
    }
  }

  Future<void> _saveViewPreference(FavoritesViewType viewType) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('favorites_view_type', viewType.index);
  }

  void _cycleViewType() {
    setState(() {
      final nextIndex = (_currentView.index + 1) % FavoritesViewType.values.length;
      _currentView = FavoritesViewType.values[nextIndex];
      _saveViewPreference(_currentView);
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final l10n = AppLocalizations.of(context)!;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.favoritesTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite_border, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  l10n.loginToSaveFavorites,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.organizeFavoritesDescription,
                  style: TextStyle(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pushNamed('/login'),
                  icon: const Icon(Icons.login),
                  label: Text(l10n.loginButton),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.myFavoritesTitle),
        actions: [
          if (_tabController.index == 0)
            IconButton(
              icon: Icon(_getViewIcon()),
              tooltip: _getViewTooltip(l10n),
              onPressed: _cycleViewType,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          onTap: (index) => setState(() {}),
          tabs: [
            Tab(icon: const Icon(Icons.favorite), text: l10n.favoritesTitle),
            Tab(icon: const Icon(Icons.folder), text: l10n.foldersTab),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFavoritesTab(currentUser.uid, l10n),
          _buildFoldersTab(currentUser.uid, l10n),
        ],
      ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton(
              onPressed: () => showDialog(
                context: context,
                builder: (context) => CreateFolderDialog(userId: currentUser.uid),
              ),
              child: const Icon(Icons.create_new_folder),
            )
          : null,
    );
  }

  IconData _getViewIcon() {
    switch (_currentView) {
      case FavoritesViewType.list:
        return Icons.grid_view;
      case FavoritesViewType.grid:
        return Icons.view_list;
      case FavoritesViewType.compact:
        return Icons.view_headline;
    }
  }

  String _getViewTooltip(AppLocalizations l10n) {
    switch (_currentView) {
      case FavoritesViewType.list:
        return l10n.viewGridTooltip;
      case FavoritesViewType.grid:
        return l10n.viewCompactTooltip;
      case FavoritesViewType.compact:
        return l10n.viewListTooltip;
    }
  }

  // 🔑 CAMBIO PRINCIPAL: StreamBuilder en lugar de FutureBuilder
  Widget _buildFavoritesTab(String userId, AppLocalizations l10n) {
    final firestoreService = ref.watch(firestoreServiceProvider);

    return StreamBuilder<List<String>>(
      stream: firestoreService.getFavoriteSpotIds(userId),
      builder: (context, idsSnapshot) {
        if (idsSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (idsSnapshot.hasError) {
          return Center(child: Text(l10n.favoritesLoadError));
        }

        final ids = idsSnapshot.data ?? [];

        if (ids.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height - 200,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.favorite_border, size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        l10n.noFavoritesYet,
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.exploreMapDescription,
                        style: TextStyle(color: Colors.grey[500]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        // Con los IDs, cargamos los spots en un FutureBuilder interno
        return FutureBuilder<List<SpotModel>>(
          future: Future.wait(
            ids.map((id) async {
              try {
                return await firestoreService.getSpotById(id);
              } catch (_) {
                return null; // spot archivado o sin permisos → ignorar
              }
            }),
          ).then((spots) => spots.whereType<SpotModel>().toList()),
          builder: (context, spotsSnapshot) {
            if (spotsSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (spotsSnapshot.hasError) {
              return Center(child: Text(l10n.favoritesLoadError));
            }

            final favorites = spotsSnapshot.data ?? [];

            return RefreshIndicator(
              onRefresh: () async => setState(() {}),
              child: _buildViewWithRefresh(favorites),
            );
          },
        );
      },
    );
  }

  Widget _buildViewWithRefresh(List<SpotModel> favorites) {
    switch (_currentView) {
      case FavoritesViewType.list:
        return _buildListView(favorites);
      case FavoritesViewType.grid:
        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(12),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.85,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildGridCard(context, favorites[index]),
                  childCount: favorites.length,
                ),
              ),
            ),
          ],
        );
      case FavoritesViewType.compact:
        return _buildCompactView(favorites);
    }
  }

  Widget _buildListView(List<SpotModel> favorites) {
    return ListView.builder(
      itemCount: favorites.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) => _buildListCard(context, favorites[index]),
    );
  }

  Widget _buildCompactView(List<SpotModel> favorites) {
    return ListView.builder(
      itemCount: favorites.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) => _buildCompactCard(context, favorites[index]),
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
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    spot.category.getLocalizedName(context),
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
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
                  colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
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
                        Text(spot.category.icon, style: const TextStyle(fontSize: 20)),
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
                      spot.category.getLocalizedName(context),
                      style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
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
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      spot.category.getLocalizedName(context),
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
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
      MaterialPageRoute(builder: (context) => SpotDetailScreen(spot: spot)),
    );
  }

  Widget _buildFoldersTab(String userId, AppLocalizations l10n) {
    final foldersAsync = ref.watch(userFoldersProvider(userId));

    return foldersAsync.when(
      data: (folders) {
        if (folders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.folder_open, size: 80, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  l10n.noFoldersYet,
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.createFoldersDescription,
                  style: TextStyle(color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (context) => CreateFolderDialog(userId: userId),
                  ),
                  icon: const Icon(Icons.create_new_folder),
                  label: Text(l10n.createFolderButton),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.0,
          ),
          itemCount: folders.length,
          itemBuilder: (context, index) =>
              _buildFolderCard(context, folders[index], l10n),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('${l10n.foldersLoadError}: $error'),
      ),
    );
  }

  Widget _buildFolderCard(BuildContext context, FolderModel folder, AppLocalizations l10n) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => FolderDetailScreen(folder: folder)),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [folder.color.withOpacity(0.8), folder.color],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(folder.icon, size: 48, color: Colors.white),
                const SizedBox(height: 12),
                Text(
                  folder.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    l10n.placesCount(folder.spotIds.length),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}