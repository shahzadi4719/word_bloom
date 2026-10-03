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

  int _unlockedLevel = 1;

  final Map<int, int> _levelStars = {};

  bool _progressLoaded = false;

  final ScrollController _scrollController = ScrollController();

  // ==============================================================
  // WORLD 1 — auto-generated levels
  // ==============================================================

  static const int _totalLevels = 2000;

  static const double _nodeSpacing = 150;

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
  // PERSISTENCE
  // ==============================================================

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

    // CHANGED: label now comes from levels.dart (single source of truth)
    final String lengthText = lengthLabelFor(levelNumber);

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
      backgroundColor: const Color(0xFFE3C6B4),
      body: Stack(
        fit: StackFit.expand,
        children: [
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
// ================================================================

class _LevelTile extends StatelessWidget {
  final double screenWidth;
  final double? topXFraction;
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
          Positioned.fill(
            child: CustomPaint(
              painter: _PathSegmentPainter(
                topXFraction: topXFraction,
                bottomXFraction: bottomXFraction,
              ),
            ),
          ),
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
    if (topXFraction == null) return;

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
      ..color = const Color(0xFFC9A97E)
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
      child: SizedBox(
        width: 70,
        height: 132,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            const Positioned(bottom: 0, child: _Pedestal()),
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
            if (current) const Positioned(bottom: 88, child: _BounceArrow()),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// PEDESTAL
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
// BOUNCE ARROW
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
// ================================================================

class _SettingsDialog extends StatefulWidget {
  const _SettingsDialog();

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
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
// PILL BUTTON
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
  late final AnimationController _pressController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );

  late final Animation<double> _pressScale = Tween<double>(
    begin: 1,
    end: 0.92,
  ).chain(CurveTween(curve: Curves.easeOut)).animate(_pressController);

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