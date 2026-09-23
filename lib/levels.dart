import 'dart:math';

// ============================================================
// GAME LEVEL MODEL
// ============================================================

class GameLevel {
  final int number;
  final List<String> words;

  /// Clue for each word.
  /// For levels after 15, these can be empty because hints are hidden.
  final List<String> hints;

  /// Letters used by the board + cannon.
  final List<String> letters;

  /// Maximum number of shots allowed in this level.
  final int maxShots;

  const GameLevel({
    required this.number,
    required this.words,
    required this.hints,
    required this.letters,
    required this.maxShots,
  });

  /// Hints are shown only during the first learning levels.
  bool get showHints => number <= 15;
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

/// Number of levels that will automatically exist.
const int totalAutoLevels = 1000;

/// Random generator.
final Random _random = Random();

// ============================================================
// GET WORDS BY LEVEL
// ============================================================
//
// Difficulty now ramps up gradually across many small steps
// instead of a few big jumps, so the very first levels are truly
// easy (a single 3-letter word) and it only slowly grows into
// longer words, more words per level, and more distractors.
//

List<String> _getWordsForLevel(int levelNumber) {
  int minLength;
  int maxLength;
  int wordCount;

  // ----------------------------------------------------------
  // LEVELS 1-5
  // Ultra easy onboarding: just one 3-letter word.
  // ----------------------------------------------------------
  if (levelNumber <= 5) {
    minLength = 3;
    maxLength = 3;
    wordCount = 1;
  }
  // ----------------------------------------------------------
  // LEVELS 6-15
  // Introduce a second word, still short.
  // ----------------------------------------------------------
  else if (levelNumber <= 15) {
    minLength = 3;
    maxLength = 3;
    wordCount = 2;
  }
  // ----------------------------------------------------------
  // LEVELS 16-30
  // Mix in some 4-letter words.
  // ----------------------------------------------------------
  else if (levelNumber <= 30) {
    minLength = 3;
    maxLength = 4;
    wordCount = 2;
  }
  // ----------------------------------------------------------
  // LEVELS 31-60
  // ----------------------------------------------------------
  else if (levelNumber <= 60) {
    minLength = 4;
    maxLength = 4;
    wordCount = 2;
  }
  // ----------------------------------------------------------
  // LEVELS 61-100
  // ----------------------------------------------------------
  else if (levelNumber <= 100) {
    minLength = 4;
    maxLength = 5;
    wordCount = 2;
  }
  // ----------------------------------------------------------
  // LEVELS 101-200
  // Third word appears.
  // ----------------------------------------------------------
  else if (levelNumber <= 200) {
    minLength = 4;
    maxLength = 5;
    wordCount = 3;
  }
  // ----------------------------------------------------------
  // LEVELS 201-350
  // ----------------------------------------------------------
  else if (levelNumber <= 350) {
    minLength = 5;
    maxLength = 6;
    wordCount = 3;
  }
  // ----------------------------------------------------------
  // LEVELS 351-500
  // ----------------------------------------------------------
  else if (levelNumber <= 500) {
    minLength = 5;
    maxLength = 6;
    wordCount = 3;
  }
  // ----------------------------------------------------------
  // LEVELS 501-750
  // Very hard
  // ----------------------------------------------------------
  else if (levelNumber <= 750) {
    minLength = 6;
    maxLength = 7;
    wordCount = 3;
  }
  // ----------------------------------------------------------
  // LEVELS 751-1000+
  // Expert
  // ----------------------------------------------------------
  else {
    minLength = 6;
    maxLength = 9;
    wordCount = 4;
  }

  final available = wordBank
      .where((word) => word.length >= minLength && word.length <= maxLength)
      .toList();

  // Safety fallback.
  if (available.isEmpty) {
    return ['CAT', 'DOG'];
  }

  available.shuffle(_random);

  return available.take(min(wordCount, available.length)).toList();
}

// ============================================================
// CREATE LETTER POOL
// ============================================================
//
// Every letter needed to create the words is included.
//
// Then extra random letters are added as distractors. The
// distractor count now grows in small steps that line up with the
// word-difficulty bands above, so the board doesn't suddenly get
// noisy - it gets noisy a little at a time.
//

List<String> _createLetters(List<String> words, int levelNumber) {
  final letters = <String>[];

  // ----------------------------------------------------------
  // Add letters required by the words.
  // ----------------------------------------------------------

  for (final word in words) {
    for (final letter in word.split('')) {
      letters.add(letter);
    }
  }

  // ----------------------------------------------------------
  // Add random distractors.
  // Difficulty increases with level, in small steps.
  // ----------------------------------------------------------

  int distractorCount;

  if (levelNumber <= 5) {
    distractorCount = 3;
  } else if (levelNumber <= 15) {
    distractorCount = 5;
  } else if (levelNumber <= 30) {
    distractorCount = 6;
  } else if (levelNumber <= 60) {
    distractorCount = 7;
  } else if (levelNumber <= 100) {
    distractorCount = 9;
  } else if (levelNumber <= 200) {
    distractorCount = 10;
  } else if (levelNumber <= 350) {
    distractorCount = 12;
  } else if (levelNumber <= 500) {
    distractorCount = 14;
  } else if (levelNumber <= 750) {
    distractorCount = 16;
  } else {
    distractorCount = 18;
  }

  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

  for (int i = 0; i < distractorCount; i++) {
    letters.add(alphabet[_random.nextInt(alphabet.length)]);
  }

  return letters;
}

// ============================================================
// CREATE MAX SHOTS
// ============================================================
//
// Early levels are generous with extra shots so new players can't
// easily fail; forgiveness tapers off slowly as the level bands
// get harder.
//

int _calculateMaxShots(List<String> words, int levelNumber) {
  final requiredLetters = words.fold<int>(
    0,
    (total, word) => total + word.length,
  );

  int extraShots;

  if (levelNumber <= 5) {
    extraShots = 12;
  } else if (levelNumber <= 15) {
    extraShots = 10;
  } else if (levelNumber <= 30) {
    extraShots = 9;
  } else if (levelNumber <= 60) {
    extraShots = 9;
  } else if (levelNumber <= 100) {
    extraShots = 8;
  } else if (levelNumber <= 200) {
    extraShots = 8;
  } else if (levelNumber <= 350) {
    extraShots = 7;
  } else if (levelNumber <= 500) {
    extraShots = 7;
  } else if (levelNumber <= 750) {
    extraShots = 6;
  } else {
    extraShots = 6;
  }

  return requiredLetters + extraShots;
}

// ============================================================
// CREATE HINTS
// ============================================================

List<String> _createHints(List<String> words) {
  return words.map((word) {
    return wordHints[word] ?? '💡 Find the letters and make this word';
  }).toList();
}

// ============================================================
// AUTO LEVEL CREATOR
// ============================================================

GameLevel _createLevel(int levelNumber) {
  final words = _getWordsForLevel(levelNumber);

  final letters = _createLetters(words, levelNumber);

  final hints = _createHints(words);

  final maxShots = _calculateMaxShots(words, levelNumber);

  return GameLevel(
    number: levelNumber,
    words: words,
    hints: hints,
    letters: letters,
    maxShots: maxShots,
  );
}

// ============================================================
// AUTOMATIC LEVEL LIST
// ============================================================
//
// This creates:
// Level 1
// Level 2
// Level 3
// ...
// Level 1000
//
// No need to manually write every level.
//

final List<GameLevel> levels = List.generate(
  totalAutoLevels,
  (index) => _createLevel(index + 1),
);

// ============================================================
// GET LEVEL
// ============================================================

GameLevel getLevel(int levelNumber) {
  // Keep level number safe.
  if (levelNumber < 1) {
    levelNumber = 1;
  }

  // Automatically create a level even beyond 1000.
  //
  // This means the game can continue beyond the initial
  // 1000 generated levels.

  if (levelNumber <= levels.length) {
    return levels[levelNumber - 1];
  }

  return _createLevel(levelNumber);
}