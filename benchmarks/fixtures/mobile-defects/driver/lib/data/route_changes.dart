import 'package:hive_flutter/hive_flutter.dart';

/// Route edits from dispatch, applied to the cached route the next time the stop list opens.
class RouteChanges {
  static Future<void> record(String? id, Map<String, dynamic> change) async {
    await Hive.initFlutter();
    final box = await Hive.openBox<Map>('route_changes');
    await box.put(id ?? DateTime.now().toIso8601String(), change);
  }
}
