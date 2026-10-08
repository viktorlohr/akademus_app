// Second app entry point: the quiz question-bank admin page.
// Run with: flutter run -d chrome --target=lib/admin_main.dart
// Build with: flutter build web --target=lib/admin_main.dart --output=build/admin
import 'package:flutter/material.dart';
import 'admin/admin_home_screen.dart';

void main() => runApp(const AdminApp());

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Akademus Quiz Admin',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF264358),
        useMaterial3: true,
        fontFamily: 'Inter',
      ),
      home: const AdminHomeScreen(),
    );
  }
}
