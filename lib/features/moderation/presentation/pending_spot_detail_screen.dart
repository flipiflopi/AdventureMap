// lib/features/moderation/presentation/pending_spot_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../models/spot_suggestion_model.dart';
import '../../../providers/providers.dart';

class PendingSpotDetailScreen extends ConsumerStatefulWidget {
  final PendingSpot pendingSpot;
  final String moderatorId;

  const PendingSpotDetailScreen({
    Key? key,
    required this.pendingSpot,
    required this.moderatorId,
  }) : super(key: key);

  @override
  ConsumerState<PendingSpotDetailScreen> createState() => _PendingSpotDetailScreenState();
}

class _PendingSpotDetailScreenState extends ConsumerState<PendingSpotDetailScreen> {
  int _selectedTab = 0; // 🆕 Para controlar las tabs

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del Spot'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_circle, color: Colors.green),
            onPressed: () => _approvePendingSpot(context),
          ),
          IconButton(
            icon: const Icon(Icons.cancel, color: Colors.red),
            onPressed: () => _showRejectDialog(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner de estado
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.orange,
              child: const Row(
                children: [
                  Icon(Icons.pending_actions, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Este spot está pendiente de moderación',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Galería de fotos
            if (widget.pendingSpot.photoUrls.isNotEmpty)
              SizedBox(
                height: 300,
                child: PageView.builder(
                  itemCount: widget.pendingSpot.photoUrls.length,
                  itemBuilder: (context, index) {
                    return CachedNetworkImage(
                      imageUrl: widget.pendingSpot.photoUrls[index],
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                      const Center(child: CircularProgressIndicator()),
                      errorWidget: (context, url, error) =>
                      const Icon(Icons.error),
                    );
                  },
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nombre y categoría
                  Text(
                    widget.pendingSpot.name,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      widget.pendingSpot.category,
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 🆕 TABS DE DESCRIPCIÓN
                  _buildDescriptionTabs(),

                  const SizedBox(height: 24),

                  // Información adicional
                  _buildInfoCard(
                    icon: Icons.location_on,
                    title: 'Ubicación',
                    content:
                    'Lat: ${widget.pendingSpot.latitude.toStringAsFixed(6)}\nLng: ${widget.pendingSpot.longitude.toStringAsFixed(6)}',
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    icon: Icons.calendar_today,
                    title: 'Fecha de creación',
                    content: DateFormat('dd/MM/yyyy HH:mm')
                        .format(widget.pendingSpot.createdAt),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    icon: Icons.person,
                    title: 'Creado por',
                    content: widget.pendingSpot.createdBy,
                  ),

                  const SizedBox(height: 32),

                  // Botones de acción
                  ElevatedButton.icon(
                    onPressed: () => _approvePendingSpot(context),
                    icon: const Icon(Icons.check),
                    label: const Text('Aprobar Spot'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _showRejectDialog(context),
                    icon: const Icon(Icons.close),
                    label: const Text('Rechazar Spot'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      minimumSize: const Size(double.infinity, 56),
                      textStyle: const TextStyle(fontSize: 16),
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

  // 🆕 TABS DE DESCRIPCIÓN (igual que en spot_detail_screen)
  Widget _buildDescriptionTabs() {
    return Card(
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                _buildTab('Detalles', 0, Icons.description),
                _buildTab('Acceso', 1, Icons.directions_car),
                _buildTab('Seguridad', 2, Icons.warning_amber),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildTabContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String title, int index, IconData icon) {
    final isSelected = _selectedTab == index;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? Colors.blue : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.blue : Colors.grey,
              ),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.blue : Colors.grey[600],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    String content;
    String placeholder;

    switch (_selectedTab) {
      case 0:
        content = widget.pendingSpot.description;
        placeholder = 'Sin información de detalles';
        break;
      case 1:
      // 🆕 Acceso
        content = widget.pendingSpot.access ?? '';
        placeholder = 'Sin información de acceso';
        break;
      case 2:
      // 🆕 Seguridad
        content = widget.pendingSpot.safety ?? '';
        placeholder = 'Sin información de seguridad';
        break;
      default:
        content = '';
        placeholder = '';
    }

    return content.isEmpty
        ? Text(
      placeholder,
      style: TextStyle(
        color: Colors.grey[500],
        fontStyle: FontStyle.italic,
      ),
    )
        : Text(
      content,
      style: const TextStyle(fontSize: 16, height: 1.5),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    content,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 14,
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

  // 🔧 APROBAR - Añadir manejo de errores más detallado
  Future<void> _approvePendingSpot(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aprobar Spot'),
        content: Text(
          '¿Aprobar "${widget.pendingSpot.name}"?\n\n'
              'Este spot aparecerá en el mapa para todos los usuarios.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Aprobar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // 🆕 Mostrar loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final firestoreService = ref.read(firestoreServiceProvider);

      // 🔍 Log para debug
      print('🔄 Intentando aprobar spot: ${widget.pendingSpot.id}');
      print('👤 Moderador: ${widget.moderatorId}');

      await firestoreService.approvePendingSpot(
        widget.pendingSpot.id,
        widget.moderatorId,
      );

      print('✅ Spot aprobado exitosamente');

      if (context.mounted) {
        Navigator.pop(context); // Cerrar loading
        Navigator.pop(context); // Volver a la lista
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Spot aprobado correctamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('❌ Error aprobando spot: $e');
      print('📚 Stack trace: $stackTrace');

      if (context.mounted) {
        Navigator.pop(context); // Cerrar loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al aprobar: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _showRejectDialog(BuildContext context) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rechazar Spot'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('¿Por qué rechazas este spot?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Motivo del rechazo',
                hintText: 'Explica por qué rechazas este spot...',
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
          widget.pendingSpot.id,
          widget.moderatorId,
          reasonController.text.trim(),
        );

        if (context.mounted) {
          Navigator.pop(context);
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