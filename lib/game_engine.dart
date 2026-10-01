import 'dart:math';
import 'package:flutter/material.dart';

import 'bubble.dart';
import 'levels.dart';

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

class GameEngine {
  // ============================================================
  // DICTIONARY (any real word pops, not only the level's words)
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
  double get _ceilingY => 0.12;

  final double dangerLineY = 0.86;

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

    bubbles.clear();
    flyingBubble = null;
    _lastHitBubble = null;
    flyingPops.clear();
    collectedLetters.clear();

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

    if (levelNumber == 1) {
      _createLevelOne();
    } else {
      _createGenericLevel(currentLevel!);
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

  void _createGenericLevel(GameLevel level) {
    final List<String> source = List<String>.from(level.letters)
      ..shuffle(Random());

    if (source.isEmpty) return;

    final bool expandedBoard = level.number <= expandedBoardLevelCap;
    final List<int> rowCounts = expandedBoard
        ? const [6, 6, 6, 6]
        : const [5, 6, 5];

    int index = 0;

    for (int row = 0; row < rowCounts.length; row++) {
      final int count = rowCounts[row];
      final List<String> rowLetters = [];

      for (int i = 0; i < count; i++) {
        rowLetters.add(source[index % source.length]);
        index++;
      }

      _addRow(rowLetters, row);
    }
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

  List<String> _generateShotQueue(int minLength) {
    const String pool =
        'EEEEEEEEEEEEAAAAAAAAAIIIIIIIIIOOOOOOOONNNNNNRRRRRRTTTTTTLLLLSSSSUUUUDDDDGGGBBCCMMPPFFHHVVWWYYKJXQZ';
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
  void swapNextTwo() {
    if (shooting || levelComplete || gameOver || currentLevel == null) return;

    _ensureShotQueueHas(_shotQueueIndex + 1);

    final String temp = _shotQueue[_shotQueueIndex];
    _shotQueue[_shotQueueIndex] = _shotQueue[_shotQueueIndex + 1];
    _shotQueue[_shotQueueIndex + 1] = temp;
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

    final List<Offset> path =
        pts.map((p) => Offset(p.dx, p.dy * a)).toList();

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
    _updatePopAnimation();

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
      return Offset(
        flying.x.clamp(bubbleRadius, 1 - bubbleRadius),
        _topRowY,
      );
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

          final double distance =
              _physicalDistance(flying.x - x, flying.y - y);

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
      final double distance =
          _physicalDistance(bubble.x - x, bubble.y - y);

      if (distance < horizontalSpacing * 0.80) return false;
    }
    return true;
  }

  // ============================================================
  // WORD CHECK - any dictionary word that includes the bubble you
  // just shot, formed by a connected chain of touching bubbles.
  // ============================================================

  void _checkForWords(Bubble shot) {
    if (currentLevel == null || _dictionary.isEmpty) {
      _checkGameOver();
      return;
    }

    List<Bubble> best = [];
    String bestWord = '';
    final List<Bubble> path = [];
    final Set<int> used = {};

    void dfs(Bubble current, String text) {
      path.add(current);
      used.add(current.id);

      final String next = text + current.letter.toUpperCase();

      // Stop early if no dictionary word starts with this text.
      if (_prefixes.contains(next)) {
        if (next.length >= minWordLength &&
            _dictionary.contains(next) &&
            path.any((b) => b.id == shot.id) &&
            next.length > bestWord.length) {
          bestWord = next;
          best = List<Bubble>.from(path);
        }
        if (next.length < maxWordLength) {
          for (final Bubble n in _getNeighbors(current)) {
            if (!used.contains(n.id)) dfs(n, next);
          }
        }
      }

      path.removeLast();
      used.remove(current.id);
    }

    for (final Bubble b in List<Bubble>.from(bubbles)) {
      dfs(b, '');
    }

    if (best.isNotEmpty) {
      _popWord(bestWord, best);
    }
    _checkGameOver();
  }

  List<Bubble> _getNeighbors(Bubble source) {
    final List<Bubble> neighbors = [];

    for (final Bubble bubble in bubbles) {
      if (bubble.id == source.id) continue;

      final double distance =
          _physicalDistance(bubble.x - source.x, bubble.y - source.y);

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

    for (final Bubble bubble in matched) {
      flyingPops.add(
        FlyingPopBubble(
          letter: bubble.letter,
          color: bubble.color,
          startX: bubble.x,
          startY: bubble.y,
        ),
      );
      collectedLetters.add(bubble.letter);
      bubbles.removeWhere((b) => b.id == bubble.id);
    }

    Future<void>.delayed(const Duration(milliseconds: 550), () {
      if (currentLevel != null &&
          completedWords.length >= currentLevel!.words.length) {
        levelComplete = true;
      }
    });
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
  int get starsEarned {
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