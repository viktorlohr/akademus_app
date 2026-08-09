import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import '../models/quiz_question.dart';
import '../models/study_session_config.dart';
import '../constants/categories.dart';

class QuizService {
  final _random = Random();

  static List<QuizQuestion>? _cache;

  Future<List<QuizQuestion>> _loadManifest() async {
    if (_cache != null) return _cache!;
    final jsonString = await rootBundle.loadString(
      'assets/quiz_manifest.json',
    );
    final decoded = jsonDecode(jsonString) as List;
    _cache = decoded
        .map((e) => QuizQuestion.fromJson(e as Map<String, dynamic>))
        .toList();
    return _cache!;
  }

  /// Builds the question list for a run: filtered by category, optionally
  /// shuffled, optionally capped. No proficiency weighting yet — unlike
  /// flashcards there's no per-question mastery storage in this prototype.
  Future<List<QuizQuestion>> getQuestionsForSession(
    StudySessionConfig config,
  ) async {
    final all = await _loadManifest();
    final selected = all
        .where((q) => config.categories.contains(q.category))
        .toList();

    if (config.shuffle) {
      selected.shuffle(_random);
    }

    final limit = config.maxCards;
    return (limit != null && limit < selected.length)
        ? selected.sublist(0, limit)
        : selected;
  }

  Future<Map<String, int>> countByCategory() async {
    final all = await _loadManifest();
    final counts = <String, int>{
      for (final c in flashcardCategories) c.label: 0,
    };
    for (final q in all) {
      counts[q.category] = (counts[q.category] ?? 0) + 1;
    }
    return counts;
  }
}
