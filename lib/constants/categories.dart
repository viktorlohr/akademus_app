import 'package:flutter/material.dart';

/// A topic the app can study. The icon lives here so the topic grid and
/// the session setup screen can't drift apart when a category is added.
@immutable
class FlashcardCategory {
  /// Must match the `category` field in flashcards_manifest.json.
  final String label;
  final IconData icon;

  const FlashcardCategory(this.label, this.icon);
}

/// The client's fixed set of categories. Not user-editable — this is the
/// closed list the topic grid and session setup both draw from.
const List<FlashcardCategory> flashcardCategories = [
  FlashcardCategory('Analysis', Icons.show_chart),
  FlashcardCategory('Geometrie', Icons.square_foot),
  FlashcardCategory('Stochastik', Icons.bar_chart),
];

/// Just the labels, in canonical order.
List<String> get flashcardCategoryLabels =>
    flashcardCategories.map((c) => c.label).toList();
