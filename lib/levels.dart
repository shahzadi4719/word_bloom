import 'dart:math';
import 'word_dictionary.dart';

// ============================================================
// GAME LEVEL MODEL
// ============================================================

class GameLevel {
  final int number;
  final List<String> words;

  /// One clue per word. Empty string = no clue for that word.
  final List<String> hints;
  final List<String> letters;
  final int maxShots;

  final int world; // 1..8
  final String difficulty; // label for UI

  /// 0 = none. Metadata for future special bubbles.
  final int specialTier;

  const GameLevel({
    required this.number,
    required this.words,
    required this.hints,
    required this.letters,
    required this.maxShots,
    this.world = 1,
    this.difficulty = 'Very Easy',
    this.specialTier = 0,
  });

  bool get showHints => hints.any((h) => h.isNotEmpty);

  int get wordCount => words.length;

  int get minWordLength => words.map((w) => w.length).reduce(min);

  int get maxWordLength => words.map((w) => w.length).reduce(max);

  int get totalRequiredLetters => words.fold<int>(0, (t, w) => t + w.length);
}

// ============================================================
// WORD BANK
// ============================================================

List<String> wordBank = [];

Future<void> initializeWordBank() async {
  wordBank = (await loadWordList()).toList();
}

// ============================================================
// HINTS
// ============================================================

const Map<String, String> wordHints = {
  'CAT': '🐱 An animal that says meow',
  'DOG': '🐶 A loyal friend that barks',
  'SUN': '☀️ It shines bright in the day',
  'SKY': '🌤️ The blue space above us',
  'STAR': '⭐ It twinkles at night',
  'MOON': '🌙 It glows in the night sky',
  'FISH': '🐟 It swims and lives in water',
  'BIRD': '🐦 It flies and sings songs',
  'BLOOM': '🌸 When a flower opens up',
  'FLOWER': '🌺 A colorful blossom in a garden',
  'TREE': '🌳 A tall plant with branches',
  'BOOK': '📖 You read this',
  'BALL': '⚽ You can kick or throw it',
  'CAKE': '🎂 A sweet treat for birthdays',
  'APPLE': '🍎 A red or green fruit',
  'GRAPE': '🍇 A small juicy fruit',
  'MANGO': '🥭 A sweet tropical fruit',
  'ROSE': '🌹 A beautiful garden flower',
  'RAINBOW': '🌈 Colorful arc seen after rain',
  'BUTTERFLY': '🦋 A colorful insect with wings',
  'SUNFLOWER': '🌻 A bright yellow flower',
};

// ============================================================
// SETTINGS
// ============================================================

const int totalAutoLevels = 2000;

/// Hand-made levels.
/// Anything put here replaces the generated level.
const Map<int, GameLevel> levelOverrides = {};

const List<String> worldNames = [
  'Learning',
  'Growing',
  'Challenge',
  'Advanced',
  'Expert',
  'Master',
  'Master+',
  'Final Garden',
];

const List<String> _difficultyLabels = [
  'Very Easy',
  'Easy',
  'Medium',
  'Hard',
  'Hard+',
  'Expert',
  'Master',
  'Legend',
];

// ============================================================
// ROADMAP TABLES
// ============================================================

int worldFor(int n) {
  if (n <= 100) return 1;
  if (n <= 300) return 2;
  if (n <= 500) return 3;
  if (n <= 800) return 4;
  if (n <= 1000) return 5;
  if (n <= 1400) return 6;
  if (n <= 1700) return 7;
  return 8;
}

String worldNameFor(int n) => worldNames[worldFor(n) - 1];

// ============================================================
// HOW MANY WORDS PER LEVEL
// ============================================================
//
// 1   - 5     => 1
// 6   - 15    => 2
// 16  - 60    => 3
// 61  - 200   => 4
// 201 - 400   => 5
// 401 - 900   => 6
// 901 - 1600  => 7
// 1601- 2000  => 8
//
// Mobile players don't enjoy 12-word levels, so the count stops
// at 8. Difficulty comes from word length + obstacles instead.
// ============================================================

