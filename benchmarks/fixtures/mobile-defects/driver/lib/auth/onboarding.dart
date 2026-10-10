import '../api/api_client.dart';
import 'session.dart';

class DriverSignUp {
  const DriverSignUp({required this.name, required this.email, required this.phone, required this.vehicle});

  final String name;
  final String email;
  final String phone;
  final String vehicle;

  Map<String, dynamic> toJson() => {'name': name, 'email': email, 'phone': phone, 'vehicle': vehicle};
}

/// Self-serve driver registration from the welcome screen: the account is created here, then approved by dispatch.
Future<void> signUpDriver(DriverSignUp form) async {
  await api.post('/driver/accounts', form.toJson());
  driverSession.start('pending-approval', form.email);
}
