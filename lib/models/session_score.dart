import 'package:meta/meta.dart';

/// Which study feature produced a [SessionScore] — lets the progress
/// screen split "Letzte Sessions" (and everything else but the streak)
/// by feature instead of lumping flashcards and quiz together.
enum SessionMode {
  flashcard,
  quiz;

  String toJson() => name;

  /// Sessions saved before this field existed don't have a `mode` key.
  /// They all came from flashcards (quiz's history entries postdate this
  /// split), so that's the safe default for missing/unknown values.
  static SessionMode fromJson(String? value) =>
      SessionMode.values.firstWhere(
        (m) => m.name == value,
        orElse: () => SessionMode.flashcard,
      );
}

/// The graded outcome of one rated session. Separate from per-card
/// proficiency on purpose: proficiency is long-term memory strength,
/// this is "how did I do just now".
@immutable
class SessionScore {
  final String title;
  final List<String> categories;
  final int total;
  final int known;
  final int maxStreak;
  final DateTime finishedAt;
  final SessionMode mode;

  const SessionScore({
    required this.title,
    required this.categories,
    required this.total,
    required this.known,
    required this.maxStreak,
    required this.finishedAt,
    required this.mode,
  });

  double get accuracy => total > 0 ? known / total : 0.0;
  int get percent => (accuracy * 100).round();

  /// Streak is capped at a third of the deck so a 5-card session can't
  /// out-grade a 40-card one on a lucky run.
  int get points {
    final streakBonus = total > 0
        ? (maxStreak / total * 3).clamp(0.0, 1.0) * 20
        : 0.0;
    return (accuracy * 80 + streakBonus).round();
  }

  /// Schulnote-style band, since the audience is German pupils.
  String get grade {
    final p = points;
    if (p >= 92) return 'A';
    if (p >= 81) return 'B';
    if (p >= 67) return 'C';
    if (p >= 50) return 'D';
    return 'E';
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'categories': categories,
    'total': total,
    'known': known,
    'maxStreak': maxStreak,
    'finishedAt': finishedAt.toIso8601String(),
    'mode': mode.toJson(),
  };

  factory SessionScore.fromJson(Map<String, dynamic> json) => SessionScore(
    title: json['title'] as String,
    categories: (json['categories'] as List).cast<String>(),
    mode: SessionMode.fromJson(json['mode'] as String?),
    total: json['total'] as int,
    known: json['known'] as int,
    maxStreak: json['maxStreak'] as int,
    finishedAt: DateTime.parse(json['finishedAt'] as String),
  );
}
