import 'package:flutter/material.dart';

import '../levels.dart';
import '../word_bloom.dart';
import '../progress_service.dart';

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
    final int stars = _levelStars[levelNumber] ?? 0;

    final String lengthLabel = lv.words.length <= 3
        ? 'Short'
        : lv.words.length <= 5
        ? 'Medium'
        : 'Long';

    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 28,
            vertical: 24,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFE8F2), Color(0xFFF8D2E2)],
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.9),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFB56B8D).withValues(alpha: 0.25),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'LEVEL',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: Color(0xFF9A607A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$levelNumber',
                  style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF7B405D),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'World 1 • Misty Cliff',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF9A607A),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _InfoBox(
                        icon: Icons.auto_awesome,
                        title: 'Difficulty',
                        value: lv.difficulty,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _InfoBox(
                        icon: Icons.text_fields_rounded,
                        title: 'Words',
                        value: '${lv.words.length}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _InfoBox(
                        icon: Icons.short_text_rounded,
                        title: 'Length',
                        value: lengthLabel,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _InfoBox(
                        icon: Icons.star_rounded,
                        title: 'Stars',
                        value: '$stars / 3',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    3,
                    (index) => Icon(
                      index < stars
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      size: 27,
                      color: const Color(0xFFFFB52E),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _PillButton(
                  label: 'PLAY',
                  icon: Icons.play_arrow_rounded,
                  onTap: () {
                    Navigator.pop(context);
                    _openLevel(levelNumber);
                  },
                ),
              ],
            ),
          ),
        );
      },
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

            // Top bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'World 1',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF9A607A),
                            ),
                          ),
                          SizedBox(height: 1),
                          Text(
                            'Misty Cliff',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF70465A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _AnimatedSettingsButton(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => const _SettingsDialog(),
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
          if (current) const Positioned(top: -40, child: _BounceArrow()),

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
      duration: const Duration(milliseconds: 700),
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
        final double offset = Tween<double>(
          begin: 0,
          end: 8,
        ).evaluate(_controller);

        return Transform.translate(offset: Offset(0, offset), child: child);
      },
      child: const Icon(
        Icons.arrow_downward_rounded,
        size: 36,
        color: Color(0xFFF06BAA),
        shadows: [
          Shadow(color: Colors.white, blurRadius: 8),
          Shadow(
            color: Color(0x55E0388C),
            blurRadius: 10,
            offset: Offset(0, 3),
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
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
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
        final double scale = Tween<double>(
          begin: 1,
          end: 1.08,
        ).evaluate(_controller);

        return Transform.scale(scale: scale, child: child);
      },
      child: _RoundIconButton(
        icon: Icons.settings_rounded,
        onTap: widget.onTap,
      ),
    );
  }
}

class _SettingsDialog extends StatelessWidget {
  const _SettingsDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFE8F2), Color(0xFFF6CFDF)],
          ),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.9),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFB56B8D).withValues(alpha: 0.25),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Settings',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w900,
                color: Color(0xFF70465A),
              ),
            ),
            const SizedBox(height: 18),
            const _SettingsRow(icon: Icons.music_note_rounded, label: 'Music'),
            const SizedBox(height: 10),
            const _SettingsRow(icon: Icons.volume_up_rounded, label: 'Sound'),
            const SizedBox(height: 10),
            const _SettingsRow(icon: Icons.vibration_rounded, label: 'Vibrate'),
            const SizedBox(height: 18),
            _PillButton(
              label: 'RATE US',
              icon: Icons.star_rounded,
              onTap: () {
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Color(0xFF70465A),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatefulWidget {
  final IconData icon;
  final String label;

  const _SettingsRow({required this.icon, required this.label});

  @override
  State<_SettingsRow> createState() => _SettingsRowState();
}

class _SettingsRowState extends State<_SettingsRow> {
  bool enabled = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.65),
            ),
            child: Icon(widget.icon, size: 20, color: const Color(0xFF9A607A)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF70465A),
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                enabled = !enabled;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 52,
              height: 29,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                color: enabled
                    ? const Color(0xFFE0388C)
                    : const Color(0xFFB5B5B5),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 220),
                alignment: enabled
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  width: 23,
                  height: 23,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PillButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _PillButton({
    required this.label,
    required this.icon,
    required this.onTap,
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
            end: 1.06,
          ).evaluate(_pulseController);

          return Transform.scale(
            scale: pulse * _pressController.value,
            child: child,
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF9BC4), Color(0xFFE0388C)],
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.8),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE0388C).withValues(alpha: 0.3),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: Colors.white, size: 20),
              const SizedBox(width: 7),
              Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
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

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoBox({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.white.withValues(alpha: 0.65)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: const Color(0xFFB15F83)),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF9A607A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF70465A),
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