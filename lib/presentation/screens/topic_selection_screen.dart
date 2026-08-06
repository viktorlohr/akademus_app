import 'package:flutter/material.dart';
import 'grid_selection_screen.dart';
import 'flashcard_screen.dart';

class TopicSelectionScreen extends StatelessWidget {
  const TopicSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GridSelectionScreen(
      title: 'Thema wählen',
      backgroundPath: 'assets/images/background_male.jpg',
      items: const [
        {'label': 'Analysis', 'icon': Icons.show_chart},
        {'label': 'Geometrie', 'icon': Icons.square_foot},
        {'label': 'Stochastik', 'icon': Icons.bar_chart},
      ],
      // Straight into study mode — no overview/list screen in between.
      onItemSelected: (label) => FlashcardScreen(category: label),
    );
  }
}
