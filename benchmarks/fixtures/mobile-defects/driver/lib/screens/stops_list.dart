import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api/api_client.dart';

/// Today's stops, in route order, with the customer's door photo from their last delivery.
class StopsList extends StatefulWidget {
  const StopsList({super.key});

  @override
  State<StopsList> createState() => _StopsListState();
}

class _StopsListState extends State<StopsList> {
  late final Future<List<Map<String, dynamic>>> _stops = api.todaysStops();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Today')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _stops,
        builder: (context, snapshot) {
          final stops = snapshot.data ?? const [];
          return ListView.builder(
            itemCount: stops.length,
            itemBuilder: (context, index) {
              final stop = stops[index];
              return ListTile(
                leading: Image.network(stop['doorPhotoUrl'] as String, width: 56, height: 56, fit: BoxFit.cover),
                title: Text(stop['customer'] as String),
                subtitle: Text(stop['address'] as String),
                onTap: () => context.go('/stops/${stop['id']}'),
              );
            },
          );
        },
      ),
    );
  }
}
