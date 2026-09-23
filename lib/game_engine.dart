import 'dart:math';
import 'package:flutter/material.dart';

import 'bubble.dart';
import 'levels.dart';

/// A bubble that has just popped and is animating toward the basket
/// at the bottom of the screen, purely for visual flair - it no
/// longer exists in `bubbles` / affects game logic.
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
  // BOARD
  // ============================================================

  final List<Bubble> bubbles = [];

  Bubble? flyingBubble;

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

  // Where popped bubbles fly to (normalized 0-1, same space as
  // bubble.x / bubble.y) - keep this in sync with wherever the UI
  // draws the basket icon.
  final double basketX = 0.13;
  final double basketY = 0.90;

  final List<FlyingPopBubble> flyingPops = [];
  final List<String> collectedLetters = [];

  final double bubbleRadius = 0.052;
  final double horizontalSpacing = 0.104;

  /// Everything - resting bubbles, the flying shot's collision
  /// ceiling, and the aim clamp in the UI - stays below this y so
  /// nothing is ever drawn on top of the hint box near the top of
  /// the screen.
  final double boardTopY = 0.16;

  double _aspect = 0.5;

  /// Exposed so the UI layer (aim-line preview) can do the same
  /// aspect-corrected geometry the engine itself uses.
  double get aspect => _aspect;

  void configureForScreen(Size size) {
    if (size.width > 0 && size.height > 0) {
      _aspect = size.width / size.height;
    }
  }

  double _physicalDistance(double dx, double dyHeightFraction) {
    final double dyPhysical = dyHeightFraction / _aspect;
    return sqrt(dx * dx + dyPhysical * dyPhysical);
  }

  double get verticalSpacing => horizontalSpacing * _aspect * 0.87;

  // ------------------------------------------------------------
  // Shot queue: replaces the old fixed/sequential letter order.
  // Letters are shuffled, every letter needed by the level shows
  // up 2-3 times (so a missed letter comes back around), and no
  // two consecutive shots either repeat a letter or spell out two
  // adjacent letters of a target word.
  // ------------------------------------------------------------
  List<String> _shotQueue = [];
  int _shotQueueIndex = 0;

  final List<String> completedWords = [];

  static const List<String> _fillerLetters = ['X', 'Z', 'Q', 'W', 'V', 'J'];

  /// Guided assist (auto-connecting a shot to the nearest in-progress
  /// word chain) is only given during the very first tutorial levels
  /// - just enough to teach the mechanic - not the whole learning
  /// window. From here on the player has to aim for real; hints and
  /// generous shot counts (see levels.dart) are what keep the early
  /// game easy, not the game secretly playing itself.
  static const int guidedAssistLevelCap = 2;

  /// Levels at or below this get a bigger board (more bubbles) since
  /// their words are short and otherwise the board would look sparse.
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

    _breakPreformedWords();
  }

  // ============================================================
  // LEVEL 1 BOARD - distractors only, C/A/T/D/O/G must be shot
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

    // Early levels (short, 1-2 word levels) get a bigger, fuller
    // board - 24 bubbles across 4 rows of 6 - instead of the
    // default 16, since a sparse board looks odd with such short
    // words. Later levels keep the original 3-row layout.
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

    final double rowWidth = (letters.length - 1) * horizontalSpacing;
    double startX = 0.5 - rowWidth / 2;

    // Rows start just below the hint box (boardTopY) and stack
    // downward, so bubbles never sit above/behind the hint text.
    final double y = boardTopY + 0.03 + row * verticalSpacing;
    final bool offsetRow = row.isOdd;

    for (int i = 0; i < letters.length; i++) {
      double x = startX + i * horizontalSpacing;
      if (offsetRow) x += horizontalSpacing / 2;

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

  void _breakPreformedWords() {
    if (currentLevel == null) return;

    int fillerIndex = 0;
    int safety = 0;
    bool changed = true;

    while (changed && safety < 50) {
      changed = false;
      safety++;

      for (final String word in currentLevel!.words) {
        for (final Bubble bubble in List<Bubble>.from(bubbles)) {
          if (bubble.letter != word[0]) continue;

          final List<Bubble> matched = _findWordFromBubble(bubble, word);

          if (matched.length == word.length) {
            final Bubble toChange = matched.last;
            final String filler =
                _fillerLetters[fillerIndex % _fillerLetters.length];
            fillerIndex++;

            toChange.letter = filler;
            toChange.color = _colorForLetter(filler);

            changed = true;
          }
        }
      }
    }
  }

  Color _colorForLetter(String letter) {
    return letterColors[letter.toUpperCase()] ?? const Color(0xFF7E8CFF);
  }

  // ============================================================
  // SHOT QUEUE - random letters, no obvious "auto-spell" order,
  // each needed letter repeated 2-3 times so a missed one comes
  // back around.
  // ============================================================

  /// Builds a shuffled queue biased heavily toward the letters the
  /// player actually needs to complete the words - distractor
  /// letters (present in `level.letters` but not in any word) are
  /// kept a clear minority so they can never drown out the letters
  /// the hint is asking for. Each needed letter's copy count scales
  /// with how many times it's required across all words (e.g. the
  /// two O's in "MOON"), plus extra redundancy so a miss is never
  /// fatal. Decluster-passed so it doesn't hand the player a word
  /// for free.
  List<String> _generateShotQueue(int minLength) {
    final GameLevel level = currentLevel!;
    final Random rnd = Random();

    // How many times each letter is actually required to spell out
    // every word in this level (summed, since words are solved one
    // after another and each needs its own bubbles).
    final Map<String, int> demand = {};
    for (final String word in level.words) {
      for (final String ch in word.split('')) {
        final String letter = ch.toUpperCase();
        demand[letter] = (demand[letter] ?? 0) + 1;
      }
    }

    final Set<String> wordLetters = demand.keys.toSet();
    final Set<String> distractors =
        level.letters.map((l) => l.toUpperCase()).toSet()
          ..removeAll(wordLetters);

    final List<String> pool = [];

    // Needed letters get generous, demand-scaled redundancy - they
    // dominate the pool so the player sees them constantly instead
    // of waiting for a lucky draw.
    demand.forEach((letter, count) {
      final int copies = (count * 6) + 5;
      for (int i = 0; i < copies; i++) {
        pool.add(letter);
      }
    });

    if (pool.isEmpty) return List<String>.filled(minLength, 'A');

    // Distractors are kept to a light sprinkle only - just enough
    // for a bit of variety, never enough to meaningfully compete
    // with the letters the player actually needs.
    final int distractorBudget = max(pool.length ~/ 6, 0);
    if (distractors.isNotEmpty) {
      final List<String> distractorList = distractors.toList();
      for (int i = 0; i < distractorBudget; i++) {
        pool.add(distractorList[i % distractorList.length]);
      }
    }

    final List<String> queue = [];
    while (queue.length < minLength) {
      final List<String> batch = List<String>.from(pool)..shuffle(rnd);
      queue.addAll(batch);
    }

    return _declusterQueue(queue, level.words);
  }

  /// Pushes apart any adjacent pair that would either repeat a
  /// letter or continue a word in sequence (e.g. C immediately
  /// followed by A when "CAT" is a target word) - so the player
  /// can never just fire a word in one uninterrupted burst.
  List<String> _declusterQueue(List<String> queue, List<String> words) {
    final Random rnd = Random();

    bool isBadPair(String a, String b) {
      if (a == b) return true;
      for (final String word in words) {
        for (int i = 0; i < word.length - 1; i++) {
          if (word[i] == a && word[i + 1] == b) return true;
        }
      }
      return false;
    }

    for (int i = 0; i < queue.length - 1; i++) {
      int attempts = 0;
      while (isBadPair(queue[i], queue[i + 1]) && attempts < 20) {
        final int span = queue.length - i - 2;
        if (span <= 0) break;
        final int swapIdx = i + 2 + rnd.nextInt(span);

        final String temp = queue[i + 1];
        queue[i + 1] = queue[swapIdx];
        queue[swapIdx] = temp;
        attempts++;
      }
    }

    return queue;
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

  /// Swaps the ball about to be fired with the one right after it,
  /// so the player can fix a bad draw instead of being stuck with
  /// it. Blocked mid-shot / on level end, same as shoot().
  void swapNextTwo() {
    if (shooting || levelComplete || gameOver || currentLevel == null) return;

    _ensureShotQueueHas(_shotQueueIndex + 1);

    final String temp = _shotQueue[_shotQueueIndex];
    _shotQueue[_shotQueueIndex] = _shotQueue[_shotQueueIndex + 1];
    _shotQueue[_shotQueueIndex + 1] = temp;
  }

  // ============================================================
  // SHOOT
  // ============================================================

  void shoot({
    required String letter,
    required double startX,
    required double startY,
    required double targetX,
    required double targetY,
  }) {
    if (shooting || levelComplete || gameOver || currentLevel == null) return;

    shooting = true;

    flyingBubble = Bubble(
      x: startX,
      y: startY,
      letter: letter,
      color: _colorForLetter(letter),
      radius: bubbleRadius,
    );

    final double dx = targetX - startX;
    final double dy = targetY - startY;
    final double distance = sqrt(dx * dx + dy * dy);

    if (distance == 0) {
      velocityX = 0;
      velocityY = -0.016;
      return;
    }

    const double speed = 0.016;
    velocityX = (dx / distance) * speed;
    velocityY = (dy / distance) * speed;
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

    flyingBubble!.x += velocityX;
    flyingBubble!.y += velocityY;

    if (flyingBubble!.x - bubbleRadius <= 0) {
      flyingBubble!.x = bubbleRadius;
      velocityX = velocityX.abs();
    }
    if (flyingBubble!.x + bubbleRadius >= 1) {
      flyingBubble!.x = 1 - bubbleRadius;
      velocityX = -velocityX.abs();
    }

    if (flyingBubble!.y - bubbleRadius <= boardTopY) {
      flyingBubble!.y = boardTopY + bubbleRadius;
      _attachFlyingBubble();
      return;
    }

    for (final Bubble bubble in List<Bubble>.from(bubbles)) {
      final double dx = flyingBubble!.x - bubble.x;
      final double dy = flyingBubble!.y - bubble.y;
      final double distance = _physicalDistance(dx, dy);
      final double collisionDistance = bubbleRadius + bubble.radius;

      if (distance <= collisionDistance) {
        _attachFlyingBubble();
        return;
      }
    }
  }

  void _attachFlyingBubble() {
    final Bubble? shot = flyingBubble;
    if (shot == null) return;

    // Guided assist (auto-connecting to the right slot on an
    // in-progress word) only exists during the first tutorial
    // levels, to teach the drag-and-release mechanic. Beyond that,
    // a shot only ever snaps to wherever it actually lands, so the
    // player has to aim for real - the game never builds the word
    // for them.
    final bool assistAllowed =
        (currentLevel?.number ?? 1) <= guidedAssistLevelCap;

    final Offset? snap = assistAllowed
        ? (_findGuidedSnapPosition(shot) ?? _findSnapPosition(shot))
        : _findSnapPosition(shot);

    if (snap == null) {
      shooting = false;
      flyingBubble = null;
      return;
    }

    shot.x = snap.dx;
    shot.y = snap.dy;

    bubbles.add(shot);

    flyingBubble = null;
    shooting = false;
    shotsUsed++;

    _checkForWords();
  }

  /// Finds the longest run of consecutive correct letters for
  /// [word] that already exists on the board, trying every possible
  /// starting bubble and neighbor path. Returns an empty list if no
  /// letter of the word has been placed yet.
  List<Bubble> _longestPartialChain(String word) {
    List<Bubble> best = [];

    for (final Bubble start in bubbles) {
      if (start.letter != word[0]) continue;

      final List<Bubble> path = [];
      final Set<int> used = {};

      void search(Bubble current, int letterIndex) {
        path.add(current);
        used.add(current.id);

        if (path.length > best.length) {
          best = List<Bubble>.from(path);
        }

        if (letterIndex < word.length - 1) {
          for (final Bubble neighbor in _getNeighbors(current)) {
            if (used.contains(neighbor.id)) continue;
            if (neighbor.letter != word[letterIndex + 1]) continue;
            search(neighbor, letterIndex + 1);
          }
        }

        path.removeLast();
        used.remove(current.id);
      }

      search(start, 0);
    }

    return best;
  }

  /// If the bubble that was just shot is the next letter needed to
  /// continue an already-started word chain, snap it into the empty
  /// slot right next to that chain's last bubble - so a correct
  /// shot always connects the word instead of landing somewhere
  /// unrelated on the board. Only ever called for levels within
  /// [guidedAssistLevelCap].
  Offset? _findGuidedSnapPosition(Bubble flying) {
    if (currentLevel == null || bubbles.isEmpty) return null;

    for (final String word in currentLevel!.words) {
      if (completedWords.contains(word)) continue;

      final List<Bubble> chain = _longestPartialChain(word);
      if (chain.isEmpty)
        continue; // nothing started yet - no anchor to guide to

      final int nextIndex = chain.length;
      if (nextIndex >= word.length) continue;
      if (word[nextIndex] != flying.letter) continue;

      final Bubble anchor = chain.last;
      final double vSpace = verticalSpacing;

      final List<Offset> directions = [
        Offset(horizontalSpacing, 0),
        Offset(-horizontalSpacing, 0),
        Offset(horizontalSpacing / 2, vSpace),
        Offset(-horizontalSpacing / 2, vSpace),
        Offset(horizontalSpacing / 2, -vSpace),
        Offset(-horizontalSpacing / 2, -vSpace),
      ];

      Offset? bestSlot;
      double bestDist = double.infinity;

      for (final Offset direction in directions) {
        final double x = anchor.x + direction.dx;
        final double y = anchor.y + direction.dy;

        if (x - bubbleRadius < 0 ||
            x + bubbleRadius > 1 ||
            y - bubbleRadius < boardTopY ||
            y + bubbleRadius > 0.84) {
          continue;
        }
        if (!_positionIsFree(x, y)) continue;

        final double dx = flying.x - x;
        final double dy = flying.y - y;
        final double dist = _physicalDistance(dx, dy);
        if (dist < bestDist) {
          bestDist = dist;
          bestSlot = Offset(x, y);
        }
      }

      if (bestSlot != null) return bestSlot;
    }

    return null;
  }

  Offset? _findSnapPosition(Bubble flying) {
    if (bubbles.isEmpty) {
      return Offset(
        flying.x.clamp(bubbleRadius, 1 - bubbleRadius),
        boardTopY + bubbleRadius,
      );
    }

    Offset? bestPosition;
    double bestDistance = double.infinity;

    final double vSpace = verticalSpacing;

    final List<Offset> directions = [
      Offset(horizontalSpacing, 0),
      Offset(-horizontalSpacing, 0),
      Offset(horizontalSpacing / 2, vSpace),
      Offset(-horizontalSpacing / 2, vSpace),
      Offset(horizontalSpacing / 2, -vSpace),
      Offset(-horizontalSpacing / 2, -vSpace),
    ];

    for (final Bubble bubble in bubbles) {
      for (final Offset direction in directions) {
        final double x = bubble.x + direction.dx;
        final double y = bubble.y + direction.dy;

        if (x - bubbleRadius < 0 ||
            x + bubbleRadius > 1 ||
            y - bubbleRadius < boardTopY ||
            y + bubbleRadius > 0.84) {
          continue;
        }

        if (!_positionIsFree(x, y)) continue;

        final double dx = flying.x - x;
        final double dy = flying.y - y;
        final double distance = _physicalDistance(dx, dy);

        if (distance < bestDistance) {
          bestDistance = distance;
          bestPosition = Offset(x, y);
        }
      }
    }

    return bestPosition;
  }

  bool _positionIsFree(double x, double y) {
    for (final Bubble bubble in bubbles) {
      final double dx = bubble.x - x;
      final double dy = bubble.y - y;
      final double distance = _physicalDistance(dx, dy);

      if (distance < horizontalSpacing * 0.80) return false;
    }
    return true;
  }

  // ============================================================
  // WORD CHECK
  // ------------------------------------------------------------
  // Checks EVERY bubble on the board as a possible start of each
  // unfinished word - not just the bubble that was just shot. This
  // matters because the letter that completes a word (by finally
  // connecting the chain) is very often NOT the first letter of
  // that word, e.g. shooting C, then A, then T: the chain C-A-T
  // only becomes complete once T lands, but T is word[2], not
  // word[0]. Scanning every bubble is cheap (boards are tiny) and
  // is what makes pops actually fire reliably.
  // ============================================================

  void _checkForWords() {
    if (currentLevel == null) return;

    for (final String word in currentLevel!.words) {
      if (completedWords.contains(word)) continue;

      for (final Bubble candidate in List<Bubble>.from(bubbles)) {
        if (candidate.letter != word[0]) continue;

        final List<Bubble> matched = _findWordFromBubble(candidate, word);

        if (matched.length == word.length) {
          _popWord(word, matched);
          return;
        }
      }
    }

    _checkGameOver();
  }

  List<Bubble> _findWordFromBubble(Bubble start, String word) {
    final List<Bubble> result = [];
    final List<Bubble> path = [];
    final Set<int> used = {};

    bool search(Bubble current, int letterIndex) {
      if (current.letter != word[letterIndex]) return false;

      path.add(current);
      used.add(current.id);

      if (letterIndex == word.length - 1) {
        result.addAll(path);
        return true;
      }

      final List<Bubble> neighbors = _getNeighbors(current);

      for (final Bubble neighbor in neighbors) {
        if (used.contains(neighbor.id)) continue;
        if (neighbor.letter != word[letterIndex + 1]) continue;

        if (search(neighbor, letterIndex + 1)) return true;
      }

      path.removeLast();
      used.remove(current.id);
      return false;
    }

    search(start, 0);
    return result;
  }

  List<Bubble> _getNeighbors(Bubble source) {
    final List<Bubble> neighbors = [];

    for (final Bubble bubble in bubbles) {
      if (bubble.id == source.id) continue;

      final double dx = bubble.x - source.x;
      final double dy = bubble.y - source.y;
      final double distance = _physicalDistance(dx, dy);

      if (distance <= horizontalSpacing * 1.30) {
        neighbors.add(bubble);
      }
    }

    return neighbors;
  }

  // ============================================================
  // POP WORD - bubbles fly to the basket instead of just fading
  // in place.
  // ============================================================

  void _popWord(String word, List<Bubble> matched) {
    if (completedWords.contains(word)) return;

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
          completedWords.length == currentLevel!.words.length) {
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

  // Kept for the board painter's API - bubbles no longer shrink in
  // place (they fly to the basket instead), so these are no-ops.
  double getBubbleScale(Bubble bubble) => 1;
  double getBubbleOpacity(Bubble bubble) => 1;

  void _checkGameOver() {
    if (currentLevel == null) return;
    if (completedWords.length == currentLevel!.words.length) return;

    if (shotsUsed >= currentLevel!.maxShots) {
      gameOver = true;
    }
  }

  /// 1-3 stars based on how efficiently the level was cleared.
  int get starsEarned {
    if (currentLevel == null || currentLevel!.maxShots == 0) return 3;
    final double ratio = shotsUsed / currentLevel!.maxShots;
    if (ratio <= 0.6) return 3;
    if (ratio <= 0.85) return 2;
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
