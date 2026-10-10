import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../api/api_client.dart';
import '../data/location_permission.dart';
import 'eta_card.dart';

/// Turn-by-turn hand-off screen: shows the ETA and refreshes it every 30 seconds while the driver is on the way.
class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key, required this.stopId});

  final String stopId;

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  Timer? _etaTimer;
  Duration? _eta;

  @override
  void initState() {
    super.initState();
    _etaTimer = Timer.periodic(const Duration(seconds: 30), (_) => _refreshEta());
    _refreshEta();
  }

  Future<void> _refreshEta() async {
    if (!await ensureLocation()) return;
    final position = await Geolocator.getCurrentPosition();
    await api.post('/driver/position', {'lat': position.latitude, 'lng': position.longitude});
    final eta = await api.eta(widget.stopId);
    if (mounted) setState(() => _eta = eta);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('On the way')),
      body: Center(child: EtaCard(stopId: widget.stopId, initial: _eta)),
    );
  }
}
