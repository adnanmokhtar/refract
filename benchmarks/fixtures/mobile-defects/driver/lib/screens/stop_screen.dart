import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api/api_client.dart';
import '../native/scanner_channel.dart';
import '../widgets/delivery_summary.dart';
import '../widgets/stop_chip.dart';

class StopScreen extends StatelessWidget {
  const StopScreen({super.key, required this.stopId});

  final int stopId;

  Future<void> _callCustomer() => api.post('/driver/stops/$stopId/call', const {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Stop $stopId'),
        actions: [
          IconButton(icon: const Icon(Icons.call), onPressed: _callCustomer),
          IconButton(
            icon: const Icon(Icons.flashlight_on),
            tooltip: 'Torch',
            onPressed: () => ScannerChannel.flashOn(),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: api.stop(stopId),
        builder: (context, snapshot) {
          final stop = snapshot.data ?? const {};
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(spacing: 8, children: [
                for (final tag in (stop['tags'] as List<dynamic>? ?? const [])) StopChip(label: tag as String),
              ]),
              DeliverySummary(
                bagCount: stop['bags'] as int? ?? 0,
                totalLabel: stop['total'] as String? ?? '',
                onReportProblem: () => context.go('/stops/$stopId/notes'),
              ),
              FilledButton(
                onPressed: () => context.go('/stops/$stopId/proof'),
                child: const Text('Deliver'),
              ),
            ],
          );
        },
      ),
    );
  }
}
