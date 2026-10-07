import 'dart:math';
import 'package:flutter/material.dart';

import 'bubble.dart';
import 'levels.dart';
import 'booster_service.dart';
import 'booster_model.dart';
import 'booster_bar.dart';

/// A bubble that has just popped - purely visual, it no longer
/// exists in `bubbles` / affects game logic.
class FlyingPopBubble {
  final String letter;
  final Color color;
  final double startX;
  final double startY;
  double progress; // 0 -> 1

  FlyingPopBubble({
    required this.letter,
    required this.color,
    required this.startX,
    required this.startY,
    this.progress = 0,
  });
}

/// A leftover shot flying out of the launcher ring after a level is won.
class BonusShotBubble {
  final String letter;
  final Color color;
  final double startX;
  final double startY;
  final double endX;
  final double endY;
  final int points;
  double progress; // 0 -> 1

  BonusShotBubble({
    required this.letter,
    required this.color,
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
    required this.points,
    this.progress = 0,
  });
}

class GameEngine {
  // ============================================================
  // DICTIONARY (any real word pops, but only within the level's
  // allowed length range - see lengthRangeFor in levels.dart)
  // ============================================================
  static const int minWordLength = 3;
  static const int maxWordLength = 8;

  Set<String> _dictionary = {};
  Set<String> _prefixes = {};

  void setDictionary(Set<String> words) {
    _dictionary = words;
    _prefixes = {};
    for (final String w in words) {
      for (int i = 1; i <= w.length; i++) {
        _prefixes.add(w.substring(0, i));
      }
    }
  }

  // ============================================================
  // BOARD
  // ============================================================

  final List<Bubble> bubbles = [];

  Bubble? flyingBubble;

  // The board bubble the shot actually collided with.
  Bubble? _lastHitBubble;

  double velocityX = 0;
  double velocityY = 0;

  bool shooting = false;
  bool levelComplete = false;
  bool gameOver = false;

  GameLevel? currentLevel;

  int shotsUsed = 0;
  int score = 0;

  String? foundWord;
  double wordMessageTimer = 0;

  final List<FlyingPopBubble> flyingPops = [];
  final List<String> collectedLetters = [];

  /// Bubbles that lost their connection to the ceiling and are
  /// falling off the board (visual + bonus score only).
  final List<Bubble> fallingBubbles = [];
  final Map<int, double> _fallSpeeds = {};

  // ---- board scrolling -------------------------------------------------
  /// How many rows are visible on screen at once. Taller patterns
  /// start partly above the screen and slide down as the bottom
  /// of the board gets cleared.
  static const int visibleRows = 6;

  /// Total vertical shift applied to the board (<= 0 while rows are
  /// still hidden above the screen).
  double _scrollOffset = 0;

  /// Distance the board still has to slide down (animated).
  double _scrollRemaining = 0;

  bool get isScrolling => _scrollRemaining > 0.0005;

  // ---- level-win bonus: leftover shots fly out of the ring --------------
  static const int pointsPerLeftoverShot = 10;

  final List<BonusShotBubble> bonusShots = [];
  int bonusShotsLeft = 0;
  bool _winPending = false;
  double _winWait = 0;
  double _bonusTimer = 0;
  double _bonusInterval = 0.06;
  int? _lockedStars;
  final Random _bonusRnd = Random();

  // ---- player feedback --------------------------------------------------
  /// Short message under the top bar ("too short", "already found").
  String? toastMessage;
  double _toastTimer = 0;

  void _showToast(String message) {
    toastMessage = message;
    _toastTimer = 1.8;
  }

  /// e.g. "4 letters" or "3–4 letters" for the current level.
  String get lengthRuleText {
    final List<int> r = lengthRangeFor(currentLevel?.number ?? 1);
    return r[0] == r[1] ? '${r[0]} letters' : '${r[0]}–${r[1]} letters';
  }

  /// All of the level's words have been found (board is clearing).
  bool get goalReached =>
      currentLevel != null &&
      completedWords.length >= currentLevel!.words.length;

  /// Frames each falling bubble still waits before it starts to drop
  /// (used for the cascade when a level is won).
  final Map<int, int> _fallDelays = {};

  // ---- obstacles --------------------------------------------------------
  /// Locked bubbles: bubble id -> how many more shots must land next to
  /// it before it unlocks. A locked bubble can't be part of a word.
  final Map<int, int> lockHits = {};

  /// Stone bubbles (no letter). They never join a word and only break
  /// when a word pops right next to them.
  final Set<int> stoneIds = {};

  static const int lockStrength = 2;

  /// Ice: frozen letter, melts (and becomes usable) when a word pops next to it.
  final Set<int> iceIds = {};

  /// Hidden: shows '?', revealed when a shot lands next to it.
  final Set<int> hiddenIds = {};

  /// Bomb: when its word pops, every neighbour pops too.
  final Set<int> bombIds = {};

  /// Wildcard: can be any letter.
  final Set<int> wildIds = {};

  static const List<String> _alphabet = [
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'P',
    'Q',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z',
  ];

  // ---- per-level rules --------------------------------------------------
  /// 0 = no timer. Otherwise seconds for the whole level.
  double timeLimit = 0;
  double timeLeft = 0;
  bool timeUp = false;
  DateTime? _lastTick;

  /// -1 = unlimited swaps.
  int swapsLeft = -1;

  /// 0 = board never drops. Otherwise it drops one row every N shots.
  int descendEvery = 0;
  int _shotsSinceDescend = 0;

  /// Shots left until the next drop (-1 when this level has no drops).
  int get shotsUntilDescend =>
      descendEvery <= 0 ? -1 : descendEvery - _shotsSinceDescend;

  /// How consonant-heavy the shooter letters are (0 = friendly).
  int _poolTier = 0;

  /// Pixel diameter of the shooter ball. Board bubbles use the same
  /// size (clamped so a full row still fits on screen).
  static const double shooterBubbleDiameterPx = 72;
  static const int maxBoardColumns = 6;

  double bubbleRadius = 0.052;
  double horizontalSpacing = 0.104;

