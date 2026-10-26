// lib/features/favorites/presentation/folder_detail_screen.dart
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
import 'edit_folder_dialog.dart';

class FolderDetailScreen extends ConsumerWidget {
  final FolderModel folder;

  const FolderDetailScreen({Key? key, required this.folder}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spotsAsyncValue = ref.watch(folderSpotsProvider(folder.id));
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(folder.name),
        backgroundColor: folder.color,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareFolder(context, l10n),
            tooltip: l10n.share, // 🔄 Usando llave genérica 'share'
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => EditFolderDialog(folder: folder),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _showDeleteConfirmation(context, ref, l10n),
          ),
        ],
      ),
      body: spotsAsyncValue.when(
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
                  const SizedBox(height: 8),
                  Text(
                    l10n.addSpotsTip,
                    style: TextStyle(color: Colors.grey[500]),
                    textAlign: TextAlign.center,
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
              return _buildSpotCard(context, ref, spot, l10n);
            },
          );
        },
      ),
    );
  }

  Future<void> _shareFolder(BuildContext context, AppLocalizations l10n) async {
    try {
      // 🔄 1. Generar el cuerpo del mensaje usando la traducción y placeholders
      final localizedBody = l10n.shareFolderMessage(folder.name, folder.id);

      // 🔄 2. Pasar el texto al servicio con el parámetro nombrado correcto
      final shareText = DeepLinkService.generateShareText(
        localizedMessage: localizedBody,
      );

      await Share.share(
        shareText,
        // Opcional: El asunto suele ser la primera línea del mensaje
        subject: folder.name, 
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(l10n.folderShared),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.shareError}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildSpotCard(BuildContext context, WidgetRef ref, SpotModel spot, AppLocalizations l10n) {
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
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                child: CachedNetworkImage(
                  imageUrl: spot.photoUrls.first,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
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
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                        onPressed: () => _removeSpotFromFolder(context, ref, spot, l10n),
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
                  const SizedBox(height: 8),
                  Text(
                    spot.details, // 🔄 Asegúrate de usar 'details' si actualizaste el modelo
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

  // ... (Resto de métodos como _removeSpotFromFolder y _showDeleteConfirmation se mantienen igual)

  Future<void> _removeSpotFromFolder(BuildContext context, WidgetRef ref, SpotModel spot, AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.removeFromFolder),
        content: Text(l10n.removeSpotConfirm(spot.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.remove),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final folderService = ref.read(folderServiceProvider);
        await folderService.removeSpotFromFolder(folder.id, spot.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.spotRemovedFromFolder)),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _showDeleteConfirmation(BuildContext context, WidgetRef ref, AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteFolder),
        content: Text(l10n.deleteFolderConfirm(folder.name)),
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

    if (confirmed == true) {
      try {
        final folderService = ref.read(folderServiceProvider);
        await folderService.deleteFolder(folder.id);
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.folderDeleted)),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${l10n.deleteError}: $e')),
          );
        }
      }
    }
  }
}