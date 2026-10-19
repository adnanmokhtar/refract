import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'background/jobs.dart';
import 'offline/connectivity_trigger.dart';
import 'push/push_setup.dart';
import 'router.dart';
import 'theme/driver_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await Hive.initFlutter();
  unawaited(registerBackgroundSync());
  drainOnNetworkChange();
  runApp(const DriverApp());
}

class DriverApp extends StatefulWidget {
  const DriverApp({super.key});

  @override
  State<DriverApp> createState() => _DriverAppState();
}

class _DriverAppState extends State<DriverApp> {
  @override
  void initState() {
    super.initState();
    unawaited(setUpPush(router));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Pantry Go Driver',
      theme: driverTheme,
      routerConfig: router,
    );
  }
}
