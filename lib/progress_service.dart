import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Single source of truth for saved progress (unlocked level + per
/// level stars). Deliberately kept independent of any widget - the
/// game engine calls [saveLevelResult] the instant a level is won,
/// and the level-select screen calls [getUnlockedLevel] /
/// [getLevelStars] whenever it needs the current truth from disk.
/// This avoids progress ever being lost to a widget-tree timing
/// issue (a screen popped early, a callback that didn't fire, etc).
class ProgressService {
  static const String _unlockedKey = 'word_bloom_unlocked_level';
  static const String _starsKey = 'word_bloom_level_stars';

  static Future<int> getUnlockedLevel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_unlockedKey) ?? 1;
  }

  static Future<Map<int, int>> getLevelStars() async {
    final prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_starsKey);
    if (raw == null || raw.isEmpty) return {};

    try {
      final Map<String, dynamic> decoded =
          jsonDecode(raw) as Map<String, dynamic>;
      final Map<int, int> result = {};
      decoded.forEach((key, value) {
        final int? levelNum = int.tryParse(key);
        if (levelNum != null && value is int) {
          result[levelNum] = value;
        }
      });
      return result;
    } catch (_) {
      // Corrupt/old data - treat as empty rather than crashing.
      return {};
    }
  }

  /// Called the moment a level is won. Bumps the unlocked level (if
  /// this was the frontier level) and records the best star result
  /// for it, both persisted immediately.
  static Future<void> saveLevelResult(int level, int stars) async {
    final prefs = await SharedPreferences.getInstance();

    final int currentUnlocked = prefs.getInt(_unlockedKey) ?? 1;
    if (level >= currentUnlocked) {
      await prefs.setInt(_unlockedKey, level + 1);
    }

    final Map<int, int> stored = await getLevelStars();
    final int existing = stored[level] ?? 0;
    if (stars > existing) {
      stored[level] = stars;
    }

    final Map<String, int> encodable = stored.map(
      (lvl, st) => MapEntry(lvl.toString(), st),
    );
    await prefs.setString(_starsKey, jsonEncode(encodable));
  }
}