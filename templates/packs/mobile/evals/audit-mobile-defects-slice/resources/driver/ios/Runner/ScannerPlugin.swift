import Flutter
import Foundation

/// The barcode sled clipped to the driver's iPhone: the vendor SDK owns the laser and the sled's torch LED.
final class ScannerPlugin {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "pantrygo/scanner", binaryMessenger: messenger)
    let sled = ScannerSled.shared

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "start":
        sled.startScan()
        result(nil)
      case "stop":
        sled.stopScan()
        result(nil)
      default:
        break
      }
    }
  }
}
