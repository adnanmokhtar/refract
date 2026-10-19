import 'package:go_router/go_router.dart';

import 'auth/session.dart';
import 'screens/handover_screen.dart';
import 'screens/navigation_screen.dart';
import 'screens/not_found_screen.dart';
import 'screens/notes_screen.dart';
import 'screens/proof_screen.dart';
import 'screens/stop_screen.dart';
import 'screens/stops_list.dart';
import 'screens/welcome_screen.dart';

/// Stop and hand-over links arrive from the dispatch SMS (https://drive.pantrygo.example/stops/1234).
final router = GoRouter(
  initialLocation: '/stops',
  refreshListenable: driverSession,
  redirect: (context, state) => driverSession.isSignedIn ? null : '/welcome',
  routes: [
    GoRoute(path: '/welcome', builder: (context, state) => const WelcomeScreen()),
    GoRoute(path: '/stops', builder: (context, state) => const StopsList()),
    GoRoute(
      path: '/stops/:id',
      builder: (context, state) => StopScreen(stopId: int.parse(state.pathParameters['id']!)),
    ),
    GoRoute(
      path: '/stops/:id/navigate',
      builder: (context, state) => NavigationScreen(stopId: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: '/stops/:id/proof',
      builder: (context, state) => ProofScreen(stopId: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: '/stops/:id/notes',
      builder: (context, state) => NotesScreen(stopId: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: '/handover/:orderId',
      builder: (context, state) {
        final orderId = int.tryParse(state.pathParameters['orderId'] ?? '');
        return orderId == null ? const NotFoundScreen() : HandoverScreen(orderId: orderId);
      },
    ),
  ],
);
