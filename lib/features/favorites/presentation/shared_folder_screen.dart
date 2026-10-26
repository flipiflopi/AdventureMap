// lib/features/favorites/presentation/shared_folder_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../models/folder_model.dart';
import '../../../models/spot_model.dart';
import '../../../providers/providers.dart';
import '../../../services/deep_link_service.dart';
import '../../spots/presentation/spot_detail_screen.dart';

class SharedFolderScreen extends ConsumerWidget {
  final String folderId;

  const SharedFolderScreen({Key? key, required this.folderId}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folderService = ref.watch(folderServiceProvider);
    final l10n = AppLocalizations.of(context)!;

    return FutureBuilder<FolderModel?>(
      future: folderService.getFolderById(folderId),
      builder: (context, folderSnapshot) {
        if (folderSnapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(
              title: Text(l10n.loading),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(l10n.loadingSharedFolder),
                ],
              ),
            ),
          );
        }

        if (folderSnapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: Text(l10n.error),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(l10n.folderLoadError),
                  const SizedBox(height: 8),
                  Text(
                    folderSnapshot.error.toString(),
                    style: TextStyle(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.back),
                  ),
                ],
              ),
            ),
          );
        }

        final folder = folderSnapshot.data;

        if (folder == null) {
          return Scaffold(
            appBar: AppBar(
              title: Text(l10n.folderNotFound),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_off, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    l10n.folderNotFoundDescription,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.back),
                  ),
                ],
              ),
            ),
          );
        }

        final spotsAsyncValue = ref.watch(folderSpotsProvider(folder.id));

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Icon(folder.icon, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    folder.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: folder.color,
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () => _shareFolder(context, folder, l10n),
                tooltip: l10n.share,
              ),
            ],
          ),
          body: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: folder.color.withOpacity(0.1),
                  border: Border(
                    bottom: BorderSide(
                      color: folder.color.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.share,
                      color: folder.color,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.sharedFolderBanner,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.exploreSpotsCount(folder.spotIds.length),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: spotsAsyncValue.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) {
                    return Center(
                      child: Text('${l10n.favoritesLoadError}: $err'),
                    );
                  },
                  data: (spots) {
                    if (spots.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              folder.icon,
                              size: 80,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              l10n.folderEmpty,
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: spots.length,
                      padding: const EdgeInsets.all(16),
                      itemBuilder: (context, index) {
                        final spot = spots[index];
                        return _buildSpotCard(context, spot, index + 1);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          bottomNavigationBar: _buildBottomBar(context, folder, l10n),
        );
      },
    );
  }

  Widget _buildSpotCard(BuildContext context, SpotModel spot, int number) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    child: CachedNetworkImage(
                      imageUrl: spot.photoUrls.first,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '#$number',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
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
                    spot.category.getLocalizedName(context),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  if (spot.details.isNotEmpty) ...[ // 🔄 Corregido de description a details si usas el modelo nuevo
                    const SizedBox(height: 8),
                    Text(
                      spot.details,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, FolderModel folder, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _shareFolder(context, folder, l10n),
              icon: const Icon(Icons.share),
              label: Text(l10n.share),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/home',
                  (route) => false,
                );
              },
              icon: const Icon(Icons.explore),
              label: Text(l10n.exploreApp),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareFolder(BuildContext context, FolderModel folder, AppLocalizations l10n) async {
    try {
      // 🔄 CORRECCIÓN: Generar el mensaje traducido desde el l10n y pasarlo como parámetro nombrado
      final localizedBody = l10n.shareFolderMessage(folder.name, folder.id);
      
      final shareText = DeepLinkService.generateShareText(
        localizedMessage: localizedBody,
      );

      await Share.share(
        shareText,
        // Suponiendo que tienes una llave 'shareSubject' en tu ARB que acepta un nombre
        subject: l10n.shareFolderMessage(folder.name, folder.id).split('\n').first,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.error}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}