  /// Used by the UI aim clamp and as the reference for the first row.
  final double boardTopY = 0.16;

  /// Center y of the first row (must match _addRow).
  double get _topRowY => boardTopY + 0.03;

  /// Highest y where a shot bubble's center can go (aim line and
  /// bubble both stop here). Raise this number if it hits the top bar.
  double get _ceilingY => headerY + bubbleRadius * _aspect;

  final double dangerLineY = 0.86;

  /// Fraction of the screen height covered by the top bar area.
  static const double headerY = 0.125;

  double _aspect = 0.5;

  /// Exposed so the UI layer can use the same aspect.
  double get aspect => _aspect;

  void configureForScreen(Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    _aspect = size.width / size.height;

    final double maxFitDiameter = size.width * 0.90 / maxBoardColumns;
    final double diameterPx = min(shooterBubbleDiameterPx, maxFitDiameter);
    bubbleRadius = (diameterPx / 2) / size.width;
    horizontalSpacing = bubbleRadius * 2;
  }

  double _physicalDistance(double dx, double dyHeightFraction) {
    final double dyPhysical = dyHeightFraction / _aspect;
    return sqrt(dx * dx + dyPhysical * dyPhysical);
  }

  double get verticalSpacing => horizontalSpacing * _aspect * 0.87;

  List<String> _shotQueue = [];
  int _shotQueueIndex = 0;

  final List<String> completedWords = [];

  /// Levels at or below this get a bigger board (more bubbles).
  static const int expandedBoardLevelCap = 20;

  // ============================================================
  // COLORS
  // ============================================================

  final Map<String, Color> letterColors = {
    'A': const Color(0xFFFF6FAE),
    'B': const Color(0xFF8D7CFF),
    'C': const Color(0xFF4FC3F7),
    'D': const Color(0xFFFFB84D),
    'E': const Color(0xFF66D9A0),
    'F': const Color(0xFFFF8A80),
    'G': const Color(0xFFAB8CFF),
    'H': const Color(0xFF4DD0D0),
    'I': const Color(0xFFFF8FCB),
    'J': const Color(0xFF6CA8FF),
    'K': const Color(0xFFFFCA5C),
    'L': const Color(0xFF6FE0AE),
    'M': const Color(0xFFFF95AC),
    'N': const Color(0xFF8B93FF),
    'O': const Color(0xFFFFA45B),
    'P': const Color(0xFF5CC8FF),
    'Q': const Color(0xFFC08BFF),
    'R': const Color(0xFF63D6B0),
    'S': const Color(0xFFFF7BA8),
    'T': const Color(0xFF5DABFF),
    'U': const Color(0xFFFFC966),
    'V': const Color(0xFF9B8FFF),
    'W': const Color(0xFF6BDDAA),
    'X': const Color(0xFFFF8C8C),
    'Y': const Color(0xFF6FBEFF),
    'Z': const Color(0xFFC08BFF),
  };

  // ============================================================
  // GAME START
  // ============================================================

  void startNewGame() {
    score = 0;
    startLevel(1);
  }

  void startLevel(int levelNumber) {
    currentLevel = getLevel(levelNumber);
    _configureDifficulty(levelNumber);

    bubbles.clear();
    flyingBubble = null;
    _lastHitBubble = null;
    flyingPops.clear();
    collectedLetters.clear();
    fallingBubbles.clear();
    _fallSpeeds.clear();
    _fallDelays.clear();
    _scrollOffset = 0;
    _scrollRemaining = 0;
    lockHits.clear();
    stoneIds.clear();
    iceIds.clear();
    hiddenIds.clear();
    bombIds.clear();
    wildIds.clear();

    velocityX = 0;
    velocityY = 0;

    shooting = false;
    levelComplete = false;
    gameOver = false;

    shotsUsed = 0;
    _shotQueueIndex = 0;
    _shotQueue = _generateShotQueue(max(30, currentLevel!.maxShots * 2));

    completedWords.clear();

    foundWord = null;
    wordMessageTimer = 0;
    toastMessage = null;
    _toastTimer = 0;
    _lockedStars = null;
    _winPending = false;
    bonusShotsLeft = 0;
    bonusShots.clear();

    if (levelNumber == 1) {
      _createLevelOne();
    } else {
      _createPatternLevel(currentLevel!);
    }
  }

  // ============================================================
  // BOARDS
  // ============================================================

  void _createLevelOne() {
    const List<List<String>> board = [
      ['P', 'B', 'I', 'N', 'U'],
      ['E', 'R', 'L', 'M', 'S', 'H'],
      ['W', 'K', 'N', 'U'],
    ];

    for (int row = 0; row < board.length; row++) {
      _addRow(board[row], row);
    }
  }

  // ------------------------------------------------------------
  // PATTERN BOARDS (tall - they scroll down as you clear them)
  // '#' = bubble, '.' = empty. Every row is exactly 6 characters.
  // Odd rows are shifted half a bubble to the right (hex grid).
  // Every pattern is connected to its top row, so nothing falls
  // at the start of a level. Only the bottom [visibleRows] rows
  // show at first; the rest slide in from above.
  // ------------------------------------------------------------
  static const List<List<String>> _patterns = [
    // Keyhole
    [
      '..##..',
      '.####.',
      '##..##',
      '#....#',
      '##..##',
      '.####.',
      '..###.',
      '..##..',
      '..###.',
      '..##..',
      '..###.',
    ],
    // Hourglass
    [
      '######',
      '.####.',
      '..##..',
      '..##..',
      '..##..',
      '..##..',
      '.####.',
      '.####.',
      '######',
    ],
    // Big diamond
    [
      '..##..',
      '.####.',
      '######',
      '######',
      '.####.',
      '.####.',
      '..##..',
      '..##..',
      '..#...',
    ],
    // Snake
    [
      '######',
      '#.....',
      '##....',
      '.##...',
      '..##..',
      '...##.',
      '....##',
      '...##.',
      '..##..',
      '.##...',
      '##....',
    ],
    // Pillars
    [
      '######',
      '##..##',
      '##..##',
      '##..##',
      '##..##',
      '##..##',
      '##..##',
      '######',
    ],
    // Tall ring
    [
      '.####.',
      '##..##',
      '#....#',
      '##..##',
      '.####.',
      '..##..',
      '..##..',
      '..##..',
    ],
    // Funnel
    [
      '######',
      '######',
      '.####.',
      '.####.',
      '..##..',
      '..##..',
      '...#..',
      '..#...',
      '..#...',
    ],
    // Chevron
    [
      '######',
      '.#####',
      '..####',
      '...###',
      '....##',
      '.....#',
      '....##',
      '...###',
      '..####',
      '.#####',
      '######',
    ],
  ];

