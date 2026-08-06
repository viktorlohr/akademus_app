import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/flashcard.dart';
import '../storage/proficiency_storage.dart';

/// A flashcard paired with its current proficiency for a study session.
class StudyCard {
  final Flashcard card;
  final int proficiency;
  const StudyCard(this.card, this.proficiency);
}

class FlashcardService {
  final _proficiency = ProficiencyStorage();

  // The manifest is static for the lifetime of the app, so it only needs
  // to be read from disk once.
  List<Flashcard>? _cache;

  Future<List<Flashcard>> _loadManifest() async {
    if (_cache != null) return _cache!;
    final jsonString = await rootBundle.loadString(
      'assets/flashcards_manifest.json',
    );
    final decoded = jsonDecode(jsonString) as List;
    _cache = decoded
        .map((e) => Flashcard.fromJson(e as Map<String, dynamic>))
        .toList();
    return _cache!;
  }

  /// Cards for a category, sorted weakest-first so the least-known cards
  /// come up earliest in the session.
  Future<List<StudyCard>> getCardsForCategory(String category) async {
    final all = await _loadManifest();
    final proficiencyMap = await _proficiency.getAll();

    final filtered = all.where((c) => c.category == category).toList()
      ..sort((a, b) {
        final pa = proficiencyMap[a.id] ?? 0;
        final pb = proficiencyMap[b.id] ?? 0;
        return pa.compareTo(pb);
      });

    return filtered
        .map((c) => StudyCard(c, proficiencyMap[c.id] ?? 0))
        .toList();
  }

  Future<void> rateCard(String cardId, bool known) async {
    final current = await _proficiency.get(cardId);
    final updated = known
        ? (current < 4 ? current + 1 : current)
        : (current > 0 ? current - 1 : current);
    await _proficiency.set(cardId, updated);
  }
}
