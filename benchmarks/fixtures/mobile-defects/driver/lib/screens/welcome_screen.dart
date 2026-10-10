import 'package:flutter/material.dart';

import '../auth/onboarding.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  String _vehicle = 'bike';

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _register() => signUpDriver(DriverSignUp(
        name: _name.text,
        email: _email.text,
        phone: _phone.text,
        vehicle: _vehicle,
      ));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Drive with Pantry Go')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full name')),
            TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone')),
            DropdownButton<String>(
              value: _vehicle,
              items: const [
                DropdownMenuItem(value: 'bike', child: Text('E-bike')),
                DropdownMenuItem(value: 'van', child: Text('Van')),
              ],
              onChanged: (value) => setState(() => _vehicle = value ?? 'bike'),
            ),
            FilledButton(onPressed: _register, child: const Text('Create driver account')),
          ],
        ),
      ),
    );
  }
}