  void _createPatternLevel(GameLevel level) {
    final List<String> source = List<String>.from(level.letters)
      ..shuffle(Random());

    if (source.isEmpty) return;

    final List<String> pattern =
        _patterns[(level.number * 5 + 1) % _patterns.length];

    // Tall pattern: push the top rows above the screen so only the
    // bottom [visibleRows] rows are showing.
    final int hiddenRows = max(0, pattern.length - visibleRows);
    _scrollOffset = -hiddenRows * verticalSpacing;

    int index = 0;

    for (int row = 0; row < pattern.length; row++) {
      for (int col = 0; col < pattern[row].length; col++) {
        if (pattern[row][col] != '#') continue;
        _addBubbleAt(source[index % source.length], row, col);
        index++;
      }
    }

    _applyObstacles(level.number);
  }

  // ------------------------------------------------------------
  // DIFFICULTY - what each level gets (all 2000 levels)
  // ------------------------------------------------------------
  // What arrives when (see the level blueprint):
  //   15  lock        31 stone + limited swaps     61 hidden letter + falling board
  //   201 ice         401 wildcard + timer         701 bomb
  int _lockCountFor(int n) {
    if (n < 15) return 0;
    if (n <= 60) return 1;
    if (n <= 200) return 2;
    if (n <= 600) return 3;
    if (n <= 1000) return 4;
    return 5;
  }

  int _stoneCountFor(int n) {
    if (n <= 30) return 0;
    if (n <= 200) return 1;
    if (n <= 400) return 2;
    if (n <= 700) return 3;
    if (n <= 1100) return 4;
    return 5;
  }

  int _hiddenCountFor(int n) {
    if (n < 61) return 0;
    if (n <= 200) return 1;
    if (n <= 500) return 2;
    if (n <= 1000) return 3;
    return 4;
  }

  int _iceCountFor(int n) {
    if (n < 201) return 0;
    if (n < 500) return 1;
    if (n < 900) return 2;
    if (n < 1300) return 3;
    return 4;
  }

  /// Helper: every second level from 701.
  int _bombCountFor(int n) {
    if (n < 701 || n.isOdd) return 0;
    return n < 1201 ? 1 : 2;
  }

  /// Helper: every 5th level from 400.
  int _wildCountFor(int n) {
    if (n < 401 || n % 5 != 0) return 0;
    return n < 1201 ? 1 : 2;
  }

  /// Swaps allowed per level (-1 = unlimited).
  int _swapLimitFor(int n) {
    if (n <= 30) return -1;
    if (n <= 100) return 20;
    if (n <= 300) return 12;
    if (n <= 600) return 9;
    if (n <= 1000) return 7;
    if (n <= 1500) return 5;
    return 3;
  }

  /// Seconds for the whole level, 0 = no timer.
  double _timeLimitFor(int n, int wordCount) {
    final bool timed = (n >= 400 && n % 10 == 0) || (n >= 1100 && n % 5 == 0);
    return timed ? 40.0 + wordCount * 30.0 : 0;
  }

  /// The board drops one row every N shots (0 = never).
  /// Only every third level, starting at level 61.
  int _descendEveryFor(int n) {
    if (n < 61 || n % 3 != 0) return 0;
    if (n < 600) return 16;
    if (n < 1200) return 12;
    if (n < 1700) return 10;
    return 9;
  }

  /// "Breather" levels: after a few hard ones the player gets an easier
  /// one (levels 35, 45, 55 ...): half the obstacles, no timer, no drop.
  bool _isBreather(int n) => n > 30 && n % 10 == 5;

  /// Shooter letters: how scarce vowels are.
  int _poolTierFor(int n) {
    if (n <= 30) return 0;
    if (n <= 200) return 1;
    if (n <= 700) return 2;
    return 3;
  }

  void _configureDifficulty(int n) {
    final int wordCount = currentLevel?.words.length ?? 1;

    _poolTier = _poolTierFor(n);
    swapsLeft = _swapLimitFor(n);
    descendEvery = _isBreather(n) ? 0 : _descendEveryFor(n);
    _shotsSinceDescend = 0;

    timeLimit = _isBreather(n) ? 0 : _timeLimitFor(n, wordCount);
    timeLeft = timeLimit;
    timeUp = false;
    _lastTick = null;
  }

  Bubble _replaceBubble(Bubble old, String letter, Color color) {
    final Bubble fresh = Bubble(
      x: old.x,
      y: old.y,
      letter: letter,
      color: color,
      radius: bubbleRadius,
    );
    bubbles[bubbles.indexOf(old)] = fresh;
    return fresh;
  }

