part of '../word_bloom.dart';

enum _RingSpin { shot, swap }

class _LauncherRing extends StatefulWidget {
  final String currentLetter;
  final String nextLetter;
  final String thirdLetter;
  final Color thirdColor;
  final double muzzleOffsetY;
  final Color currentColor;
  final Color nextColor;
  final int shotsRemaining;
  final int shotTrigger;
  final int swapTrigger;
  final VoidCallback onSwapTap;
  final VoidCallback onThirdTap;
  final bool showSuperSwap;

  /// Booster that is armed right now: its icon sits on the ring's ball.
  final BoosterId? armed;

  const _LauncherRing({
    required this.currentLetter,
    required this.nextLetter,
    required this.thirdLetter,
    required this.thirdColor,
    required this.muzzleOffsetY,
    required this.currentColor,
    required this.nextColor,
    required this.shotsRemaining,
    required this.shotTrigger,
    required this.swapTrigger,
    required this.onSwapTap,
    required this.onThirdTap,
    this.showSuperSwap = false,
    this.armed,
  });

  @override
  State<_LauncherRing> createState() => _LauncherRingState();
}

class _LauncherRingState extends State<_LauncherRing>
    with TickerProviderStateMixin {
  late final AnimationController _ringController;
  late final AnimationController _transitionController;
  late final Animation<double> _transition;

  _RingSpin _spinKind = _RingSpin.shot;

  static const double _topAngle = -pi / 2;
  static const double _nextAngle = .08;
  static const double _thirdAngle = .77;

  @override
  void initState() {
    super.initState();

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      value: 1.0,
    );
    _transition = CurvedAnimation(
      parent: _transitionController,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void didUpdateWidget(covariant _LauncherRing oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.shotTrigger != oldWidget.shotTrigger) {
      _spinKind = _RingSpin.shot;
      _transitionController.forward(from: 0);
    } else if (widget.swapTrigger != oldWidget.swapTrigger) {
      _spinKind = _RingSpin.swap;
      _transitionController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ringController.dispose();
    _transitionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final Size size = Size(constraints.maxWidth, constraints.maxHeight);

        final geometry = _launcherGeometry(size, widget.muzzleOffsetY);
        final Offset center = geometry.center;
        final double ringRadius = geometry.radius;
        final nextDiameter = min(42.0, ringRadius * .66);
        final thirdDiameter = min(36.0, ringRadius * .57);

        Offset onRing(double angle) {
          return Offset(
            center.dx + cos(angle) * ringRadius,
            center.dy + sin(angle) * ringRadius,
          );
        }

        return AnimatedBuilder(
          animation: Listenable.merge([_ringController, _transitionController]),
          builder: (context, child) {
            final double t = _transition.value;
            final double rotation = _ringController.value * pi * 2;

            final double currentAngle =
                _nextAngle + (_topAngle - _nextAngle) * t;
            final Offset currentPos = onRing(currentAngle);

            Offset nextPos;

            if (_spinKind == _RingSpin.swap) {
              final double angle = _topAngle + (_nextAngle - _topAngle) * t;
              nextPos = onRing(angle);
            } else {
              nextPos = onRing(_nextAngle);
            }

            final double nextOpacity = _spinKind == _RingSpin.shot
                ? Curves.easeOut.transform(t)
                : 1.0;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _LauncherRingPainter(
                      muzzleOffsetY: widget.muzzleOffsetY,
                      rotation: rotation,
                      pulse: sin(rotation) * 0.5 + 0.5,
                      color: widget.currentColor,
                    ),
                  ),
                ),
                Positioned(
                  left: center.dx - 35,
                  top: center.dy - 18,
                  width: 70,
                  height: 36,
                  child: Center(
                    child: Text(
                      '${widget.shotsRemaining}',
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF7A4A3A),
                        shadows: [Shadow(color: Colors.white, blurRadius: 5)],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: currentPos.dx - 34.56,
                  top: currentPos.dy - 34.56,
                  child: IgnorePointer(
                    child: _AnimatedShooterBubble(
                      letter: widget.currentLetter,
                      color: widget.currentColor,
                      size: 69.12,
                      booster: widget.armed,
                    ),
                  ),
                ),
                Positioned(
                  left: nextPos.dx - nextDiameter / 2,
                  top: nextPos.dy - nextDiameter / 2,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onSwapTap,
                    child: Opacity(
                      opacity: nextOpacity.clamp(0.0, 1.0),
                      child: _GlossyBubble(
                        letter: widget.nextLetter,
                        color: widget.nextColor,
                        size: nextDiameter,
                      ),
                    ),
                  ),
                ),
                if (widget.showSuperSwap)
                  Positioned(
                    left: onRing(_thirdAngle).dx - thirdDiameter / 2,
                    top: onRing(_thirdAngle).dy - thirdDiameter / 2,
                    child: GestureDetector(
                      onTap: widget.onThirdTap,
                      child: Opacity(
                        opacity: nextOpacity.clamp(0.0, 1.0),
                        child: _GlossyBubble(
                          letter: widget.thirdLetter,
                          color: widget.thirdColor,
                          size: thirdDiameter,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

// ================================================================
// LEVEL COMPLETE: ONE pink card holding YOU WIN! + stars (pink
// header), score, found words and the NEXT LEVEL button.
// ================================================================

class _AnimatedShooterBubble extends StatefulWidget {
  final String letter;
  final Color color;
  final double size;
  final BoosterId? booster; // armed booster: icon instead of the letter

  const _AnimatedShooterBubble({
    required this.letter,
    required this.color,
    required this.size,
    this.booster,
  });

  @override
  State<_AnimatedShooterBubble> createState() => _AnimatedShooterBubbleState();
}

class _AnimatedShooterBubbleState extends State<_AnimatedShooterBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
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
      builder: (context, child) {
        final double t = Curves.easeInOut.transform(_controller.value);
        final double scale = 1.0 + (0.035 * t);

        return Transform.scale(
          scale: scale,
          child: CustomPaint(
            size: Size.square(widget.size),
            painter: _ShooterBubblePainter(color: widget.color, glow: t),
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: Center(
                child: widget.booster != null
                    ? SizedBox(
                        width: widget.size * 0.78,
                        height: widget.size * 0.78,
                        child: CustomPaint(
                          painter: BoosterIconPainter(widget.booster!),
                        ),
                      )
                    : Text(
                        widget.letter,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: widget.size * 0.42,
                          fontWeight: FontWeight.w900,
                          shadows: const [
                            Shadow(
                              color: Colors.black45,
                              blurRadius: 3,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ShooterBubblePainter extends CustomPainter {
  final Color color;
  final double glow;

  const _ShooterBubblePainter({required this.color, required this.glow});

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = min(size.width, size.height) / 2;
    final Offset center = Offset(size.width / 2, size.height / 2);

    final Paint glowPaint = Paint()
      ..color = color.withValues(alpha: 0.16 + glow * 0.10)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 + glow * 4);
    canvas.drawCircle(center, radius * 0.94, glowPaint);

    paintBloomBubble(canvas, center, radius * .90, color, shimmer: glow);
  }

  @override
  bool shouldRepaint(covariant _ShooterBubblePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.glow != glow;
  }
}

// ================================================================
// RING PAINTER
// ================================================================

({Offset center, double radius}) _launcherGeometry(Size size, double muzzleY) {
  final radius = max(
    26.0,
    min(
      size.height * .37,
      min(size.width * .22, (size.height - muzzleY) * .48),
    ),
  );
  return (center: Offset(size.width / 2, muzzleY + radius), radius: radius);
}

class _LauncherRingPainter extends CustomPainter {
  final double muzzleOffsetY;
  final double rotation;
  final double pulse;
  final Color color;

  const _LauncherRingPainter({
    required this.muzzleOffsetY,
    required this.rotation,
    required this.pulse,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _launcherGeometry(size, muzzleOffsetY);
    final Offset center = geometry.center;
    final double ringRadius = geometry.radius;

    final Paint shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, size.height * 0.91),
        width: ringRadius * 1.65,
        height: ringRadius * 0.25,
      ),
      shadowPaint,
    );

    final Paint outerGlow = Paint()
      ..color = color.withValues(alpha: 0.12 + pulse * 0.08)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 18 + pulse * 5);
    canvas.drawCircle(center, ringRadius * 0.98, outerGlow);

    final Paint innerGlow = Paint()
      ..color = Colors.white.withValues(alpha: 0.12 + pulse * 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    canvas.drawCircle(center, ringRadius, innerGlow);

    final Paint ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..shader = SweepGradient(
        transform: GradientRotation(rotation),
        colors: [
          Colors.white.withValues(alpha: 0.25),
          color.withValues(alpha: 0.95),
          Colors.white.withValues(alpha: 0.95),
          color.withValues(alpha: 0.35),
          Colors.white.withValues(alpha: 0.25),
        ],
        stops: const [0.00, 0.20, 0.32, 0.62, 1.00],
      ).createShader(Rect.fromCircle(center: center, radius: ringRadius));
    canvas.drawCircle(center, ringRadius, ringPaint);

    final Paint movingArc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 8
      ..color = Colors.white.withValues(alpha: 0.72 + pulse * 0.20)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    final Rect arcRect = Rect.fromCircle(
      center: center,
      radius: ringRadius + 1,
    );
    canvas.drawArc(arcRect, rotation - 0.55, 0.75, false, movingArc);

    final Paint highlight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.72);
    canvas.drawCircle(center, ringRadius - 5, highlight);
  }

  @override
  bool shouldRepaint(covariant _LauncherRingPainter oldDelegate) {
    return oldDelegate.muzzleOffsetY != muzzleOffsetY ||
        oldDelegate.rotation != rotation ||
        oldDelegate.pulse != pulse ||
        oldDelegate.color != color;
  }
}

// ================================================================
// FOUND WORD
// ================================================================
