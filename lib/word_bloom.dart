import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';

import 'game_engine.dart';
import 'bubble.dart';

class WordBloom extends StatefulWidget {
  final int startLevel;

  /// Called the moment a level is actually won (not just visited),
  /// with the level number that was completed - lets the level
  /// select screen know it's safe to unlock the next one.
  final ValueChanged<int>? onLevelComplete;

  const WordBloom({super.key, this.startLevel = 1, this.onLevelComplete});

  @override
  State<WordBloom> createState() => _WordBloomState();
}

class _WordBloomState extends State<WordBloom>
    with SingleTickerProviderStateMixin {
  final GameEngine _engine = GameEngine();

  late final AnimationController _gameLoopController;
  late final ConfettiController _confettiController;

  double _aimX = 0.50;
  double _aimY = 0.12;

  final double _launcherX = 0.50;
  final double _launcherY = 0.90;

  bool _initialized = false;
  bool _confettiPlayed = false;

  // Shown only on level 1, before the player's very first shot -
  // teaches the drag-to-aim / release-to-shoot mechanic. This is
  // pure UI teaching (an overlay + text), never gameplay assistance
  // - it disappears the instant the player starts dragging.
  bool _showTutorial = false;

  // The aiming line only shows up while the player is actively
  // touching/dragging - not by default at the start of a level.
  bool _isAiming = false;

  @override
  void initState() {
    super.initState();

    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );

    _gameLoopController = AnimationController(
      vsync: this,
      duration: const Duration(days: 1),
    )..addListener(_gameLoopControllerListener);

    _gameLoopController.repeat();
  }

  void _gameLoopControllerListener() {
    if (!mounted) return;

    _engine.update();

    if (_engine.levelComplete && !_confettiPlayed) {
      _confettiPlayed = true;
      _confettiController.play();
      final int? completed = _engine.currentLevel?.number;
      if (completed != null) {
        widget.onLevelComplete?.call(completed);
      }
    }

    setState(() {});
  }

  @override
  void dispose() {
    _gameLoopController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _updateAim(Offset localPosition, Size size) {
    double x = localPosition.dx / size.width;
    double y = localPosition.dy / size.height;

    x = x.clamp(0.04, 0.96);
    y = y.clamp(_engine.boardTopY, 0.78);

    setState(() {
      _aimX = x;
      _aimY = y;
    });
  }

  void _shoot() {
    if (_engine.shooting || _engine.gameOver || _engine.levelComplete) return;

    final String letter = _engine.getNextLetter();

    _engine.shoot(
      letter: letter,
      startX: _launcherX,
      startY: _launcherY - 0.10,
      targetX: _aimX,
      targetY: _aimY,
    );

    setState(() {});
  }

  /// Builds a polyline (in normalized 0-1 space) for the dashed aim
  /// preview. It bounces off the left/right walls at an angle just
  /// like the real shot physics, AND stops dead the moment it would
  /// hit an existing bubble - it never draws through/past a bubble
  /// the way a real shot never would.
  List<Offset> _buildTrajectory(Offset start, Offset target) {
    final double aspect = _engine.aspect;

    // Work in a "physical" space where x and y use the same pixel
    // scale (both effectively width-based) so circle/wall geometry
    // is correct regardless of the phone's aspect ratio.
    Offset toPhysical(Offset p) => Offset(p.dx, p.dy / aspect);
    Offset toNormalized(Offset p) => Offset(p.dx, p.dy * aspect);

    final Offset physStart = toPhysical(start);
    final Offset physTarget = toPhysical(target);

    final List<Offset> physPoints = [physStart];

    Offset direction = physTarget - physStart;
    final double dist = direction.distance;
    if (dist < 0.001) return [start];

    Offset dir = direction / dist;
    Offset current = physStart;

    double remainingBudget = 2.4;
    const int maxBounces = 4;
    int bounces = 0;

    final double collisionR =
        _engine.bubbleRadius * 2; // shooter + board bubble
    final double topPhysY = _engine.boardTopY / aspect;

    while (bounces <= maxBounces && remainingBudget > 0.001) {
      double? tWall;
      if (dir.dx > 0.0001) {
        tWall = (1 - current.dx) / dir.dx;
      } else if (dir.dx < -0.0001) {
        tWall = (0 - current.dx) / dir.dx;
      }

      double? tTop;
      if (dir.dy < -0.0001) {
        tTop = (topPhysY - current.dy) / dir.dy;
      }

      // Nearest bubble the ray would hit, if any.
      double? tBubble;
      for (final b in _engine.bubbles) {
        final Offset c = Offset(b.x, b.y / aspect);
        final Offset l = c - current;
        final double tca = l.dx * dir.dx + l.dy * dir.dy;
        if (tca < 0) continue;

        final double d2 = (l.dx * l.dx + l.dy * l.dy) - tca * tca;
        final double r2 = collisionR * collisionR;
        if (d2 > r2) continue;

        final double thc = sqrt(r2 - d2);
        final double t0 = tca - thc;
        if (t0 > 0.001 && (tBubble == null || t0 < tBubble)) {
          tBubble = t0;
        }
      }

      double tCandidate = remainingBudget;
      bool hitWall = false;
      bool hitTop = false;
      bool hitBubble = false;

      if (tWall != null && tWall > 0.0001 && tWall < tCandidate) {
        tCandidate = tWall;
        hitWall = true;
        hitTop = false;
        hitBubble = false;
      }
      if (tTop != null && tTop > 0.0001 && tTop < tCandidate) {
        tCandidate = tTop;
        hitWall = false;
        hitTop = true;
        hitBubble = false;
      }
      if (tBubble != null && tBubble > 0.0001 && tBubble < tCandidate) {
        tCandidate = tBubble;
        hitWall = false;
        hitTop = false;
        hitBubble = true;
      }

      final Offset next = current + dir * tCandidate;
      physPoints.add(next);
      remainingBudget -= tCandidate;
      current = next;

      // Stop for good on hitting a bubble or the ceiling - that's
      // exactly where a real shot would come to rest.
      if (hitTop || hitBubble || (!hitWall && !hitTop && !hitBubble)) break;

      if (hitWall) {
        dir = Offset(-dir.dx, dir.dy);
        bounces++;
      }
    }

    return physPoints.map(toNormalized).toList();
  }

  Color _bubbleColor(String letter) {
    return _engine.letterColors[letter.toUpperCase()] ??
        const Color(0xFF7E8CFF);
  }

  void _restartAndRetry() {
    _confettiPlayed = false;
    _engine.retryLevel();
    setState(() {});
  }

  void _goNext() {
    _confettiPlayed = false;
    _engine.goToNextLevel();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F3ED),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final Size size = Size(constraints.maxWidth, constraints.maxHeight);

            if (!_initialized) {
              _engine.configureForScreen(size);
              _engine.startLevel(widget.startLevel);
              _initialized = true;
              _aimY = _engine.boardTopY + 0.05;
              _showTutorial = widget.startLevel == 1;
            }

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              // Touch anywhere to start aiming - the dashed line
              // only appears from this point on, not by default.
              onPanStart: (details) {
                _updateAim(details.localPosition, size);
                setState(() {
                  _isAiming = true;
                  _showTutorial = false;
                });
              },
              onPanUpdate: (details) {
                _updateAim(details.localPosition, size);
              },
              onPanEnd: (_) {
                if (_isAiming) _shoot();
                setState(() => _isAiming = false);
              },
              onPanCancel: () {
                setState(() => _isAiming = false);
              },
              child: Stack(
                children: [
                  // Simple soft gradient - the game screen no longer
                  // uses the home screen's background artwork.
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFCDEFFF), Color(0xFFF7F3ED)],
                        ),
                      ),
                    ),
                  ),

                  // TOP UI
                  Positioned(
                    top: 12,
                    left: 14,
                    right: 14,
                    child: _TopBar(
                      level: _engine.currentLevel?.number ?? 1,
                      score: _engine.score,
                      lives: _remainingShots,
                      onBack: () => Navigator.of(context).maybePop(),
                    ),
                  ),

                  // SINGLE ACTIVE HINT
                  Positioned(
                    top: 74,
                    left: 20,
                    right: 20,
                    child: _ActiveHint(
                      words: _engine.currentLevel?.words ?? [],
                      hints: _engine.currentLevel?.hints ?? [],
                      showHints: _engine.currentLevel?.showHints ?? true,
                      completedWords: _engine.completedWords,
                    ),
                  ),

                  // GAME BOARD
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _GameBoardPainter(
                        bubbles: _engine.bubbles,
                        flyingBubble: _engine.flyingBubble,
                      ),
                    ),
                  ),

                  // BUBBLES FLYING TO THE BASKET
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _FlyingPopPainter(
                        pops: _engine.flyingPops,
                        basketX: _engine.basketX,
                        basketY: _engine.basketY,
                      ),
                    ),
                  ),

                  // AIMING LINE - only while actively touching/dragging,
                  // bounces off the side walls at an angle like a real
                  // bubble shooter instead of a plain straight line.
                  if (_isAiming &&
                      !_engine.gameOver &&
                      !_engine.levelComplete &&
                      !_engine.shooting)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _AimingLinePainter(
                          points: _buildTrajectory(
                            Offset(_launcherX, _launcherY - 0.10),
                            Offset(_aimX, _aimY),
                          ),
                          color: _bubbleColor(_engine.getNextLetterPreview()),
                        ),
                      ),
                    ),

                  // BASKET (bottom-left) - matches engine.basketX/Y
                  Align(
                    alignment: const Alignment(-0.74, 0.80),
                    child: _Basket(count: _engine.collectedLetters.length),
                  ),

                  // FLOWER CANNON
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: SizedBox(
                      height: 210,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _FlowerLauncherPainter(
                                color: _bubbleColor(
                                  _engine.getNextLetterPreview(),
                                ),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: Align(
                              alignment: const Alignment(0, 0.06),
                              child: _GlossyBubble(
                                letter: _engine.getNextLetterPreview(),
                                color: _bubbleColor(
                                  _engine.getNextLetterPreview(),
                                ),
                                size: 78,
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: Align(
                              alignment: const Alignment(0.62, 0.42),
                              // Tapping the "NEXT" preview swaps it
                              // with the ball about to be fired -
                              // lets the player fix a bad draw
                              // instead of being stuck with it.
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  _engine.swapNextTwo();
                                  setState(() {});
                                },
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Text(
                                          'NEXT',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.4,
                                            color: Color(0xFF5B4636),
                                          ),
                                        ),
                                        SizedBox(width: 3),
                                        Icon(
                                          Icons.swap_horiz_rounded,
                                          size: 12,
                                          color: Color(0xFF5B4636),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    _GlossyBubble(
                                      letter: _engine
                                          .getLetterAfterNextPreview(),
                                      color: _bubbleColor(
                                        _engine.getLetterAfterNextPreview(),
                                      ),
                                      size: 40,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // FOUND WORD
                  if (_engine.foundWord != null)
                    Positioned(
                      top: 150,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: _FoundWord(word: _engine.foundWord!),
                      ),
                    ),

                  // GAME OVER
                  if (_engine.gameOver)
                    Positioned.fill(
                      child: _GameOverOverlay(onPressed: _restartAndRetry),
                    ),

                  // LEVEL COMPLETE
                  if (_engine.levelComplete)
                    Positioned.fill(
                      child: _LevelCompleteOverlay(
                        confettiController: _confettiController,
                        score: _engine.score,
                        stars: _engine.starsEarned,
                        collectedLetters: _engine.collectedLetters,
                        letterColors: _engine.letterColors,
                        onPressed: _goNext,
                      ),
                    ),

                  // FIRST-SHOT TUTORIAL - pure UI teaching (drag to
                  // aim, release to shoot). Only ever shown once, on
                  // level 1, before the player's first drag. Taps
                  // pass through to the game beneath it except on
                  // the "GOT IT" button, so a player who just starts
                  // dragging dismisses it naturally too.
                  if (_showTutorial)
                    Positioned.fill(
                      child: IgnorePointer(
                        ignoring: true,
                        child: _TutorialOverlay(),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  int get _remainingShots {
    final int maxShots = _engine.currentLevel?.maxShots ?? 0;
    return max(0, maxShots - _engine.shotsUsed);
  }
}

// ================================================================
// FIRST-SHOT TUTORIAL - teaches the mechanic, never plays for the
// player. Non-interactive (IgnorePointer) so the very drag it's
// teaching also dismisses it - no separate button needed.
// ================================================================

class _TutorialOverlay extends StatefulWidget {
  @override
  State<_TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<_TutorialOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.32),
      child: Stack(
        children: [
          // Instruction card near the top, clear of the hint box
          // and clear of where the demo hand moves.
          Align(
            alignment: const Alignment(0, -0.62),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 36),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Drag to aim, let go to shoot!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF292929),
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Connect letters to spell the word above',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B6B6B),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Animated hand sliding from the launcher up toward an
          // aim point, looping, to demonstrate the drag gesture.
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final double t = Curves.easeInOut.transform(_controller.value);
              final double dy = 0.72 - (t * 0.46);
              final double dx = 0.5 + (sin(t * pi) * 0.10);
              final double opacity = t < 0.9 ? 1.0 : (1.0 - (t - 0.9) * 10);

              return Align(
                alignment: Alignment((dx - 0.5) * 2, (dy - 0.5) * 2),
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: const Icon(
                    Icons.touch_app_rounded,
                    color: Colors.white,
                    size: 46,
                    shadows: [Shadow(color: Colors.black45, blurRadius: 8)],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final int level;
  final int score;
  final int lives;
  final VoidCallback onBack;

  const _TopBar({
    required this.level,
    required this.score,
    required this.lives,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _GlassBox(
          padding: const EdgeInsets.all(9),
          child: GestureDetector(
            onTap: onBack,
            child: const Icon(
              Icons.arrow_back_rounded,
              size: 18,
              color: Color(0xFF292929),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: _GlassBox(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.auto_awesome,
                  size: 19,
                  color: Color(0xFFFF6FAE),
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'LEVEL $level',
                      maxLines: 1,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        _GlassBox(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.favorite_rounded,
                size: 18,
                color: Color(0xFFFF5C87),
              ),
              const SizedBox(width: 5),
              Text(
                '$lives',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: _GlassBox(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.star_rounded,
                  size: 20,
                  color: Color(0xFFFFB84D),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$score',
                      maxLines: 1,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        _GlassBox(
          padding: const EdgeInsets.all(9),
          child: const Icon(
            Icons.pause_rounded,
            size: 18,
            color: Color(0xFF292929),
          ),
        ),
      ],
    );
  }
}

// ================================================================
// SINGLE ACTIVE HINT - only the current word's clue is ever shown
// ================================================================

class _ActiveHint extends StatelessWidget {
  final List<String> words;
  final List<String> hints;
  final bool showHints;
  final List<String> completedWords;

  const _ActiveHint({
    required this.words,
    required this.hints,
    required this.showHints,
    required this.completedWords,
  });

  @override
  Widget build(BuildContext context) {
    // Find the first word that hasn't been solved yet - that's the
    // only one we show a clue for.
    int activeIndex = -1;
    for (int i = 0; i < words.length; i++) {
      if (!completedWords.contains(words[i])) {
        activeIndex = i;
        break;
      }
    }

    if (activeIndex == -1) {
      // Every word is solved - nothing left to hint at.
      return const SizedBox.shrink();
    }

    final String word = words[activeIndex];
    final String hint = activeIndex < hints.length ? hints[activeIndex] : '';

    final String label = showHints && hint.isNotEmpty
        ? hint
        : List.filled(word.length, '_').join(' ');

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Small dots showing overall progress (e.g. found 0 of 2)
        // without revealing any letters.
        for (int i = 0; i < words.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: completedWords.contains(words[i])
                    ? const Color(0xFFFF6FAE)
                    : Colors.white.withValues(alpha: 0.6),
                border: Border.all(color: Colors.white, width: 1),
              ),
            ),
          ),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF292929),
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ================================================================
// GLASS BOX
// ================================================================

class _GlassBox extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const _GlassBox({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ================================================================
// BASKET
// ================================================================

class _Basket extends StatelessWidget {
  final int count;
  const _Basket({required this.count});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 58,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          CustomPaint(size: const Size(64, 50), painter: _BasketPainter()),
          if (count > 0)
            Positioned(
              top: -6,
              right: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4D96),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.4),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BasketPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Path basket = Path();
    basket.moveTo(size.width * 0.08, size.height * 0.42);
    basket.lineTo(size.width * 0.92, size.height * 0.42);
    basket.lineTo(size.width * 0.80, size.height * 0.98);
    basket.lineTo(size.width * 0.20, size.height * 0.98);
    basket.close();

    final Paint basketPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFE8B784), Color(0xFFC98F55)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(basket, basketPaint);

    // Woven lines
    final Paint weave = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1.4;
    for (int i = 1; i < 4; i++) {
      final double t = i / 4;
      canvas.drawLine(
        Offset(size.width * (0.10 + t * 0.06), size.height * 0.46),
        Offset(size.width * (0.24 + t * 0.5), size.height * 0.96),
        weave,
      );
    }

    // Rim
    final Paint rim = Paint()
      ..color = const Color(0xFF8A5A34)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawLine(
      Offset(size.width * 0.06, size.height * 0.40),
      Offset(size.width * 0.94, size.height * 0.40),
      rim,
    );

    // Handle
    final Paint handle = Paint()
      ..color = const Color(0xFF8A5A34)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4;
    final Path handlePath = Path();
    handlePath.moveTo(size.width * 0.28, size.height * 0.40);
    handlePath.quadraticBezierTo(
      size.width * 0.5,
      -size.height * 0.28,
      size.width * 0.72,
      size.height * 0.40,
    );
    canvas.drawPath(handlePath, handle);
  }

  @override
  bool shouldRepaint(covariant _BasketPainter oldDelegate) => false;
}

// ================================================================
// FLYING POP BUBBLES (board -> basket)
// ================================================================

class _FlyingPopPainter extends CustomPainter {
  final List<FlyingPopBubble> pops;
  final double basketX;
  final double basketY;

  const _FlyingPopPainter({
    required this.pops,
    required this.basketX,
    required this.basketY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final fp in pops) {
      final double t = Curves.easeIn.transform(fp.progress.clamp(0, 1));

      final double x = fp.startX + (basketX - fp.startX) * t;
      // Slight arc upward then down toward the basket.
      final double arc = -0.06 * sin(pi * t);
      final double y = fp.startY + (basketY - fp.startY) * t + arc;

      final Offset center = Offset(x * size.width, y * size.height);
      final double baseRadius = 0.052 * size.width;
      final double radius = baseRadius * (1 - t * 0.75);
      final double opacity = 1 - (t * 0.5);

      if (radius <= 0) continue;

      final Paint paint = Paint()
        ..shader = RadialGradient(
          colors: [
            fp.color.withValues(alpha: opacity),
            fp.color.withValues(alpha: opacity * 0.8),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius));

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FlyingPopPainter oldDelegate) => true;
}

// ================================================================
// GLOSSY BUBBLE
// ================================================================

class _GlossyBubble extends StatelessWidget {
  final String letter;
  final Color color;
  final double size;

  const _GlossyBubble({
    required this.letter,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _GlossyBubblePainter(color: color),
      child: SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Text(
            letter,
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.42,
              fontWeight: FontWeight.w900,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlossyBubblePainter extends CustomPainter {
  final Color color;
  const _GlossyBubblePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = min(size.width, size.height) / 2;
    final Offset center = Offset(size.width / 2, size.height / 2);

    final Paint shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawCircle(center.translate(0, 3), radius * 0.90, shadowPaint);

    final Paint bubblePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.45),
        radius: 0.9,
        colors: [
          Colors.white.withValues(alpha: 0.48),
          color,
          color.withValues(alpha: 0.82),
        ],
        stops: const [0.0, 0.28, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius * 0.90, bubblePaint);

    final Paint shine = Paint()..color = Colors.white.withValues(alpha: 0.60);
    canvas.drawOval(
      Rect.fromLTWH(
        size.width * 0.23,
        size.height * 0.15,
        size.width * 0.27,
        size.height * 0.16,
      ),
      shine,
    );
  }

  @override
  bool shouldRepaint(covariant _GlossyBubblePainter oldDelegate) =>
      oldDelegate.color != color;
}

// ================================================================
// GAME BOARD PAINTER
// ================================================================

class _GameBoardPainter extends CustomPainter {
  final List<Bubble> bubbles;
  final Bubble? flyingBubble;

  const _GameBoardPainter({required this.bubbles, required this.flyingBubble});

  @override
  void paint(Canvas canvas, Size size) {
    for (final bubble in bubbles) {
      _drawBubble(canvas, size, bubble);
    }
    if (flyingBubble != null) {
      _drawBubble(canvas, size, flyingBubble!);
    }
  }

  void _drawBubble(Canvas canvas, Size size, Bubble bubble) {
    final Offset center = Offset(bubble.x * size.width, bubble.y * size.height);
    final double radius = bubble.radius * size.width;

    if (radius <= 0) return;

    final Paint shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.13)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(center.translate(0, 3), radius * 0.92, shadow);

    final Paint paint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.45),
        radius: 0.9,
        colors: [
          Colors.white.withValues(alpha: 0.48),
          bubble.color,
          bubble.color.withValues(alpha: 0.78),
        ],
        stops: const [0.0, 0.30, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);

    final Paint shine = Paint()..color = Colors.white.withValues(alpha: 0.58);
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(-radius * 0.25, -radius * 0.38),
        width: radius * 0.48,
        height: radius * 0.28,
      ),
      shine,
    );

    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: bubble.letter,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.92,
          fontWeight: FontWeight.w900,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.20),
              blurRadius: 3,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _GameBoardPainter oldDelegate) => true;
}

// ================================================================
// AIMING LINE
// ================================================================

class _AimingLinePainter extends CustomPainter {
  final List<Offset> points; // normalized 0-1 polyline, wall bounces included
  final Color color;

  const _AimingLinePainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final Paint dotPaint = Paint()..color = color;
    final Paint dotOutline = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    const double dotRadius = 4.2;
    const double gap = 14;

    double carryOver = 0;

    for (int i = 0; i < points.length - 1; i++) {
      final Offset segStart = Offset(
        points[i].dx * size.width,
        points[i].dy * size.height,
      );
      final Offset segEnd = Offset(
        points[i + 1].dx * size.width,
        points[i + 1].dy * size.height,
      );

      final Offset segVector = segEnd - segStart;
      final double segLength = segVector.distance;
      if (segLength < 0.5) continue;

      final Offset segDir = segVector / segLength;

      double travelled = carryOver > 0 ? gap - carryOver : 0;
      if (carryOver == 0) travelled = 0;

      while (travelled < segLength) {
        final Offset p = segStart + segDir * travelled;
        canvas.drawCircle(p, dotRadius, dotPaint);
        canvas.drawCircle(p, dotRadius, dotOutline);
        travelled += gap;
      }

      carryOver = travelled - segLength;
    }

    // Small ring at the very end of the trajectory to show where the
    // bubble will land.
    final Offset last = Offset(
      points.last.dx * size.width,
      points.last.dy * size.height,
    );
    final Paint ring = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    canvas.drawCircle(last, 9, ring);
  }

  @override
  bool shouldRepaint(covariant _AimingLinePainter oldDelegate) {
    if (oldDelegate.color != color) return true;
    if (oldDelegate.points.length != points.length) return true;
    for (int i = 0; i < points.length; i++) {
      if (oldDelegate.points[i] != points[i]) return true;
    }
    return false;
  }
}

// ================================================================
// FLOWER LAUNCHER - redesigned to match the reference art: round
// layered pink petals, a soft gold ring behind the ball, and a
// simple green stem/leaf base (no brown basket-style pot).
// ================================================================

class _FlowerLauncherPainter extends CustomPainter {
  final Color color;
  const _FlowerLauncherPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height * 0.46);
    final double flowerRadius = min(size.width, size.height) * 0.50;

    // ---- soft ground shadow under the whole plant ----
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, size.height * 0.92),
        width: flowerRadius * 1.6,
        height: flowerRadius * 0.32,
      ),
      shadowPaint,
    );

    // ---- stem ----
    final double stemTop = center.dy + flowerRadius * 0.30;
    final double stemBottom = size.height * 0.90;
    final Paint stemPaint = Paint()
      ..shader =
          const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF6FBF63), Color(0xFF3E8E4C)],
          ).createShader(
            Rect.fromLTWH(center.dx - 10, stemTop, 20, stemBottom - stemTop),
          );
    final Path stem = Path();
    stem.moveTo(center.dx - 7, stemTop);
    stem.quadraticBezierTo(
      center.dx - 14,
      (stemTop + stemBottom) / 2,
      center.dx - 5,
      stemBottom,
    );
    stem.lineTo(center.dx + 5, stemBottom);
    stem.quadraticBezierTo(
      center.dx + 12,
      (stemTop + stemBottom) / 2,
      center.dx + 7,
      stemTop,
    );
    stem.close();
    canvas.drawPath(stem, stemPaint);

    // ---- two leaves flanking the stem ----
    void drawLeaf(bool left) {
      final double dir = left ? -1 : 1;
      final Offset base = Offset(
        center.dx + dir * 4,
        stemTop + (stemBottom - stemTop) * 0.42,
      );

      canvas.save();
      canvas.translate(base.dx, base.dy);
      canvas.rotate(dir * 0.55);

      final double leafLen = flowerRadius * 0.62;
      final double leafW = flowerRadius * 0.34;

      final Path leaf = Path();
      leaf.moveTo(0, 0);
      leaf.quadraticBezierTo(
        dir * leafLen * 0.55,
        -leafW * 0.5,
        dir * leafLen,
        0,
      );
      leaf.quadraticBezierTo(dir * leafLen * 0.55, leafW * 0.5, 0, 0);
      leaf.close();

      final Paint leafPaint = Paint()
        ..shader = LinearGradient(
          colors: const [Color(0xFF8BD65C), Color(0xFF3C9B55)],
        ).createShader(Rect.fromLTWH(0, -leafW / 2, dir * leafLen, leafW));
      canvas.drawPath(leaf, leafPaint);

      final Paint vein = Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..strokeWidth = 1.3
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset.zero, Offset(dir * leafLen * 0.85, 0), vein);

      canvas.restore();
    }

    drawLeaf(true);
    drawLeaf(false);

    // ---- outer petal layer (soft light pink, rounded) ----
    final Paint outerPetalPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.30, -0.40),
        radius: 1.0,
        colors: [Color(0xFFFFEAF4), Color(0xFFFFB2D8), Color(0xFFFF7FC0)],
        stops: [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: flowerRadius));

    const int outerPetalCount = 10;
    for (int i = 0; i < outerPetalCount; i++) {
      final double angle = (pi * 2 / outerPetalCount) * i - pi / 2;
      final Offset petalCenter = Offset(
        center.dx + cos(angle) * flowerRadius * 0.58,
        center.dy + sin(angle) * flowerRadius * 0.58,
      );

      canvas.save();
      canvas.translate(petalCenter.dx, petalCenter.dy);
      canvas.rotate(angle + pi / 2);

      final double pw = flowerRadius * 0.50;
      final double ph = flowerRadius * 0.62;
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: pw, height: ph),
        outerPetalPaint,
      );

      canvas.restore();
    }

    // ---- inner petal layer (deeper pink, slightly rotated offset) ----
    final Paint innerPetalPaint = Paint()
      ..shader =
          const RadialGradient(
            center: Alignment(-0.30, -0.40),
            radius: 1.0,
            colors: [Color(0xFFFFD3EA), Color(0xFFFF8AC8), Color(0xFFF25CA8)],
            stops: [0.0, 0.55, 1.0],
          ).createShader(
            Rect.fromCircle(center: center, radius: flowerRadius * 0.75),
          );

    const int innerPetalCount = 8;
    for (int i = 0; i < innerPetalCount; i++) {
      final double angle =
          (pi * 2 / innerPetalCount) * i - pi / 2 + (pi / innerPetalCount);
      final Offset petalCenter = Offset(
        center.dx + cos(angle) * flowerRadius * 0.34,
        center.dy + sin(angle) * flowerRadius * 0.34,
      );

      canvas.save();
      canvas.translate(petalCenter.dx, petalCenter.dy);
      canvas.rotate(angle + pi / 2);

      final double pw = flowerRadius * 0.34;
      final double ph = flowerRadius * 0.42;
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: pw, height: ph),
        innerPetalPaint,
      );

      canvas.restore();
    }

    // ---- gold ring behind the ball ----
    final Paint ringPaint = Paint()
      ..shader =
          const RadialGradient(
            colors: [Color(0xFFFFF6C8), Color(0xFFFFD658), Color(0xFFF0A61E)],
            stops: [0.0, 0.65, 1.0],
          ).createShader(
            Rect.fromCircle(center: center, radius: flowerRadius * 0.50),
          );
    canvas.drawCircle(center, flowerRadius * 0.50, ringPaint);

    final Paint ringEdge = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawCircle(center, flowerRadius * 0.50, ringEdge);

    final Paint glowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.20)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(center, flowerRadius * 0.46, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _FlowerLauncherPainter oldDelegate) =>
      oldDelegate.color != color;
}

