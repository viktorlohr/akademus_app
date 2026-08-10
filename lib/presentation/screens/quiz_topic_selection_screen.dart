import 'package:flutter/material.dart';
import '../../constants/categories.dart';
import 'grid_selection_screen.dart';
import 'quiz_screen.dart';
import 'quiz_session_setup_screen.dart';

class QuizTopicSelectionScreen extends StatelessWidget {
  const QuizTopicSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GridSelectionScreen(
      title: 'Quiz-Thema wählen',
      backgroundPath: 'assets/images/background_male.jpg',
      items: [
        for (final c in flashcardCategories) {'label': c.label, 'icon': c.icon},
      ],
      // Straight into quiz mode — no overview/list screen in between.
      onItemSelected: (label) => QuizScreen.category(label),
      action: Builder(
        builder: (context) => SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const QuizSessionSetupScreen()),
            ),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text(
              'Session starten',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF264358),
              foregroundColor: const Color(0xFFF5AC26),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
