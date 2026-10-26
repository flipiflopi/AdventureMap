// lib/features/map/presentation/home_screen.dart
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../models/spot_model.dart' hide UserProfileModel;
import '../../../models/user_profile_model.dart';

import '../../spots/presentation/spot_detail_screen.dart';
import '../../spots/presentation/create_spot_screen.dart';
import '../../favorites/presentation/favorites_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../profile/presentation/user_profile_screen.dart';
import '../../friends/presentation/friends_screen.dart';
import '../../../services/friends_service.dart';

import '../../../providers/providers.dart';
import '../../../providers/favorites_provider.dart';

final showFavoritesOnMapProvider = StateProvider<bool>((ref) => false);
final showMyOwnSpotsProvider = StateProvider<bool>((ref) => false);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;
  final Map<String, SpotModel> _spotsByAnnotationId = {};

  List<SpotModel> _allSpots = [];
  bool _isUpdatingMarkers = false;
  final Map<SpotCategory, Uint8List> _markerIconCache = {};

  final _searchController = TextEditingController();
  bool _isSearching = false;
  List<dynamic> _searchResults = [];
  bool _showSearchResults = false;
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _requestLocationPermission() async {
    final locationService = ref.read(locationServiceProvider);
    await locationService.requestLocationPermission();
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
    _mapboxMap?.annotations.createPointAnnotationManager().then((manager) {
      _pointAnnotationManager = manager;
      _loadInitialSpots();
    });

    _mapboxMap?.location.updateSettings(LocationComponentSettings(
      enabled: true,
      pulsingEnabled: true,
    ));

    _mapboxMap?.scaleBar.updateSettings(ScaleBarSettings(
      enabled: true,
      position: OrnamentPosition.BOTTOM_LEFT,
      marginLeft: 8.0,
      marginBottom: 8.0,
      textColor: Colors.black.value,
      primaryColor: Colors.black.value,
      secondaryColor: Colors.white.value,
      borderWidth: 1.0,
      height: 6.0,
      textBarMargin: 6.0,
      textBorderWidth: 1.5,
      textSize: 10.0,
      isMetricUnits: true,
      refreshInterval: 15,
    ));

    _mapboxMap?.compass.updateSettings(CompassSettings(
      enabled: true,
      position: OrnamentPosition.BOTTOM_RIGHT,
      marginRight: 16.0,
      marginBottom: 140.0,
    ));

    _mapboxMap?.logo.updateSettings(LogoSettings(enabled: false));
    _mapboxMap?.attribution.updateSettings(AttributionSettings(
      position: OrnamentPosition.BOTTOM_RIGHT,
      marginRight: 8.0,
      marginBottom: 8.0,
    ));
  }

  void _loadInitialSpots() {
    final spotsAsync = ref.read(allSpotsProvider);
    spotsAsync.whenData((spots) {
      _allSpots = spots;
      _applyFilter();
    });
  }

  void _applyFilter() {
    if (_mapboxMap == null || _isUpdatingMarkers) return;

    final providerFilter = ref.read(filteredSpotsProvider);
    final showFavorites = ref.read(showFavoritesOnMapProvider);
    final showMySpots = ref.read(showMyOwnSpotsProvider);
    final currentUser = ref.read(currentUserProvider);

    List<SpotModel> displayedSpots;

    if (showFavorites && currentUser != null) {
      final favoriteIds = ref.read(optimizedFavoritesProvider);
      displayedSpots = _allSpots.where((spot) => favoriteIds.contains(spot.id)).toList();
    } else if (showMySpots && currentUser != null) {
      displayedSpots = _allSpots.where((spot) => spot.createdBy == currentUser.uid).toList();
    } else if (providerFilter != null) {
      displayedSpots = _allSpots.where((spot) => spot.category == providerFilter).toList();
    } else {
      displayedSpots = List.from(_allSpots);
    }

    _updateMarkers(displayedSpots);
  }

  Future<void> _updateMarkers(List<SpotModel> spots) async {
    if (_pointAnnotationManager == null || _isUpdatingMarkers) return;

    final currentIds = _spotsByAnnotationId.values.map((s) => s.id).toSet();
    final newIds = spots.map((s) => s.id).toSet();

    if (currentIds.length == newIds.length &&
        currentIds.every((id) => newIds.contains(id))) {
      return;
    }

    setState(() => _isUpdatingMarkers = true);

    try {
      await _pointAnnotationManager?.deleteAll();
      _spotsByAnnotationId.clear();

      if (spots.isEmpty) {
        setState(() => _isUpdatingMarkers = false);
        return;
      }

      List<PointAnnotationOptions> optionsList = [];

      for (var spot in spots) {
        if (!_markerIconCache.containsKey(spot.category)) {
          _markerIconCache[spot.category] = await _createMarkerImage(spot.category);
        }

        optionsList.add(
          PointAnnotationOptions(
            geometry: Point(coordinates: Position(spot.longitude, spot.latitude)),
            image: _markerIconCache[spot.category],
            iconSize: 1.0,
            iconAnchor: IconAnchor.BOTTOM,
          ),
        );
      }

      final annotations = await _pointAnnotationManager?.createMulti(optionsList);

      if (annotations != null) {
        for (int i = 0; i < annotations.length; i++) {
          final ann = annotations[i];
          if (ann != null) {
            _spotsByAnnotationId[ann.id] = spots[i];
          }
        }
      }

      _pointAnnotationManager?.addOnPointAnnotationClickListener(
        _PointAnnotationClickListener(
          onTap: (annotation) {
            final spot = _spotsByAnnotationId[annotation.id];
            if (spot != null) _onMarkerTap(spot);
          },
        ),
      );
    } catch (e) {
      debugPrint('Error actualizando marcadores: $e');
    } finally {
      if (mounted) {
        setState(() => _isUpdatingMarkers = false);
      }
    }
  }

  Future<Uint8List> _createMarkerImage(SpotCategory category) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = 60.0;
    final bgColor = _getCategoryColor(category);

    final bgPaint = Paint()..color = bgColor..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, bgPaint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2 - 1.5, borderPaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: category.icon,
        style: const TextStyle(fontSize: 28.0, fontFamily: 'emoji'),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2),
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  Color _getCategoryColor(SpotCategory category) {
    switch (category) {
      case SpotCategory.surf: return Colors.blue;
      case SpotCategory.snorkel: return Colors.cyan;
      case SpotCategory.cliffJumping: return Colors.orange;
      case SpotCategory.caves: return Colors.grey.shade700;
      case SpotCategory.naturalPool: return Colors.lightBlue;
      case SpotCategory.viewpoint: return Colors.purple;
      case SpotCategory.sunset: return Colors.deepOrange;
      case SpotCategory.other: return Colors.grey;
    }
  }

  void _onMarkerTap(SpotModel spot) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SpotDetailScreen(spot: spot)),
    );
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
      return;
    }

    final spotResults = _allSpots
        .where((spot) => spot.name.toLowerCase().contains(query.toLowerCase()))
        .toList();

    // Mostramos modo búsqueda inmediatamente, con _isSearching=true para que
    // el IgnorePointer deshabilite el GestureDetector durante el async
    // (evita que un toque accidental cierre la búsqueda mientras carga)
    setState(() {
      _searchResults = [...spotResults];
      _showSearchResults = true;
      _isSearching = true;
    });
    _searchFocusNode.requestFocus();

    try {
      final userResults = await FriendsService().searchUsers(query);
      final currentUser = ref.read(authStateProvider).value;

      final seenUserIds = <String>{};
      final uniqueUsers = <UserProfileModel>[];
      for (var user in userResults) {
        if (user.uid != currentUser?.uid && !seenUserIds.contains(user.uid)) {
          seenUserIds.add(user.uid);
          uniqueUsers.add(user);
        }
      }

      List<Location> locations = [];
      try {
        locations = await locationFromAddress(query);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _searchResults = [
            ...spotResults,
            ...uniqueUsers.take(5),
            if (locations.isNotEmpty) query,
          ];
          _isSearching = false;
        });
        _searchFocusNode.requestFocus();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        _searchFocusNode.requestFocus();
      }
    }
  }

  void _dismissSearch() {
    FocusScope.of(context).unfocus();
    setState(() {
      _showSearchResults = false;
      _searchController.clear();
      _searchResults = [];
    });
  }

  Future<void> _goToSearchResult(dynamic result) async {
    final l10n = AppLocalizations.of(context)!;
    _dismissSearch();

    if (result is SpotModel) {
      _mapboxMap?.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(result.longitude, result.latitude)),
          zoom: 14.0,
        ),
        MapAnimationOptions(duration: 2000),
      );
    } else if (result is String) {
      try {
        List<Location> locations = await locationFromAddress(result);
        if (locations.isNotEmpty) {
          final loc = locations.first;
          _mapboxMap?.flyTo(
            CameraOptions(
              center: Point(coordinates: Position(loc.longitude, loc.latitude)),
              zoom: 12.0,
            ),
            MapAnimationOptions(duration: 2000),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.locationNotFoundError)),
          );
        }
      }
    }
  }

  Future<void> _centerOnUserLocation() async {
    final position = await ref.read(locationServiceProvider).getCurrentLocation();
    if (position != null && _mapboxMap != null) {
      _mapboxMap?.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(position.longitude, position.latitude)),
          zoom: 14.0,
        ),
        MapAnimationOptions(duration: 1000),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(navigationIndexProvider);
    final l10n = AppLocalizations.of(context)!;

    ref.listen<AsyncValue<List<SpotModel>>>(allSpotsProvider, (prev, next) {
      next.whenData((spots) {
        final int prevCount = prev?.value?.length ?? 0;
        if (prevCount != spots.length) {
          _allSpots = spots;
          _applyFilter();
        }
      });
    });

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: IndexedStack(
        index: currentIndex,
        children: [
          _buildMapView(l10n),
          const FavoritesScreen(),
          const FriendsScreen(),
          const ProfileScreen(),
        ],
      ),
      floatingActionButton: currentIndex == 0
          ? Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton(
                  heroTag: 'center',
                  mini: true,
                  onPressed: _centerOnUserLocation,
                  child: const Icon(Icons.my_location),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: 'add',
                  onPressed: () async {
                    final currentUser = ref.read(authStateProvider).value;
                    if (currentUser == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.mustLoginError)),
                      );
                      return;
                    }
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CreateSpotScreen()),
                    );
                  },
                  child: const Icon(Icons.add),
                ),
              ],
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
        onTap: (index) => ref.read(navigationIndexProvider.notifier).state = index,
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.map), label: l10n.mapTab),
          BottomNavigationBarItem(icon: const Icon(Icons.favorite), label: l10n.favoritesTitle),
          BottomNavigationBarItem(icon: const Icon(Icons.people), label: l10n.friendsTitle),
          BottomNavigationBarItem(icon: const Icon(Icons.person), label: l10n.profileTab),
        ],
      ),
    );
  }

  Widget _buildMapView(AppLocalizations l10n) {
    return Stack(
      children: [
        MapWidget(
          key: const ValueKey('mapWidget'),
          onMapCreated: _onMapCreated,
          cameraOptions: CameraOptions(
            center: Point(coordinates: Position(-3.7038, 40.4168)),
            zoom: 6.0,
          ),
          styleUri: MapboxStyles.OUTDOORS,
        ),
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !(_showSearchResults && !_isSearching),
            child: GestureDetector(
              onTap: _dismissSearch,
              child: Container(color: Colors.transparent),
            ),
          ),
        ),
        Positioned(
          top: 50,
          left: 16,
          right: 16,
          child: Column(
            children: [
              _buildSearchBar(l10n),
              if (_showSearchResults) ...[
                const SizedBox(height: 8),
                _buildSearchResultsDropdown(l10n),
              ],
            ],
          ),
        ),
        if (!_showSearchResults)
          Positioned(top: 120, left: 16, right: 16, child: _buildCategoryFilter(l10n)),
      ],
    );
  }

  Widget _buildSearchBar(AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 2))],
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        decoration: InputDecoration(
          hintText: l10n.searchHint,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchResults = [];
                      _showSearchResults = false;
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        onChanged: _performSearch,
      ),
    );
  }

  Widget _buildSearchResultsDropdown(AppLocalizations l10n) {
    // Solo mostramos spinner si todavía no hay resultados que mostrar
    if (_isSearching && _searchResults.isEmpty) {
      return Container(
        height: 150,
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(12)),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 2))],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          final result = _searchResults[index];

          if (result is UserProfileModel) {
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue,
                backgroundImage: result.photoUrl != null
                    ? CachedNetworkImageProvider(result.photoUrl!)
                    : null,
                child: result.photoUrl == null
                    ? const Icon(Icons.person, color: Colors.white, size: 20)
                    : null,
              ),
              title: Text(result.displayNameOrEmail),
              subtitle: Text(result.email, style: const TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.person, size: 14, color: Colors.blue),
              onTap: () {
                _dismissSearch();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => UserProfileScreen(userId: result.uid)),
                );
              },
            );
          }

          if (result is SpotModel) {
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: _getCategoryColor(result.category),
                child: Text(result.category.icon),
              ),
              title: Text(result.name),
              subtitle: Text(result.category.getLocalizedName(context)),
              trailing: const Icon(Icons.location_on, color: Colors.grey),
              onTap: () => _goToSearchResult(result),
            );
          }

          if (result is String) {
            return ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.green,
                child: Icon(Icons.public, color: Colors.white),
              ),
              title: Text(result),
              subtitle: Text(l10n.geoPlace),
              trailing: const Icon(Icons.arrow_forward, color: Colors.grey),
              onTap: () => _goToSearchResult(result),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildCategoryFilter(AppLocalizations l10n) {
    final selectedCategory = ref.watch(filteredSpotsProvider);
    final showFavorites = ref.watch(showFavoritesOnMapProvider);
    final showMySpots = ref.watch(showMyOwnSpotsProvider);
    final currentUser = ref.watch(currentUserProvider);

    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(25),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 2))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          children: [
            if (currentUser != null)
              _buildFilterChip(
                label: l10n.favoritesFilter,
                icon: showFavorites ? Icons.star : Icons.star_border,
                isSelected: showFavorites,
                color: Colors.amber,
                onSelected: (val) {
                  ref.read(showFavoritesOnMapProvider.notifier).state = val;
                  if (val) {
                    ref.read(showMyOwnSpotsProvider.notifier).state = false;
                    ref.read(filteredSpotsProvider.notifier).state = null;
                  }
                  _applyFilter();
                },
              ),
            if (currentUser != null)
              _buildFilterChip(
                label: l10n.mySpotsFilter,
                icon: showMySpots ? Icons.person : Icons.person_outline,
                isSelected: showMySpots,
                color: Colors.blue,
                onSelected: (val) {
                  ref.read(showMyOwnSpotsProvider.notifier).state = val;
                  if (val) {
                    ref.read(showFavoritesOnMapProvider.notifier).state = false;
                    ref.read(filteredSpotsProvider.notifier).state = null;
                  }
                  _applyFilter();
                },
              ),
            ...SpotCategory.values.map((cat) => _buildCategoryChip(cat, selectedCategory)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color color,
    required Function(bool) onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: FilterChip(
        selected: isSelected,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: isSelected ? color : Colors.grey),
            const SizedBox(width: 4),
            Text(label),
          ],
        ),
        selectedColor: color.withOpacity(0.25),
        checkmarkColor: color,
        onSelected: _isUpdatingMarkers ? null : onSelected,
      ),
    );
  }

  Widget _buildCategoryChip(SpotCategory category, SpotCategory? selectedCategory) {
    final isSelected = category == selectedCategory;
    final color = _getCategoryColor(category);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(category.icon),
            const SizedBox(width: 4),
            Text(category.getLocalizedName(context)),
          ],
        ),
        selected: isSelected,
        selectedColor: color.withOpacity(0.25),
        checkmarkColor: color,
        onSelected: _isUpdatingMarkers ? null : (_) {
          final current = ref.read(filteredSpotsProvider);
          final newFilter = current == category ? null : category;
          ref.read(filteredSpotsProvider.notifier).state = newFilter;
          if (newFilter != null) {
            ref.read(showFavoritesOnMapProvider.notifier).state = false;
            ref.read(showMyOwnSpotsProvider.notifier).state = false;
          }
          _applyFilter();
        },
      ),
    );
  }
}

class _PointAnnotationClickListener extends OnPointAnnotationClickListener {
  final Function(PointAnnotation) onTap;
  _PointAnnotationClickListener({required this.onTap});
  @override
  void onPointAnnotationClick(PointAnnotation annotation) => onTap(annotation);
}