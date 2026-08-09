import 'package:flutter/material.dart';
import '../../models/session_score.dart';
import '../../models/study_session_config.dart';
import '../widgets/app_chrome.dart';
import 'flashcard_screen.dart';

class StatsScreen extends StatelessWidget {
  final StudySessionConfig config;
  final SessionScore score;

  /// Best previous run on the same categories, if any.
  final SessionScore? previousBest;

  const StatsScreen({
    super.key,
    required this.config,
    required this.score,
    this.previousBest,
  });

  final Color myBlue = const Color(0xFF264358);
  final Color myOrange = const Color(0xFFF5AC26);
  final Color myGreen = const Color(0xFF2E7D32);
  final Color myRed = const Color(0xFFC62828);

  void _goHome(BuildContext context) =>
      Navigator.popUntil(context, (route) => route.isFirst);

  @override
  Widget build(BuildContext context) {
    final isRecord =
        config.rated &&
        (previousBest == null || score.points > previousBest!.points);

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
                    Text(
                      isRecord ? '🏆' : '✅',
                      style: const TextStyle(fontSize: 42),
                    ),
                    Text(
                      config.rated
                          ? 'Session abgeschlossen!'
                          : 'Sitzung abgeschlossen!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: myOrange,
                      ),
                    ),
                    Text(
                      config.title,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Grade card — only meaningful for rated runs.
              if (config.rated) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          Text(
                            score.grade,
                            style: TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.bold,
                              color: myOrange,
                            ),
                          ),
                          Text(
                            'Note',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            '${score.points}',
                            style: TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.bold,
                              color: myBlue,
                            ),
                          ),
                          Text(
                            'Punkte',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  isRecord
                      ? 'Neue Bestleistung!'
                      : 'Bestleistung: ${previousBest!.points} Punkte',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isRecord ? myGreen : Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 14),
              ],

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
                      '${score.percent}% gewusst',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: myBlue,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: score.accuracy,
                        minHeight: 12,
                        backgroundColor: myRed.withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(myGreen),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${score.known}/${score.total} richtig · '
                      'längste Serie: ${score.maxStreak}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FlashcardScreen(config: config),
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