  void _applyObstacles(int n) {
    lockHits.clear();
    stoneIds.clear();
    iceIds.clear();
    hiddenIds.clear();
    bombIds.clear();
    wildIds.clear();

    // Seeded: level N always gets the same obstacles.
    final Random rnd = Random(n * 31 + 7);

    // breather levels get half the obstacles
    int cut(int v) => _isBreather(n) ? v ~/ 2 : v;

    // Never the top row.
    final double firstRowLimit =
        _topRowY + _scrollOffset + verticalSpacing * 0.5;

    final List<Bubble> candidates =
        bubbles.where((b) => b.y > firstRowLimit).toList()..shuffle(rnd);

    // Never more than half the board is special.
    final int cap = (candidates.length * 0.5).floor();
    int i = 0;

    bool hasRoom() => i < candidates.length && i < cap;

    // helpers first, so they always get a slot
    for (int k = 0; k < _wildCountFor(n) && hasRoom(); k++, i++) {
      final Bubble w = _replaceBubble(
        candidates[i],
        '*',
        const Color(0xFFFFC857),
      );
      wildIds.add(w.id);
    }
    for (int k = 0; k < _bombCountFor(n) && hasRoom(); k++, i++) {
      bombIds.add(candidates[i].id);
    }
    for (int k = 0; k < cut(_stoneCountFor(n)) && hasRoom(); k++, i++) {
      final Bubble st = _replaceBubble(
        candidates[i],
        '#',
        const Color(0xFF7D8491),
      );
      stoneIds.add(st.id);
    }
    for (int k = 0; k < cut(_lockCountFor(n)) && hasRoom(); k++, i++) {
      lockHits[candidates[i].id] = lockStrength;
    }
    for (int k = 0; k < cut(_iceCountFor(n)) && hasRoom(); k++, i++) {
      iceIds.add(candidates[i].id);
    }
    for (int k = 0; k < cut(_hiddenCountFor(n)) && hasRoom(); k++, i++) {
      hiddenIds.add(candidates[i].id);
    }
  }

  /// True while a bubble can't be used in a word.
  bool _blocked(Bubble b) =>
      stoneIds.contains(b.id) ||
      lockHits.containsKey(b.id) ||
      iceIds.contains(b.id) ||
      hiddenIds.contains(b.id);

  void _forgetBubble(int id) {
    lockHits.remove(id);
    stoneIds.remove(id);
    iceIds.remove(id);
    hiddenIds.remove(id);
    bombIds.remove(id);
    wildIds.remove(id);
  }

  void _addBubbleAt(String letter, int row, int col) {
    const int gridCols = 6;
    final double h = horizontalSpacing;

    final double gridLeft = 0.5 - ((gridCols - 1) * h + h / 2) / 2;
    final double y = _topRowY + row * verticalSpacing + _scrollOffset;
    final double rowShift = row.isOdd ? h / 2 : 0;
    final double x = gridLeft + col * h + rowShift;

    bubbles.add(
      Bubble(
        x: x,
        y: y,
        letter: letter,
        color: _colorForLetter(letter),
        radius: bubbleRadius,
      ),
    );
  }

  void _addRow(List<String> letters, int row) {
    if (letters.isEmpty) return;

    const int gridCols = 6;
    final double h = horizontalSpacing;

    // One shared hex grid for every row.
    final double gridLeft = 0.5 - ((gridCols - 1) * h + h / 2) / 2;
    final int colOffset = ((gridCols - letters.length) / 2).floor();

    final double y = _topRowY + row * verticalSpacing;
    final double rowShift = row.isOdd ? h / 2 : 0;

    for (int i = 0; i < letters.length; i++) {
      final double x = gridLeft + (colOffset + i) * h + rowShift;

      bubbles.add(
        Bubble(
          x: x,
          y: y,
          letter: letters[i],
          color: _colorForLetter(letters[i]),
          radius: bubbleRadius,
        ),
      );
    }
  }

  Color _colorForLetter(String letter) {
    return letterColors[letter.toUpperCase()] ?? const Color(0xFF7E8CFF);
  }

  // ============================================================
  // SHOT QUEUE - vowel-friendly random letters
  // ============================================================

  static const List<String> _pools = [
    // 0 friendly
    'EEEEEEEEEEEEAAAAAAAAAIIIIIIIIIOOOOOOOONNNNNNRRRRRRTTTTTTLLLLSSSSUUUUDDDDGGGBBCCMMPPFFHHVVWWYYKJXQZ',
    // 1 fewer vowels
    'EEEEEEEEAAAAAAIIIIIIOOOOONNNNNNRRRRRRTTTTTTLLLLSSSSSUUUDDDDGGGBBCCMMPPFFHHVVWWYYKJXQZ',
    // 2 even fewer
    'EEEEEEAAAAAIIIIOOOOUUNNNNNNRRRRRRTTTTTTLLLLLSSSSSDDDDDGGGGBBBCCCMMMPPPFFHHHVVWWYYKJXQZ',
    // 3 consonant heavy
    'EEEEEAAAAIIIIOOOUUNNNNNNRRRRRRTTTTTTLLLLLSSSSSDDDDDGGGGBBBBCCCCMMMMPPPPFFFHHHVVWWYYKKJJXXQZZ',
  ];

  List<String> _generateShotQueue(int minLength) {
    final String pool = _pools[_poolTier.clamp(0, _pools.length - 1)];
    final Random rnd = Random();
    return List.generate(
      max(minLength, 30),
      (_) => pool[rnd.nextInt(pool.length)],
    );
  }

  void _ensureShotQueueHas(int index) {
    while (index >= _shotQueue.length) {
      _shotQueue.addAll(_generateShotQueue(20));
    }
  }

  // ============================================================
  // NEXT LETTER / PREVIEW
  // ============================================================

  String getNextLetter() {
    if (currentLevel == null) return 'C';

    _ensureShotQueueHas(_shotQueueIndex);

    final String letter = _shotQueue[_shotQueueIndex];
    _shotQueueIndex++;
    return letter;
  }

  String getNextLetterPreview() => _previewAt(0);

  String getLetterAfterNextPreview() => _previewAt(1);

  String _previewAt(int lookahead) {
    if (currentLevel == null) return 'C';

    final int index = _shotQueueIndex + lookahead;
    _ensureShotQueueHas(index);
    return _shotQueue[index];
  }

  /// Swaps the ball about to be fired with the one right after it.
  bool swapNextTwo() {
    if (shooting ||
        levelComplete ||
        gameOver ||
        goalReached ||
        currentLevel == null) {
      return false;
    }
    if (swapsLeft == 0) return false;

    _ensureShotQueueHas(_shotQueueIndex + 1);

    final String temp = _shotQueue[_shotQueueIndex];
    _shotQueue[_shotQueueIndex] = _shotQueue[_shotQueueIndex + 1];
    _shotQueue[_shotQueueIndex + 1] = temp;

    if (swapsLeft > 0) swapsLeft--;
    return true;
  }

