import 'package:flutter/material.dart';

const brandGreen = Color(0xFF1F6F43);

final driverTheme = ThemeData(
  colorSchemeSeed: brandGreen,
  useMaterial3: true,
  textTheme: const TextTheme(
    bodyMedium: TextStyle(fontSize: 16),
    labelSmall: TextStyle(fontSize: 13, color: Color(0xFF5C5F66)),
  ),
);
