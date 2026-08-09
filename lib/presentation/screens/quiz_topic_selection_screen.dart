import 'package:flutter/material.dart';
import '../../constants/categories.dart';
import 'grid_selection_screen.dart';
import 'quiz_screen.dart';

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
      onItemSelected: (label) => QuizScreen.category(label),
    );
  }
}
