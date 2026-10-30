import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../levels.dart';
import '../bloom_visuals.dart';
import '../booster_shop.dart' show showBoosterShop;
import '../game_mode.dart';
import '../word_bloom.dart';
import '../progress_service.dart';
import '../gift_service.dart';
import '../gift_box.dart';
import '../sound_service.dart';

// ─────────────────────────────────────────────────────────────
// Shared pink palette for popups
// ─────────────────────────────────────────────────────────────
const Color _kPink = Color(0xFFE0388C);
const Color _kPinkLight = Color(0xFFFF9BC4);
const Color _kPinkDark = Color(0xFFB0206B);
const Color _kInk = Color(0xFF70465A);

/// Opens a popup with a soft blur, fade and "pop" scale animation.
Future<T?> _showPrettyDialog<T>(BuildContext context, WidgetBuilder builder) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: const Color(0x66381327),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (ctx, _, _) => SafeArea(
      child: Center(
        child: Material(type: MaterialType.transparency, child: builder(ctx)),
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
  final GameMode mode;
  const LevelSelectScreen({super.key, this.mode = GameMode.wordBloom});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen>
    with SingleTickerProviderStateMixin {
  int _unlockedLevel = 1;
  Map<int, int> _levelStars = {};
  bool _progressLoaded = false;

  // Coins are now loaded from GiftService (see _loadProgress).
  // If you already have your own coins source, change
  // GiftService.getCoins(mode: widget.mode) / addCoins() inside gift_service.dart.
  int _coins = 0;

  // Gift boxes that the player has already opened.
  Set<int> _openedGifts = {};

  final ScrollController _scrollController = ScrollController();

  int _totalLevels = 200;
  bool _mapReady = false;
  bool _extendingMap = false;

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
    _scrollController.addListener(_extendMapWhenNeeded);
    SoundService.instance.playMenuMusic();
    SoundService.instance.ensureStarted(); // background nature music
    _loadProgress(jumpToLevel: true);
  }

  Future<void> _loadProgress({bool jumpToLevel = false}) async {
    final unlocked = await ProgressService.getUnlockedLevel(mode: widget.mode);
    final stars = await ProgressService.getLevelStars(mode: widget.mode);
    final coins = await GiftService.getCoins(mode: widget.mode);
    final openedGifts = await GiftService.getOpenedGifts(mode: widget.mode);

    if (!mounted) return;

    setState(() {
      _unlockedLevel = math.max(1, unlocked);
      _totalLevels = math.max(
        _totalLevels,
        visibleLevelCountFor(_unlockedLevel),
      );
      _levelStars = stars;
      _coins = coins;
      _openedGifts = openedGifts;
      _progressLoaded = true;
    });

    if (jumpToLevel) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToUnlockedLevel();
        _mapReady = true;
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

  // Higher levels sit above the current path. Prepend a batch before the
  // player reaches the top, then compensate for its height so the same
  // level stays at the same screen position.
  void _extendMapWhenNeeded() {
    if (!_mapReady ||
        _extendingMap ||
        !mounted ||
        !_scrollController.hasClients) {
      return;
    }
    if (_scrollController.offset > _nodeSpacing * 4) return;

    _extendingMap = true;
    final double previousOffset = _scrollController.offset;
    setState(() => _totalLevels += levelMapBatchSize);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scrollController.hasClients) {
        final position = _scrollController.position;
        _scrollController.jumpTo(
          (previousOffset + levelMapBatchSize * _nodeSpacing).clamp(
            position.minScrollExtent,
            position.maxScrollExtent,
          ),
        );
      }
      _extendingMap = false;
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_extendMapWhenNeeded);
    _scrollController.dispose();
    super.dispose();
  }

  // ── Gift boxes ──────────────────────────────────────────────

  void _showGiftHint(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          backgroundColor: _kPink,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1600),
          shape: const StadiumBorder(),
          margin: const EdgeInsets.fromLTRB(40, 0, 40, 90),
        ),
      );
  }

  Future<void> _onGiftTap(int giftLevel, GiftState state) async {
    SoundService.instance.click();
    if (state == GiftState.locked) {
      _showGiftHint('Complete level $giftLevel to unlock this gift');
      return;
    }
    if (state == GiftState.opened) {
      _showGiftHint('You already opened this gift');
      return;
    }

    // Random rewards are picked and saved right here.
    final List<GiftReward> rewards = await GiftService.open(
      giftLevel,
      mode: widget.mode,
    );
    if (!mounted || rewards.isEmpty) return;

    await showGiftOpenDialog(context, rewards);
    if (!mounted) return;

    final int coins = await GiftService.getCoins(mode: widget.mode);
    if (!mounted) return;
    setState(() {
      _coins = coins;
      _openedGifts = {..._openedGifts, giftLevel};
    });
  }

  void _showLevelPreview(int levelNumber) {
    if (levelNumber > _unlockedLevel) return;
    SoundService.instance.click();

    final GameLevel lv = getLevel(levelNumber, mode: widget.mode);

    _showPrettyDialog(
      context,
      (dialogContext) => _LevelPreviewDialog(
        levelNumber: levelNumber,
        mode: widget.mode,
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
          mode: widget.mode,
          onLevelComplete: (level, stars) async {
            // Gameplay has already persisted this mode’s result.

            await _loadProgress(jumpToLevel: true);
          },
        ),
      ),
    ).then((_) {
      // Coins are saved while playing, so refresh them when coming back
      // (also when the player leaves without finishing the level).
      if (mounted) _loadProgress();
    });
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-screen background picture (also behind status bar / bottom)
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg_level_select.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
              gaplessPlayback: true,
              errorBuilder: (context, error, stack) => const DecoratedBox(
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
          ),
          SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _RoadPainter(_scrollController, _totalLevels),
                  ),
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

                // GIFT BOXES on the road (after every 11 levels + a few extra)
                Positioned.fill(
                  child: GiftPathLayer(
                    controller: _scrollController,
                    unlockedLevel: _unlockedLevel,
                    openedGifts: _openedGifts,
                    totalLevels: _totalLevels,
                    nodeSpacing: _nodeSpacing,
                    topPad: 105,
                    nodeCenterY: _nodeCenterY,
                    xPattern: _xPattern,
                    onGiftTap: _onGiftTap,
                  ),
                ),

                // Top bar: coins + stars + settings
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    // transparent: the background picture shows through
                    // (only the pills / buttons themselves stay visible)
                    child: Row(
                      children: [
                        BloomBackButton(
                          onTap: () {
                            Navigator.pop(context);
                          },
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatPill(
                            icon: Icons.monetization_on_rounded,
                            iconColor: const Color(0xFFFFB52E),
                            leading: const CoinIcon(size: 30),
                            value: '$_coins',
                            showPlus: true,
                            onPlusTap: () {
                              showBoosterShop(context, mode: widget.mode).then((
                                _,
                              ) {
                                if (mounted) _loadProgress();
                              });
                            },
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
              ],
            ),
          ),
        ],
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

  _RoadPainter(this.controller, this._total) : super(repaint: controller);

  static const double _topPad = 105;
  static const double _spacing = _LevelSelectScreenState._nodeSpacing;
  static const double _cy = _LevelSelectScreenState._nodeCenterY;
  final int _total;

  @override
  void paint(Canvas canvas, Size size) {
    final double offset = controller.hasClients ? controller.offset : 0;

    final int firstList = ((offset - _topPad - 300) / _spacing).floor().clamp(
      0,
      _total - 1,
    );
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
        ..color = const Color(0x22E58AB8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Soft pink outer rim (no white)
    canvas.drawPath(path, stroke(58)..color = const Color(0x88FFB6D5));

    // Main ribbon (deeper pink -> lilac, matches background)
    canvas.drawPath(
      path,
      stroke(48)
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xCCFFD0E5), Color(0xCCEBD3FA), Color(0xCCFFD0E5)],
        ).createShader(Offset.zero & size),
    );

    // Slightly lighter inner lane (pink tint, not white)
    canvas.drawPath(path, stroke(28)..color = const Color(0x55FFEAF3));

    // Thin soft highlight
    canvas.drawPath(path, stroke(3)..color = const Color(0x88FFF3F8));
  }

  @override
  bool shouldRepaint(covariant _RoadPainter old) =>
      old.controller != controller || old._total != _total;
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
        ? const [Color(0xFFFFD0B0), Color(0xFFF2845C)]
        : unlocked
        ? const [Color(0xFFFFB3D1), Color(0xFFE0388C)]
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
                                  ? const Color(0xFFF5A27E)
                                  : const Color(0xFFE0388C))
                              .withValues(alpha: current ? 0.5 : 0.28),
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
          colors: [Color(0xFFFFE3F0), Color(0xFFF3C4E0)],
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
        ..color = const Color(0x88F5A27E)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // body
    canvas.drawPath(
      arrow,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFD0B0), Color(0xFFF2845C)],
        ).createShader(const Rect.fromLTWH(0, 0, 44, 52)),
    );

    // outline
    canvas.drawPath(
      arrow,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFFB5502E),
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
      builder: (_, _) {
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
                  const Color(0xFFF5A27E).withValues(alpha: 0.35 + 0.35 * t),
                  const Color(0xFFF5A27E).withValues(alpha: 0.12 + 0.1 * t),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(
                    0xFFFFB08A,
                  ).withValues(alpha: 0.35 + 0.35 * t),
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

  /// Optional custom icon widget (used for the coin) instead of [icon].
  final Widget? leading;

  const _StatPill({
    required this.icon,
    required this.iconColor,
    this.leading,
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
        border: Border.all(
          color: _kPinkLight.withValues(alpha: 0.6),
          width: 1.5,
        ),
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
          leading ??
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
              onTap: () {
                SoundService.instance.click();
                onPlusTap?.call();
              },
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
                child: const Icon(
                  Icons.add_rounded,
                  size: 20,
                  color: Colors.white,
                ),
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
        SoundService.instance.click();
        _tap.forward(from: 0);
        widget.onTap();
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([_idle, _tap]),
        builder: (_, _) {
          final double glow =
              0.5 + 0.5 * math.sin(_idle.value * 2 * math.pi * 4);
          final double rotation =
              _idle.value * 2 * math.pi +
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
  final List<Widget> children;
  final VoidCallback onClose;

  const _DialogShell({
    required this.badge,
    required this.title,
    required this.children,
    required this.onClose,
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
                          BloomDialogTitle(title, size: 26),
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
              child: BloomCloseButton(
                onTap: () {
                  SoundService.instance.click();
                  onClose();
                },
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
  final GameMode mode;
  final int levelNumber;
  final int wordCount;
  final VoidCallback onPlay;
  final VoidCallback onClose;

  const _LevelPreviewDialog({
    required this.mode,
    required this.levelNumber,
    required this.wordCount,
    required this.onPlay,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return _DialogShell(
      onClose: onClose,
      title: mode.title,
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
        BloomGoalAnimation(mode: mode, height: 106),
        Text(
          mode.isWordMode
              ? (wordCount == 1 ? 'Make 1 word' : 'Make $wordCount words')
              : mode == GameMode.colorMatch
              ? 'Match 3 of one color'
              : 'Match 3 of one letter',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Fredoka',
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Color(0xFFBA3A87),
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
            Shadow(
              color: Color(0x55000000),
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
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
  void initState() {
    super.initState();
    // Music / Sound switches are real now (saved on the phone).
    if (widget.label == 'Music') enabled = SoundService.instance.musicOn;
    if (widget.label == 'Sound') enabled = SoundService.instance.soundOn;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() => enabled = !enabled);
        if (widget.label == 'Music') {
          SoundService.instance.setMusicOn(enabled);
        } else if (widget.label == 'Sound') {
          SoundService.instance.setSoundOn(enabled);
        } else {
          SoundService.instance.click();
        }
      },
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
                  BloomAnimatedLabel(widget.label, size: 20),
                  const SizedBox(height: 3),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: Text(
                      enabled ? 'On' : 'Off',
                      key: ValueKey(enabled),
                      style: TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: enabled
                            ? const Color(0xFFC3458D)
                            : const Color(0xFF9C8A95),
                      ),
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
                alignment: enabled
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
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
        SoundService.instance.click();
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
