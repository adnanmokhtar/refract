import 'package:flutter/services.dart';

/// The parcel scanner's torch and laser, owned by the platform side (a camera session on iOS, the rugged
/// handset's scanner SDK on Android).
class ScannerChannel {
  static const _channel = MethodChannel('pantrygo/scanner');

  static Future<void> start() => _channel.invokeMethod('start');

  static Future<void> stop() => _channel.invokeMethod('stop');

  static Future<void> flashOn() => _channel.invokeMethod('flashOn');
}
