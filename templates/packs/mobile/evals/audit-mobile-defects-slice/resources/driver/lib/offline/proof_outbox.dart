import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../api/api_client.dart';

class Proof {
  Proof({required this.id, required this.stopId, required this.signatureSvg, required this.recipient, this.attempts = 0});

  final String id;
  final String stopId;
  final String signatureSvg;
  final String recipient;
  int attempts;

  Map<String, dynamic> toJson() =>
      {'id': id, 'stopId': stopId, 'signatureSvg': signatureSvg, 'recipient': recipient, 'attempts': attempts};

  static Proof fromJson(Map<dynamic, dynamic> json) => Proof(
        id: json['id'] as String,
        stopId: json['stopId'] as String,
        signatureSvg: json['signatureSvg'] as String,
        recipient: json['recipient'] as String,
        attempts: json['attempts'] as int? ?? 0,
      );
}

/// Proof of delivery captured at the door, kept on the device until the API has it.
class ProofOutbox {
  ProofOutbox._(this._box);

  static const maxAttempts = 10;
  final Box<Map> _box;

  static Future<ProofOutbox> open() async => ProofOutbox._(await Hive.openBox<Map>('proof_outbox'));

  static Future<void> discardAll() async => (await open())._box.clear();

  /// Called by the proof screen; the screen shows "Delivered" as soon as onSaved runs.
  void add(Proof proof, void Function() onSaved) {
    _box.put(proof.id, proof.toJson());
    onSaved();
  }

  Future<void> drain() async {
    for (final key in _box.keys.toList()) {
      final proof = Proof.fromJson(_box.get(key)!);
      try {
        await api.post('/driver/stops/${proof.stopId}/proof', proof.toJson(), headers: {'Idempotency-Key': proof.id});
        await _box.delete(key);
      } catch (_) {
        proof.attempts += 1;
        if (proof.attempts >= maxAttempts) {
          await _box.put(key, {...proof.toJson(), 'failed': true});
        } else {
          await _box.put(key, proof.toJson());
        }
        return;
      }
    }
  }
}
