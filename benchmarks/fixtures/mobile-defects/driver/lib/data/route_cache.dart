import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class RoutePlan {
  RoutePlan(this.stops);

  factory RoutePlan.fromJson(Map<String, dynamic> json) =>
      RoutePlan((json['stops'] as List<dynamic>).cast<Map<String, dynamic>>());

  final List<Map<String, dynamic>> stops;
}

/// Today's route, cached to disk so the stop list opens instantly. A full day is 60-90 stops with geometry.
class RouteCache {
  RouteCache(this._dir);

  final Directory _dir;

  static Future<RouteCache> open() async => RouteCache(await getApplicationSupportDirectory());

  RoutePlan? readToday() {
    final file = File('${_dir.path}/route-today.json');
    if (!file.existsSync()) return null;
    final raw = file.readAsStringSync();
    return RoutePlan.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}
