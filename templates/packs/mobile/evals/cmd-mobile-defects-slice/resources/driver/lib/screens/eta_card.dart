import 'package:flutter/material.dart';

import '../api/api_client.dart';

/// The ETA the customer also sees. Refresh asks the API again; the card may be gone by the time it answers.
class EtaCard extends StatefulWidget {
  const EtaCard({super.key, required this.stopId, this.initial});

  final String stopId;
  final Duration? initial;

  @override
  State<EtaCard> createState() => _EtaCardState();
}

class _EtaCardState extends State<EtaCard> {
  late Duration? _eta = widget.initial;

  Future<void> _refresh() async {
    final eta = await api.eta(widget.stopId);
    if (!mounted) return;
    setState(() => _eta = eta);
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _eta?.inMinutes;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(minutes == null ? 'Working out your ETA' : '$minutes min', style: Theme.of(context).textTheme.headlineMedium),
          TextButton(onPressed: _refresh, child: const Text('Refresh')),
        ]),
      ),
    );
  }
}
