import 'package:meta/meta.dart';
import '../models/session_score.dart';

/// One point on the trend chart: a single rated session's outcome.
@immutable
class TrendPoint {
  final DateTime date;
  final double accuracy;
  final int points;

  const TrendPoint({
    required this.date,
    required this.accuracy,
    required this.points,
  });
}

/// Weighted accuracy for one category across every session that included it.
@immutable
class CategoryBreakdown {
  final String category;
  final double accuracy;
  final int sessionCount;

  const CategoryBreakdown({
    required this.category,
    required this.accuracy,
    required this.sessionCount,
  });
}

/// Day-streak numbers, shared across flashcards and quiz — see
/// [ProgressStatsService.buildStreak].
@immutable
class StreakStats {
  final int currentStreak;
  final int longestStreak;

  /// Last 7 calendar days, oldest first, whether a rated session (of
  /// either mode) was finished that day.
  final List<bool> last7Days;

  const StreakStats({
    required this.currentStreak,
    required this.longestStreak,
    required this.last7Days,
  });
}

/// Every number the progress screen needs for one mode (flashcards or
/// quiz), derived once from the rated session history. Pure/stateless on
/// purpose — [SessionHistoryStorage] is already the source of truth, this
/// just aggregates it.
@immutable
class ProgressStats {
  final int totalSessions;
  final int totalQuestions;
  final double overallAccuracy;

  /// Chronological (oldest first), capped to the most recent
  /// [ProgressStatsService.trendLimit] sessions so the chart stays legible.
  final List<TrendPoint> trend;

  final List<CategoryBreakdown> categoryBreakdown;

  /// Most recent sessions first, capped to
  /// [ProgressStatsService.recentLimit].
  final List<SessionScore> recentSessions;

  const ProgressStats({
    required this.totalSessions,
    required this.totalQuestions,
    required this.overallAccuracy,
    required this.trend,
    required this.categoryBreakdown,
    required this.recentSessions,
  });

  bool get isEmpty => totalSessions == 0;
}

/// Turns raw [SessionScore] history into everything the progress screen
/// renders. Streaks and the "last 7 days" strip are derived from
/// [SessionScore.finishedAt] across *both* modes (see [buildStreak]) since
/// a rated session of either kind is the only signal we persist for "the
/// user studied that day" — ungraded topic-tile practice isn't recorded,
/// so it can't feed the streak. Everything else is scoped to a single
/// [SessionMode] via [build], since "Letzte Sessions" and the rest of the
/// screen are split by feature.
class ProgressStatsService {
  static const trendLimit = 20;
  static const recentLimit = 5;

  /// Streak numbers from the full history, regardless of mode.
  StreakStats buildStreak(List<SessionScore> sessions) {
    final activeDays = sessions.map((s) => _dateOnly(s.finishedAt)).toSet();
    return StreakStats(
      currentStreak: _currentStreak(activeDays),
      longestStreak: _longestStreak(activeDays),
      last7Days: _last7Days(activeDays),
    );
  }

  /// Everything but the streak, scoped to [mode].
  ProgressStats build(List<SessionScore> allSessions, {required SessionMode mode}) {
    final sessions = allSessions.where((s) => s.mode == mode).toList();
    if (sessions.isEmpty) {
      return const ProgressStats(
        totalSessions: 0,
        totalQuestions: 0,
        overallAccuracy: 0,
        trend: [],
        categoryBreakdown: [],
        recentSessions: [],
      );
    }

    final chronological = [...sessions]
      ..sort((a, b) => a.finishedAt.compareTo(b.finishedAt));

    var totalQuestions = 0;
    var totalKnown = 0;
    for (final s in sessions) {
      totalQuestions += s.total;
      totalKnown += s.known;
    }

    return ProgressStats(
      totalSessions: sessions.length,
      totalQuestions: totalQuestions,
      overallAccuracy: totalQuestions > 0 ? totalKnown / totalQuestions : 0,
      trend: chronological
          .skip(chronological.length > trendLimit
              ? chronological.length - trendLimit
              : 0)
          .map(
            (s) => TrendPoint(
              date: s.finishedAt,
              accuracy: s.accuracy,
              points: s.points,
            ),
          )
          .toList(),
      categoryBreakdown: _categoryBreakdown(sessions),
      recentSessions: sessions.take(recentLimit).toList(),
    );
  }

  DateTime _dateOnly(DateTime d) {
    final local = d.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  int _currentStreak(Set<DateTime> activeDays) {
    var cursor = _dateOnly(DateTime.now());
    if (!activeDays.contains(cursor)) {
      // No session yet today — the streak isn't broken until the day ends,
      // so fall back to checking whether yesterday was covered.
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var streak = 0;
    while (activeDays.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  int _longestStreak(Set<DateTime> activeDays) {
    final sorted = activeDays.toList()..sort();
    var longest = 0;
    var current = 0;
    DateTime? previous;
    for (final day in sorted) {
      if (previous != null && day.difference(previous).inDays == 1) {
        current++;
      } else {
        current = 1;
      }
      if (current > longest) longest = current;
      previous = day;
    }
    return longest;
  }

  List<bool> _last7Days(Set<DateTime> activeDays) {
    final today = _dateOnly(DateTime.now());
    return List.generate(7, (i) {
      final day = today.subtract(Duration(days: 6 - i));
      return activeDays.contains(day);
    });
  }

  List<CategoryBreakdown> _categoryBreakdown(List<SessionScore> sessions) {
    final known = <String, int>{};
    final total = <String, int>{};
    final count = <String, int>{};
    for (final s in sessions) {
      for (final category in s.categories) {
        known[category] = (known[category] ?? 0) + s.known;
        total[category] = (total[category] ?? 0) + s.total;
        count[category] = (count[category] ?? 0) + 1;
      }
    }
    final categories = known.keys.toList()..sort();
    return categories
        .map(
          (c) => CategoryBreakdown(
            category: c,
            accuracy: total[c]! > 0 ? known[c]! / total[c]! : 0,
            sessionCount: count[c]!,
          ),
        )
        .toList();
  }
}