// ================================================================
// FOUND WORD
// ================================================================

class _FoundWord extends StatelessWidget {
  final String word;
  const _FoundWord({required this.word});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Text(
        '✨ $word ✨',
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: Color(0xFFFF4D96),
          letterSpacing: 2,
        ),
      ),
    );
  }
}

// ================================================================
// GAME OVER OVERLAY
// ================================================================

class _GameOverOverlay extends StatelessWidget {
  final VoidCallback onPressed;
  const _GameOverOverlay({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.34),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 28),
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFDF9),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🌸', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 8),
              const Text(
                'TRY AGAIN',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF292929),
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'You ran out of shots',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black.withValues(alpha: 0.58),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: onPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF292929),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    'RETRY',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// LEVEL COMPLETE OVERLAY - confetti + counting score + stars +
// letters popping out of the basket one by one
// ================================================================

class _LevelCompleteOverlay extends StatelessWidget {
  final ConfettiController confettiController;
  final int score;
  final int stars;
  final List<String> collectedLetters;
  final Map<String, Color> letterColors;
  final VoidCallback onPressed;

  const _LevelCompleteOverlay({
    required this.confettiController,
    required this.score,
    required this.stars,
    required this.collectedLetters,
    required this.letterColors,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.40),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              numberOfParticles: 26,
              gravity: 0.25,
              colors: const [
                Color(0xFFFF6FAE),
                Color(0xFFFFD15C),
                Color(0xFF63D6B0),
                Color(0xFF5DABFF),
                Color(0xFFC08BFF),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 28),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFDF9),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🌸', style: TextStyle(fontSize: 44)),
                const SizedBox(height: 4),
                const Text(
                  'LEVEL COMPLETE!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF292929),
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 14),

