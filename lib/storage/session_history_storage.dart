import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/session_score.dart';

/// Keeps the last [_limit] rated sessions, newest first.
class SessionHistoryStorage {
  static const _key = 'session_history';
  static const _limit = 50;

  Future<List<SessionScore>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded
          .map((e) => SessionScore.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> add(SessionScore score) async {
    final all = await getAll();
    final updated = [score, ...all].take(_limit).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(updated.map((s) => s.toJson()).toList()),
    );
  }

  /// Best score ever recorded for the same set of categories, so the
  /// stats screen can say "personal best".
  Future<SessionScore?> bestFor(List<String> categories) async {
    final key = ([...categories]..sort()).join('|');
    final matches = await getAll();
    SessionScore? best;
    for (final s in matches) {
      if (([...s.categories]..sort()).join('|') != key) continue;
      if (best == null || s.points > best.points) best = s;
    }
    return best;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
