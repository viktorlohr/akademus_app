import 'package:flutter/material.dart';
import '../widgets/app_chrome.dart';

class PrivacyInfoScreen extends StatelessWidget {
  const PrivacyInfoScreen({super.key});

  final Color myBlue = const Color(0xFF264358);

  Future<String> _loadText(BuildContext context) async {
    return await DefaultAssetBundle.of(
      context,
    ).loadString('assets/datenschutz.txt');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Impressum | Datenschutz'),
        backgroundColor: Colors.white,
        foregroundColor: myBlue,
        elevation: 0,
      ),
      body: AppBackground(
        child: FutureBuilder<String>(
          future: _loadText(context),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Text(
                  snapshot.data ?? 'Inhalt konnte nicht geladen werden.',
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Colors.black87,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