int wordCountForLevel(int n) {
  if (n <= 5) return 1;
  if (n <= 15) return 2;
  if (n <= 60) return 3;
  if (n <= 200) return 4;
  if (n <= 400) return 5;
  if (n <= 900) return 6;
  if (n <= 1600) return 7;
  return 8;
}

// ============================================================
// WORD LENGTH PROGRESSION
// ============================================================
//
// 1    - 30    => 3 letters
// 31   - 60    => 3 to 4 letters
// 61   - 200   => 4 letters
// 201  - 400   => 4 to 5 letters
// 401  - 700   => 5 letters
// 701  - 1100  => 5 to 6 letters
// 1101 - 2000  => 6 to 7 letters
//
// The game engine uses the same table (lengthRangeFor) to decide
// which dictionary words are allowed to pop on each level.
// ============================================================

List<int> _lengthRange(int n) {
  if (n <= 30) return [3, 3];

  if (n <= 60) return [3, 4];

  if (n <= 200) return [4, 4];

  if (n <= 400) return [4, 5];

  if (n <= 700) return [5, 5];

  if (n <= 1100) return [5, 6];

  return [6, 7];
}

/// Public: min/max word length for a level.
List<int> lengthRangeFor(int n) => _lengthRange(n);

/// Public: label for the level preview dialog.
String lengthLabelFor(int n) {
  final r = _lengthRange(n);
  return r[0] == r[1]
      ? '${r[0]} LETTER WORDS'
      : '${r[0]}–${r[1]} LETTER WORDS';
}

// ============================================================
// HINTS / SPECIALS / DISTRACTORS
// ============================================================

int _hintCountForLevel(int n) {
  if (n <= 10) return 3;
  if (n <= 100) return 2;
  if (n <= 300) return n.isEven ? 2 : 1;
  if (n <= 500) return 1;
  if (n <= 1000) return n % 3 == 0 ? 1 : 0;
  return n % 25 == 0 ? 1 : 0;
}

int _specialTierFor(int n) {
  if (n <= 100) return 0;
  if (n <= 300) return n % 8 == 0 ? 1 : 0;
  if (n <= 500) return n % 6 == 0 ? 2 : 0;
  if (n <= 1000) return n % 4 == 0 ? 3 : 0;
  return n % 3 == 0 ? 4 : 0;
}

int _distractorCount(int n) {
  if (n <= 5) return 3;
  if (n <= 15) return 5;
  if (n <= 30) return 6;
  if (n <= 60) return 7;
  if (n <= 100) return 9;
  if (n <= 200) return 10;
  if (n <= 350) return 12;
  if (n <= 500) return 14;
  if (n <= 750) return 16;
  return 18;
}

// ============================================================
// WORD SELECTION
// ============================================================

// IMPORTANT:
// This is a getter, not a final variable.
//
// wordBank is loaded later by initializeWordBank().
// Therefore we must read the current wordBank whenever
// _pickWords() runs.

List<String> get _uniqueBank => wordBank.toSet().toList();

bool _conflicts(String w, List<String> picked) {
  for (final p in picked) {
    if (p == w || p.contains(w) || w.contains(p)) {
      return true;
    }
  }

  return false;
}

List<String> _pickWords(int n, Random rnd) {
  final int count = wordCountForLevel(n);

  final List<int> range = _lengthRange(n);

  final int lo = range[0];
  final int hi = range[1];

  final List<String> picked = [];

  final pool =
      _uniqueBank.where((w) => w.length >= lo && w.length <= hi).toList()
        ..shuffle(rnd);

  for (final w in pool) {
    if (picked.length >= count) {
      break;
    }

    if (_conflicts(w, picked)) {
      continue;
    }

    picked.add(w);
  }

  return picked;
}

// ============================================================
// LETTERS
// ============================================================

List<String> _createLetters(List<String> words, int n, Random rnd) {
  final letters = <String>[];

  for (final word in words) {
    letters.addAll(word.split(''));
  }

  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

  for (int i = 0; i < _distractorCount(n); i++) {
    letters.add(alphabet[rnd.nextInt(alphabet.length)]);
  }

  return letters;
}

// ============================================================
// HINTS
// ============================================================

List<String> _createHints(List<String> words, int n) {
  final int clues = _hintCountForLevel(n);

  return List.generate(words.length, (i) {
    if (i >= clues) {
      return '';
    }

    final w = words[i];

    return wordHints[w] ?? '';
  });
}

