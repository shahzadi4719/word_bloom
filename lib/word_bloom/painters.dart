part of '../word_bloom.dart';

// ================================================================
// POP EFFECT
// ================================================================
class _BonusShotPainter extends CustomPainter {
  final List<BonusShotBubble> shots;
  final double radiusFrac;
  final bool showLetters;

  const _BonusShotPainter({
    required this.shots,
    required this.radiusFrac,
    this.showLetters = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double r = radiusFrac * size.width;

    for (final BonusShotBubble s in shots) {
      final double p = s.progress.clamp(0.0, 1.0);
      const double flightEnd = 0.7;

      if (p < flightEnd) {
        // flying out of the ring
        final double t = Curves.easeOut.transform(p / flightEnd);
        final Offset pos = Offset(
          (s.startX + (s.endX - s.startX) * t) * size.width,
          (s.startY + (s.endY - s.startY) * t) * size.height,
        );
        _drawBubble(canvas, pos, r * (1.0 - 0.30 * t), s);
      } else {
        // pop: ring + coin "+10" rising and fading
        final double t = (p - flightEnd) / (1 - flightEnd);
        final Offset pos = Offset(s.endX * size.width, s.endY * size.height);

        canvas.drawCircle(
          pos,
          r * (0.7 + t * 1.5),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.16
            ..color = s.color.withValues(alpha: (1 - t) * 0.75),
        );

        final double fade = 1 - t;
        final TextPainter tp = TextPainter(
          text: TextSpan(
            text: '+${s.points}',
            style: TextStyle(
              color: const Color(0xFFFFF3C4).withValues(alpha: fade),
              fontSize: r * 0.8,
              fontWeight: FontWeight.w900,
              shadows: [
                Shadow(
                  color: const Color(0xFFFFA726).withValues(alpha: fade),
                  blurRadius: 8,
                ),
                Shadow(
                  color: Colors.black.withValues(alpha: 0.35 * fade),
                  blurRadius: 3,
                ),
              ],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        // coin + number, rising together
        final double coinR = r * 0.42;
        final double gap = r * 0.12;
        final double totalW = coinR * 2 + gap + tp.width;
        final double left = pos.dx - totalW / 2;
        final double cy = pos.dy - t * r * 1.4;

        CoinIcon.paint(canvas, Offset(left + coinR, cy), coinR, alpha: fade);
        tp.paint(canvas, Offset(left + coinR * 2 + gap, cy - tp.height / 2));
      }
    }
  }

  void _drawBubble(Canvas canvas, Offset c, double radius, BonusShotBubble s) {
    canvas.drawCircle(
      c,
      radius * 1.3,
      Paint()
        ..shader = RadialGradient(
          colors: [
            s.color.withValues(alpha: 0.30),
            s.color.withValues(alpha: 0.0),
          ],
          stops: const [0.7, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: radius * 1.3)),
    );

    paintBloomBubble(canvas, c, radius, s.color);

    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: showLetters ? s.letter : '',
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.92,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _BonusShotPainter oldDelegate) => true;
}

class _FlyingPopPainter extends CustomPainter {
  final List<FlyingPopBubble> pops;

  const _FlyingPopPainter({required this.pops});

  @override
  void paint(Canvas canvas, Size size) {
    for (final fp in pops) {
      final double t = Curves.easeOut.transform(fp.progress.clamp(0, 1));

      final Offset origin = Offset(
        fp.startX * size.width,
        fp.startY * size.height,
      );

      final double baseRadius = 0.052 * size.width;

      final double ringRadius = baseRadius * (0.4 + t * 2.2);
      final double ringOpacity = (1 - t) * 0.55;
      if (ringOpacity > 0) {
        final Paint ringPaint = Paint()
          ..color = fp.color.withValues(alpha: ringOpacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = baseRadius * 0.22;
        canvas.drawCircle(origin, ringRadius, ringPaint);
      }

      const int particleCount = 8;
      final int seed = fp.letter.codeUnitAt(0);

      for (int i = 0; i < particleCount; i++) {
        final double angle = (2 * pi * i / particleCount) + (seed % 7) * 0.35;

        final double travel = baseRadius * (1.6 + (i % 3) * 0.5) * t;

        final Offset particleCenter = Offset(
          origin.dx + cos(angle) * travel,
          origin.dy + sin(angle) * travel,
        );

        final double particleRadius =
            baseRadius * 0.22 * (1 - t).clamp(0.0, 1.0);
        final double particleOpacity = (1 - t).clamp(0.0, 1.0);

        if (particleRadius <= 0) continue;

        final Paint particlePaint = Paint()
          ..color = fp.color.withValues(alpha: particleOpacity);
        canvas.drawCircle(particleCenter, particleRadius, particlePaint);
      }

      final double flashOpacity = (1 - t * 1.6).clamp(0.0, 1.0);
      if (flashOpacity > 0) {
        final Paint flashPaint = Paint()
          ..color = Colors.white.withValues(alpha: flashOpacity * 0.8);
        canvas.drawCircle(origin, baseRadius * (1 - t * 0.6), flashPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FlyingPopPainter oldDelegate) => true;
}

// ================================================================
// BOOSTER EFFECTS (Bloom Bomb / Flower Blast / Lightning / Rainbow)
// ================================================================

BoosterId? _boosterIdFor(ShotSpecial s) {
  switch (s) {
    case ShotSpecial.bomb:
      return BoosterId.bloomBomb;
    case ShotSpecial.rainbow:
      return BoosterId.rainbowBloom;
    case ShotSpecial.lightning:
      return BoosterId.bloomLightning;
    case ShotSpecial.flower:
      return BoosterId.flowerBlast;
    case ShotSpecial.none:
      return null;
  }
}

class _BoosterEffectPainter extends CustomPainter {
  final List<BoosterEffect> effects;

  const _BoosterEffectPainter({required this.effects});

  @override
  void paint(Canvas canvas, Size size) {
    for (final BoosterEffect e in effects) {
      final double t = e.progress.clamp(0.0, 1.0);
      final double ease = Curves.easeOut.transform(t);
      final double fade = 1 - t;

      // ---- Bloom Lightning: bright beam along the path ----
      if (e.kind == ShotSpecial.lightning) {
        if (e.path.length < 2) continue;
        final Path p = Path()
          ..moveTo(e.path.first.dx * size.width, e.path.first.dy * size.height);
        for (int i = 1; i < e.path.length; i++) {
          p.lineTo(e.path[i].dx * size.width, e.path[i].dy * size.height);
        }

        Paint line(double w, Color c, {double blur = 0}) {
          final Paint paint = Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..strokeWidth = w
            ..color = c;
          if (blur > 0) {
            paint.maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
          }
          return paint;
        }

        canvas.drawPath(
          p,
          line(
            20 * fade + 4,
            const Color(0xFFFF9BC4).withValues(alpha: fade * 0.55),
            blur: 8,
          ),
        );
        canvas.drawPath(
          p,
          line(
            10 * fade + 2,
            const Color(0xFF6FA8FF).withValues(alpha: fade * 0.9),
          ),
        );
        canvas.drawPath(
          p,
          line(4 * fade + 1, Colors.white.withValues(alpha: fade)),
        );
        continue;
      }

      final Offset c = Offset(e.x * size.width, e.y * size.height);
      final double r = e.radius * size.width;

      // ---- Rainbow Bloom: small rainbow shimmer ring ----
      if (e.kind == ShotSpecial.rainbow) {
        final double ringR = r * (0.5 + 0.7 * ease);
        canvas.drawCircle(
          c,
          ringR,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5 * fade + 1
            ..shader = SweepGradient(
              colors: const [
                Color(0xFFFF8FB8),
                Color(0xFFFFC37A),
                Color(0xFFFFF08A),
                Color(0xFF9BE8B5),
                Color(0xFF8FD0FF),
                Color(0xFFC3A3FF),
                Color(0xFFFF8FB8),
              ],
              transform: GradientRotation(t * 3),
            ).createShader(Rect.fromCircle(center: c, radius: ringR)),
        );
        for (int i = 0; i < 6; i++) {
          final double a = 2 * pi * i / 6 + t * 2;
          canvas.drawCircle(
            c.translate(cos(a) * ringR, sin(a) * ringR),
            3 * fade,
            Paint()..color = Colors.white.withValues(alpha: fade),
          );
        }
        continue;
      }

      // ---- Bloom Bomb / Flower Blast: glow + wave + petals ----
      canvas.drawCircle(
        c,
        r * (0.45 + 0.75 * ease),
        Paint()
          ..color = const Color(0xFFFF6FAE).withValues(alpha: fade * 0.30)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
      );
      canvas.drawCircle(
        c,
        r * (0.25 + 0.85 * ease),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.12 * fade + 1.5
          ..color = Colors.white.withValues(alpha: fade * 0.9),
      );

      final int petals = e.kind == ShotSpecial.flower ? 10 : 6;
      final double dist = r * (0.15 + 0.85 * ease);
      for (int i = 0; i < petals; i++) {
        final double a = 2 * pi * i / petals + t * 0.8;
        canvas.save();
        canvas.translate(c.dx + cos(a) * dist, c.dy + sin(a) * dist);
        canvas.rotate(a);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: r * 0.34 * (1 - 0.4 * t),
            height: r * 0.16 * (1 - 0.4 * t),
          ),
          Paint()
            ..color =
                (i.isEven ? const Color(0xFFFFB3D4) : const Color(0xFFC8A8FF))
                    .withValues(alpha: fade),
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BoosterEffectPainter oldDelegate) => true;
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

    paintBloomBubble(canvas, center, radius * .90, color);
  }

  @override
  bool shouldRepaint(covariant _GlossyBubblePainter oldDelegate) =>
      oldDelegate.color != color;
}

// ================================================================
// GAME BOARD PAINTER
// ================================================================

class _GameBoardPainter extends CustomPainter {
  final bool showLetters;
  final List<Bubble> bubbles;
  final Bubble? flyingBubble;
  final ShotSpecial flyingSpecial;
  final Set<int> stoneIds;
  final Map<int, int> lockHits;
  final Set<int> iceIds;
  final Set<int> hiddenIds;
  final Set<int> bombIds;
  final Set<int> starIds;
  final Set<int> wildIds;
  final double entranceProgress;
  final double flyingPulse;

  const _GameBoardPainter({
    this.showLetters = true,
    required this.bubbles,
    required this.flyingBubble,
    this.flyingSpecial = ShotSpecial.none,
    this.stoneIds = const {},
    this.lockHits = const {},
    this.iceIds = const {},
    this.hiddenIds = const {},
    this.bombIds = const {},
    this.wildIds = const {},
    this.starIds = const {},
    this.entranceProgress = 1.0,
    this.flyingPulse = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // No hard clip here any more: a clip slices bubbles in half.
    // Bubbles near the top bar fade out instead (see the loop below),
    // and the solid header band in the UI hides whatever is left.

    final double t = Curves.easeOutBack.transform(
      entranceProgress.clamp(0.0, 1.0),
    );

    const double travelDistance = 0.9;
    final double offsetY = (1 - t) * travelDistance;

    void drawBubble(
      Canvas canvas,
      Size size,
      Bubble bubble, {
      double? overrideY,
      double pulse = 0.0,
      bool boostSize = false,
    }) {
      final double y = overrideY ?? bubble.y;
      final Offset center = Offset(bubble.x * size.width, y * size.height);

      final double radius = bubble.radius * size.width;
      if (radius <= 0) return;

      final double haloRadius = radius * 1.35;
      final double haloAlpha = boostSize ? 0.28 + pulse * 0.12 : 0.20;
      canvas.drawCircle(
        center,
        haloRadius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              bubble.color.withValues(alpha: haloAlpha),
              bubble.color.withValues(alpha: 0.0),
            ],
            stops: const [0.72, 1.0],
          ).createShader(Rect.fromCircle(center: center, radius: haloRadius)),
      );

      final Offset shadowCenter = center.translate(0, 3);
      canvas.drawCircle(
        shadowCenter,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.black.withValues(alpha: 0.16),
              Colors.black.withValues(alpha: 0.0),
            ],
            stops: const [0.70, 1.0],
          ).createShader(Rect.fromCircle(center: shadowCenter, radius: radius)),
      );

      // STONE: grey rock with cracks, no letter.
      if (stoneIds.contains(bubble.id)) {
        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..shader = const RadialGradient(
              center: Alignment(-0.35, -0.45),
              radius: 0.95,
              colors: [Color(0xFFC3C8D1), Color(0xFF7D8491), Color(0xFF4F5560)],
              stops: [0.0, 0.45, 1.0],
            ).createShader(Rect.fromCircle(center: center, radius: radius)),
        );

        final Paint crack = Paint()
          ..color = Colors.black.withValues(alpha: 0.38)
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.07
          ..strokeCap = StrokeCap.round;
        final Offset mid = center.translate(radius * 0.12, -radius * 0.05);
        canvas.drawLine(
          center.translate(-radius * 0.10, -radius * 0.55),
          mid,
          crack,
        );
        canvas.drawLine(
          mid,
          center.translate(-radius * 0.20, radius * 0.45),
          crack,
        );
        canvas.drawLine(
          mid,
          center.translate(radius * 0.50, radius * 0.20),
          crack,
        );

        canvas.drawOval(
          Rect.fromCenter(
            center: center.translate(-radius * 0.25, -radius * 0.38),
            width: radius * 0.42,
            height: radius * 0.24,
          ),
          Paint()..color = Colors.white.withValues(alpha: 0.35),
        );
        return;
      }

      final Color bodyColor = hiddenIds.contains(bubble.id)
          ? const Color(0xFF6D6A94)
          : bubble.color;

      paintBloomBubble(
        canvas,
        center,
        radius,
        bodyColor,
        shimmer: boostSize ? .5 + .5 * pulse : 0,
      );

      // Letter (layout() is required before measuring/painting).
      final TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: _displayLetter(bubble),
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
      )..layout();

      textPainter.paint(
        canvas,
        Offset(
          center.dx - textPainter.width / 2,
          center.dy - textPainter.height / 2,
        ),
      );

      // ICE: frosted cover with a snowflake.
      if (iceIds.contains(bubble.id)) {
        canvas.drawCircle(
          center,
          radius,
          Paint()..color = const Color(0xFFBFE9FF).withValues(alpha: 0.62),
        );
        final Paint flake = Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.09
          ..strokeCap = StrokeCap.round;
        for (int k = 0; k < 3; k++) {
          final double a = k * pi / 3;
          canvas.drawLine(
            center.translate(cos(a) * radius * 0.72, sin(a) * radius * 0.72),
            center.translate(-cos(a) * radius * 0.72, -sin(a) * radius * 0.72),
            flake,
          );
        }
        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.85)
            ..style = PaintingStyle.stroke
            ..strokeWidth = radius * 0.08,
        );
      }

      // BOMB: dark ring and a lit fuse spark.
      if (bombIds.contains(bubble.id)) {
        canvas.drawCircle(
          center,
          radius * 0.96,
          Paint()
            ..color = const Color(0xFF2B2B3A)
            ..style = PaintingStyle.stroke
            ..strokeWidth = radius * 0.16,
        );
        final Offset spark = center.translate(radius * 0.72, -radius * 0.72);
        canvas.drawCircle(
          spark,
          radius * 0.24,
          Paint()..color = const Color(0xFFFF8A3D),
        );
        canvas.drawCircle(
          spark,
          radius * 0.11,
          Paint()..color = const Color(0xFFFFE28A),
        );
      }

      // LOCK: a steel chain around the bubble + a padlock badge.
      // Full chain = 2 hits needed. Half-broken chain and a cracked, open
      // padlock = 1 hit left. No numbers needed.
      final int? hitsLeft = lockHits[bubble.id];
      if (hitsLeft != null) {
        final bool damaged = hitsLeft < GameEngine.lockStrength;

        // slightly greyed so it reads as "not usable yet", letter stays visible
        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..color = const Color(
              0xFF3A3F55,
            ).withValues(alpha: damaged ? 0.20 : 0.30),
        );

        // chain links around the edge
        const int linkCount = 10;
        const Set<int> missing = {1, 2, 6, 7};
        final double chainR = radius * 0.86;

        for (int k = 0; k < linkCount; k++) {
          if (damaged && missing.contains(k)) continue;

          final double a = (2 * pi * k / linkCount) - pi / 2;
          final Offset p = center.translate(cos(a) * chainR, sin(a) * chainR);

          canvas.save();
          canvas.translate(p.dx, p.dy);
          canvas.rotate(a + pi / 2);

          if (k.isEven) {
            // link seen from the front (an open oval)
            final RRect link = RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset.zero,
                width: radius * 0.50,
                height: radius * 0.22,
              ),
              Radius.circular(radius * 0.11),
            );
            canvas.drawRRect(
              link.shift(Offset(0, radius * 0.04)),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = radius * 0.07
                ..color = Colors.black.withValues(alpha: 0.35),
            );
            canvas.drawRRect(
              link,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = radius * 0.07
                ..color = const Color(0xFFD5DBE6),
            );
          } else {
            // link seen from the side (a short bar)
            final RRect link = RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset.zero,
                width: radius * 0.30,
                height: radius * 0.12,
              ),
              Radius.circular(radius * 0.06),
            );
            canvas.drawRRect(
              link.shift(Offset(0, radius * 0.04)),
              Paint()..color = Colors.black.withValues(alpha: 0.35),
            );
            canvas.drawRRect(link, Paint()..color = const Color(0xFF9AA3B5));
          }