                // Stars, filled in one after another.
                _StarRow(stars: stars),
                const SizedBox(height: 14),

                // Bubbles "popping out of the basket" one by one.
                _CollectedLettersReveal(
                  letters: collectedLetters,
                  colors: letterColors,
                ),
                const SizedBox(height: 10),

                // Score counting up.
                TweenAnimationBuilder<int>(
                  tween: IntTween(begin: 0, end: score),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Text(
                      '$value pts',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFF4D96),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: onPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF292929),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text(
                      'NEXT LEVEL',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  final int stars;
  const _StarRow({required this.stars});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final bool filled = i < stars;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: filled ? 1 : 0.6),
            duration: Duration(milliseconds: 400 + i * 150),
            curve: Curves.elasticOut,
            builder: (context, scale, child) {
              return Transform.scale(
                scale: scale,
                child: Icon(
                  filled ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 40,
                  color: filled ? const Color(0xFFFFC857) : Colors.black26,
                ),
              );
            },
          ),
        );
      }),
    );
  }
}

class _CollectedLettersReveal extends StatefulWidget {
  final List<String> letters;
  final Map<String, Color> colors;

  const _CollectedLettersReveal({required this.letters, required this.colors});

  @override
  State<_CollectedLettersReveal> createState() =>
      _CollectedLettersRevealState();
}

class _CollectedLettersRevealState extends State<_CollectedLettersReveal> {
  int _visibleCount = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 130), (timer) {
      if (!mounted) return;
      setState(() {
        _visibleCount++;
      });
      if (_visibleCount >= widget.letters.length) {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: List.generate(widget.letters.length, (i) {
        final String letter = widget.letters[i];
        final Color color =
            widget.colors[letter.toUpperCase()] ?? const Color(0xFF7E8CFF);
        final bool visible = i < _visibleCount;

        return AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 220),
          child: AnimatedScale(
            scale: visible ? 1 : 0.3,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              alignment: Alignment.center,
              child: Text(
                letter,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
