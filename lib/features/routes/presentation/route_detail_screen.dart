// lib/features/routes/presentation/route_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/spot_model.dart';
import '../../../providers/providers.dart';

class RouteDetailScreen extends ConsumerWidget {
  final RouteModel route;

  const RouteDetailScreen({Key? key, required this.route}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firestoreService = ref.watch(firestoreServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(route.name),
      ),
      body: FutureBuilder<List<SpotModel?>>(
        future: Future.wait(
          route.spotIds.map((id) => firestoreService.getSpotById(id)),
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final spots = snapshot.data?.whereType<SpotModel>().toList() ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          route.name,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(route.description),
                        const SizedBox(height: 12),
                        Text(
                          '${spots.length} spots en esta ruta',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Spots de la Ruta',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...spots.asMap().entries.map((entry) {
                  final index = entry.key;
                  final spot = entry.value;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text('${index + 1}'),
                      ),
                      title: Text(spot.name),
                      subtitle: Text(spot.category.getLocalizedName(context)),
                      trailing: Text(spot.category.icon, style: TextStyle(fontSize: 24)),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}