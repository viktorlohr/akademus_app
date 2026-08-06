import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks per-card proficiency (0-4) keyed by card id. Card content itself
/// comes from the read-only bundled manifest, so this is the only thing
/// that actually needs to persist across sessions.
class ProficiencyStorage {
  static const _key = 'card_proficiency';

  Future<Map<String, int>> _readAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v as int));
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeAll(Map<String, int> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(data));
  }

  Future<int> get(String cardId) async {
    final all = await _readAll();
    return all[cardId] ?? 0;
  }

  Future<Map<String, int>> getAll() => _readAll();

  Future<void> set(String cardId, int proficiency) async {
    final all = await _readAll();
    all[cardId] = proficiency.clamp(0, 4);
    await _writeAll(all);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