  // ============================================================
  // SHOOT (simulate once, replay exactly)
  // ============================================================
  List<Offset> _flightPath = const [];
  int _flightSeg = 0;
  double _flightDone = 0;
  Offset? _flightLanding;
  Bubble? _flightHit;

  /// Path (normalized coords) the shot will take, ending at the
  /// exact slot where the bubble will land.
  ({List<Offset> path, Offset? landing, Bubble? hit}) previewShot({
    required String letter,
    required double startX,
    required double startY,
    required double targetX,
    required double targetY,
  }) {
    final double a = _aspect;

    double px = startX, py = startY / a;
    double dx = targetX - startX;
    double dy = (targetY - startY) / a;
    final double len = sqrt(dx * dx + dy * dy);
    if (len < 1e-6) {
      dx = 0;
      dy = -1;
    } else {
      dx /= len;
      dy /= len;
    }
    if (dy > -0.05) {
      dy = -0.05;
      final double m = sqrt(1 - dy * dy);
      dx = dx < 0 ? -m : m;
    }

    final double lo = bubbleRadius, hi = 1 - bubbleRadius;
    final double ceilY = _ceilingY / a;
    final double R = bubbleRadius * 2;

    final List<Offset> pts = [Offset(px, py)];
    Bubble? hit;

    for (int bounce = 0; bounce < 10; bounce++) {
      double tWall = double.infinity;
      if (dx > 1e-9) tWall = (hi - px) / dx;
      if (dx < -1e-9) tWall = (lo - px) / dx;
      if (tWall < 0) tWall = 0;

      double tCeil = (ceilY - py) / dy;
      if (tCeil < 0) tCeil = 0;

      double tBub = double.infinity;
      Bubble? bubHit;
      for (final Bubble b in bubbles) {
        final double fx = b.x - px;
        final double fy = b.y / a - py;
        final double proj = fx * dx + fy * dy;
        if (proj <= 0) continue;
        final double perp2 = fx * fx + fy * fy - proj * proj;
        if (perp2 > R * R) continue;
        double th = proj - sqrt(R * R - perp2);
        if (th < 0) th = 0;
        if (th < tBub) {
          tBub = th;
          bubHit = b;
        }
      }

      final double t = min(tWall, min(tCeil, tBub));
      px += dx * t;
      py += dy * t;
      pts.add(Offset(px, py));

      if (t == tBub) {
        hit = bubHit;
        break;
      }
      if (t == tCeil) break;
      dx = -dx;
    }

    final List<Offset> path = pts.map((p) => Offset(p.dx, p.dy * a)).toList();

    final Offset end = path.last;
    final Bubble temp = Bubble(
      x: end.dx,
      y: end.dy,
      letter: letter,
      color: _colorForLetter(letter),
      radius: bubbleRadius,
    );
    final Bubble? saved = _lastHitBubble;
    _lastHitBubble = hit;
    final Offset? landing = _findSnapPosition(temp);
    _lastHitBubble = saved;

    if (landing != null) path.add(landing);
    return (path: path, landing: landing, hit: hit);
  }

  void shoot({
    required String letter,
    required double startX,
    required double startY,
    required double targetX,
    required double targetY,
  }) {
    if (shooting || levelComplete || gameOver || currentLevel == null) return;
    if (isScrolling || goalReached) return;

    final plan = previewShot(
      letter: letter,
      startX: startX,
      startY: startY,
      targetX: targetX,
      targetY: targetY,
    );
    _flightPath = plan.path;
    _flightLanding = plan.landing;
    _flightHit = plan.hit;
    _flightSeg = 0;
    _flightDone = 0;

    debugPrint('PLANNED ${plan.landing}');

    shooting = true;
    flyingBubble = Bubble(
      x: startX,
      y: startY,
      letter: letter,
      color: _colorForLetter(letter),
      radius: bubbleRadius,
    );
  }

  // ============================================================
  // UPDATE
  // ============================================================
  void update() {
    _updateTimer();
    _updatePopAnimation();
    _updateFalling();
    _updateScroll();
    _updateWin();
    _updateBonusShots();

    if (_toastTimer > 0) {
      _toastTimer -= 0.016;
      if (_toastTimer <= 0) {
        _toastTimer = 0;
        toastMessage = null;
      }
    }

    if (wordMessageTimer > 0) {
      wordMessageTimer -= 0.016;
      if (wordMessageTimer <= 0) {
        wordMessageTimer = 0;
        foundWord = null;
      }
    }

    if (!shooting || flyingBubble == null) return;

    // Shot speed (physical distance per frame). Higher = faster.
    double remaining = 0.07;
    while (remaining > 0 && _flightSeg < _flightPath.length - 1) {
      final Offset a = _flightPath[_flightSeg];
      final Offset b = _flightPath[_flightSeg + 1];
      final double left =
          _physicalDistance(b.dx - a.dx, b.dy - a.dy) - _flightDone;
      if (remaining < left) {
        _flightDone += remaining;
        remaining = 0;
      } else {
        remaining -= left;
        _flightSeg++;
        _flightDone = 0;
      }
    }

    if (_flightSeg >= _flightPath.length - 1) {
      final Offset end = _flightPath.last;
      flyingBubble!.x = end.dx;
      flyingBubble!.y = end.dy;
      _lastHitBubble = _flightHit;
      _attachFlyingBubble(snapOverride: _flightLanding);
      return;
    }

    final Offset a = _flightPath[_flightSeg];
    final Offset b = _flightPath[_flightSeg + 1];
    final double segLen = _physicalDistance(b.dx - a.dx, b.dy - a.dy);
    final double t = segLen == 0 ? 0 : _flightDone / segLen;
    flyingBubble!.x = a.dx + (b.dx - a.dx) * t;
    flyingBubble!.y = a.dy + (b.dy - a.dy) * t;
  }

