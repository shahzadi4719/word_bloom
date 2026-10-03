import 'package:flutter/material.dart';

import '../levels.dart';
import '../word_bloom.dart';
import '../progress_service.dart';

class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({super.key});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  // ==============================================================
  // PLAYER PROGRESS
  // ==============================================================

  // Highest level the player is allowed to play. Persisted to disk
  // via ProgressService (see _loadProgress) so closing and
  // reopening the app resumes exactly where the player left off
  // instead of resetting back to level 1.
  int _unlockedLevel = 1;

  // Stars earned per completed level (levelNumber -> 1..3), also
  // persisted. This is what actually gets drawn under each node on
  // the path, instead of a hardcoded "3 stars for any done level".
  final Map<int, int> _levelStars = {};

  // Becomes true once saved progress has been read from disk, so we
  // don't flash "level 1" for a frame before the real value loads.
  bool _progressLoaded = false;

  final ScrollController _scrollController = ScrollController();

  // ==============================================================
  // WORLD 1 — auto-generated levels
  // ==============================================================

  // Total number of levels to auto-generate. Change this one
  // number to generate more or fewer levels — nothing else needs
  // to be touched.
  static const int _totalLevels = 2000;

  // Vertical space each level "slot" takes up. Because this is a
  // fixed value, ListView.builder can compute the scroll extent
  // for all 2000 levels WITHOUT building all 2000 widgets — only
  // the ones actually visible on screen get built. This is what
  // keeps the screen smooth even with thousands of levels.
  static const double _nodeSpacing = 150;

  // Horizontal position of every node as a fraction of screen
  // width (0.0 = far left, 1.0 = far right). This list repeats
  // (cycles) forever to create the never-ending zig-zag/wavy path,
  // so it works for any level count, including 2000+.
  static const List<double> _xPattern = [
    0.85,
    0.25,
    0.75,
    0.20,
    0.80,
    0.35,
    0.70,
    0.15,
  ];

  double _xFor(int levelIndex) => _xPattern[levelIndex % _xPattern.length];

  // ==============================================================
  // INIT
  // ==============================================================

  @override
  void initState() {
    super.initState();
    _loadProgress(jumpToLevel: true);
  }

  // ==============================================================
  // PERSISTENCE - load/save unlocked level + per-level stars so
  // progress survives the app being closed and reopened.
  // ==============================================================

  /// Re-reads progress from disk via [ProgressService] - the single
  /// source of truth. Safe to call repeatedly (e.g. every time the
  /// player returns to this screen from a play session) since it
  /// always reflects whatever was actually saved, regardless of
  /// what happened inside the game screen.
  Future<void> _loadProgress({bool jumpToLevel = false}) async {
    final int savedUnlocked = await ProgressService.getUnlockedLevel();
    final Map<int, int> savedStars = await ProgressService.getLevelStars();

    debugPrint(
      'LevelSelectScreen: loaded unlocked=$savedUnlocked '
      'stars=$savedStars',
    );

    if (!mounted) return;

    setState(() {
      _unlockedLevel = savedUnlocked.clamp(1, _totalLevels);
      _levelStars
        ..clear()
        ..addAll(savedStars);
      _progressLoaded = true;
    });

    if (jumpToLevel) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToUnlockedLevel(animate: false);
      });
    }
  }

  // Scrolls so the player's current/unlocked level node is roughly
  // centered in view. List index 0 = top = highest level number, so
  // the unlocked level's list index counts down from the top.
  void _scrollToUnlockedLevel({required bool animate}) {
    if (!_scrollController.hasClients) return;

    final int listIndex = _totalLevels - _unlockedLevel;
    final double target =
        (listIndex * _nodeSpacing) -
        (_scrollController.position.viewportDimension / 2) +
        (_nodeSpacing / 2);

    final double clamped = target.clamp(
      _scrollController.position.minScrollExtent,
      _scrollController.position.maxScrollExtent,
    );

    if (animate) {
      _scrollController.animateTo(
        clamped,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      _scrollController.jumpTo(clamped);
    }
  }

  // ==============================================================
  // DISPOSE
  // ==============================================================

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showLevelPreview(int levelNumber) {
    if (levelNumber > _unlockedLevel) return;

    final GameLevel lv = getLevel(levelNumber);
    final int stars = _levelStars[levelNumber] ?? 0;

    final String lengthText = lv.minWordLength == lv.maxWordLength
        ? '${lv.minWordLength} LETTER WORDS'
        : '${lv.minWordLength}–${lv.maxWordLength} LETTER WORDS';

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFDCEA), Color(0xFFFFC2DC)],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'LEVEL $levelNumber',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF7A4A3A),
                      shadows: [Shadow(color: Colors.white, blurRadius: 4)],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'World ${lv.world} · ${worldNames[lv.world - 1]} · ${lv.difficulty}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF9C6E5C),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        Text(
                          lv.wordCount == 1
                              ? '1 WORD'
                              : '${lv.wordCount} WORDS',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFFF4D96),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          lengthText,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF7A4A3A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${lv.maxShots} SHOTS',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF9C6E5C),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      3,
                      (i) => Icon(
                        Icons.star_rounded,
                        size: 34,
                        color: i < stars
                            ? const Color(0xFFFFD23F)
                            : Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _PillButton(
                    label: 'PLAY',
                    icon: Icons.play_arrow_rounded,
                    colors: const [Color(0xFFFF9BC4), Color(0xFFFF4D96)],
                    onTap: () {
                      Navigator.of(dialogContext).pop();
                      _openLevel(levelNumber);
                    },
                  ),
                ],
              ),
            ),
            Positioned(
              top: -14,
              right: -8,
              child: GestureDetector(
                onTap: () => Navigator.of(dialogContext).pop(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFE0554C),
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==============================================================
  // OPEN LEVEL
  // ==============================================================

  void _openLevel(int levelNumber) async {
    if (levelNumber > _unlockedLevel) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WordBloom(
          startLevel: levelNumber,
          onLevelComplete: (completedLevel, starsEarned) {
            // Optimistic in-memory update so the UI feels instant if
            // the player is still on this screen's stack somehow.
            // The real, guaranteed-correct sync happens below, right
            // after the game screen is popped (see _loadProgress
            // call after the push returns) - that one always wins
            // because it re-reads whatever was actually written to
            // disk by ProgressService the moment the level was won.
            if (!mounted) return;
            setState(() {
              final int existingStars = _levelStars[completedLevel] ?? 0;
              _levelStars[completedLevel] = starsEarned > existingStars
                  ? starsEarned
                  : existingStars;

              if (completedLevel >= _unlockedLevel &&
                  completedLevel < _totalLevels &&
                  completedLevel < levels.length) {
                _unlockedLevel = completedLevel + 1;
              }
            });
          },
        ),
      ),
    );

    // The player is back on this screen now - resync fully with
    // disk so whatever was actually saved (even across several
    // levels played back-to-back in one session) is reflected here,
    // no matter what happened with the callback above.
    await _loadProgress();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToUnlockedLevel(animate: true);
    });
  }

  // ==============================================================
  // SETTINGS DIALOG
  // ==============================================================

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (context) => const _SettingsDialog(),
    );
  }

  // ==============================================================
  // BUILD
  // ==============================================================

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    if (!_progressLoaded) {
      return Scaffold(
        backgroundColor: const Color(0xFFE3C6B4),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/images/level_select_bg.png', fit: BoxFit.cover),
            const Center(child: CircularProgressIndicator()),
          ],
        ),
      );
    }
    return Scaffold(
      // Dull, muted peachy background matching the castle-path theme.
      backgroundColor: const Color(0xFFE3C6B4),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ==================================================
          // DREAMY PINK LEVEL-MAP BACKGROUND
          // ==================================================
          Positioned.fill(
            child: Image.asset(
              'assets/images/level_select_bg.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // ==================================================
                // HEADER
                // ==================================================
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      _RoundIconButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () {
                          Navigator.of(context).maybePop();
                        },
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'World 1',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF7A4A3A),
                                shadows: [
                                  Shadow(color: Colors.white70, blurRadius: 4),
                                ],
                              ),
                            ),
                            Text(
                              'Misty Cliff',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF9C6E5C),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _AnimatedSettingsButton(
                        onTap: () => _showSettingsDialog(context),
                      ),
                    ],
                  ),
                ),

                // ==================================================
                // AUTO-GENERATED SCROLLABLE LEVEL LIST
                //
                // ListView.builder + a fixed itemExtent means Flutter
                // only ever builds the handful of level tiles that
                // are actually on screen, no matter whether
                // _totalLevels is 10 or 20,000. The path segment for
                // each tile is drawn locally inside that tile, and
                // because neighboring tiles share the same x
                // coordinate at their shared edge, the path still
                // looks like one continuous winding line.
                //
                // List index 0 = the TOP of the list = the highest
                // level number. Index (_totalLevels - 1) = level 1,
                // which sits at the very bottom — matching the
                // original bottom-up layout.
                // ==================================================
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _totalLevels,
                    itemExtent: _nodeSpacing,
                    itemBuilder: (context, listIndex) {
                      final int level = _totalLevels - listIndex;
                      final int levelIndex = level - 1; // 0-based

                      final double bottomX = _xFor(levelIndex);
                      final bool hasLevelAbove = level < _totalLevels;
                      final double? topX = hasLevelAbove
                          ? _xFor(levelIndex + 1)
                          : null;

                      return _LevelTile(
                        screenWidth: screenWidth,
                        topXFraction: topX,
                        bottomXFraction: bottomX,
                        level: level,
                        unlocked: level <= _unlockedLevel,
                        current: level == _unlockedLevel,
                        // Real, persisted stars for this level - 0
                        // until it's actually been cleared, then
                        // whatever the best clear earned (1-3).
                        stars: _levelStars[level] ?? 0,
                        onTap: () => _showLevelPreview(level),
                      );
                    },
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

