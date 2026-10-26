// lib/features/routes/presentation/routes_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/providers.dart';
import 'create_route_screen.dart';
import 'route_detail_screen.dart';

class RoutesScreen extends ConsumerWidget {
  const RoutesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Mis Rutas')),
        body: Center(child: Text('Debes iniciar sesión')),
      );
    }

    final routesAsync = ref.watch(userRoutesProvider(currentUser.uid));

    return Scaffold(
      appBar: AppBar(
        title: Text('Mis Rutas'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreateRouteScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: routesAsync.when(
        data: (routes) {
          if (routes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.route, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No tienes rutas creadas',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreateRouteScreen(),
                        ),
                      );
                    },
                    icon: Icon(Icons.add),
                    label: Text('Crear Ruta'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: routes.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final route = routes[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Icon(Icons.route),
                  ),
                  title: Text(
                    route.name,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${route.spotIds.length} spots\n${route.description}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  isThreeLine: true,
                  trailing: Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RouteDetailScreen(route: route),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
        loading: () => Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error al cargar rutas'),
        ),
      ),
    );
  }
}

