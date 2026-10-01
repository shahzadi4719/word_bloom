import 'dart:math';

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
  /// 0 = none. Metadata for future special bubbles (engine does not use it yet).
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
  int get totalRequiredLetters =>
      words.fold<int>(0, (t, w) => t + w.length);
}
// ============================================================
// WORD BANK
// ============================================================
//
// Add more words here whenever you want.
// The automatic generator will use these words to create levels.
//
// IMPORTANT:
// Keep words in CAPITAL letters.
//

const List<String> wordBank = [
  // ----------------------------------------------------------
  // 3 LETTER WORDS
  // ----------------------------------------------------------

  'CAT',
  'DOG',
  'SUN',
  'SKY',
  'CAR',
  'BUS',
  'CUP',
  'HAT',
  'MAP',
  'PEN',
  'BOX',
  'FOX',
  'BAT',
  'RAT',
  'PIG',
  'HEN',
  'COW',
  'BEE',
  'ANT',
  'OWL',
  'EGG',
  'ICE',
  'RED',
  'BIG',
  'RUN',
  'FUN',
  'JAM',
  'BED',
  'KEY',
  'TOY',
  'BOY',
  'GIRL',
  'AIR',
  'SEA',
  'SUN',
  'DAY',
  'NIGHT',

  // ----------------------------------------------------------
  // 4 LETTER WORDS
  // ----------------------------------------------------------
  'STAR',
  'MOON',
  'FISH',
  'BIRD',
  'TREE',
  'BOOK',
  'BALL',
  'MILK',
  'CAKE',
  'HOME',
  'HAND',
  'FOOD',
  'FROG',
  'DUCK',
  'BEAR',
  'LION',
  'WOLF',
  'SHIP',
  'RAIN',
  'SNOW',
  'WIND',
  'FIRE',
  'GOLD',
  'BLUE',
  'PINK',
  'ROSE',
  'LEAF',
  'LOVE',
  'GAME',
  'PLAY',
  'JUMP',
  'WALK',
  'TALK',
  'SING',
  'DANCE',

  // ----------------------------------------------------------
  // 5 LETTER WORDS
  // ----------------------------------------------------------
  'BLOOM',
  'FLOWER',
  'APPLE',
  'GRAPE',
  'MANGO',
  'LEMON',
  'PEACH',
  'BERRY',
  'TIGER',
  'HORSE',
  'SHEEP',
  'MOUSE',
  'HOUSE',
  'WORLD',
  'HEART',
  'SMILE',
  'DREAM',
  'LIGHT',
  'CLOUD',
  'WATER',
  'EARTH',
  'SPACE',
  'GREEN',
  'BLACK',
  'WHITE',
  'HAPPY',
  'SWEET',
  'MAGIC',
  'MUSIC',
  'CANDY',
  'PARTY',
  'QUEEN',
  'CROWN',

  // ----------------------------------------------------------
  // 6 LETTER WORDS
  // ----------------------------------------------------------
  'GARDEN',
  'BUTTER',
  'BUNNY',
  'MONKEY',
  'PUPPY',
  'KITTEN',
  'SUNSET',
  'SUNRISE',
  'RAINBOW',
  'FOREST',
  'PLANET',
  'GALAXY',
  'OCEANS',
  'ISLAND',
  'CASTLE',
  'BRIDGE',
  'FRIEND',
  'FAMILY',
  'SUMMER',
  'WINTER',
  'SPRING',
  'AUTUMN',
  'PURPLE',
  'YELLOW',
  'ORANGE',
  'SILVER',
  'GOLDEN',
  'BEAUTY',
  'HAPPY',
  'SMILES',
  'DREAMS',
  'MAGICAL',

  // ----------------------------------------------------------
  // 7 LETTER WORDS
  // ----------------------------------------------------------
  'FLOWERS',
  'RAINBOW',
  'BUTTERFLY',
  'SUNFLOWER',
  'GARDENS',
  'KINGDOM',
  'FRIENDS',
  'FAMILY',
  'DOLPHIN',
  'PENGUIN',
  'UNICORN',
  'DRAGON',
  'PRINCESS',
  'TREASURE',
  'ADVENTURE',
  'JOURNEY',
  'AMAZING',
  'BEAUTIFUL',
  'SPARKLE',
  'SUNSHINE',

  // ----------------------------------------------------------
  // 8+ LETTER WORDS
  // ----------------------------------------------------------
  'BUTTERFLY',
  'SUNFLOWER',
  'ADVENTURE',
  'BEAUTIFUL',
  'CHOCOLATE',
  'RAINBOWS',
  'BUTTERFLIES',
  'HAPPINESS',
  'CREATIVE',
  'DREAMING',
  'WONDERFUL',
  'STARLIGHT',
  'MOONLIGHT',
  'FLOWERING',
];

// ============================================================
// HINTS
// ============================================================
//
// These are used for the first few levels.
// If a word does not have a custom hint, a generic hint is used.
//

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

/// Hand-made levels. Anything put here replaces the generated level.
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
// ROADMAP TABLES (level number -> properties)
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