// ============================================================
// SHOTS
// ============================================================
//
// shots = (total letters of the level's words) x ratio
//
// The ratio goes UP with the level (2.2 -> 3.0): longer words are
// much harder to chain from random board letters, so late levels
// need more shots per letter, not fewer.
//
// Never below 24 (+1 every 60 levels), and never below
// required letters + 12.
//
//   level 1     -> 24
//   level 84    -> ~36
//   level 300   -> ~52
//   level 1000  -> ~100
//   level 2000  -> ~156
// ============================================================

double _shotRatio(int n) => 2.2 + (n.clamp(1, 2000) / 2000) * 0.8;

int _calculateMaxShots(List<String> words, int n, Random rnd) {
  final int required = words.fold<int>(0, (t, w) => t + w.length);

  final int byLetters = (required * _shotRatio(n)).round();
  final int floorShots = 24 + n ~/ 60;

  // tiny random variation so neighbouring levels don't feel identical
  final int wiggle = n <= 5 ? 0 : rnd.nextInt(3);

  return max(max(byLetters, floorShots), required + 12) + wiggle;
}

// ============================================================
// VALIDATION
// ============================================================

bool _isValid(GameLevel level) {
  final n = level.number;

  // Correct number of words.
  if (level.words.length != wordCountForLevel(n)) {
    return false;
  }

  // No duplicate words.
  if (level.words.toSet().length != level.words.length) {
    return false;
  }

  // Validate words and prevent one word
  // from containing another.
  for (int i = 0; i < level.words.length; i++) {
    final a = level.words[i];

    if (!RegExp(r'^[A-Z]+$').hasMatch(a)) {
      return false;
    }

    for (int j = i + 1; j < level.words.length; j++) {
      final b = level.words[j];

      if (a.contains(b) || b.contains(a)) {
        return false;
      }
    }
  }

  // Check that all required letters
  // actually exist in the level.
  final need = <String, int>{};

  for (final w in level.words) {
    for (final c in w.split('')) {
      need[c] = (need[c] ?? 0) + 1;
    }
  }

  final have = <String, int>{};

  for (final c in level.letters) {
    have[c] = (have[c] ?? 0) + 1;
  }

  for (final e in need.entries) {
    if ((have[e.key] ?? 0) < e.value) {
      return false;
    }
  }

  // Minimum four extra shots.
  return level.maxShots >= level.totalRequiredLetters + 4;
}

// ============================================================
// LEVEL CREATOR
// ============================================================

GameLevel _createLevel(int n) {
  final GameLevel? custom = levelOverrides[n];

  if (custom != null) {
    return custom;
  }

  final int world = worldFor(n);

  GameLevel? last;

  // Seeded, so level N is the same every time
  // the app opens.
  for (int attempt = 0; attempt < 20; attempt++) {
    final rnd = Random(n * 7919 + attempt * 104729);

    final words = _pickWords(n, rnd);

    if (words.isEmpty) {
      continue;
    }

    final level = GameLevel(
      number: n,
      words: words,
      hints: _createHints(words, n),
      letters: _createLetters(words, n, rnd),
      maxShots: _calculateMaxShots(words, n, rnd),
      world: world,
      difficulty: _difficultyLabels[world - 1],
      specialTier: _specialTierFor(n),
    );

    last = level;

    if (_isValid(level)) {
      return level;
    }
  }

  // Safety fallback.
  return last ??
      GameLevel(
        number: n,
        words: const ['CAT'],
        hints: const ['🐱 An animal that says meow'],
        letters: const ['C', 'A', 'T', 'X', 'Z', 'Q'],
        maxShots: 24,
      );
}

// ============================================================
// LEVEL LIST + GET LEVEL
// ============================================================

late List<GameLevel> levels;

void generateLevels() {
  levels = List.generate(totalAutoLevels, (index) => _createLevel(index + 1));
}

GameLevel getLevel(int levelNumber) {
  if (levelNumber < 1) {
    levelNumber = 1;
  }

  if (levelNumber <= levels.length) {
    return levels[levelNumber - 1];
  }

  return _createLevel(levelNumber);
}