          canvas.restore();
        }

        // padlock badge at the bottom
        final Offset badge = center.translate(0, radius * 0.78);
        final double badgeR = radius * 0.30;

        canvas.drawCircle(
          badge.translate(0, radius * 0.04),
          badgeR,
          Paint()..color = Colors.black.withValues(alpha: 0.30),
        );
        canvas.drawCircle(
          badge,
          badgeR,
          Paint()
            ..shader = const RadialGradient(
              center: Alignment(-0.3, -0.4),
              colors: [Color(0xFF4A5390), Color(0xFF1B1F3B)],
            ).createShader(Rect.fromCircle(center: badge, radius: badgeR)),
        );
        canvas.drawCircle(
          badge,
          badgeR,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = radius * 0.05
            ..color = const Color(0xFFFFD23F),
        );

        // shackle (pops open a little when the lock is damaged)
        final double lift = damaged ? radius * 0.07 : 0;
        canvas.drawArc(
          Rect.fromCenter(
            center: badge.translate(
              damaged ? radius * 0.05 : 0,
              -radius * 0.07 - lift,
            ),
            width: radius * 0.22,
            height: radius * 0.26,
          ),
          pi,
          pi,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = radius * 0.05
            ..strokeCap = StrokeCap.round
            ..color = const Color(0xFFE6EAF2),
        );
        // lock body + keyhole
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: badge.translate(0, radius * 0.05),
              width: radius * 0.30,
              height: radius * 0.22,
            ),
            Radius.circular(radius * 0.05),
          ),
          Paint()..color = const Color(0xFFFFD23F),
        );
        canvas.drawCircle(
          badge.translate(0, radius * 0.04),
          radius * 0.035,
          Paint()..color = const Color(0xFF1B1F3B),
        );

        // crack across the badge when damaged
        if (damaged) {
          final Path crack = Path()
            ..moveTo(badge.dx - badgeR * 0.5, badge.dy - badgeR * 0.7)
            ..lineTo(badge.dx - badgeR * 0.05, badge.dy - badgeR * 0.1)
            ..lineTo(badge.dx + badgeR * 0.25, badge.dy + badgeR * 0.15)
            ..lineTo(badge.dx + badgeR * 0.55, badge.dy + badgeR * 0.7);
          canvas.drawPath(
            crack,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = radius * 0.04
              ..strokeCap = StrokeCap.round
              ..color = Colors.white.withValues(alpha: 0.9),
          );
        }
      }
    }

    // Paint the upper bubbles behind the translucent HUD, just like the
    // rest of the board. Only clip at the viewport's actual top edge.
    const double headerLine = 0;

    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(0, headerLine, size.width, size.height - headerLine),
    );
    for (final bubble in bubbles) {
      final double animatedY = bubble.y + offsetY;
      final double r = bubble.radius * size.width;
      final double bottomEdge = animatedY * size.height + r;
      if (bottomEdge <= headerLine) continue; // fully above the bar
      drawBubble(canvas, size, bubble, overrideY: animatedY);
      if (!showLetters && starIds.contains(bubble.id)) {
        final center = Offset(bubble.x * size.width, animatedY * size.height);
        _paintGoldStar(canvas, center, r * .52);
      }
    }
    canvas.restore();

    if (flyingBubble != null) {
      drawBubble(
        canvas,
        size,
        flyingBubble!,
        pulse: flyingPulse,
        boostSize: true,
      );

      // booster icon drawn on top of the flying bubble
      final BoosterId? sp = _boosterIdFor(flyingSpecial);
      if (sp != null) {
        final Offset c = Offset(
          flyingBubble!.x * size.width,
          flyingBubble!.y * size.height,
        );
        final double r = flyingBubble!.radius * size.width * 1.3;
        canvas.save();
        canvas.translate(c.dx - r, c.dy - r);
        BoosterIconPainter(sp).paint(canvas, Size(r * 2, r * 2));
        canvas.restore();
      }
    }
  }

  String _displayLetter(Bubble b) {
    if (hiddenIds.contains(b.id)) return '?';
    if (wildIds.contains(b.id)) return '★';
    return showLetters ? b.letter : '';
  }

  // The engine mutates the same list and the glow controller ticks
  // every frame, so always repainting is the safe choice here.
  @override
  bool shouldRepaint(covariant _GameBoardPainter old) => true;
}

