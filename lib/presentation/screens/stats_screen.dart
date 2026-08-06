// lib/presentation/screens/stats_screen.dart
import 'package:flutter/material.dart';
import '../widgets/app_chrome.dart';
import 'flashcard_screen.dart';

class SessionResult {
  final int total;
  final int known;
  final int unknown;
  final int maxStreak;
  const SessionResult({
    required this.total,
    required this.known,
    required this.unknown,
    required this.maxStreak,
  });
}

class StatsScreen extends StatelessWidget {
  final String topic;
  final SessionResult result;
  const StatsScreen({super.key, required this.topic, required this.result});

  final Color myBlue = const Color(0xFF264358);
  final Color myOrange = const Color(0xFFF5AC26);
  final Color myGreen = const Color(0xFF2E7D32);
  final Color myRed = const Color(0xFFC62828);

  void _goHome(BuildContext context) =>
      Navigator.popUntil(context, (route) => route.isFirst);

  @override
  Widget build(BuildContext context) {
    final knownPct = result.total > 0 ? result.known / result.total : 0.0;
    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          'assets/images/akademus_logo.jpg',
          height: 80,
          fit: BoxFit.contain,
        ),
        toolbarHeight: 100,
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
      ),
      body: AppBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: myBlue,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    const Text('🏆', style: TextStyle(fontSize: 42)),
                    Text(
                      'Sitzung abgeschlossen!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: myOrange,
                      ),
                    ),
                    Text(
                      topic,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Text(
                      '${(knownPct * 100).round()}% gewusst',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: myBlue,
                      ),
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: knownPct,
                      minHeight: 12,
                      backgroundColor: myRed.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(myGreen),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FlashcardScreen(category: topic),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: myBlue,
                  foregroundColor: myOrange,
                ),
                child: const Text('Nochmal üben'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => _goHome(context),
                style: OutlinedButton.styleFrom(foregroundColor: myBlue),
                child: const Text('Zur Startseite'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
