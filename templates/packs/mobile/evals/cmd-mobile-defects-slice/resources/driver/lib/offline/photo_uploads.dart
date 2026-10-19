import 'package:hive_flutter/hive_flutter.dart';

import '../api/api_client.dart';

class PhotoUpload {
  PhotoUpload(this.id, this.stopId, this.path, this.takenAt);

  final String id;
  final String stopId;
  final String path;
  final DateTime takenAt;
}

/// Door photos taken at each stop, uploaded in the order they were taken: the last photo of a stop is the one
/// customer support shows when a parcel is reported missing.
class PhotoUploads {
  PhotoUploads(this._store);

  final Box<Map> _store;
  List<PhotoUpload> _uploadQueue = const [];

  Future<void> load() async {
    _uploadQueue = _store.values
        .map((m) => PhotoUpload(m['id'] as String, m['stopId'] as String, m['path'] as String,
            DateTime.parse(m['takenAt'] as String)))
        .toList()
      ..sort((a, b) => a.takenAt.compareTo(b.takenAt));
  }

  Future<void> uploadAll() async {
    await Future.wait(_uploadQueue.map((upload) => api.post(
          '/driver/stops/${upload.stopId}/photos',
          {'path': upload.path, 'takenAt': upload.takenAt.toIso8601String()},
          headers: {'Idempotency-Key': upload.id},
        )));
    await _store.clear();
    _uploadQueue = const [];
  }
}