  void _attachFlyingBubble({Offset? snapOverride}) {
    final Bubble? shot = flyingBubble;
    if (shot == null) return;

    final Offset? snap = snapOverride ?? _findSnapPosition(shot);

    if (snap == null) {
      shooting = false;
      flyingBubble = null;
      return;
    }

    shot.x = snap.dx;
    shot.y = snap.dy;
    debugPrint('ACTUAL $snap');

    bubbles.add(shot);

    flyingBubble = null;
    shooting = false;
    shotsUsed++;

    if (descendEvery > 0) {
      _shotsSinceDescend++;
      if (_shotsSinceDescend >= descendEvery) {
        _shotsSinceDescend = 0;
        _scrollRemaining += verticalSpacing; // board drops one row
      }
    }

    _registerLockHits(shot);

    if (_anyBubbleTooLow()) {
      gameOver = true;
      return;
    }

    _checkForWords(shot);
  }

  bool _anyBubbleTooLow() {
    for (final Bubble bubble in bubbles) {
      if (bubble.y + bubble.radius >= dangerLineY) return true;
    }
    return false;
  }

  // ============================================================
  // SNAP TO GRID
  // ============================================================

  Offset? _findSnapPosition(Bubble flying) {
    if (bubbles.isEmpty) {
      return Offset(flying.x.clamp(bubbleRadius, 1 - bubbleRadius), _topRowY);
    }

    final double vSpace = verticalSpacing;

    final List<Offset> directions = [
      Offset(horizontalSpacing, 0),
      Offset(-horizontalSpacing, 0),
      Offset(horizontalSpacing / 2, vSpace),
      Offset(-horizontalSpacing / 2, vSpace),
      Offset(horizontalSpacing / 2, -vSpace),
      Offset(-horizontalSpacing / 2, -vSpace),
    ];

    Offset? searchAround(Iterable<Bubble> candidates) {
      Offset? bestPosition;
      double bestDistance = double.infinity;

      for (final Bubble bubble in candidates) {
        for (final Offset direction in directions) {
          final double x = bubble.x + direction.dx;
          final double y = bubble.y + direction.dy;
          if (x - bubbleRadius < 0 ||
              x + bubbleRadius > 1 ||
              y < _ceilingY - 0.001 ||
              y + bubbleRadius > dangerLineY + 0.02) {
            continue;
          }

          if (!_positionIsFree(x, y)) continue;

          final double distance = _physicalDistance(flying.x - x, flying.y - y);

          if (distance < bestDistance) {
            bestDistance = distance;
            bestPosition = Offset(x, y);
          }
        }
      }

      return bestPosition;
    }

    // First: slots next to the bubble the shot actually hit.
    if (_lastHitBubble != null) {
      final Offset? nearHit = searchAround([_lastHitBubble!]);
      if (nearHit != null) return nearHit;
    }

    // Fallback: nearest free slot anywhere on the board.
    return searchAround(bubbles);
  }

  bool _positionIsFree(double x, double y) {
    for (final Bubble bubble in bubbles) {
      final double distance = _physicalDistance(bubble.x - x, bubble.y - y);

      if (distance < horizontalSpacing * 0.80) return false;
    }
    return true;
  }

  // ============================================================
  // WORD CHECK - any dictionary word that includes the bubble you
  // just shot, formed by a connected chain of touching bubbles.
  // Word length must be inside the level's allowed range
  // (lengthRangeFor in levels.dart).
  // ============================================================

  void _checkForWords(Bubble shot) {
    if (currentLevel == null || _dictionary.isEmpty) {
      _checkGameOver();
      return;
    }

    // CHANGED: only words whose length is inside this level's range.
    final List<int> lenRange = lengthRangeFor(currentLevel!.number);
    final int minLen = lenRange[0];
    final int maxLen = lenRange[1];

    List<Bubble> best = [];
    String bestWord = '';
    String? tooShortWord; // a real word, but too short for this level
    String? repeatedWord; // a real word that was already found
    final List<Bubble> path = [];
    final Set<int> used = {};

    void dfs(Bubble current, String text) {
      // stones, locks, ice and hidden letters can't be used yet
      if (_blocked(current)) return;

      path.add(current);
      used.add(current.id);

      final List<String> options = wildIds.contains(current.id)
          ? _alphabet
          : [current.letter.toUpperCase()];

      for (final String ch in options) {
        final String next = text + ch;

        // Stop early if no dictionary word starts with this text.
        if (!_prefixes.contains(next)) continue;

        if (next.length >= minLen &&
            next.length <= maxLen &&
            _dictionary.contains(next) &&
            !completedWords.contains(next) && // every word counts once
            path.any((b) => b.id == shot.id) &&
            next.length > bestWord.length) {
          bestWord = next;
          best = List<Bubble>.from(path);
        }

        // real words that don't count: tell the player why
        if (_dictionary.contains(next) &&
            next.length >= minWordLength &&
            path.any((b) => b.id == shot.id)) {
          if (next.length < minLen) {
            if (tooShortWord == null || next.length > tooShortWord!.length) {
              tooShortWord = next;
            }
          }
          if (next.length >= minLen && completedWords.contains(next)) {
            repeatedWord ??= next;
          }
        }

        if (next.length < maxLen) {
          for (final Bubble n in _getNeighbors(current)) {
            if (!used.contains(n.id) && _isOnScreen(n)) dfs(n, next);
          }
        }
      }

      path.removeLast();
      used.remove(current.id);
    }

    for (final Bubble b in List<Bubble>.from(bubbles)) {
      if (_isOnScreen(b)) dfs(b, '');
    }

    if (best.isNotEmpty) {
      _popWord(bestWord, best);
    } else if (tooShortWord != null) {
      _showToast('$tooShortWord is too short — use $lengthRuleText');
    } else if (repeatedWord != null) {
      _showToast('$repeatedWord is already found');
    }
    _checkGameOver();
  }

  List<Bubble> _getNeighbors(Bubble source) {
    final List<Bubble> neighbors = [];

    for (final Bubble bubble in bubbles) {
      if (bubble.id == source.id) continue;

      final double distance = _physicalDistance(
        bubble.x - source.x,
        bubble.y - source.y,
      );

      if (distance <= horizontalSpacing * 1.30) {
        neighbors.add(bubble);
      }
    }

    return neighbors;
  }