// ================================================================
// AIMING LINE
// ================================================================

class _AimingLinePainter extends CustomPainter {
  /// Normalized 0-1 polyline from the engine: wall bounces included,
  /// last point is the exact slot where the bubble will land.
  final List<Offset> points;
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

    // Ring at the landing slot.
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
// ANIMATED LAUNCHER RING
// ================================================================

void _paintGoldStar(Canvas canvas, Offset center, double radius) {
  final path = Path();
  for (int i = 0; i < 10; i++) {
    final a = -pi / 2 + i * pi / 5;
    final r = i.isEven ? radius : radius * .46;
    final x = center.dx + cos(a) * r;
    final y = center.dy + sin(a) * r;
    if (i == 0) {
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
  }
  path.close();
  canvas.drawPath(path, Paint()..color = const Color(0xFFFFC43D));
  canvas.drawPath(
    path,
    Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2,
  );
}

class _StarFlightPainter extends CustomPainter {
  final List<FlyingPopBubble> stars;
  final bool wordMode;
  const _StarFlightPainter({required this.stars, required this.wordMode});
  @override
  void paint(Canvas canvas, Size size) {
    // Same padding and thresholds as the header's star track.
    final trackLeft = 14.0 + 46 + 16 + 14 + 2;
    final trackWidth = size.width - trackLeft - 14 - 14 - 2;
    for (final star in stars) {
      final t = Curves.easeInOutCubic.transform(star.progress.clamp(0.0, 1.0));
      final start = Offset(star.startX * size.width, star.startY * size.height);
      final end = Offset(
        trackLeft +
            (trackWidth - 25) *
                const [.5, .75, 1.0][star.starSlot.clamp(0, 2)] +
            12.5,
        wordMode ? 52 : 44,
      );
      final control = Offset(
        (start.dx + end.dx) / 2 + 38,
        min(start.dy, end.dy) - 45,
      );
      final point =
          start * ((1 - t) * (1 - t)) +
          control * (2 * (1 - t) * t) +
          end * (t * t);
      canvas.drawCircle(
        point,
        12,
        Paint()
          ..color = const Color(0x66FFD45C)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      _paintGoldStar(canvas, point, 10 + 4 * sin(pi * t));
    }
  }

  @override
  bool shouldRepaint(covariant _StarFlightPainter oldDelegate) => true;
}

class _BoosterPreviewPainter extends CustomPainter {
  final ({
    List<Bubble> victims,
    Offset center,
    double radius,
    List<Offset> path,
  })
  preview;
  final Color color;
  final ShotSpecial special;
  const _BoosterPreviewPainter({
    required this.preview,
    required this.color,
    required this.special,
  });
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final center = Offset(
      preview.center.dx * size.width,
      preview.center.dy * size.height,
    );
    if (preview.radius > 0) {
      canvas.drawCircle(
        center,
        preview.radius * size.width,
        Paint()..color = color.withValues(alpha: .12),
      );
      canvas.drawCircle(
        center,
        preview.radius * size.width,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white.withValues(alpha: .8),
      );
    }
    if (special == ShotSpecial.lightning && preview.path.length >= 2) {
      canvas.drawLine(
        Offset(
          preview.path.first.dx * size.width,
          preview.path.first.dy * size.height,
        ),
        Offset(
          preview.path.last.dx * size.width,
          preview.path.last.dy * size.height,
        ),
        Paint()
          ..strokeWidth = 16
          ..color = color.withValues(alpha: .18)
          ..strokeCap = StrokeCap.round,
      );
    }
    for (final bubble in preview.victims) {
      final p = Offset(bubble.x * size.width, bubble.y * size.height);
      final r = bubble.radius * size.width;
      canvas.drawCircle(
        p,
        r,
        Paint()..color = Colors.white.withValues(alpha: .24),
      );
      canvas.drawCircle(
        p,
        r + 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = Colors.white,
      );
    }
    final label = switch (special) {
      ShotSpecial.bomb => 'Bomb',
      ShotSpecial.flower => 'Blast',
      ShotSpecial.rainbow => 'Rainbow',
      ShotSpecial.lightning => 'Lightning',
      ShotSpecial.none => '',
    };
    final tp = TextPainter(
      text: TextSpan(
        text: '$label · ${preview.victims.length} bubbles',
        style: const TextStyle(
          fontFamily: 'Fredoka',
          fontSize: 15,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final x = (center.dx - tp.width / 2)
        .clamp(12.0, max(12.0, size.width - tp.width - 12))
        .toDouble();
    final y = (center.dy + size.width * .12)
        .clamp(size.height * .18, size.height * .73)
        .toDouble();
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 8, y - 6, tp.width + 16, tp.height + 12),
        const Radius.circular(14),
      ),
      Paint()..color = const Color(0xFFC52F83),
    );
    tp.paint(canvas, Offset(x, y));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BoosterPreviewPainter oldDelegate) => true;
}

class _LiveLightningPainter extends CustomPainter {
  final Offset start, end;
  const _LiveLightningPainter({required this.start, required this.end});
  @override
  void paint(Canvas canvas, Size size) {
    final a = Offset(start.dx * size.width, start.dy * size.height);
    final b = Offset(end.dx * size.width, end.dy * size.height);
    canvas.drawLine(
      a,
      b,
      Paint()
        ..strokeWidth = 19
        ..color = const Color(0x889F7FFF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7)
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      a,
      b,
      Paint()
        ..strokeWidth = 7
        ..color = const Color(0xFF91DCFF)
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      a,
      b,
      Paint()
        ..strokeWidth = 2.5
        ..color = Colors.white
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _LiveLightningPainter oldDelegate) => true;
}
