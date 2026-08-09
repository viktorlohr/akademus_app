import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import '../models/flashcard.dart';
import '../models/study_session_config.dart';
import '../storage/proficiency_storage.dart';
import '../constants/categories.dart';

/// A flashcard paired with its current proficiency for a study session.
class StudyCard {
  final Flashcard card;
  final int proficiency;
  const StudyCard(this.card, this.proficiency);
}

class FlashcardService {
  final _proficiency = ProficiencyStorage();
  final _random = Random();

  // Static so the manifest is read from disk once per app run, not once
  // per screen that happens to construct a service.
  static List<Flashcard>? _cache;

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

  /// Builds the card list for a run.
  ///
  /// Rated sessions shuffle, but weighted: a card at proficiency 0 is
  /// far likelier to be drawn than one at 4, so randomization doesn't
  /// throw away the adaptive ordering that topic mode relies on.
  Future<List<StudyCard>> getCardsForSession(StudySessionConfig config) async {
    final all = await _loadManifest();
    final proficiencyMap = await _proficiency.getAll();

    final selected = all
        .where((c) => config.categories.contains(c.category))
        .toList();

    if (config.shuffle) {
      // Sort by a random key scaled by mastery. Weakest cards get the
      // smallest keys most often, but nothing is ever fully excluded.
      final keys = <String, double>{
        for (final c in selected)
          c.id: _random.nextDouble() * (1 + (proficiencyMap[c.id] ?? 0)),
      };
      selected.sort((a, b) => keys[a.id]!.compareTo(keys[b.id]!));
    } else {
      selected.sort((a, b) {
        final pa = proficiencyMap[a.id] ?? 0;
        final pb = proficiencyMap[b.id] ?? 0;
        return pa.compareTo(pb);
      });
    }

    final limit = config.maxCards;
    final drawn = (limit != null && limit < selected.length)
        ? selected.sublist(0, limit)
        : selected;

    return drawn.map((c) => StudyCard(c, proficiencyMap[c.id] ?? 0)).toList();
  }

  /// How many cards exist per category. Seeded with every known category
  /// so a topic with no cards yet still reports 0 rather than going missing.
  Future<Map<String, int>> countByCategory() async {
    final all = await _loadManifest();
    final counts = <String, int>{
      for (final c in flashcardCategories) c.label: 0,
    };
    for (final c in all) {
      counts[c.category] = (counts[c.category] ?? 0) + 1;
    }
    return counts;
  }

  Future<void> rateCard(String cardId, bool known) async {
    final current = await _proficiency.get(cardId);
    final updated = known
        ? (current < 4 ? current + 1 : current)
        : (current > 0 ? current - 1 : current);
    await _proficiency.set(cardId, updated);
  }
}
