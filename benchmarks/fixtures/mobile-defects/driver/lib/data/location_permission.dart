import 'package:geolocator/geolocator.dart';

/// Asks for location on the screen that needs it; after a permanent denial, sends the driver to Settings.
Future<bool> ensureLocation() async {
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.deniedForever) {
    await Geolocator.openAppSettings();
    return false;
  }
  return permission == LocationPermission.whileInUse || permission == LocationPermission.always;
}
