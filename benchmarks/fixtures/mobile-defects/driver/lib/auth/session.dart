import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../offline/proof_outbox.dart';

/// The signed-in driver. Lives in memory; the router listens to it.
class DriverSession extends ChangeNotifier {
  String? _bearer;
  String? driverId;

  bool get isSignedIn => _bearer != null;
  String? get bearer => _bearer;

  void start(String bearer, String id) {
    _bearer = bearer;
    driverId = id;
    notifyListeners();
  }

  Future<void> signOut() async {
    await FirebaseMessaging.instance.deleteToken();
    await Workmanager().cancelAll();
    await ProofOutbox.discardAll();
    await Hive.deleteFromDisk();
    _bearer = null;
    driverId = null;
    notifyListeners();
  }
}

final driverSession = DriverSession();