  // ============================================================
  // POP WORD
  // ============================================================

  void _popWord(String word, List<Bubble> matched) {
    completedWords.add(word);
    foundWord = word;
    wordMessageTimer = 1.2;
    score += word.length * 50;

    for (int mi = 0; mi < matched.length; mi++) {
      final Bubble bubble = matched[mi];
      flyingPops.add(
        FlyingPopBubble(
          letter: word[mi],
          color: bubble.color,
          startX: bubble.x,
          startY: bubble.y,
        ),
      );
      collectedLetters.add(word[mi]);
      bubbles.removeWhere((b) => b.id == bubble.id);
    }

    _explodeBombs(matched);
    _breakStonesNextTo(matched);
    _dropFloatingBubbles();
    _requestScroll();

    // Last word found: everything left on the board falls away.
    if (goalReached) _cascadeBoard();
  }

  void _updatePopAnimation() {
    if (flyingPops.isEmpty) return;

    for (final FlyingPopBubble fp in List<FlyingPopBubble>.from(flyingPops)) {
      fp.progress += 0.045;
      if (fp.progress >= 1) {
        flyingPops.remove(fp);
      }
    }
  }

  // ============================================================
  // OBSTACLE RULES
  // ============================================================

  void _burst(Bubble b, Color color, String letter) {
    flyingPops.add(
      FlyingPopBubble(
        letter: letter.isEmpty ? 'X' : letter,
        color: color,
        startX: b.x,
        startY: b.y,
      ),
    );
  }

  /// A shot that lands next to a locked bubble takes one hit off it,
  /// and reveals hidden letters.
  void _registerLockHits(Bubble shot) {
    if (lockHits.isEmpty && hiddenIds.isEmpty) return;

    for (final Bubble n in _getNeighbors(shot)) {
      if (hiddenIds.remove(n.id)) {
        score += 10;
        _burst(n, const Color(0xFF8D7CFF), n.letter);
      }

      final int? left = lockHits[n.id];
      if (left == null) continue;

      if (left <= 1) {
        lockHits.remove(n.id); // unlocked!
        score += 30;
        _burst(n, Colors.white, n.letter);
      } else {
        lockHits[n.id] = left - 1;
      }
    }
  }

  /// Every bomb inside a popped word also pops all of its neighbours.
  void _explodeBombs(List<Bubble> matched) {
    if (bombIds.isEmpty) return;

    final Set<int> matchedIds = matched.map((m) => m.id).toSet();
    final Map<int, Bubble> victims = {};

    for (final Bubble m in matched) {
      if (!bombIds.contains(m.id)) continue;
      for (final Bubble n in _getNeighbors(m)) {
        if (!matchedIds.contains(n.id)) victims[n.id] = n;
      }
    }

    for (final Bubble v in victims.values) {
      final bool isStone = stoneIds.contains(v.id);
      bubbles.removeWhere((x) => x.id == v.id);
      _forgetBubble(v.id);
      score += 25;
      if (!isStone) collectedLetters.add(v.letter);
      _burst(v, const Color(0xFFFF8A3D), v.letter);
    }
  }

  /// Stones next to a popped word break; ice next to it melts.
  void _breakStonesNextTo(List<Bubble> matched) {
    if (stoneIds.isEmpty && iceIds.isEmpty) return;

    final List<Bubble> broken = [];
    final List<Bubble> melted = [];

    for (final Bubble b in bubbles) {
      final bool stone = stoneIds.contains(b.id);
      final bool ice = iceIds.contains(b.id);
      if (!stone && !ice) continue;

      for (final Bubble m in matched) {
        final double d = _physicalDistance(b.x - m.x, b.y - m.y);
        if (d <= horizontalSpacing * 1.30) {
          if (stone) broken.add(b);
          if (ice) melted.add(b);
          break;
        }
      }
    }

    for (final Bubble b in broken) {
      bubbles.removeWhere((x) => x.id == b.id);
      stoneIds.remove(b.id);
      score += 40;
      _burst(b, const Color(0xFF9AA1AD), 'S');
    }

    for (final Bubble b in melted) {
      iceIds.remove(b.id); // letter is usable now
      score += 20;
      _burst(b, const Color(0xFF9EE4FF), b.letter);
    }
  }

  // ============================================================
  // GRAVITY - bubbles no longer connected to the top row fall
  // ============================================================

  void _dropFloatingBubbles() {
    if (bubbles.isEmpty) return;

    // Anything at (or above) the first row counts as attached.
    final double anchorY = _topRowY + _scrollOffset + verticalSpacing * 0.5;

    final Set<int> connected = {};
    final List<Bubble> queue = [];

    for (final Bubble b in bubbles) {
      if (b.y <= anchorY) {
        connected.add(b.id);
        queue.add(b);
      }
    }

    while (queue.isNotEmpty) {
      final Bubble current = queue.removeLast();
      for (final Bubble n in _getNeighbors(current)) {
        if (connected.add(n.id)) queue.add(n);
      }
    }

    final List<Bubble> floating = bubbles
        .where((b) => !connected.contains(b.id))
        .toList();

    for (final Bubble b in floating) {
      bubbles.removeWhere((x) => x.id == b.id);
      fallingBubbles.add(b);
      _fallSpeeds[b.id] = 0.004;
      score += 20; // bonus for every bubble that drops
    }
  }

  /// Level won: every bubble still on the board drops (lowest first),
  /// each one worth bonus points, plus a bonus for unused shots.
  void _cascadeBoard() {
    _scrollRemaining = 0;

    final List<Bubble> rest = List<Bubble>.from(bubbles)
      ..sort((a, b) => b.y.compareTo(a.y)); // lowest first

    int rank = 0;
    for (final Bubble b in rest) {
      bubbles.removeWhere((x) => x.id == b.id);
      fallingBubbles.add(b);
      _fallSpeeds[b.id] = -0.010; // a little hop up, then it falls
      _fallDelays[b.id] = min(rank * 2, 40);
      if (!stoneIds.contains(b.id)) score += 15;
      rank++;
    }

    // Stars are decided NOW, before the leftover shots are spent.
    _lockedStars = _computeStars();

    // Leftover shots fly out of the ring one by one (see _updateWin).
    bonusShotsLeft = max(0, (currentLevel?.maxShots ?? 0) - shotsUsed);
    _bonusInterval = (2.4 / max(1, bonusShotsLeft))
        .clamp(0.035, 0.12)
        .toDouble();
    _bonusTimer = 0;
    _winWait = 1.0; // let the board finish falling first
    _winPending = true;
  }