int wordCountForLevel(int n) {
  if (n <= 5) return 1;
  if (n <= 20) return 2;
  if (n <= 70) return 3;
  if (n <= 150) return 4;
  if (n <= 300) return 5;
  if (n <= 500) return 6;
  if (n <= 800) return 7;
  if (n <= 1200) return 8;
  if (n <= 1600) return 9;
  if (n <= 1950) return 10;
  if (n <= 1975) return 11;
  return 12;
}

List<int> _lengthRange(int n) {
  if (n <= 10) return [3, 3];
  if (n <= 70) return [3, 4];
  if (n <= 500) return [4, 5];
  if (n <= 1200) return [5, 6];
  if (n <= 1600) return [5, 7];
  if (n <= 1800) return [6, 7];
  return [6, 8];
}

/// Every 10th level (after 10) is a "breather": shorter words, more shots.
bool _isBreather(int n) => n > 10 && n % 10 == 0;

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

double _extraRatio(int n) {
  if (n <= 100) return 0.9;
  if (n <= 300) return 0.7;
  if (n <= 500) return 0.6;
  if (n <= 800) return 0.5;
  if (n <= 1000) return 0.45;
  if (n <= 1400) return 0.4;
  if (n <= 1700) return 0.35;
  return 0.3;
}

// ============================================================
// WORD SELECTION
// ============================================================

final List<String> _uniqueBank = wordBank.toSet().toList();

bool _conflicts(String w, List<String> picked) {
  for (final p in picked) {
    if (p == w || p.contains(w) || w.contains(p)) return true;
  }
  return false;
}

List<String> _pickWords(int n, Random rnd) {
  final int count = wordCountForLevel(n);
  final List<int> range = _lengthRange(n);
  int lo = range[0];
  int hi = range[1];
  if (_isBreather(n)) {
    lo = max(3, lo - 1);
    hi = max(lo, hi - 1);
  }

  final List<String> picked = [];

  for (int widen = 0; widen <= 3 && picked.length < count; widen++) {
    final pool = _uniqueBank
        .where((w) => w.length >= max(3, lo - widen) && w.length <= hi + widen)
        .toList()
      ..shuffle(rnd);

    for (final w in pool) {
      if (picked.length >= count) break;
      if (_conflicts(w, picked)) continue;
      picked.add(w);
    }
  }
  return picked;
}

// ============================================================
// LETTERS / HINTS / SHOTS
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

List<String> _createHints(List<String> words, int n) {
  final int clues = _hintCountForLevel(n);
  return List.generate(words.length, (i) {
    if (i >= clues) return '';
    final w = words[i];
    return wordHints[w] ?? '';
  });
}

int _calculateMaxShots(List<String> words, int n, Random rnd) {
  final int required = words.fold<int>(0, (t, w) => t + w.length);

  int extra;
  if (n <= 5) {
    extra = 12; // tutorial: very generous
  } else {
    double ratio = _extraRatio(n) + (rnd.nextDouble() * 0.06 - 0.03);
    if (_isBreather(n)) ratio += 0.2;
    final int minExtra = n <= 100 ? 9 : (n <= 500 ? 7 : 6);
    extra = max(minExtra, (required * ratio).round());
  }
  return required + extra;
}

// ============================================================
// VALIDATION
// ============================================================

bool _isValid(GameLevel level) {
  final n = level.number;
  if (level.words.length != wordCountForLevel(n)) return false;
  if (level.words.toSet().length != level.words.length) return false;

  for (int i = 0; i < level.words.length; i++) {
    final a = level.words[i];
    if (!RegExp(r'^[A-Z]+$').hasMatch(a)) return false;
    for (int j = i + 1; j < level.words.length; j++) {
      final b = level.words[j];
      if (a.contains(b) || b.contains(a)) return false;
    }
  }

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
    if ((have[e.key] ?? 0) < e.value) return false;
  }

  return level.maxShots >= level.totalRequiredLetters + 4;
}

// ============================================================
// LEVEL CREATOR
// ============================================================

GameLevel _createLevel(int n) {
  final GameLevel? custom = levelOverrides[n];
  if (custom != null) return custom;

  final int world = worldFor(n);
  GameLevel? last;

  // Seeded, so level N is the same every time the app opens.
  for (int attempt = 0; attempt < 20; attempt++) {
    final rnd = Random(n * 7919 + attempt * 104729);

    final words = _pickWords(n, rnd);
    if (words.isEmpty) continue;

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
    if (_isValid(level)) return level;
  }

  return last ??
      GameLevel(
        number: n,
        words: const ['CAT'],
        hints: const ['🐱 An animal that says meow'],
        letters: const ['C', 'A', 'T', 'X', 'Z', 'Q'],
        maxShots: 15,
      );
}

// ============================================================
// LEVEL LIST + GET LEVEL
// ============================================================

final List<GameLevel> levels = List.generate(
  totalAutoLevels,
  (index) => _createLevel(index + 1),
);

GameLevel getLevel(int levelNumber) {
  if (levelNumber < 1) levelNumber = 1;
  if (levelNumber <= levels.length) return levels[levelNumber - 1];
  return _createLevel(levelNumber);
}