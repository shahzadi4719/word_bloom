import 'package:flutter/material.dart';
import 'dart:math';

import '../levels.dart';
import '../bubble.dart'; // <-- change this import to wherever your Bubble class file actually is

class GameScreen extends StatefulWidget {
  final int level;

  const GameScreen({
    super.key,
    required this.level,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  Offset? _startPoint;
  Offset? _currentPoint;

  // ==============================================================
  // BOARD BUBBLES
  // ==============================================================
  late List<Bubble> _boardBubbles;

  // ==============================================================
  // ENTRANCE ANIMATION (bottom -> top, staggered, bouncy landing)
  // ==============================================================
  late final AnimationController _entranceController;

  static const List<Color> _bubbleColors = [
    Color(0xFF3FB6FF), // blue
    Color(0xFFFF9E2C), // orange
    Color(0xFFFF5C93), // pink
    Color(0xFF57D68D), // green
    Color(0xFFC583FF), // purple
  ];

  @override
  void initState() {
    super.initState();

    final level = getLevel(widget.level);
    _boardBubbles = _generateBoard(level.letters);

    _entranceController = AnimationController(
      vsync: this,
      // Total time for the whole spawn sequence. Individual bubbles
      // are staggered inside this window (see _animatedYFor).
      duration: const Duration(milliseconds: 1400),
    )..forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  // ==============================================================
  // BOARD GENERATION
  // Lays letters out in a hex-packed grid (offset every other row),
  // same shape as classic bubble-shooter boards.
  // ==============================================================
  List<Bubble> _generateBoard(List<String> letters) {
    const int cols = 8;
    const double radius = 0.052;
    const double startY = 0.10;
    const double rowHeight = radius * 1.8;

    final rng = Random(letters.length);
    final bubbles = <Bubble>[];

    for (int i = 0; i < letters.length; i++) {
      final row = i ~/ cols;
      final col = i % cols;
      final bool offsetRow = row.isOdd;

      final double x =
          0.10 + col * (radius * 2) + (offsetRow ? radius : 0.0);
      final double y = startY + row * rowHeight;

      bubbles.add(
        Bubble(
          x: x.clamp(0.06, 0.94),
          y: y,
          letter: letters[i],
          color: _bubbleColors[rng.nextInt(_bubbleColors.length)],
          radius: radius,
        ),
      );
    }

    return bubbles;
  }

  // ==============================================================
  // Computes a bubble's CURRENT y (0-1 normalized) at this point in
  // the entrance animation. Each bubble starts just below the
  // bottom of the screen and eases up into its final board position
  // with a slight overshoot ("bounce") thanks to easeOutBack.
  //
  // Bubbles are staggered by index so they don't all fly up at once
  // - earlier bubbles (top of board) start a beat before later ones,
  // matching the reference gif's cascading feel.
  // ==============================================================
  double _animatedYFor(int index, int total, Bubble bubble) {
    final double staggerStart =
        total > 1 ? (index / total) * 0.5 : 0.0; // spread over first half
    final double start = staggerStart.clamp(0.0, 0.5);
    final double end = (start + 0.5).clamp(0.0, 1.0);

    final double t = _entranceController.value;
    final double localT = end > start
        ? ((t - start) / (end - start)).clamp(0.0, 1.0)
        : 1.0;

    final double curvedT = Curves.easeOutBack.transform(localT);

    const double belowScreen = 1.18;
    return belowScreen + (bubble.y - belowScreen) * curvedT;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);

          return GestureDetector(
            onPanStart: (details) {
              setState(() {
                _startPoint = details.localPosition;
                _currentPoint = details.localPosition;
              });
            },
            onPanUpdate: (details) {
              setState(() {
                _currentPoint = details.localPosition;
              });
            },
            onPanEnd: (_) {
              setState(() {
                _startPoint = null;
                _currentPoint = null;
              });
            },
            child: Stack(
              children: [
                // ======================================
                // BACKGROUND
                // ======================================
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF55BFFF),
                        Color(0xFF9BDDF5),
                        Color(0xFFB8E6C1),
                        Color(0xFFFFD6A5),
                      ],
                    ),
                  ),
                ),

                // ======================================
                // BOARD BUBBLES (glossy + spawn animation)
                // ======================================
                AnimatedBuilder(
                  animation: _entranceController,
                  builder: (context, _) {
                    return Stack(
                      children: List.generate(_boardBubbles.length, (i) {
                        final bubble = _boardBubbles[i];
                        final double animatedY = _animatedYFor(
                          i,
                          _boardBubbles.length,
                          bubble,
                        );

                        final double diameter =
                            bubble.radius * 2 * size.width;

                        return Positioned(
                          left: bubble.x * size.width - diameter / 2,
                          top: animatedY * size.height - diameter / 2,
                          width: diameter,
                          height: diameter,
                          child: _GlossyBubble(
                            letter: bubble.letter,
                            color: bubble.color,
                            size: diameter,
                          ),
                        );
                      }),
                    );
                  },
                ),

                // ======================================
                // AIMING LINE (on top of bubbles)
                // ======================================
                CustomPaint(
                  size: size,
                  painter: _AimingLinePainter(
                    startPoint: _startPoint,
                    currentPoint: _currentPoint,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ================================================================
// GLOSSY BUBBLE WIDGET
// Radial gradient + white highlight + soft shadow, matching the
// shiny reference art (light spot top-left, darker shade bottom).
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
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.35, -0.45),
          radius: 0.95,
          colors: [
            Colors.white.withOpacity(0.65),
            color,
            color.withOpacity(0.85),
          ],
          stops: const [0.0, 0.4, 1.0],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.8),
          width: size * 0.03,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: size * 0.12,
            offset: Offset(0, size * 0.06),
          ),
        ],
      ),
      child: Stack(
        children: [
          // small extra shine spot, top-left
          Positioned(
            top: size * 0.16,
            left: size * 0.20,
            child: Container(
              width: size * 0.22,
              height: size * 0.14,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.55),
                borderRadius: BorderRadius.circular(size * 0.1),
              ),
            ),
          ),
          Center(
            child: Text(
              letter,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: size * 0.42,
                shadows: const [
                  Shadow(color: Colors.black45, blurRadius: 3, offset: Offset(0, 1)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// AIMING LINE PAINTER (unchanged from your version)
// ================================================================

class _AimingLinePainter extends CustomPainter {
  final Offset? startPoint;
  final Offset? currentPoint;

  _AimingLinePainter({
    required this.startPoint,
    required this.currentPoint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (startPoint == null || currentPoint == null) return;

    final dx = currentPoint!.dx - startPoint!.dx;
    final dy = currentPoint!.dy - startPoint!.dy;

    if (dx == 0 && dy == 0) return;

    final angle = atan2(dy, dx);
    final length = 500.0;

    final endPoint = Offset(
      startPoint!.dx + cos(angle) * length,
      startPoint!.dy + sin(angle) * length,
    );

    final paint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    const dashLength = 12.0;
    const gapLength = 8.0;

    final distance = (endPoint - startPoint!).distance;
    final direction = (endPoint - startPoint!) / distance;

    double currentDistance = 0;

    while (currentDistance < distance) {
      final dashStart = startPoint! + direction * currentDistance;
      final dashEndDistance = min(currentDistance + dashLength, distance);
      final dashEnd = startPoint! + direction * dashEndDistance;

      canvas.drawLine(dashStart, dashEnd, paint);
      currentDistance += dashLength + gapLength;
    }
  }

  @override
  bool shouldRepaint(covariant _AimingLinePainter oldDelegate) {
    return oldDelegate.startPoint != startPoint ||
        oldDelegate.currentPoint != currentPoint;
  }
}