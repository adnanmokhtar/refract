import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import '../api/api_client.dart';
import '../data/route_changes.dart';

/// "New stop added to your route" and "customer left a note" pushes.
Future<void> setUpPush(GoRouter router) async {
  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission();

  final token = await messaging.getToken();
  if (token != null) await api.post('/driver/devices', {'token': token});
  messaging.onTokenRefresh.listen((next) => api.post('/driver/devices', {'token': next}));

  final initial = await messaging.getInitialMessage();
  if (initial != null) _open(router, initial);
  FirebaseMessaging.onMessageOpenedApp.listen((message) => _open(router, message));

  // Route changes arrive as data-only messages; keep the cached route fresh while the app is in the background.
  FirebaseMessaging.onBackgroundMessage((message) async {
    await RouteChanges.record(message.messageId, message.data);
  });
}

void _open(GoRouter router, RemoteMessage message) {
  final stopId = message.data['stopId'];
  if (stopId is String) router.go('/stops/$stopId');
}
