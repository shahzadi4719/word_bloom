import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../levels.dart';
import '../word_bloom.dart';
import '../progress_service.dart';

// ─────────────────────────────────────────────────────────────
// Shared pink palette for popups
// ─────────────────────────────────────────────────────────────
const Color _kPink = Color(0xFFE0388C);
const Color _kPinkLight = Color(0xFFFF9BC4);
const Color _kPinkDark = Color(0xFFB0206B);
const Color _kInk = Color(0xFF70465A);
const Color _kInkSoft = Color(0xFF9A607A);

/// Opens a popup with a soft blur, fade and "pop" scale animation.
Future<T?> _showPrettyDialog<T>(BuildContext context, WidgetBuilder builder) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: const Color(0x66381327),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (ctx, _, __) => SafeArea(
      child: Center(
        child: Material(
          type: MaterialType.transparency,
          child: builder(ctx),
        ),
      ),
    ),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeIn,
      );
      return BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 4 * anim.value,
          sigmaY: 4 * anim.value,
        ),
        child: FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1.0).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}

class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({super.key});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen>
    with SingleTickerProviderStateMixin {
  int _unlockedLevel = 1;
  Map<int, int> _levelStars = {};
  bool _progressLoaded = false;

  // TODO: connect to your real coins source, e.g.
  // _coins = await ProgressService.getCoins();  (inside _loadProgress)
  int _coins = 0;

  int get _totalStars => _levelStars.values.fold(0, (a, b) => a + b);

  final ScrollController _scrollController = ScrollController();

  static const int _totalLevels = 2000;

  static const double _nodeSpacing = 172;
  static const double _nodeTop = 55;
  static const double _nodeCenterY = 90; // _nodeTop + 35 (half of 70px sphere)

  // right -> center -> left -> center -> repeat (same as the reference)
  static const List<double> _xPattern = [0.80, 0.50, 0.20, 0.50];

  static double _xFor(int levelIndex) =>
      _xPattern[levelIndex % _xPattern.length];

  // Direction the road travels (left/right) when passing through a node.
  // 0 means the node is on an edge, so the road turns and runs vertically.
  static double _tangentDx(int levelIndex) {
    final double x = _xFor(levelIndex);
    if ((x - 0.5).abs() > 0.01) return 0;
    return (_xFor(levelIndex + 1) - _xFor(levelIndex - 1)).sign;
  }

  @override
  void initState() {
    super.initState();
    _loadProgress(jumpToLevel: true);
  }

  Future<void> _loadProgress({bool jumpToLevel = false}) async {
    final unlocked = await ProgressService.getUnlockedLevel();
    final stars = await ProgressService.getLevelStars();

    if (!mounted) return;

    setState(() {
      _unlockedLevel = unlocked.clamp(1, _totalLevels);
      _levelStars = stars;
      _progressLoaded = true;
    });

    if (jumpToLevel) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToUnlockedLevel();
      });
    }
  }

  void _scrollToUnlockedLevel() {
    if (!_scrollController.hasClients) return;

    final int listIndex = _totalLevels - _unlockedLevel;

    final double targetOffset =
        listIndex * _nodeSpacing - (MediaQuery.of(context).size.height * 0.45);

    final double maxScroll = _scrollController.position.maxScrollExtent;

    final double finalOffset = targetOffset.clamp(0.0, maxScroll);

    _scrollController.jumpTo(finalOffset);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showLevelPreview(int levelNumber) {
    if (levelNumber > _unlockedLevel) return;

    final GameLevel lv = getLevel(levelNumber);

    _showPrettyDialog(
      context,
      (dialogContext) => _LevelPreviewDialog(
        levelNumber: levelNumber,
        wordCount: lv.words.length,
        onClose: () => Navigator.pop(dialogContext),
        onPlay: () {
          Navigator.pop(dialogContext);
          _openLevel(levelNumber);
        },
      ),
    );
  }

  void _openLevel(int levelNumber) {
    if (levelNumber > _unlockedLevel) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WordBloom(
          startLevel: levelNumber,
          onLevelComplete: (level, stars) async {
            await ProgressService.saveLevelResult(level, stars);

            await _loadProgress();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_progressLoaded) {
      return const Scaffold(
        backgroundColor: Color(0xFFFFEDF4),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFD979A7)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFEDF4),
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFFFF4F8),
                      Color(0xFFF9DFEA),
                      Color(0xFFFFEDF4),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(painter: _RoadPainter(_scrollController)),
            ),
            ListView.builder(
              controller: _scrollController,
              reverse: false,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(top: 105, bottom: 100),
              itemCount: _totalLevels,
              itemExtent: _nodeSpacing,
              itemBuilder: (context, listIndex) {
                final int level = _totalLevels - listIndex;
                return _LevelTile(
                  level: level,
                  unlocked: level <= _unlockedLevel,
                  current: level == _unlockedLevel,
                  stars: _levelStars[level] ?? 0,
                  onTap: () => _showLevelPreview(level),
                );
              },
            ),

            // Top bar: coins + stars + settings
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7FA).withValues(alpha: 0.96),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _RoundIconButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () {
                        Navigator.pop(context);
                      },
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatPill(
                        icon: Icons.monetization_on_rounded,
                        iconColor: const Color(0xFFFFB52E),
                        value: '$_coins',
                        showPlus: true,
                        onPlusTap: () {
                          // TODO: open shop / coin store
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatPill(
                        icon: Icons.star_rounded,
                        iconColor: const Color(0xFFFFC43D),
                        value: '$_totalStars',
                      ),
                    ),
                    const SizedBox(width: 10),
                    _AnimatedSettingsButton(
                      onTap: () {
                        _showPrettyDialog(
                          context,
                          (dialogContext) => _SettingsDialog(
                            onClose: () => Navigator.pop(dialogContext),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Bottom "Level N" button
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: Center(
                child: _PillButton(
                  label: 'Level $_unlockedLevel',
                  icon: Icons.play_arrow_rounded,
                  onTap: () => _showLevelPreview(_unlockedLevel),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  final int level;
  final bool unlocked;
  final bool current;
  final int stars;
  final VoidCallback onTap;

  const _LevelTile({
    required this.level,
    required this.unlocked,
    required this.current,
    required this.stars,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // The road is painted by ONE painter behind the list (_RoadPainter),
    // using the same width and the same x-pattern as this node.
    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth;
        return SizedBox(
          width: w,
          height: _LevelSelectScreenState._nodeSpacing,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: _LevelSelectScreenState._xFor(level - 1) * w - 52,
                top: _LevelSelectScreenState._nodeTop,
                width: 104,
                child: _LevelNode(
                  number: level,
                  unlocked: unlocked,
                  current: current,
                  stars: stars,
                  onTap: onTap,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Paints the whole visible road as ONE continuous ribbon.
/// Because it is a single path, there are no seams or stripes.
class _RoadPainter extends CustomPainter {
  final ScrollController controller;

  _RoadPainter(this.controller) : super(repaint: controller);

  static const double _topPad = 105;
  static const double _spacing = _LevelSelectScreenState._nodeSpacing;
  static const double _cy = _LevelSelectScreenState._nodeCenterY;
  static const int _total = _LevelSelectScreenState._totalLevels;

  @override
  void paint(Canvas canvas, Size size) {
    final double offset = controller.hasClients ? controller.offset : 0;

    final int firstList =
        ((offset - _topPad - 300) / _spacing).floor().clamp(0, _total - 1);
    final int lastList = ((offset - _topPad + size.height + 300) / _spacing)
        .ceil()
        .clamp(0, _total - 1);

    // listIndex -> level index (0-based). Bigger listIndex = lower level.
    final int lowIdx = _total - 1 - lastList;
    final int highIdx = _total - 1 - firstList;
    if (highIdx <= lowIdx) return;

    Offset pt(int idx) {
      final int listIndex = _total - 1 - idx;
      return Offset(
        _LevelSelectScreenState._xFor(idx) * size.width,
        _topPad + listIndex * _spacing - offset + _cy,
      );
    }

    final Path path = Path();
    final Offset start = pt(lowIdx);
    path.moveTo(start.dx, start.dy);

    for (int i = lowIdx; i < highIdx; i++) {
      final Offset low = pt(i);
      final Offset top = pt(i + 1);

      final double lowT = _LevelSelectScreenState._tangentDx(i);
      final double topT = _LevelSelectScreenState._tangentDx(i + 1);
      final double dx = (top.dx - low.dx).abs();

      final Offset tLow = lowT != 0 ? Offset(lowT, 0) : const Offset(0, -1);
      final Offset tTop = topT != 0 ? Offset(topT, 0) : const Offset(0, -1);

      final double lenLow = lowT != 0 ? dx * 1.0 : _spacing * 0.62;
      final double lenTop = topT != 0 ? dx * 1.0 : _spacing * 0.62;

      final Offset c1 = low + tLow * lenLow;
      final Offset c2 = top - tTop * lenTop;

      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, top.dx, top.dy);
    }

    Paint stroke(double w) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Soft drop shadow under the ribbon
    canvas.drawPath(
      path.shift(const Offset(0, 5)),
      stroke(60)
        ..color = const Color(0x33B5588F)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Pale outer rim
    canvas.drawPath(path, stroke(58)..color = const Color(0xFFFFF8FB));

    // Main ribbon (pink -> lavender glass feel)
    canvas.drawPath(
      path,
      stroke(48)
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF2C3E3), Color(0xFFE3C6F2), Color(0xFFF2C3E3)],
        ).createShader(Offset.zero & size),
    );

    // Lighter inner lane
    canvas.drawPath(path, stroke(28)..color = const Color(0x55FFFFFF));

    // Thin glossy highlight
    canvas.drawPath(path, stroke(3)..color = const Color(0xAAFFFFFF));
  }

  @override
  bool shouldRepaint(covariant _RoadPainter old) => old.controller != controller;
}

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
    final List<Color> sphereColors = current
        ? const [Color(0xFFFFB3D1), Color(0xFFE0388C)]
        : unlocked
        ? const [Color(0xFFD9C2F5), Color(0xFF9272CC)]
        : const [Color(0xFFDDD0EA), Color(0xFFB2A2C6)];

    return SizedBox(
      width: 104,
      height: 110,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          if (current) const Positioned(top: -58, child: _BounceArrow()),

          // Pulsing pink bloom under the current level
          if (current) const Positioned(top: 33, child: _PedestalGlow()),

          // White pedestal behind the sphere
          const Positioned(top: 46, child: _Pedestal()),

          // Glossy sphere
          Positioned(
            top: 0,
            child: GestureDetector(
              onTap: unlocked ? onTap : null,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.4, -0.45),
                    radius: 0.95,
                    colors: sphereColors,
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.85),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          (current
                                  ? const Color(0xFFFF6FAE)
                                  : const Color(0xFF7B5BB5))
                              .withValues(alpha: current ? 0.45 : 0.28),
                      blurRadius: current ? 20 : 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Glass highlight
                    Positioned(
                      top: 7,
                      left: 13,
                      child: Container(
                        width: 26,
                        height: 13,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                    Text(
                      '$number',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white.withValues(
                          alpha: unlocked ? 1 : 0.8,
                        ),
                        shadows: const [
                          Shadow(
                            color: Color(0x66000000),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Stars arc under the sphere (only after earning some)
          if (stars > 0)
            Positioned(
              top: 66,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  final bool earned = i < stars;
                  return Transform.translate(
                    offset: Offset(0, i == 1 ? 5 : 0),
                    child: Icon(
                      Icons.star_rounded,
                      size: 21,
                      color: earned
                          ? const Color(0xFFFFC43D)
                          : Colors.white.withValues(alpha: 0.6),
                      shadows: const [
                        Shadow(
                          color: Color(0x55B56B00),
                          blurRadius: 3,
                          offset: Offset(0, 1.5),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class _Pedestal extends StatelessWidget {
  const _Pedestal();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 82,
      height: 30,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.elliptical(41, 15)),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Color(0xFFEBDDF0)],
        ),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8A5C9E).withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
    );
  }
}

class _BounceArrow extends StatefulWidget {
  const _BounceArrow();

  @override
  State<_BounceArrow> createState() => _BounceArrowState();
}

class _BounceArrowState extends State<_BounceArrow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) {
        final double offset =
            Curves.easeInOut.transform(_controller.value) * 10;
        return Transform.translate(offset: Offset(0, offset), child: child);
      },
      child: const SizedBox(
        width: 44,
        height: 52,
        child: CustomPaint(painter: _ArrowPainter()),
      ),
    );
  }
}

/// Chunky glossy pink arrow (like a classic game level arrow).
class _ArrowPainter extends CustomPainter {
  const _ArrowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Path arrow = Path()
      ..moveTo(14, 3)
      ..lineTo(30, 3)
      ..lineTo(30, 24)
      ..lineTo(41, 24)
      ..lineTo(22, 48)
      ..lineTo(3, 24)
      ..lineTo(14, 24)
      ..close();

    // soft glow
    canvas.drawPath(
      arrow,
      Paint()
        ..color = const Color(0x88FF6FAE)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // body
    canvas.drawPath(
      arrow,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFB3D1), Color(0xFFE0388C)],
        ).createShader(const Rect.fromLTWH(0, 0, 44, 52)),
    );

    // outline
    canvas.drawPath(
      arrow,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFFB0206B),
    );

    // glossy highlight on the shaft
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(17, 7, 4, 13),
        const Radius.circular(3),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter oldDelegate) => false;
}

/// Soft pulsing pink glow ("bloom") around the current level's pedestal.
class _PedestalGlow extends StatefulWidget {
  const _PedestalGlow();

  @override
  State<_PedestalGlow> createState() => _PedestalGlowState();
}

class _PedestalGlowState extends State<_PedestalGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final double t = Curves.easeInOut.transform(_controller.value);
        return Transform.scale(
          scale: 0.9 + 0.2 * t,
          child: Container(
            width: 112,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.elliptical(56, 26)),
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFFF6FAE).withValues(alpha: 0.35 + 0.35 * t),
                  const Color(0xFFFF6FAE).withValues(alpha: 0.12 + 0.1 * t),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF4F9F)
                      .withValues(alpha: 0.35 + 0.35 * t),
                  blurRadius: 18 + 12 * t,
                  spreadRadius: 2 + 4 * t,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Pill that shows a value (coins / stars) with an icon on the left.
class _StatPill extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final bool showPlus;
  final VoidCallback? onPlusTap;

  const _StatPill({
    required this.icon,
    required this.iconColor,
    required this.value,
    this.showPlus = false,
    this.onPlusTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.fromLTRB(6, 0, 5, 0),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _kPinkLight.withValues(alpha: 0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _kPink.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 30,
            color: iconColor,
            shadows: const [
              Shadow(
                color: Color(0x55B56B00),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _kInk,
                ),
              ),
            ),
          ),
          if (showPlus)
            GestureDetector(
              onTap: onPlusTap,
              child: Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_kPinkLight, _kPink],
                  ),
                ),
                child: const Icon(Icons.add_rounded, size: 20, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

class _AnimatedSettingsButton extends StatefulWidget {
  final VoidCallback onTap;

  const _AnimatedSettingsButton({required this.onTap});

  @override
  State<_AnimatedSettingsButton> createState() =>
      _AnimatedSettingsButtonState();
}

class _AnimatedSettingsButtonState extends State<_AnimatedSettingsButton>
    with TickerProviderStateMixin {
  // Slow endless gear rotation + glow pulse
  late final AnimationController _idle;
  // Extra spin + squish when tapped
  late final AnimationController _tap;

  @override
  void initState() {
    super.initState();

    _idle = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _tap = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
  }

  @override
  void dispose() {
    _idle.dispose();
    _tap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _tap.forward(from: 0);
        widget.onTap();
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([_idle, _tap]),
        builder: (_, __) {
          final double glow =
              0.5 + 0.5 * math.sin(_idle.value * 2 * math.pi * 4);
          final double rotation = _idle.value * 2 * math.pi +
              Curves.easeOutBack.transform(_tap.value) * math.pi;
          final double scale = 1 - 0.1 * math.sin(_tap.value * math.pi);

          return Transform.scale(
            scale: scale,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  center: Alignment(-0.4, -0.5),
                  radius: 1.0,
                  colors: [Color(0xFFFFB3D1), Color(0xFFE0388C)],
                ),
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: _kPink.withValues(alpha: 0.28 + 0.2 * glow),
                    blurRadius: 10 + 8 * glow,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // glass highlight
                  Positioned(
                    top: 4,
                    left: 9,
                    child: Container(
                      width: 18,
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                  Transform.rotate(
                    angle: rotation,
                    child: const Icon(
                      Icons.settings_rounded,
                      size: 25,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Color(0x55000000),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Reusable popup shell: card + floating badge + close button
// ─────────────────────────────────────────────────────────────
class _DialogShell extends StatelessWidget {
  final Widget badge;
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final VoidCallback onClose;

  const _DialogShell({
    required this.badge,
    required this.title,
    required this.children,
    required this.onClose,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            // Card
            Container(
              margin: const EdgeInsets.only(top: 46),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFFFFFF),
                    Color(0xFFFFF0F6),
                    Color(0xFFFFDDEA),
                  ],
                ),
                borderRadius: BorderRadius.circular(34),
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: _kPink.withValues(alpha: 0.28),
                    blurRadius: 40,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Stack(
                  children: [
                    // Soft pink glow at the top of the card
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 130,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              _kPinkLight.withValues(alpha: 0.45),
                              _kPinkLight.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Decorative sparkles
                    Positioned(
                      top: 22,
                      left: 22,
                      child: Icon(
                        Icons.auto_awesome,
                        size: 16,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    Positioned(
                      top: 60,
                      left: 44,
                      child: Icon(
                        Icons.circle,
                        size: 6,
                        color: _kPinkLight.withValues(alpha: 0.7),
                      ),
                    ),
                    Positioned(
                      top: 30,
                      right: 62,
                      child: Icon(
                        Icons.auto_awesome,
                        size: 11,
                        color: _kPinkLight.withValues(alpha: 0.9),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 58, 20, 22),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: _kInk,
                              letterSpacing: 0.3,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _kPinkLight.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Text(
                                subtitle!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _kInkSoft,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          ...children,
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Floating badge
            Positioned(top: 0, child: badge),

            // Close button
            Positioned(
              top: 58,
              right: 14,
              child: GestureDetector(
                onTap: onClose,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: _kPink.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: _kInk,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Round glossy badge that floats over the top edge of a popup.
class _DialogBadge extends StatelessWidget {
  final Widget child;
  final List<Color> colors;

  const _DialogBadge({required this.child, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: _kPink.withValues(alpha: 0.35),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.4, -0.45),
            radius: 1.0,
            colors: colors,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 9,
              left: 18,
              child: Container(
                width: 32,
                height: 15,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Level preview popup
// ─────────────────────────────────────────────────────────────
class _LevelPreviewDialog extends StatelessWidget {
  final int levelNumber;
  final int wordCount;
  final VoidCallback onPlay;
  final VoidCallback onClose;

  const _LevelPreviewDialog({
    required this.levelNumber,
    required this.wordCount,
    required this.onPlay,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return _DialogShell(
      onClose: onClose,
      title: 'Word Bloom',
      subtitle: 'Level $levelNumber',
      badge: _DialogBadge(
        colors: const [Color(0xFFFFB3D1), Color(0xFFE0388C)],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: FittedBox(
            child: Text(
              '$levelNumber',
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: Color(0x66000000),
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      children: [
        // Goal guide
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white),
            boxShadow: [
              BoxShadow(
                color: _kPink.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(17),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFC3A6F2), Color(0xFF8E6CCF)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8E6CCF).withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.text_fields_rounded,
                  size: 27,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'YOUR GOAL',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                        color: _kInkSoft,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      wordCount == 1
                          ? 'Make 1 word'
                          : 'Make $wordCount words',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: _kInk,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _PillButton(
          label: 'PLAY',
          icon: Icons.play_arrow_rounded,
          onTap: onPlay,
          expand: true,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Settings popup
// ─────────────────────────────────────────────────────────────
class _SettingsDialog extends StatelessWidget {
  final VoidCallback onClose;

  const _SettingsDialog({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return _DialogShell(
      onClose: onClose,
      title: 'Settings',
      badge: const _DialogBadge(
        colors: [Color(0xFFFFB3D1), Color(0xFFE0388C)],
        child: Icon(
          Icons.settings_rounded,
          size: 44,
          color: Colors.white,
          shadows: [
            Shadow(color: Color(0x55000000), blurRadius: 5, offset: Offset(0, 2)),
          ],
        ),
      ),
      children: [
        const _SettingsRow(
          icon: Icons.music_note_rounded,
          label: 'Music',
          colors: [Color(0xFFFF9BC4), Color(0xFFE0388C)],
        ),
        const SizedBox(height: 10),
        const _SettingsRow(
          icon: Icons.volume_up_rounded,
          label: 'Sound',
          colors: [Color(0xFFC3A6F2), Color(0xFF8E6CCF)],
        ),
        const SizedBox(height: 10),
        const _SettingsRow(
          icon: Icons.vibration_rounded,
          label: 'Vibrate',
          colors: [Color(0xFFFFB199), Color(0xFFFF7A59)],
        ),
        const SizedBox(height: 20),
        _PillButton(
          label: 'RATE US',
          icon: Icons.star_rounded,
          expand: true,
          onTap: onClose,
        ),
        const SizedBox(height: 12),
        const Text(
          'Word Bloom  •  v1.0',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _kInkSoft,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _SettingsRow extends StatefulWidget {
  final IconData icon;
  final String label;
  final List<Color> colors;

  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.colors,
  });

  @override
  State<_SettingsRow> createState() => _SettingsRowState();
}

class _SettingsRowState extends State<_SettingsRow> {
  bool enabled = true;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => enabled = !enabled),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white),
          boxShadow: [
            BoxShadow(
              color: _kPink.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: enabled
                      ? widget.colors
                      : const [Color(0xFFD9D2D6), Color(0xFFB9B0B5)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (enabled ? widget.colors.last : Colors.grey)
                        .withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(widget.icon, size: 23, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _kInk,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    enabled ? 'On' : 'Off',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: enabled ? _kPink : const Color(0xFFA89EA3),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              width: 54,
              height: 30,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: LinearGradient(
                  colors: enabled
                      ? const [_kPinkLight, _kPink]
                      : const [Color(0xFFD5CDD1), Color(0xFFBDB4B9)],
                ),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                alignment:
                    enabled ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PillButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool expand;

  const _PillButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.expand = false,
  });

  @override
  State<_PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<_PillButton>
    with TickerProviderStateMixin {
  late final AnimationController _pressController;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      lowerBound: 0.92,
      upperBound: 1.0,
      value: 1.0,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pressController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        _pressController.reverse();
      },
      onTapUp: (_) {
        _pressController.forward();
        widget.onTap();
      },
      onTapCancel: () {
        _pressController.forward();
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([_pressController, _pulseController]),
        builder: (_, child) {
          final double pulse = Tween<double>(
            begin: 1,
            end: 1.04,
          ).evaluate(_pulseController);

          return Transform.scale(
            scale: pulse * _pressController.value,
            child: child,
          );
        },
        child: Container(
          width: widget.expand ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFA9CF), Color(0xFFEC4C9B), Color(0xFFD42D82)],
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.85),
              width: 2,
            ),
            boxShadow: [
              // "3D" bottom edge
              const BoxShadow(color: _kPinkDark, offset: Offset(0, 4)),
              BoxShadow(
                color: _kPink.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: Colors.white, size: 24),
              const SizedBox(width: 7),
              Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                  shadows: [
                    Shadow(
                      color: Color(0x55000000),
                      blurRadius: 3,
                      offset: Offset(0, 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 44,
          height: 44,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.5),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.7),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF70465A)),
        ),
      ),
    );
  }
}