import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import '../../../models/spot_suggestion_model.dart';
import '../../../models/spot_model.dart';
import '../../../models/spot_report_model.dart';
import '../../../models/comment_report_model.dart';

import '../../../providers/providers.dart';

import 'pending_spot_detail_screen.dart';
import '../../spots/presentation/spot_detail_screen.dart';

class ModerationScreen extends ConsumerStatefulWidget {
  final int initialTab;

  const ModerationScreen({Key? key, this.initialTab = 0}) : super(key: key);

  @override
  ConsumerState<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends ConsumerState<ModerationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
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

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Moderación')),
        body: const Center(child: Text('Debes iniciar sesión')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Moderación'),
        backgroundColor: Colors.orange,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Spots Pendientes', icon: Icon(Icons.pending_actions)),
            Tab(text: 'Reportes Spots', icon: Icon(Icons.report_problem)),
            Tab(text: 'Reportes Comentarios', icon: Icon(Icons.comment_bank)),
            Tab(text: 'Archivados', icon: Icon(Icons.archive)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingSpotsTab(context, currentUser.uid),
          _buildReportsTab(context, currentUser.uid),
          _buildCommentReportsTab(context, currentUser.uid),
          _buildArchivedSpotsTab(context, currentUser.uid),
        ],
      ),
    );
  }

  Widget _buildAccessDenied() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Solo moderadores pueden acceder a esta sección',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPendingSpotsTab(BuildContext context, String userId) {
    final firestoreService = ref.watch(firestoreServiceProvider);

    return FutureBuilder(
      future: firestoreService.getUserProfile(userId),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData || userSnapshot.data?.isModerator != true) {
          return _buildAccessDenied();
        }

        return StreamBuilder<List<PendingSpot>>(
          stream: firestoreService.getPendingSpots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final pendingSpots = snapshot.data ?? [];

            if (pendingSpots.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, size: 80, color: Colors.green),
                    SizedBox(height: 16),
                    Text(
                      'No hay spots pendientes de revisión',
                      style: TextStyle(fontSize: 18),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: pendingSpots.length,
              itemBuilder: (context, index) {
                final pendingSpot = pendingSpots[index];
                return _buildPendingSpotCard(context, pendingSpot, userId);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildReportsTab(BuildContext context, String userId) {
    final firestoreService = ref.watch(firestoreServiceProvider);

    return FutureBuilder(
      future: firestoreService.getUserProfile(userId),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData || userSnapshot.data?.isModerator != true) {
          return _buildAccessDenied();
        }

        return StreamBuilder<List<SpotReport>>(
          stream: firestoreService.getPendingReports(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final reports = snapshot.data ?? [];

            if (reports.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, size: 80, color: Colors.green),
                    SizedBox(height: 16),
                    Text('No hay reportes de spots pendientes',
                        style: TextStyle(fontSize: 18)),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: reports.length,
              itemBuilder: (context, index) {
                final report = reports[index];
                return _buildReportCard(context, report, userId);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCommentReportsTab(BuildContext context, String userId) {
    final firestoreService = ref.watch(firestoreServiceProvider);

    return FutureBuilder(
      future: firestoreService.getUserProfile(userId),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData || userSnapshot.data?.isModerator != true) {
          return _buildAccessDenied();
        }

        return StreamBuilder<List<CommentReport>>(
          stream: firestoreService.getPendingCommentReports(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final commentReports = snapshot.data ?? [];

            if (commentReports.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, size: 80, color: Colors.green),
                    SizedBox(height: 16),
                    Text(
                      'No hay reportes de comentarios pendientes',
                      style: TextStyle(fontSize: 18),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: commentReports.length,
              itemBuilder: (context, index) {
                final report = commentReports[index];
                return _buildCommentReportCard(context, report, userId);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildArchivedSpotsTab(BuildContext context, String userId) {
    final firestoreService = ref.watch(firestoreServiceProvider);

    return FutureBuilder(
      future: firestoreService.getUserProfile(userId),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData || userSnapshot.data?.isModerator != true) {
          return _buildAccessDenied();
        }

        return StreamBuilder<List<SpotModel>>(
          stream: firestoreService.getArchivedSpots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final archivedSpots = snapshot.data ?? [];

            if (archivedSpots.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inventory_2, size: 80, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No hay spots archivados',
                        style: TextStyle(fontSize: 18)),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: archivedSpots.length,
              itemBuilder: (context, index) {
                final spot = archivedSpots[index];
                return _buildArchivedSpotCard(context, spot, userId);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPendingSpotCard(
      BuildContext context,
      PendingSpot pendingSpot,
      String moderatorId,
      ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PendingSpotDetailScreen(
                pendingSpot: pendingSpot,
                moderatorId: moderatorId,
              ),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                if (pendingSpot.photoUrls.isNotEmpty)
                  ClipRRect(
                    borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(4)),
                    child: CachedNetworkImage(
                      imageUrl: pendingSpot.photoUrls.first,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        height: 200,
                        color: Colors.grey[300],
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 200,
                        color: Colors.grey[300],
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image,
                                size: 48, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('Error al cargar imagen'),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image_not_supported,
                            size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('Sin imágenes'),
                      ],
                    ),
                  ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Text(
                      'PENDIENTE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pendingSpot.name.isNotEmpty ? pendingSpot.name : 'Sin nombre',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    pendingSpot.description.isNotEmpty
                        ? pendingSpot.description
                        : 'Sin descripción',
                    style: TextStyle(color: Colors.grey[700]),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.category, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(pendingSpot.category,
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 14)),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_on,
                              size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '${pendingSpot.latitude.toStringAsFixed(4)}, ${pendingSpot.longitude.toStringAsFixed(4)}',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PendingSpotDetailScreen(
                                  pendingSpot: pendingSpot,
                                  moderatorId: moderatorId,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.visibility, size: 18),
                          label: const Text('Ver detalles'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _approvePendingSpot(
                              context, pendingSpot.id, moderatorId),
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Aprobar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showRejectDialog(
                          context, pendingSpot.id, moderatorId),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Rechazar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(
      BuildContext context, SpotReport report, String moderatorId) {
    final firestoreService = ref.watch(firestoreServiceProvider);

    return FutureBuilder<SpotModel?>(
      future: firestoreService.getSpotById(report.spotId),
      builder: (context, spotSnapshot) {
        if (spotSnapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            margin: EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final spot = spotSnapshot.data;
        if (spot == null) {
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                  'Spot reportado no encontrado (ID: ${report.spotId})'),
            ),
          );
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  if (spot.photoUrls.isNotEmpty)
                    ClipRRect(
                      borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
                      child: CachedNetworkImage(
                        imageUrl: spot.photoUrls.first,
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Container(
                      height: 150,
                      color: Colors.grey[300],
                      child: const Center(
                          child: Icon(Icons.image_not_supported, size: 48)),
                    ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'REPORTADO: ${report.reasons.length} motivos',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(spot.category.icon,
                            style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            spot.name,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Motivos reportados:',
                      style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: report.reasons.map((reason) {
                        return Chip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(reason.icon),
                              const SizedBox(width: 4),
                              Text(reason.getLocalizedName(context),
                                  style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                          backgroundColor: Colors.red.withOpacity(0.1),
                          side: const BorderSide(color: Colors.red, width: 1),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.comment, size: 16, color: Colors.grey),
                              SizedBox(width: 6),
                              Text(
                                'Descripción del problema:',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            report.description.isNotEmpty
                                ? report.description
                                : 'Sin descripción adicional.',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Reportado: ${DateFormat('dd/MM/yyyy HH:mm').format(report.createdAt)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      SpotDetailScreen(spot: spot),
                                ),
                              );
                            },
                            icon: const Icon(Icons.visibility, size: 18),
                            label: const Text('Ver spot'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _showResolveReportDialog(
                                context, report.id, moderatorId),
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('Resolver'),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showDismissReportDialog(
                            context, report.id, moderatorId),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Descartar reporte'),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCommentReportCard(
      BuildContext context,
      CommentReport report,
      String moderatorId,
      ) {
    final firestoreService = ref.watch(firestoreServiceProvider);

    return FutureBuilder<SpotComment?>(
      future: firestoreService.getCommentById(report.commentId),
      builder: (context, commentSnapshot) {
        if (commentSnapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            margin: EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final comment = commentSnapshot.data;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.comment, color: Colors.red, size: 24),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Comentario reportado',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${report.reasons.length} motivos',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.05),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (comment != null) ...[
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundImage: comment.userPhoto != null
                                  ? CachedNetworkImageProvider(
                                  comment.userPhoto!)
                                  : null,
                              backgroundColor: Colors.grey[300],
                              child: comment.userPhoto == null
                                  ? const Icon(Icons.person, size: 16)
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    comment.userName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    DateFormat('dd/MM/yyyy HH:mm')
                                        .format(comment.createdAt),
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
                        const SizedBox(height: 12),
                        Text(
                          comment.comment,
                          style: const TextStyle(fontSize: 15),
                        ),
                      ] else ...[
                        const Text(
                          '⚠️ Comentario no encontrado o ya eliminado',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Motivos reportados:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: report.reasons.map((reason) {
                    return Chip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(reason.icon),
                          const SizedBox(width: 4),
Text(reason.getDisplayName(context)) // 👈 Cambiar por el método traducido                              style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                      backgroundColor: Colors.red.withOpacity(0.1),
                      side: const BorderSide(color: Colors.red, width: 1),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                if (report.description.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 16, color: Colors.grey),
                            SizedBox(width: 6),
                            Text(
                              'Descripción adicional:',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(report.description,
                            style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  'Reportado: ${DateFormat('dd/MM/yyyy HH:mm').format(report.createdAt)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final spot =
                          await firestoreService.getSpotById(report.spotId);
                          if (spot != null && context.mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    SpotDetailScreen(spot: spot),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.visibility, size: 18),
                        label: const Text('Ver spot'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: comment != null
                            ? () => _showDeleteCommentDialog(
                          context,
                          report,
                          comment,
                          moderatorId,
                        )
                            : null,
                        icon: const Icon(Icons.delete, size: 18),
                        label: const Text('Eliminar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showDismissCommentReportDialog(
                      context,
                      report.id,
                      moderatorId,
                    ),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Descartar reporte'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildArchivedSpotCard(
      BuildContext context, SpotModel spot, String moderatorId) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              if (spot.photoUrls.isNotEmpty)
                ClipRRect(
                  borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(4)),
                  child: CachedNetworkImage(
                    imageUrl: spot.photoUrls.first,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  height: 200,
                  color: Colors.grey[300],
                  child: const Center(
                      child: Icon(Icons.image_not_supported, size: 48)),
                ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'ARCHIVADO',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(spot.category.icon,
                        style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(spot.name,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(spot.category.getLocalizedName(context),
                    style: TextStyle(color: Colors.grey[600])),
                const SizedBox(height: 8),
                Text(spot.description,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 12),
                Text(
                  'Creado: ${DateFormat('dd/MM/yyyy').format(spot.createdAt)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    SpotDetailScreen(spot: spot)),
                          );
                        },
                        icon: const Icon(Icons.visibility, size: 18),
                        label: const Text('Ver'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _unarchiveSpot(context, spot.id, moderatorId),
                        icon: const Icon(Icons.unarchive, size: 18),
                        label: const Text('Desarchivar'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _permanentlyDeleteSpot(context, spot.id, spot.name),
                    icon: const Icon(Icons.delete_forever, size: 18),
                    label: const Text('Eliminar permanentemente'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _approvePendingSpot(
      BuildContext context,
      String pendingSpotId,
      String moderatorId,
      ) async {
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      await firestoreService.approvePendingSpot(pendingSpotId, moderatorId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Spot aprobado correctamente'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _showResolveReportDialog(
      BuildContext context,
      String reportId,
      String moderatorId,
      ) async {
    final commentController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resolver reporte'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('¿Se ha corregido el problema reportado?'),
            const SizedBox(height: 16),
            TextField(
              controller: commentController,
              decoration: const InputDecoration(
                labelText: 'Comentario (opcional)',
                hintText: 'Explica qué se hizo para resolver...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('Resolver'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      await firestoreService.resolveReport(
        reportId,
        moderatorId,
        commentController.text.trim(),
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reporte marcado como resuelto'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }

    commentController.dispose();
  }

  Future<void> _showDismissReportDialog(
      BuildContext context,
      String reportId,
      String moderatorId,
      ) async {
    final commentController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Descartar reporte'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('¿El reporte no es válido o el spot está correcto?'),
            const SizedBox(height: 16),
            TextField(
              controller: commentController,
              decoration: const InputDecoration(
                labelText: 'Razón',
                hintText: 'Explica por qué se descarta...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange, foregroundColor: Colors.white),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      await firestoreService.dismissReport(
        reportId,
        moderatorId,
        commentController.text.trim(),
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reporte descartado'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }

    commentController.dispose();
  }

  Future<void> _showDeleteCommentDialog(
      BuildContext context,
      CommentReport report,
      SpotComment comment,
      String moderatorId,
      ) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red),
            SizedBox(width: 8),
            Text('Eliminar comentario'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '⚠️ Vas a eliminar este comentario permanentemente.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                comment.comment,
                style:
                const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Razón de la eliminación',
                hintText: 'Explica por qué eliminas el comentario...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      await firestoreService.deleteComment(comment.id);
      await firestoreService.resolveCommentReport(
        report.id,
        moderatorId,
        'Comentario eliminado. Razón: ${reasonController.text.trim()}',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Comentario eliminado y reporte resuelto'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    reasonController.dispose();
  }

  Future<void> _showDismissCommentReportDialog(
      BuildContext context,
      String reportId,
      String moderatorId,
      ) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Descartar reporte'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('El comentario es válido y no requiere acción.'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Razón (opcional)',
                hintText: 'Explica por qué se descarta...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      await firestoreService.dismissCommentReport(
        reportId,
        moderatorId,
        reasonController.text.trim(),
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reporte de comentario descartado'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }

    reasonController.dispose();
  }

  Future<void> _unarchiveSpot(
      BuildContext context,
      String spotId,
      String moderatorId,
      ) async {
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      await firestoreService.unarchiveSpot(spotId, moderatorId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Spot desarchivado'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _permanentlyDeleteSpot(
      BuildContext context,
      String spotId,
      String spotName,
      ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Eliminar permanentemente'),
        content: Text(
            '¿Estás seguro de eliminar "$spotName"?\n\nEsta acción NO se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      await firestoreService.permanentlyDeleteSpot(spotId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Spot eliminado permanentemente'),
              backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _showRejectDialog(
      BuildContext context,
      String pendingSpotId,
      String moderatorId,
      ) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rechazar Spot'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Motivo del rechazo',
            hintText: 'Explica por qué rechazas este spot...',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final firestoreService = ref.read(firestoreServiceProvider);
        await firestoreService.rejectPendingSpot(
          pendingSpotId,
          moderatorId,
          reasonController.text.trim(),
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Spot rechazado'),
              backgroundColor: Colors.orange,
            ),
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

    reasonController.dispose();
  }
}