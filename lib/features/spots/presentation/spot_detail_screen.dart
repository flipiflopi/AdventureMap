// lib/features/spots/presentation/spot_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:map_launcher/map_launcher.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../models/spot_model.dart' hide UserProfileModel;
import '../../../models/user_profile_model.dart';
import '../../../providers/providers.dart';
import '../../profile/presentation/user_profile_screen.dart';
import 'edit_spot_screen.dart';
import 'suggest_edit_screen.dart';
import '../../../providers/favorites_provider.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../favorites/presentation/create_folder_dialog.dart';
import '../../../models/spot_report_model.dart';
import 'report_spot_dialog.dart';
import '../../../services/content_moderation_service.dart';
import 'report_comment_dialog.dart';
import '../../../models/comment_report_model.dart';

class SpotDetailScreen extends ConsumerStatefulWidget {
  final SpotModel spot;

  const SpotDetailScreen({Key? key, required this.spot}) : super(key: key);

  @override
  ConsumerState<SpotDetailScreen> createState() => _SpotDetailScreenState();
}

class _SpotDetailScreenState extends ConsumerState<SpotDetailScreen>
    with TickerProviderStateMixin {
  int _currentImageIndex = 0;
  final PageController _pageController = PageController();

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  int _selectedDescriptionTab = 0;

  final TextEditingController _commentController = TextEditingController();
  int _commentsLimit = 10;

  int? _userRating;
  SpotModel? _currentSpot;
  bool _spotWasEdited = false;

  // 🆕 Estado de moderador cargado una sola vez
  bool _isModerator = false;

  @override
  void initState() {
    super.initState();
    _currentSpot = widget.spot;

    timeago.setLocaleMessages('es', timeago.EsMessages());

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOut),
    );

    _fadeController.forward();
    _slideController.forward();

    if (widget.spot.photoUrls.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        precacheImage(CachedNetworkImageProvider(widget.spot.photoUrls[0]), context);
        if (widget.spot.photoUrls.length > 1) {
          precacheImage(CachedNetworkImageProvider(widget.spot.photoUrls[1]), context);
        }
      });
    }

    _loadUserRating();
    _loadModeratorStatus(); // 🆕
  }

  // 🆕 Carga el estado de moderador una sola vez, sin streams
  // TODO: reemplazar con el link real de Play Store cuando esté publicada
  static const _appStoreLink = 'https://play.google.com/store/apps/details?id=com.adventuremap.app';

  void _shareSpot(AppLocalizations l10n) {
    final spot = _currentSpot ?? widget.spot;
    final text = l10n.shareSpotMessage(spot.name, _appStoreLink);
    Share.share(text, subject: spot.name);
  }

  Future<void> _loadModeratorStatus() async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;
    try {
      final profile = await ref.read(firestoreServiceProvider).getUserProfile(currentUser.uid);
      if (mounted) {
        setState(() {
          _isModerator = profile?.isModerator ?? false;
        });
      }
    } catch (e) {
      print('Error cargando moderador: $e');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _deleteSpot() async {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    final isOwner = currentUser.uid == widget.spot.createdBy;
    if (!isOwner && !_isModerator) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.delete_forever, color: Colors.red),
            const SizedBox(width: 8),
            Text(_isModerator && !isOwner ? l10n.deleteSpotMod : l10n.deleteSpot),
          ],
        ),
        content: Text(
          '${l10n.deleteSpotConfirm(widget.spot.name)}\n\n'
          '${_isModerator && !isOwner ? l10n.deleteSpotModNotice : ""}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        await ref.read(firestoreServiceProvider).deleteSpot(widget.spot.id);
        if (mounted) {
          Navigator.pop(context);
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isModerator && !isOwner ? l10n.spotDeletedMod : l10n.spotDeletedSuccess),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${l10n.error}: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _reloadSpot() async {
    try {
      final updatedSpot = await ref.read(firestoreServiceProvider).getSpotById(widget.spot.id);
      if (updatedSpot != null && mounted) {
        setState(() {
          _currentSpot = updatedSpot;
          _commentsLimit = 10;
          _spotWasEdited = true;
        });
        await _loadUserRating();
      }
    } catch (e) {
      print('❌ Error recargando spot: $e');
    }
  }

  Future<void> _showReportDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.loginToReport)));
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => ReportSpotDialog(spotId: widget.spot.id, spotName: widget.spot.name),
    );

    if (result != null && mounted) {
      try {
        await ref.read(firestoreServiceProvider).createSpotReport(SpotReport(
          id: '',
          spotId: widget.spot.id,
          reportedBy: currentUser.uid,
          reasons: result['reasons'] as List<ReportReason>,
          description: result['description'] as String,
          createdAt: DateTime.now(),
        ));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.reportSentSuccess), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.error}: $e')));
        }
      }
    }
  }

  Future<void> _archiveSpot() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.inventory, color: Colors.orange),
            const SizedBox(width: 8),
            Text(l10n.archiveSpot),
          ],
        ),
        content: Text(l10n.archiveSpotConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text(l10n.archive),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final currentUser = ref.read(currentUserProvider);
        if (currentUser == null) return;
        await ref.read(firestoreServiceProvider).archiveSpot(widget.spot.id, currentUser.uid);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.spotArchivedSuccess), backgroundColor: Colors.orange),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.error}: $e')));
        }
      }
    }
  }

  Future<void> _showAddToFolderDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.mustLoginError)));
      return;
    }

    final folderService = ref.read(folderServiceProvider);
    final foldersSnapshot = await folderService.getUserFolders(currentUser.uid).first;
    final foldersWithSpot = await folderService.getFoldersContainingSpot(currentUser.uid, widget.spot.id);
    final foldersWithSpotIds = foldersWithSpot.map((f) => f.id).toSet();

    if (!mounted) return;

    if (foldersSnapshot.isEmpty) {
      final createFolder = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.noFolders),
          content: Text(l10n.noFoldersDesc),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.createFolder)),
          ],
        ),
      );
      if (createFolder == true && mounted) {
        await showDialog(
          context: context,
          builder: (context) => CreateFolderDialog(userId: currentUser.uid),
        );
        if (mounted) _showAddToFolderDialog();
      }
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.saveToFolder),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: foldersSnapshot.length,
            itemBuilder: (context, index) {
              final folder = foldersSnapshot[index];
              final isInFolder = foldersWithSpotIds.contains(folder.id);
              return CheckboxListTile(
                secondary: Icon(folder.icon, color: folder.color),
                title: Text(folder.name),
                subtitle: Text('${folder.spotIds.length} ${l10n.places}'),
                value: isInFolder,
                onChanged: (value) async {
                  try {
                    if (value == true) {
                      await folderService.addSpotToFolder(folder.id, widget.spot.id);
                    } else {
                      await folderService.removeSpotFromFolder(folder.id, widget.spot.id);
                    }
                    if (context.mounted) {
                      Navigator.pop(context);
                      _showAddToFolderDialog();
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.error}: $e')));
                    }
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.close)),
        ],
      ),
    );
  }

  Future<void> _loadUserRating() async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;
    try {
      final rating = await ref.read(firestoreServiceProvider).getUserRatingForSpot(currentUser.uid, widget.spot.id);
      if (mounted && rating != null) {
        setState(() => _userRating = rating.rating);
      }
    } catch (e) {
      print('Error cargando rating: $e');
    }
  }

  Future<void> _showRatingDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.loginToRate)));
      return;
    }

    int tempRating = _userRating ?? 0;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 24),
              const SizedBox(width: 8),
              Text(l10n.rateSpotTitle),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  final starValue = index + 1;
                  final isSelected = tempRating >= starValue;
                  return GestureDetector(
                    onTap: () => setDialogState(() => tempRating = starValue),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Icon(
                        isSelected ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 36,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              if (tempRating > 0)
                Text(l10n.starCount(tempRating),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
            ElevatedButton(
              onPressed: tempRating > 0 ? () { Navigator.pop(context); _submitRating(tempRating); } : null,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.white),
              child: Text(l10n.puntuar),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitRating(int rating) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final currentUser = ref.read(currentUserProvider)!;
      await ref.read(firestoreServiceProvider).rateSpot(
        spotId: widget.spot.id,
        userId: currentUser.uid,
        rating: rating,
      );
      setState(() => _userRating = rating);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.ratingSuccess(rating)), backgroundColor: Colors.green, duration: const Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.error}: $e')));
      }
    }
  }

  Future<void> _submitComment() async {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.mustLoginError)));
      return;
    }

    final comment = _commentController.text.trim();
    if (comment.isEmpty) return;
    if (comment.length > 500) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.maxPhotosError)));
      return;
    }

    final moderationResult = ContentModerationService.checkContent(comment);
    if (!moderationResult.isClean) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(moderationResult.errorMessage), backgroundColor: Colors.red, duration: const Duration(seconds: 3)),
      );
      return;
    }

    try {
      final userProfile = await ref.read(firestoreServiceProvider).getUserProfile(currentUser.uid);
      await ref.read(firestoreServiceProvider).createComment(
        spotId: widget.spot.id,
        userId: currentUser.uid,
        userName: userProfile?.displayNameOrEmail ?? l10n.user,
        userPhoto: userProfile?.photoUrl,
        comment: comment,
      );

      _commentController.clear();
      FocusScope.of(context).unfocus();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.commentPublished), backgroundColor: Colors.green, duration: const Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.error}: $e')));
      }
    }
  }

  Future<void> _editComment(SpotComment comment) async {
    final l10n = AppLocalizations.of(context)!;
    final TextEditingController editController = TextEditingController(text: comment.comment);

    final String? result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(l10n.editComment),
          content: SizedBox(
            width: double.maxFinite,
            child: TextFormField(
              controller: editController,
              maxLines: 5,
              maxLength: 500,
              autofocus: true,
              decoration: InputDecoration(hintText: l10n.addCommentHint, border: const OutlineInputBorder()),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(null), child: Text(l10n.cancel)),
            ElevatedButton(
              onPressed: () {
                final text = editController.text.trim();
                if (text.isNotEmpty) Navigator.of(dialogContext).pop(text);
              },
              child: Text(l10n.saveChanges),
            ),
          ],
        );
      },
    );

    await Future.delayed(const Duration(milliseconds: 100));
    editController.dispose();

    if (result == null || result == comment.comment) return;
    if (!mounted) return;

    final moderationResult = ContentModerationService.checkContent(result);
    if (!moderationResult.isClean) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(moderationResult.errorMessage), backgroundColor: Colors.red, duration: const Duration(seconds: 3)),
      );
      return;
    }

    try {
      await ref.read(firestoreServiceProvider).updateComment(comment.id, result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.commentUpdated), backgroundColor: Colors.green, duration: const Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.error}: $e')));
      }
    }
  }

  Future<void> _deleteComment(SpotComment comment, {bool isModerator = false}) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteComment),
        content: Text(isModerator ? l10n.deleteCommentModConfirm : l10n.deleteCommentConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(firestoreServiceProvider).deleteComment(comment.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isModerator ? l10n.commentDeletedMod : l10n.commentDeleted),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${l10n.error}: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Color _getCategoryColor(SpotCategory category) {
    switch (category) {
      case SpotCategory.surf: return Colors.blue.shade700;
      case SpotCategory.snorkel: return Colors.cyan.shade600;
      case SpotCategory.cliffJumping: return Colors.red.shade700;
      case SpotCategory.caves: return Colors.brown.shade400;
      case SpotCategory.naturalPool: return Colors.lightBlue.shade600;
      case SpotCategory.viewpoint: return Colors.purple.shade500;
      case SpotCategory.sunset: return Colors.orange.shade700;
      default: return Colors.grey.shade600;
    }
  }

  Future<void> _toggleFavorite() async {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.mustLoginError)));
      return;
    }
    try {
      await ref.read(optimizedFavoritesProvider.notifier).toggle(widget.spot.id);
      if (mounted) {
        final isFavorite = ref.read(optimizedFavoritesProvider).contains(widget.spot.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isFavorite ? l10n.addedToFavorites : l10n.removedFromFavorites),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.error}: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openFullscreenGallery(int initialIndex) {
    final spot = _currentSpot ?? widget.spot;
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => FullscreenGallery(
          imageUrls: spot.photoUrls,
          initialIndex: initialIndex,
          forceRefresh: _spotWasEdited,
        ),
      ),
    );
  }

  void _editSpot() {
    final spot = _currentSpot ?? widget.spot;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditSpotScreen(spot: spot)),
    ).then((updated) async {
      if (updated == true && mounted) await _reloadSpot();
    });
  }

  void _suggestEdit() {
    final spot = _currentSpot ?? widget.spot;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SuggestEditScreen(spot: spot)),
    );
  }

  Future<void> _openInMaps() async {
    final l10n = AppLocalizations.of(context)!;
    final spot = _currentSpot ?? widget.spot;
    try {
      final availableMaps = await MapLauncher.installedMaps;
      if (availableMaps.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.noMapApp)));
        return;
      }
      if (availableMaps.length == 1) {
        await availableMaps.first.showMarker(
          coords: Coords(spot.latitude, spot.longitude),
          title: spot.name,
          description: spot.details,
        );
        return;
      }
      await showModalBottomSheet(
        context: context,
        builder: (BuildContext context) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(l10n.openWith, style: Theme.of(context).textTheme.titleLarge),
                ),
                ...availableMaps.map((map) => ListTile(
                  leading: SizedBox(width: 30, height: 30, child: Image.asset(map.icon)),
                  title: Text(map.mapName),
                  onTap: () async {
                    Navigator.pop(context);
                    await map.showMarker(
                      coords: Coords(spot.latitude, spot.longitude),
                      title: spot.name,
                      description: spot.details,
                    );
                  },
                )),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      );
    } catch (e) {
      print('Error abriendo mapas: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = ref.watch(currentUserProvider);
    final isFavorite = ref.watch(optimizedFavoritesProvider).contains(widget.spot.id);
    final isOwner = currentUser?.uid == widget.spot.createdBy;
    final screenWidth = MediaQuery.of(context).size.width;
    final imageHeight = screenWidth * 0.75;

    return StreamBuilder<SpotModel?>(
      stream: ref.read(firestoreServiceProvider).getSpotStream(widget.spot.id),
      initialData: widget.spot,
      builder: (context, spotSnapshot) {
        final displaySpot = spotSnapshot.data ?? widget.spot;

        return Scaffold(
          body: RefreshIndicator(
            onRefresh: () async => await _reloadSpot(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  expandedHeight: imageHeight,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    background: _buildImageGallery(displaySpot, l10n),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.share, color: Colors.white),
                      tooltip: l10n.shareSpot,
                      onPressed: () => _shareSpot(l10n),
                    ),
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: IconButton(
                        icon: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: isFavorite ? Colors.red : Colors.white,
                        ),
                        onPressed: _toggleFavorite,
                      ),
                    ),
                    if (currentUser != null)
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: IconButton(
                          icon: const Icon(Icons.flag_outlined),
                          tooltip: l10n.reportError,
                          onPressed: _showReportDialog,
                        ),
                      ),
                    if (currentUser != null)
                      IconButton(
                        icon: const Icon(Icons.bookmark_add_outlined),
                        tooltip: l10n.saveToFolder,
                        onPressed: _showAddToFolderDialog,
                      ),
                    if (isOwner || _isModerator)
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (value) {
                            if (value == 'edit') _editSpot();
                            else if (value == 'archive') _archiveSpot();
                            else if (value == 'delete') _deleteSpot();
                          },
                          itemBuilder: (context) => [
                            if (isOwner || _isModerator)
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    const Icon(Icons.edit, size: 20),
                                    const SizedBox(width: 12),
                                    Text(_isModerator && !isOwner ? '${l10n.editSpot} (Mod)' : l10n.editSpot),
                                  ],
                                ),
                              ),
                            if (_isModerator)
                              PopupMenuItem(
                                value: 'archive',
                                child: Row(
                                  children: [
                                    const Icon(Icons.inventory, size: 20, color: Colors.orange),
                                    const SizedBox(width: 12),
                                    Text(l10n.archiveSpot),
                                  ],
                                ),
                              ),
                            if (isOwner || _isModerator)
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    const Icon(Icons.delete_forever, size: 20, color: Colors.red),
                                    const SizedBox(width: 12),
                                    Text(
                                      _isModerator && !isOwner ? '${l10n.delete} (Mod)' : l10n.delete,
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(displaySpot, l10n),
                            const SizedBox(height: 12),
                            _buildRateButton(l10n),
                            const SizedBox(height: 16),
                            _buildDescriptionTabs(displaySpot, l10n),
                            const SizedBox(height: 16),
                            _buildCreatorCard(displaySpot, l10n),
                            const SizedBox(height: 16),
                            _buildInfoCard(
                              icon: Icons.favorite,
                              title: l10n.favoritesTitle,
                              content: '${displaySpot.favoriteCount} ${l10n.people}',
                            ),
                            const SizedBox(height: 20),
                            _buildMiniMap(displaySpot, l10n),
                            const SizedBox(height: 24),
                            _buildCommentsSection(displaySpot, l10n),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(SpotModel spot, AppLocalizations l10n) {
    final hasRatings = spot.ratingCount > 0;
    return Row(
      children: [
        ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(
            CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
          ),
          child: Text(spot.category.icon, style: const TextStyle(fontSize: 32)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(spot.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  ),
                  if (hasRatings) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.star, color: Colors.amber, size: 20),
                    const SizedBox(width: 4),
                    Text(spot.ratingAverage.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(' (${spot.ratingCount})',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(spot.category.getLocalizedName(context),
                  style: TextStyle(fontSize: 16, color: Colors.grey[600])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRateButton(AppLocalizations l10n) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _showRatingDialog,
        icon: Icon(_userRating != null ? Icons.star : Icons.star_border, color: Colors.amber, size: 20),
        label: Text(_userRating != null ? '${l10n.rateSpotTitle}: $_userRating ⭐' : l10n.rateSpotTitle),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.amber.shade700),
          foregroundColor: Colors.amber.shade700,
        ),
      ),
    );
  }

  Widget _buildDescriptionTabs(SpotModel spot, AppLocalizations l10n) {
    return Card(
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[300]!))),
            child: Row(
              children: [
                _buildTab(l10n.detailsTab, 0, Icons.description),
                _buildTab(l10n.accessTab, 1, Icons.directions_car),
                _buildTab(l10n.safetyTab, 2, Icons.warning_amber),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(16), child: _buildTabContent(spot, l10n)),
        ],
      ),
    );
  }

  Widget _buildTab(String title, int index, IconData icon) {
    final isSelected = _selectedDescriptionTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedDescriptionTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(
              color: isSelected ? Colors.blue : Colors.transparent,
              width: 2,
            )),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: isSelected ? Colors.blue : Colors.grey),
              const SizedBox(width: 4),
              Text(title, style: TextStyle(
                color: isSelected ? Colors.blue : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(SpotModel spot, AppLocalizations l10n) {
    String content;
    String placeholder;
    switch (_selectedDescriptionTab) {
      case 0: content = spot.details; placeholder = l10n.noDetailsInfo; break;
      case 1: content = spot.access; placeholder = l10n.noAccessInfo; break;
      case 2: content = spot.safety; placeholder = l10n.noSafetyInfo; break;
      default: content = ''; placeholder = '';
    }
    return content.isEmpty
        ? Text(placeholder, style: TextStyle(color: Colors.grey[500], fontStyle: FontStyle.italic))
        : Text(content, style: const TextStyle(fontSize: 16));
  }

  Widget _buildCommentsSection(SpotModel spot, AppLocalizations l10n) {
    final firestoreService = ref.watch(firestoreServiceProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.chat_bubble_outline, size: 22),
            const SizedBox(width: 8),
            Text(l10n.comments, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 16),
        _buildAddCommentBox(l10n),
        const SizedBox(height: 16),
        StreamBuilder<List<SpotComment>>(
          stream: firestoreService.getSpotComments(spot.id, limit: _commentsLimit),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Card(
                color: Colors.grey[50],
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text(l10n.noComments,
                            style: TextStyle(color: Colors.grey[600], fontSize: 16, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text(l10n.firstCommentPrompt,
                            style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              );
            }
            final comments = snapshot.data!;
            return Column(
              children: [
                ...comments.map((comment) => _buildCommentItem(comment, l10n)),
                if (comments.length >= _commentsLimit)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() => _commentsLimit += 10),
                        icon: const Icon(Icons.expand_more),
                        label: Text(l10n.viewMoreComments),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildAddCommentBox(AppLocalizations l10n) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey[300],
              child: Icon(Icons.person, size: 20, color: Colors.grey[600]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _commentController,
                maxLength: 500,
                maxLines: null,
                decoration: InputDecoration(
                  hintText: l10n.addCommentHint,
                  border: InputBorder.none,
                  counterText: '',
                ),
              ),
            ),
            IconButton(
              onPressed: _submitComment,
              icon: const Icon(Icons.send, color: Colors.blue),
              tooltip: l10n.publish,
            ),
          ],
        ),
      ),
    );
  }

  // 🔑 FIX DEFINITIVO: usa _isModerator (variable de estado), sin streams ni futures internos
  Widget _buildCommentItem(SpotComment comment, AppLocalizations l10n) {
    final currentUser = ref.watch(currentUserProvider);
    final isCommentOwner = currentUser?.uid == comment.userId;
    final canModerate = isCommentOwner || _isModerator;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InkWell(
                  onTap: () {
                    if (currentUser?.uid == comment.userId) {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
                    } else {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (context) => UserProfileScreen(userId: comment.userId),
                      ));
                    }
                  },
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: comment.userPhoto != null
                            ? CachedNetworkImageProvider(comment.userPhoto!)
                            : null,
                        backgroundColor: Colors.grey[300],
                        child: comment.userPhoto == null
                            ? Icon(Icons.person, size: 20, color: Colors.grey[600])
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(comment.userName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blue)),
                          Text(timeago.format(comment.createdAt, locale: 'es'),
                              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (currentUser != null && !isCommentOwner)
                  IconButton(
                    icon: Icon(Icons.flag_outlined, size: 20, color: Colors.grey[600]),
                    onPressed: () => _reportComment(comment),
                    tooltip: l10n.reportComment,
                  ),
                if (currentUser != null && canModerate)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, size: 20, color: Colors.grey[600]),
                    itemBuilder: (context) => [
                      if (isCommentOwner)
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              const Icon(Icons.edit, size: 18),
                              const SizedBox(width: 8),
                              Text(l10n.editComment),
                            ],
                          ),
                        ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(Icons.delete, size: 18, color: Colors.red),
                            const SizedBox(width: 8),
                            Text(_isModerator && !isCommentOwner ? '${l10n.delete} (Mod)' : l10n.delete),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) => _handleCommentAction(value, comment, _isModerator && !isCommentOwner),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(comment.comment, style: const TextStyle(fontSize: 15)),
            if (comment.editedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(l10n.edited,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500], fontStyle: FontStyle.italic)),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _reportComment(SpotComment comment) async {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.loginToReport)));
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => ReportCommentDialog(
        commentId: comment.id,
        spotId: widget.spot.id,
        commentText: comment.comment,
      ),
    );

    if (result != null && mounted) {
      try {
        await ref.read(firestoreServiceProvider).createCommentReport(CommentReport(
          id: '',
          commentId: comment.id,
          spotId: widget.spot.id,
          reportedBy: currentUser.uid,
          reasons: result['reasons'] as List<CommentReportReason>,
          description: result['description'] as String,
          createdAt: DateTime.now(),
        ));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.reportSentSuccess), backgroundColor: Colors.green, duration: const Duration(seconds: 3)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.error}: $e')));
        }
      }
    }
  }

  void _handleCommentAction(String action, SpotComment comment, bool isModerator) {
    if (action == 'edit') _editComment(comment);
    else if (action == 'delete') _deleteComment(comment, isModerator: isModerator);
  }

  Widget _buildCreatorCard(SpotModel spot, AppLocalizations l10n) {
    return FutureBuilder(
      future: ref.read(firestoreServiceProvider).getUserProfile(spot.createdBy),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(child: Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())));
        }
        final creator = snapshot.data;
        if (creator == null) return const SizedBox.shrink();
        final currentUser = ref.watch(currentUserProvider);
        final isCurrentUser = currentUser?.uid == spot.createdBy;
        return Card(
          child: InkWell(
            onTap: () {
              if (isCurrentUser) {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
              } else {
                Navigator.push(context, MaterialPageRoute(
                  builder: (context) => UserProfileScreen(userId: spot.createdBy),
                ));
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: creator.photoUrl != null ? CachedNetworkImageProvider(creator.photoUrl!) : null,
                    child: creator.photoUrl == null ? const Icon(Icons.person) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isCurrentUser ? l10n.createdByYou : l10n.createdBy,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                        const SizedBox(height: 4),
                        Text(creator.displayName ?? creator.email,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.blue)),
                        const SizedBox(height: 2),
                        Text(DateFormat('dd/MM/yyyy').format(spot.createdAt),
                            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMiniMap(SpotModel spot, AppLocalizations l10n) {
    final point = Point(coordinates: Position(spot.longitude, spot.latitude));
    final currentUser = ref.watch(currentUserProvider);
    final isOwner = currentUser?.uid == spot.createdBy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.location_on, size: 22, color: Colors.red),
            const SizedBox(width: 8),
            Text(l10n.locationLabel, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: MapWidget(
              cameraOptions: CameraOptions(center: point, zoom: 14.0),
              styleUri: MapboxStyles.OUTDOORS,
              onMapCreated: (mapboxMap) {
                mapboxMap.annotations.createCircleAnnotationManager().then((manager) {
                  manager.create(CircleAnnotationOptions(
                    geometry: point,
                    circleRadius: 12.0,
                    circleColor: _getCategoryColor(spot.category).value,
                    circleStrokeWidth: 3.0,
                    circleStrokeColor: Colors.white.value,
                  ));
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _openInMaps,
            icon: const Icon(Icons.directions),
            label: Text(l10n.howToGetThere),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
          ),
        ),
        if (!isOwner && currentUser != null) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _suggestEdit,
              icon: const Icon(Icons.edit_note),
              label: Text(l10n.suggestChanges),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text('Lat: ${spot.latitude.toStringAsFixed(6)}, Lng: ${spot.longitude.toStringAsFixed(6)}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildInfoCard({required IconData icon, required String title, required String content}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).primaryColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                  const SizedBox(height: 4),
                  Text(content, style: const TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGallery(SpotModel spot, AppLocalizations l10n) {
    if (spot.photoUrls.isEmpty) {
      return Container(
        color: Colors.grey[300],
        child: Center(child: Icon(Icons.image, size: 80, color: Colors.grey[600])),
      );
    }

    return GestureDetector(
      onTap: () => _openFullscreenGallery(_currentImageIndex),
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: spot.photoUrls.length,
            onPageChanged: (index) {
              setState(() => _currentImageIndex = index);
              if (index + 1 < spot.photoUrls.length) {
                precacheImage(CachedNetworkImageProvider(spot.photoUrls[index + 1]), context);
              }
            },
            itemBuilder: (context, index) {
              return Hero(
                tag: 'spot_image_${spot.photoUrls[index]}',
                child: CachedNetworkImage(
                  imageUrl: spot.photoUrls[index],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[300],
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[300],
                    child: Center(child: Icon(Icons.error_outline, size: 50, color: Colors.red[300])),
                  ),
                ),
              );
            },
          ),
          Positioned(
            bottom: 70,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.fullscreen, color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Text(l10n.tapToEnlarge,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          ),
          if (spot.photoUrls.length > 1)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  spot.photoUrls.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentImageIndex == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: _currentImageIndex == index ? Colors.white : Colors.white.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// FullscreenGallery
class FullscreenGallery extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final bool forceRefresh;

  const FullscreenGallery({
    Key? key,
    required this.imageUrls,
    required this.initialIndex,
    this.forceRefresh = false,
  }) : super(key: key);

  @override
  State<FullscreenGallery> createState() => _FullscreenGalleryState();
}

class _FullscreenGalleryState extends State<FullscreenGallery> {
  late int _currentIndex;
  late String _cacheKey;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _cacheKey = widget.forceRefresh ? DateTime.now().millisecondsSinceEpoch.toString() : '';
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    super.dispose();
  }

  void _nextImage() {
    if (_currentIndex < widget.imageUrls.length - 1) setState(() => _currentIndex++);
  }

  void _previousImage() {
    if (_currentIndex > 0) setState(() => _currentIndex--);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 1.0,
              maxScale: 4.0,
              child: Hero(
                tag: 'image_${widget.imageUrls[_currentIndex]}',
                child: CachedNetworkImage(
                  imageUrl: widget.imageUrls[_currentIndex],
                  cacheKey: _cacheKey.isNotEmpty
                      ? '${widget.imageUrls[_currentIndex]}_$_cacheKey'
                      : widget.imageUrls[_currentIndex],
                  fit: BoxFit.contain,
                  placeholder: (context, url) =>
                      const Center(child: CircularProgressIndicator(color: Colors.white)),
                  errorWidget: (context, url, error) =>
                      const Center(child: Icon(Icons.error, color: Colors.white, size: 50)),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Colors.white, size: 28),
                ),
              ),
            ),
          ),
          if (widget.imageUrls.length > 1)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentIndex + 1} / ${widget.imageUrls.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          if (widget.imageUrls.length > 1 && _currentIndex > 0)
            Positioned(
              left: 16, top: 0, bottom: 0,
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _previousImage,
                    child: Container(
                      width: 60, height: 60,
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 28),
                    ),
                  ),
                ),
              ),
            ),
          if (widget.imageUrls.length > 1 && _currentIndex < widget.imageUrls.length - 1)
            Positioned(
              right: 16, top: 0, bottom: 0,
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _nextImage,
                    child: Container(
                      width: 60, height: 60,
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 28),
                    ),
                  ),
                ),
              ),
            ),
          if (widget.imageUrls.length > 1)
            Positioned(
              bottom: 40, left: 0, right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.imageUrls.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentIndex == index ? Colors.white : Colors.white.withOpacity(0.4),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}