// ================================================================
// LEVEL TILE
// One fixed-height slot: draws the incoming path segment (from the
// tile above) plus this level's node. Fully self-contained so
// ListView.builder can build/dispose it independently as the user
// scrolls through thousands of levels.
// ================================================================

class _LevelTile extends StatelessWidget {
  final double screenWidth;
  final double? topXFraction; // null when this is the very top level
  final double bottomXFraction;
  final int level;
  final bool unlocked;
  final bool current;
  final int stars;
  final VoidCallback onTap;

  const _LevelTile({
    required this.screenWidth,
    required this.topXFraction,
    required this.bottomXFraction,
    required this.level,
    required this.unlocked,
    required this.current,
    required this.stars,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Path segment for this slot only.
          Positioned.fill(
            child: CustomPaint(
              painter: _PathSegmentPainter(
                topXFraction: topXFraction,
                bottomXFraction: bottomXFraction,
              ),
            ),
          ),

          // The level node hangs from a single fixed point - exactly
          // where the path curve ends for this tile. Centering it
          // with FractionalTranslation (rather than guessing a fixed
          // left offset) and giving the node itself a fixed-size,
          // absolutely-positioned layout (see _LevelNode) means the
          // ball always sits dead-center on the road at the same
          // height, whether or not this node is showing stars or the
          // bounce arrow - that inconsistency was what made the path
          // look like it was joining nodes at the wrong spot.
          Positioned(
            left: bottomXFraction * screenWidth,
            bottom: 0,
            child: FractionalTranslation(
              translation: const Offset(-0.5, 0),
              child: _LevelNode(
                number: level,
                unlocked: unlocked,
                current: current,
                stars: stars,
                onTap: onTap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// PATH SEGMENT PAINTER (per tile)
// ================================================================

class _PathSegmentPainter extends CustomPainter {
  final double? topXFraction;
  final double bottomXFraction;

  _PathSegmentPainter({
    required this.topXFraction,
    required this.bottomXFraction,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (topXFraction == null) return; // top-most level: nothing above it

    final Offset top = Offset(topXFraction! * size.width, 0);
    final Offset bottom = Offset(bottomXFraction * size.width, size.height);
    final double midY = size.height * 0.5;

    final Offset c0 = Offset(top.dx + (bottom.dx - top.dx) * 0.25, midY);

    final Offset c1 = Offset(top.dx + (bottom.dx - top.dx) * 0.75, midY);

    final path = Path()
      ..moveTo(top.dx, top.dy)
      ..cubicTo(c0.dx, c0.dy, c1.dx, c1.dy, bottom.dx, bottom.dy);

    final borderPaint = Paint()
      ..color = const Color(0xFFB08F63)
      ..strokeWidth = 28
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final paint = Paint()
      ..color =
          const Color(0xFFC9A97E) // dull sandy-tan, matches the stone path
      ..strokeWidth = 24
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, borderPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PathSegmentPainter oldDelegate) {
    return oldDelegate.topXFraction != topXFraction ||
        oldDelegate.bottomXFraction != bottomXFraction;
  }
}

// ================================================================
// LEVEL NODE
// ================================================================

class _LevelNode extends StatelessWidget {
  final int number;
  final bool unlocked;
  final bool current;
  final int stars;
  final VoidCallback onTap;

  const _LevelNode({
    required this.number,
    required this.unlocked,
    required this.current,
    required this.stars,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Three distinct looks, matching the reference art's structure
    // (grey/slate = not reached yet, blue = already cleared) but
    // with the "play me next" node recolored to this game's pink
    // theme instead of the reference's green, + glow halo + bouncing
    // arrow still calling it out.
    late final List<Color> ballColors;
    late final Color rimColor;
    Color glow = Colors.transparent;

    if (current) {
      ballColors = const [Color(0xFFFF9BC4), Color(0xFFE0388C)];
      rimColor = const Color(0xFFFFE8F3);
      glow = const Color(0xFFFF6FAE).withValues(alpha: 0.55);
    } else if (unlocked) {
      ballColors = const [Color(0xFF6FD3FF), Color(0xFF1E5FC2)];
      rimColor = const Color(0xFFE7F8FF);
    } else {
      ballColors = const [Color(0xFF808C99), Color(0xFF3F4852)];
      rimColor = const Color(0xFFD9DEE3);
    }

    return GestureDetector(
      onTap: unlocked ? onTap : null,
      // Fixed-size box, bottom-anchored. Every child below is
      // absolutely positioned from that same bottom edge, so the
      // ball + pedestal sit at one constant height no matter whether
      // stars or the bounce arrow are also being drawn - that's what
      // keeps every node lined up on the path exactly the same way.
      child: SizedBox(
        width: 70,
        height: 132,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            // Small light "socket" ellipse the ball rests on, like
            // the reference's pedestal under every node - sits right
            // where the road ends.
            const Positioned(bottom: 0, child: _Pedestal()),

            // The ball itself, fixed just above the pedestal.
            Positioned(
              bottom: 8,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.35, -0.45),
                    radius: 0.95,
                    colors: [
                      Colors.white.withValues(alpha: 0.55),
                      ballColors.first,
                      ballColors.last,
                    ],
                    stops: const [0.0, 0.35, 1.0],
                  ),
                  border: Border.all(
                    color: rimColor.withValues(alpha: 0.85),
                    width: 2.5,
                  ),
                  boxShadow: [
                    if (current)
                      BoxShadow(color: glow, blurRadius: 22, spreadRadius: 4),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '$number',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Stars - only for levels actually cleared, floating
            // below the pedestal. Purely decorative: since it's
            // absolutely positioned it can never push the ball above
            // it out of place.
            if (stars > 0)
              Positioned(
                bottom: -14,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final bool filled = i < stars;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.5),
                      child: Icon(
                        Icons.star_rounded,
                        size: 20,
                        color: filled
                            ? const Color(0xFFFFD23F)
                            : Colors.white30,
                        shadows: filled
                            ? const [
                                Shadow(
                                  color: Colors.black54,
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                                Shadow(
                                  color: Color(0xFFFFF3B0),
                                  blurRadius: 10,
                                ),
                              ]
                            : const [
                                Shadow(
                                  color: Colors.black45,
                                  blurRadius: 3,
                                  offset: Offset(0, 1),
                                ),
                              ],
                      ),
                    );
                  }),
                ),
              ),

            // Bouncing "play me" arrow - only above the current
            // level, looping gently to draw the eye like the
            // reference, now in the theme's pink instead of green.
            // Absolutely positioned above the ball so it never
            // affects where the ball/pedestal sit.
            if (current) const Positioned(bottom: 88, child: _BounceArrow()),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// PEDESTAL - the little glowing ellipse every node rests on, right
// where the path meets it.
// ================================================================

class _Pedestal extends StatelessWidget {
  const _Pedestal();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 12,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.20),
      ),
    );
  }
}

// ================================================================
// BOUNCE ARROW - loops gently above the current level's node,
// matching the reference art's "play me next" indicator, recolored
// to the game's pink theme.
// ================================================================

class _BounceArrow extends StatefulWidget {
  const _BounceArrow();

  @override
  State<_BounceArrow> createState() => _BounceArrowState();
}

class _BounceArrowState extends State<_BounceArrow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  late final Animation<double> _offset = Tween<double>(
    begin: 0,
    end: 8,
  ).chain(CurveTween(curve: Curves.easeInOut)).animate(_controller);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _offset,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _offset.value),
          child: child,
        );
      },
      child: const Padding(
        padding: EdgeInsets.only(bottom: 4),
        child: Icon(
          Icons.arrow_downward_rounded,
          color: Color(0xFFFF6FAE),
          size: 30,
          shadows: [
            Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// ANIMATED SETTINGS BUTTON
// Gentle idle pulse so the settings button feels alive.
// ================================================================

class _AnimatedSettingsButton extends StatefulWidget {
  final VoidCallback onTap;

  const _AnimatedSettingsButton({required this.onTap});

  @override
  State<_AnimatedSettingsButton> createState() =>
      _AnimatedSettingsButtonState();
}

class _AnimatedSettingsButtonState extends State<_AnimatedSettingsButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  late final Animation<double> _scale = Tween<double>(
    begin: 1.0,
    end: 1.08,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (context, child) {
        return Transform.scale(scale: _scale.value, child: child);
      },
      child: _RoundIconButton(
        icon: Icons.settings_rounded,
        onTap: widget.onTap,
      ),
    );
  }
}

// ================================================================
// SETTINGS DIALOG
// Same layout as the reference (title, X close button, 3 toggle
// rows, Rate Us button) but restyled in the game's pink/peach
// palette instead of purple.
// ================================================================

class _SettingsDialog extends StatefulWidget {
  const _SettingsDialog();

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  // Wire these up to your real audio/haptics manager as needed.
  bool _musicOn = true;
  bool _soundOn = true;
  bool _vibrateOn = true;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFDCEA), Color(0xFFFFC2DC)],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF7A4A3A),
                    shadows: [Shadow(color: Colors.white, blurRadius: 4)],
                  ),
                ),
                const SizedBox(height: 20),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      _SettingsRow(
                        icon: Icons.music_note_rounded,
                        label: 'Music',
                        value: _musicOn,
                        onChanged: (v) => setState(() => _musicOn = v),
                      ),
                      const SizedBox(height: 14),
                      _SettingsRow(
                        icon: Icons.volume_up_rounded,
                        label: 'Sound',
                        value: _soundOn,
                        onChanged: (v) => setState(() => _soundOn = v),
                      ),
                      const SizedBox(height: 14),
                      _SettingsRow(
                        icon: Icons.vibration_rounded,
                        label: 'Vibrate',
                        value: _vibrateOn,
                        onChanged: (v) => setState(() => _vibrateOn = v),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                _PillButton(
                  label: 'Rate Us',
                  icon: Icons.star_rounded,
                  colors: const [Color(0xFFFFD97A), Color(0xFFF2A93B)],
                  onTap: () {
                    // TODO: hook up to your store listing / in_app_review package.
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),

          // Close (X) button, top-right, overlapping the card edge.
          Positioned(
            top: -14,
            right: -8,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE0554C),
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// SETTINGS ROW (icon + label + toggle)
// ================================================================

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Icon badge — small gradient circle instead of a plain icon,
        // matches the node/button style used across the rest of the UI.
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFE7D6), Color(0xFFFFC79B)],
            ),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: const Color(0xFF7A4A3A), size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF7A4A3A),
              letterSpacing: 0.3,
            ),
          ),
        ),
        GestureDetector(
          onTap: () => onChanged(!value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: 68,
            height: 34,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: value
                    ? const [Color(0xFFFFD97A), Color(0xFFF2A93B)]
                    : const [Color(0xFFBFA093), Color(0xFF9C7C6E)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedAlign(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  alignment: value
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: value ? 6 : 0,
                      right: value ? 0 : 6,
                    ),
                    child: Text(
                      value ? 'On' : 'Off',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
                AnimatedAlign(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  alignment: value
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ================================================================
// PILL BUTTON (Rate Us style) — with a springy press animation
// ================================================================

class _PillButton extends StatefulWidget {
  final String label;
  final List<Color> colors;
  final IconData? icon;
  final VoidCallback onTap;

  const _PillButton({
    required this.label,
    required this.colors,
    required this.onTap,
    this.icon,
  });

  @override
  State<_PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<_PillButton>
    with TickerProviderStateMixin {
  // Press animation — squeeze down on tap, pop back with a bounce.
  late final AnimationController _pressController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );

  late final Animation<double> _pressScale = Tween<double>(
    begin: 1,
    end: 0.92,
  ).chain(CurveTween(curve: Curves.easeOut)).animate(_pressController);

  // Idle "plus" animation — a gentle continuous pulse that loops on
  // its own (in addition to the press animation) so the button
  // keeps drawing attention even when nobody is touching it.
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  late final Animation<double> _pulseScale = Tween<double>(
    begin: 1.0,
    end: 1.06,
  ).chain(CurveTween(curve: Curves.easeInOut)).animate(_pulseController);

  @override
  void dispose() {
    _pressController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _pressController.forward();

  void _onTapUp(TapUpDetails _) {
    // Bounce back with a little overshoot for a playful "pop" feel.
    _pressController.reverse().then((_) {
      _pressController.forward(from: 0).then((_) => _pressController.reverse());
    });
    widget.onTap();
  }

  void _onTapCancel() => _pressController.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pressScale, _pulseScale]),
        builder: (context, child) {
          // Both animations stack: the idle pulse plays constantly,
          // the press animation multiplies on top of it when tapped.
          return Transform.scale(
            scale: _pressScale.value * _pulseScale.value,
            child: child,
          );
        },
        child: Container(
          width: double.infinity,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: widget.colors),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: Colors.white, size: 22),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
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
// ROUND ICON BUTTON
// ================================================================

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.55),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 20, color: const Color(0xFF7A4A3A)),
        ),
      ),
    );
  }
}