  /// Win sequence: board falls -> leftover shots leave the ring one by
  /// one (+points each) -> the result card appears.
  void _updateWin() {
    if (!_winPending) return;

    if (_winWait > 0) {
      _winWait -= 0.016;
      return;
    }

    if (bonusShotsLeft > 0) {
      _bonusTimer -= 0.016;
      if (_bonusTimer <= 0) {
        _bonusTimer = _bonusInterval;
        _emitBonusShot();
      }
      return;
    }

    // wait until the last flying bubble has finished
    if (bonusShots.isNotEmpty) return;

    _winPending = false;
    levelComplete = true;
  }

  void _emitBonusShot() {
    final String letter = getNextLetter();

    bonusShots.add(
      BonusShotBubble(
        letter: letter,
        color: _colorForLetter(letter),
        startX: 0.5,
        startY: 0.80,
        endX: 0.12 + _bonusRnd.nextDouble() * 0.76,
        endY: 0.20 + _bonusRnd.nextDouble() * 0.32,
        points: pointsPerLeftoverShot,
      ),
    );

    shotsUsed++; // the number in the ring counts down
    bonusShotsLeft--;
    score += pointsPerLeftoverShot;
  }

  void _updateBonusShots() {
    if (bonusShots.isEmpty) return;

    for (final BonusShotBubble b in List<BonusShotBubble>.from(bonusShots)) {
      b.progress += 0.032;
      if (b.progress >= 1) bonusShots.remove(b);
    }
  }

  void _updateFalling() {
    if (fallingBubbles.isEmpty) return;

    for (final Bubble b in List<Bubble>.from(fallingBubbles)) {
      final int wait = _fallDelays[b.id] ?? 0;
      if (wait > 0) {
        _fallDelays[b.id] = wait - 1;
        continue;
      }

      final double speed = (_fallSpeeds[b.id] ?? 0.004) + 0.002;
      _fallSpeeds[b.id] = speed;
      b.y += speed;

      if (b.y > 1.1) {
        fallingBubbles.remove(b);
        _fallSpeeds.remove(b.id);
      }
    }
  }

  // ============================================================
  // SCROLL - upper rows slide down when the bottom gets cleared
  // ============================================================

  /// Hidden rows above the screen can't be used for words yet.
  bool _isOnScreen(Bubble b) => b.y >= _ceilingY - 0.01;

  void _requestScroll() {
    if (bubbles.isEmpty || _scrollOffset >= -0.001) return;

    double lowest = 0;
    for (final Bubble b in bubbles) {
      if (b.y > lowest) lowest = b.y;
    }

    // Keep the lowest bubble at the bottom visible row.
    final double targetBottom = _topRowY + verticalSpacing * (visibleRows - 1);

    // Never slide further than needed to reveal every hidden row.
    final double shift = min(targetBottom - lowest, -_scrollOffset);

    if (shift > 0.001) _scrollRemaining = max(_scrollRemaining, shift);
  }

  void _updateTimer() {
    if (timeLimit <= 0 || levelComplete || gameOver || goalReached) {
      _lastTick = null;
      return;
    }

    final DateTime now = DateTime.now();
    final DateTime? last = _lastTick;
    _lastTick = now;
    if (last == null) return;

    // clamp so a pause doesn't eat the clock
    final double dt = min(0.05, now.difference(last).inMicroseconds / 1e6);
    timeLeft -= dt;

    if (timeLeft <= 0) {
      timeLeft = 0;
      timeUp = true;
      gameOver = true;
    }
  }

  void _updateScroll() {
    if (_scrollRemaining <= 0) return;

    final double step = min(
      _scrollRemaining,
      max(0.004, _scrollRemaining * 0.12),
    );

    for (final Bubble b in bubbles) {
      b.y += step;
    }

    _scrollOffset += step;
    _scrollRemaining -= step;
    if (_scrollRemaining < 0.0005) _scrollRemaining = 0;

    // the board dropped onto the launcher
    if (!levelComplete && !gameOver && !goalReached && _anyBubbleTooLow()) {
      gameOver = true;
    }
  }

  double getBubbleScale(Bubble bubble) => 1;
  double getBubbleOpacity(Bubble bubble) => 1;

  void _checkGameOver() {
    if (currentLevel == null) return;

    // Level already completed - no Game Over.
    if (completedWords.length >= currentLevel!.words.length) return;

    // Any bubble in the danger zone near the launcher ends the game.
    const double dangerY = 0.78;

    for (final Bubble bubble in bubbles) {
      if (bubble.y + bubble.radius >= dangerY) {
        gameOver = true;
        return;
      }
    }

    // Out of shots.
    if (shotsUsed >= currentLevel!.maxShots) {
      gameOver = true;
    }
  }

  /// 1-3 stars based on how efficiently the level was cleared.
  int get starsEarned => _lockedStars ?? _computeStars();

  int _computeStars() {
    final GameLevel? level = currentLevel;
    if (level == null || level.maxShots == 0) return 3;

    final int required = level.totalRequiredLetters;
    final int slack = max(1, level.maxShots - required);
    final int shotsLeft = max(0, level.maxShots - shotsUsed);
    final double ratio = shotsLeft / slack;

    if (ratio >= 0.5) return 3;
    if (ratio >= 0.2) return 2;
    return 1;
  }

  void retryLevel() {
    final int levelNumber = currentLevel?.number ?? 1;
    startLevel(levelNumber);
  }

  void goToNextLevel() {
    final int currentNumber = currentLevel?.number ?? 1;
    final int nextNumber = currentNumber + 1;

    startLevel(nextNumber);
  }
}
