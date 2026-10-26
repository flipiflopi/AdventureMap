// lib/features/routes/presentation/create_route_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/providers.dart';
import '../../../providers/routes_controller.dart';

class CreateRouteScreen extends ConsumerStatefulWidget {
  const CreateRouteScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<CreateRouteScreen> createState() => _CreateRouteScreenState();
}

class _CreateRouteScreenState extends ConsumerState<CreateRouteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final List<String> _selectedSpotIds = [];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createRoute() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSpotIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Agrega al menos un spot a la ruta')),
      );
      return;
    }

    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    final success = await ref.read(routesControllerProvider.notifier).createRoute(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      spotIds: _selectedSpotIds,
      userId: currentUser.uid,
    );

    if (success && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ruta creada exitosamente')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final spotsAsync = ref.watch(allSpotsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Crear Ruta'),
        actions: [
          IconButton(
            icon: Icon(Icons.check),
            onPressed: _createRoute,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nombre de la ruta',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingresa un nombre';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Descripción',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Spots seleccionados (${_selectedSpotIds.length})',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              spotsAsync.when(
                data: (spots) {
                  return Column(
                    children: spots.map((spot) {
                      final isSelected = _selectedSpotIds.contains(spot.id);
                      return CheckboxListTile(
                        title: Text(spot.name),
                        subtitle: Text(spot.category.getLocalizedName(context)),
                        secondary: Text(spot.category.icon, style: TextStyle(fontSize: 24)),
                        value: isSelected,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selectedSpotIds.add(spot.id);
                            } else {
                              _selectedSpotIds.remove(spot.id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  );
                },
                loading: () => Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(child: Text('Error al cargar spots')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}