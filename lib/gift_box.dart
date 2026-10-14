import 'dart:math';

import 'package:flutter/material.dart';

import 'booster_bar.dart';
import 'booster_service.dart';
import 'gift_service.dart';
import 'sound_service.dart';

// ─────────────────────────────────────────────────────────────
// Pink theme (same colours as the level screen)
// ─────────────────────────────────────────────────────────────
const Color _gPink = Color(0xFFE0388C);
const Color _gPinkLight = Color(0xFFFF9BC4);
const Color _gInkSoft = Color(0xFF9A607A);

const List<Color> _burstColors = [
  Color(0xFFFF72B6),
  Color(0xFFFF9BC4),
  Color(0xFFFFB3D4),
  Color(0xFFFFD4E5),
  Color(0xFFFFC857),
  Color(0xFFC9A7FF),
  Colors.white,
];

/// locked = level not finished yet, ready = can be opened, opened = taken.
enum GiftState { locked, ready, opened }

Path _sparklePath(Offset c, double r) {
  final Path p = Path();
  for (int i = 0; i < 8; i++) {
    final double a = i * pi / 4 - pi / 2;
    final double rr = i.isEven ? r : r * 0.32;
    final Offset pt = Offset(c.dx + cos(a) * rr, c.dy + sin(a) * rr);
    if (i == 0) {
      p.moveTo(pt.dx, pt.dy);
    } else {
      p.lineTo(pt.dx, pt.dy);
    }
  }
  p.close();
  return p;
}

Path _heartPath(Offset c, double s) {
  final Path p = Path()
    ..moveTo(c.dx, c.dy + s * 0.9)
    ..cubicTo(
      c.dx - s * 1.6,
      c.dy - s * 0.2,
      c.dx - s * 0.8,
      c.dy - s * 1.3,
      c.dx,
      c.dy - s * 0.45,
    )
    ..cubicTo(
      c.dx + s * 0.8,
      c.dy - s * 1.3,
      c.dx + s * 1.6,
      c.dy - s * 0.2,
      c.dx,
      c.dy + s * 0.9,
    )
    ..close();
  return p;
}

// ================================================================
// GIFT BOX PAINTER (pink box, white ribbon, golden bow)
// ================================================================

class GiftBoxPainter extends CustomPainter {
  /// 0 = closed ... 1 = lid fully off.
  final double open;
  final double lidOpacity;
  final bool locked;

  const GiftBoxPainter({
    this.open = 0,
    this.lidOpacity = 1,
    this.locked = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final Color bodyTop = locked
        ? const Color(0xFFE6DCF0)
        : const Color(0xFFFFB3D1);
    final Color bodyBottom = locked
        ? const Color(0xFFB2A2C6)
        : const Color(0xFFE0388C);
    final Color lidTop = locked
        ? const Color(0xFFF0E9F6)
        : const Color(0xFFFFC9DF);
    final Color lidBottom = locked
        ? const Color(0xFFC6B8D8)
        : const Color(0xFFEC4C9B);
    final Color ribbon = locked ? const Color(0xFFF7F2FA) : Colors.white;
    final Color gold = locked
        ? const Color(0xFFD9CDE6)
        : const Color(0xFFFFC857);

    // ground shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.95),
        width: w * 0.80,
        height: h * 0.10,
      ),
      Paint()
        ..color = const Color(0x33B5588F)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // body
    final RRect body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.14, h * 0.46, w * 0.72, h * 0.48),
      Radius.circular(w * 0.08),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [bodyTop, bodyBottom],
        ).createShader(body.outerRect),
    );

    // inside of the box (only when open)
    if (open > 0.01) {
      final double m = min(1.0, open * 3);
      final Rect mouth = Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.47),
        width: w * 0.66 * m,
        height: h * 0.13 * m,
      );
      canvas.drawOval(
        mouth,
        Paint()
          ..shader = RadialGradient(
            colors: locked
                ? const [Color(0xFFB9ABCB), Color(0xFF8F7DA8)]
                : const [
                    Color(0xFFFFF3C4),
                    Color(0xFFFF6FAE),
                    Color(0xFF8E1F5A),
                  ],
          ).createShader(mouth),
      );
    }

    // ribbon + shine on the body
    canvas.save();
    canvas.clipRRect(body);
    final Rect rib = Rect.fromLTWH(w * 0.5 - w * 0.07, h * 0.46, w * 0.14, h * 0.48);
    canvas.drawRect(rib, Paint()..color = ribbon);
    canvas.drawRect(
      rib,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.012
        ..color = gold,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.20, h * 0.51, w * 0.06, h * 0.33),
        Radius.circular(w * 0.03),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.30),
    );
    canvas.restore();

    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.03
        ..color = Colors.white.withValues(alpha: 0.85),
    );

    // lid
    if (lidOpacity <= 0.01) return;

    if (lidOpacity < 1) {
      canvas.saveLayer(
        Rect.fromLTWH(-w, -h, w * 3, h * 3),
        Paint()..color = Colors.white.withValues(alpha: lidOpacity),
      );
    } else {
      canvas.save();
    }

    canvas.translate(w * 0.5 + open * w * 0.30, h * 0.37 - open * h * 0.55);
    canvas.rotate(open * 0.6);

    final Rect lidRect = Rect.fromCenter(
      center: Offset.zero,
      width: w * 0.86,
      height: h * 0.22,
    );
    final RRect lid = RRect.fromRectAndRadius(lidRect, Radius.circular(w * 0.07));

    canvas.drawRRect(
      lid,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [lidTop, lidBottom],
        ).createShader(lidRect),
    );

    canvas.save();
    canvas.clipRRect(lid);
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: w * 0.14, height: h * 0.22),
      Paint()..color = ribbon,
    );
    canvas.drawRect(
      Rect.fromLTWH(-w * 0.38, -h * 0.095, w * 0.76, h * 0.03),
      Paint()..color = Colors.white.withValues(alpha: 0.30),
    );
    canvas.restore();

    canvas.drawRRect(
      lid,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.03
        ..color = Colors.white.withValues(alpha: 0.9),
    );

    // bow
    final Paint loopFill = Paint()..color = ribbon;
    final Paint loopEdge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.03
      ..color = gold;
    for (final int s in const [-1, 1]) {
      canvas.save();
      canvas.translate(s * w * 0.095, -h * 0.145);
      canvas.rotate(-s * 0.55);
      final Rect loop = Rect.fromCenter(
        center: Offset.zero,
        width: w * 0.22,
        height: h * 0.13,
      );
      canvas.drawOval(loop, loopFill);
      canvas.drawOval(loop, loopEdge);
      canvas.restore();
    }
    canvas.drawCircle(Offset(0, -h * 0.12), w * 0.055, Paint()..color = gold);
    canvas.drawCircle(
      Offset(0, -h * 0.12),
      w * 0.055,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.015
        ..color = Colors.white,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GiftBoxPainter old) => true;
}

// ================================================================
// GIFT ON THE LEVEL PATH
// ================================================================

class GiftMapBox extends StatefulWidget {
  final GiftState state;
  final double size;
  final VoidCallback onTap;

  const GiftMapBox({
    super.key,
    required this.state,
    required this.onTap,
    this.size = 62,
  });

  @override
  State<GiftMapBox> createState() => _GiftMapBoxState();
}

class _GiftMapBoxState extends State<GiftMapBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _down = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    if (widget.state == GiftState.ready) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant GiftMapBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state == GiftState.ready) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double s = widget.size;
    final bool ready = widget.state == GiftState.ready;
    final bool locked = widget.state == GiftState.locked;
    final bool opened = widget.state == GiftState.opened;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: SizedBox(
        width: s,
        height: s,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final double t = _c.value;
            double dy = 0;
            double rot = 0;
            double scale = 1;

            if (ready) {
              if (t < 0.6) {
                // happy hop
                final double k = t / 0.6;
                dy = -11 * sin(k * pi);
                scale = 1 + 0.05 * sin(k * pi);
              } else {
                // "open me!" shake
                final double k = (t - 0.6) / 0.4;
                rot = 0.16 * sin(k * pi * 6) * (1 - k);
              }
            }
            if (_down) scale *= 0.92;

            Widget box = CustomPaint(
              size: Size.square(s),
              painter: GiftBoxPainter(locked: locked),
            );
            if (opened) box = Opacity(opacity: 0.5, child: box);

            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                if (ready)
                  Positioned.fill(
                    child: CustomPaint(painter: _GiftHaloPainter(t)),
                  ),
                Transform.translate(
                  offset: Offset(0, dy),
                  child: Transform.rotate(
                    angle: rot,
                    alignment: Alignment.bottomCenter,
                    child: Transform.scale(
                      scale: scale,
                      alignment: Alignment.bottomCenter,
                      child: box,
                    ),
                  ),
                ),
                if (locked)
                  const Positioned(
                    right: -4,
                    bottom: -2,
                    child: _MiniBadge(
                      icon: Icons.lock_rounded,
                      colors: [Color(0xFFB2A2C6), Color(0xFF8F7DA8)],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final IconData icon;
  final List<Color> colors;

  const _MiniBadge({required this.icon, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, size: 12, color: Colors.white),
    );
  }
}

/// Pulsing pink glow + twinkling sparkles around a ready gift.
class _GiftHaloPainter extends CustomPainter {
  final double t;
  const _GiftHaloPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double pulse = 0.5 + 0.5 * sin(t * 2 * pi * 2);
    final double r = size.width * (0.66 + 0.10 * pulse);

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFF6FAE).withValues(alpha: 0.30 + 0.22 * pulse),
            const Color(0xFFFF6FAE).withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    for (int k = 0; k < 4; k++) {
      final double a = k * pi / 2 + pi / 4;
      final double dist = size.width * 0.62;
      final double ph = (t * 2 + k * 0.25) % 1.0;
      final double tw = sin(ph * pi);
      final double sr = size.width * 0.10 * tw;
      if (sr < 0.5) continue;
      final Offset p = Offset(c.dx + cos(a) * dist, c.dy + sin(a) * dist);
      canvas.drawCircle(
        p,
        sr * 1.6,
        Paint()..color = const Color(0xFFFF9BC4).withValues(alpha: 0.35 * tw),
      );
      canvas.drawPath(_sparklePath(p, sr), Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _GiftHaloPainter old) => old.t != t;
}

// ================================================================
// LAYER THAT PUTS THE GIFTS ON THE ROAD
// ================================================================

/// Put this in the level screen's Stack (inside Positioned.fill) above the
/// list. It follows the scroll position and places each gift box on the road
/// between level N and N+1. Empty areas let touches pass to the list.
class GiftPathLayer extends StatelessWidget {
  final ScrollController controller;
  final int unlockedLevel;
  final Set<int> openedGifts;
  final int totalLevels;
  final double nodeSpacing;
  final double topPad;
  final double nodeCenterY;
  final List<double> xPattern;
  final void Function(int giftLevel, GiftState state) onGiftTap;

  const GiftPathLayer({
    super.key,
    required this.controller,
    required this.unlockedLevel,
    required this.openedGifts,
    required this.totalLevels,
    required this.nodeSpacing,
    required this.topPad,
    required this.nodeCenterY,
    required this.xPattern,
    required this.onGiftTap,
  });

  static const double _giftSize = 62;

  double _xFor(int i) => xPattern[i % xPattern.length];

  double _tangentDx(int i) {
    final double x = _xFor(i);
    if ((x - 0.5).abs() > 0.01) return 0;
    return (_xFor(i + 1) - _xFor(i - 1)).sign;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final double w = c.maxWidth;
        final double h = c.maxHeight;

        return AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final double offset = controller.hasClients ? controller.offset : 0;

            Offset pt(int idx) => Offset(
              _xFor(idx) * w,
              topPad + (totalLevels - 1 - idx) * nodeSpacing - offset + nodeCenterY,
            );

            final int kMin =
                ((-150 + offset - topPad - nodeCenterY) / nodeSpacing).floor();
            final int kMax =
                ((h + 150 + offset - topPad - nodeCenterY) / nodeSpacing)
                    .ceil();
            final int nLow = (totalLevels - kMax).clamp(1, totalLevels - 1);
            final int nHigh = (totalLevels - kMin).clamp(1, totalLevels - 1);

            final List<Widget> gifts = <Widget>[];

            for (int n = nLow; n <= nHigh; n++) {
              if (!GiftService.hasGiftAfter(n)) continue;

              // same road curve as the road painter, level n -> level n+1
              final int i = n - 1;
              final Offset p0 = pt(i);
              final Offset p3 = pt(i + 1);
              final double lowT = _tangentDx(i);
              final double topT = _tangentDx(i + 1);
              final double dx = (p3.dx - p0.dx).abs();
              final Offset tLow = lowT != 0 ? Offset(lowT, 0) : const Offset(0, -1);
              final Offset tTop = topT != 0 ? Offset(topT, 0) : const Offset(0, -1);
              final double lenLow = lowT != 0 ? dx : nodeSpacing * 0.62;
              final double lenTop = topT != 0 ? dx : nodeSpacing * 0.62;
              final Offset c1 = p0 + tLow * lenLow;
              final Offset c2 = p3 - tTop * lenTop;

              // A point ON the road piece between level n and n+1.
              // Same spot for every gift, always exactly on the road.
              const double t = 0.55;
              final double u = 1 - t;
              final Offset mid =
                  p0 * (u * u * u) +
                  c1 * (3 * u * u * t) +
                  c2 * (3 * u * t * t) +
                  p3 * (t * t * t);

              final double gx = mid.dx;

              final GiftState st = n >= unlockedLevel
                  ? GiftState.locked
                  : (openedGifts.contains(n)
                        ? GiftState.opened
                        : GiftState.ready);

              gifts.add(
                Positioned(
                  key: ValueKey('gift_$n'),
                  left: gx - _giftSize / 2,
                  top: mid.dy - _giftSize / 2,
                  width: _giftSize,
                  height: _giftSize,
                  child: GiftMapBox(
                    state: st,
                    size: _giftSize,
                    onTap: () => onGiftTap(n, st),
                  ),
                ),
              );
            }

            return Stack(clipBehavior: Clip.none, children: gifts);
          },
        );
      },
    );
  }
}

// ================================================================
// OPENING POPUP
// ================================================================

/// Shows the full-screen "opening" animation with the rewards.
/// (Rewards are already saved by GiftService.open before this is shown.)
Future<void> showGiftOpenDialog(
  BuildContext context,
  List<GiftReward> rewards,
) {
  SoundService.instance.play(Sfx.gift); // box opens
  // One sound when the rewards appear: coins -> reward, anything else -> success
  Future<void>.delayed(const Duration(milliseconds: 2300), () {
    SoundService.instance.play(
      rewards.any((r) => r.isCoins) ? Sfx.reward : Sfx.success,
    );
  });
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Gift',
    barrierColor: const Color(0xB3381327),
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (ctx, _, __) => _GiftOpenOverlay(
      rewards: rewards,
      onDone: () => Navigator.of(ctx).pop(),
    ),
    transitionBuilder: (ctx, anim, _, child) =>
        FadeTransition(opacity: anim, child: child),
  );
}

class _Particle {
  final double angle;
  final double speed;
  final double size;
  final int color;
  final int shape;

  const _Particle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
    required this.shape,
  });
}

class _GiftOpenOverlay extends StatefulWidget {
  final List<GiftReward> rewards;
  final VoidCallback onDone;

  const _GiftOpenOverlay({required this.rewards, required this.onDone});

  @override
  State<_GiftOpenOverlay> createState() => _GiftOpenOverlayState();
}

class _GiftOpenOverlayState extends State<_GiftOpenOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _seq;
  late final AnimationController _loop;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();

    final Random rnd = Random(21);
    _particles = List<_Particle>.generate(
      36,
      (i) => _Particle(
        angle: rnd.nextDouble() * 2 * pi,
        speed: 0.55 + rnd.nextDouble() * 0.9,
        size: 4 + rnd.nextDouble() * 5,
        color: rnd.nextInt(_burstColors.length),
        shape: rnd.nextInt(3),
      ),
    );

    _seq = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    )..forward();

    _loop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _seq.dispose();
    _loop.dispose();
    super.dispose();
  }

  double _seg(double a, double b) =>
      ((_seq.value - a) / (b - a)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double boxSize = (constraints.maxHeight * 0.20).clamp(
            100.0,
            140.0,
          );
          final double cardW = min(constraints.maxWidth - 40, 340.0);
          return AnimatedBuilder(
            animation: Listenable.merge([_seq, _loop]),
            builder: (context, _) => _content(boxSize, cardW),
          );
        },
      ),
    );
  }

  Widget _content(double boxSize, double cardW) {
    final double v = _seq.value;
    final double cardT = Curves.easeOutBack.transform(_seg(0.0, 0.08));
    final double titleT = Curves.elasticOut.transform(_seg(0.02, 0.16));
    final double drop = Curves.bounceOut.transform(_seg(0.05, 0.16));
    final double shakeP = _seg(0.16, 0.38);
    final double cRaw = _seg(0.38, 0.50);
    final double open = Curves.easeOutCubic.transform(cRaw);
    final double settle = Curves.easeOut.transform(_seg(0.50, 0.62));
    final double burst = v >= 0.38 ? _seg(0.38, 0.80) : 0.0;
    final double raysK = Curves.easeOut.transform(_seg(0.40, 0.58));
    final double gotT = Curves.easeOut.transform(_seg(0.44, 0.56));
    final double btnT = Curves.easeOut.transform(_seg(0.80, 0.92));
    final double loop = _loop.value;

    // box motion: drop in -> shake harder and harder -> POP -> float
    final double rot = v >= 0.38 ? 0 : sin(shakeP * pi * 12) * 0.16 * shakeP;
    double scale = 1 + 0.10 * shakeP;
    if (v >= 0.38) {
      scale = 1.10 + 0.16 * sin(cRaw * pi) - 0.10 * settle;
    }
    final double bob = sin(loop * 2 * pi) * 5 * settle;
    final double areaH = boxSize * 1.45;
    final double dropY = -(1 - drop) * areaH;
    final double lidOpacity = (1 - ((open - 0.55) / 0.45)).clamp(0.0, 1.0);
    final double glow = v < 0.38 ? shakeP : (1 - cRaw);

    return SafeArea(
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Opacity(
            opacity: cardT.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.8 + 0.2 * cardT,
              child: Container(
                width: cardW,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFFEAF3), Color(0xFFFFD9E8)],
                  ),
                  borderRadius: BorderRadius.circular(36),
                  border: Border.all(color: _gPinkLight, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: _gPink.withValues(alpha: 0.40),
                      blurRadius: 30,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(33),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ---- PINK HEADER: SURPRISE! ----
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFFFF9BC4), Color(0xFFFF4D96)],
                          ),
                        ),
                        child: Center(
                          child: Transform.scale(
                            scale: titleT.clamp(0.0, 1.4),
                            child: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: _OutlinedText(
                                text: 'SURPRISE!',
                                size: 40,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // ---- THE GIFT BOX (opens inside the card) ----
                      SizedBox(
                        width: double.infinity,
                        height: areaH,
                        child: ClipRect(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _GiftBurstPainter(
                                    unit: boxSize,
                                    glow: glow,
                                    burst: burst,
                                    rays: v >= 0.38 ? raysK : 0.0,
                                    rotation: loop * pi / 3,
                                    particles: _particles,
                                  ),
                                ),
                              ),
                              Transform.translate(
                                offset: Offset(0, dropY + bob),
                                child: Transform.rotate(
                                  angle: rot,
                                  child: Transform.scale(
                                    scale: scale,
                                    child: SizedBox(
                                      width: boxSize,
                                      height: boxSize,
                                      child: CustomPaint(
                                        painter: GiftBoxPainter(
                                          open: open,
                                          lidOpacity: lidOpacity,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ---- YOU GOT + REWARDS + COLLECT ----
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Opacity(
                              opacity: gotT,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.auto_awesome,
                                    size: 14,
                                    color: _gPink,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'YOU GOT',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.6,
                                      color: _gInkSoft.withValues(alpha: 0.95),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.auto_awesome,
                                    size: 14,
                                    color: _gPink,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: _buildItems(),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Opacity(
                              opacity: btnT,
                              child: Transform.translate(
                                offset: Offset(0, 20 * (1 - btnT)),
                                child: IgnorePointer(
                                  ignoring: btnT < 0.6,
                                  child: _CollectButton(onTap: widget.onDone),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The rewards pop in one after another inside the card.
  List<Widget> _buildItems() {
    final List<Widget> items = <Widget>[];
    for (int i = 0; i < widget.rewards.length; i++) {
      if (i > 0) {
        items.add(
          Container(
            width: 1.5,
            height: 92,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: _gPinkLight.withValues(alpha: 0.55),
            ),
          ),
        );
      }
      final double p = _seg(0.52 + i * 0.07, 0.68 + i * 0.07);
      items.add(
        Opacity(
          opacity: Curves.easeOut.transform((p * 2.5).clamp(0.0, 1.0)),
          child: Transform.scale(
            scale: Curves.elasticOut.transform(p).clamp(0.0, 1.4),
            child: _RewardCard(
              reward: widget.rewards[i],
              bob: sin(_loop.value * 2 * pi + i * 1.3) * 3,
            ),
          ),
        ),
      );
    }
    return items;
  }
}

/// Glow, light rays, flash, shock rings and flying hearts / sparkles.
class _GiftBurstPainter extends CustomPainter {
  final double glow;
  final double burst;
  final double rays;
  final double rotation;
  final List<_Particle> particles;
  final double unit;

  const _GiftBurstPainter({
    required this.unit,
    required this.glow,
    required this.burst,
    required this.rays,
    required this.rotation,
    required this.particles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double s = unit;

    // light rays behind the box
    if (rays > 0.01) {
      final double radius = s * 2.6;
      final Paint rp = Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.55 * rays),
            const Color(0xFFFF9BC4).withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: radius));
      const int n = 12;
      for (int i = 0; i < n; i++) {
        final double a0 = rotation + i * 2 * pi / n;
        final double a1 = a0 + pi / n;
        final Path wedge = Path()
          ..moveTo(c.dx, c.dy)
          ..lineTo(c.dx + cos(a0) * radius, c.dy + sin(a0) * radius)
          ..lineTo(c.dx + cos(a1) * radius, c.dy + sin(a1) * radius)
          ..close();
        canvas.drawPath(wedge, rp);
      }
    }

    // glow that grows while the box shakes
    if (glow > 0.01) {
      final double gr = s * (0.55 + 0.35 * glow);
      canvas.drawCircle(
        c,
        gr,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFF6FAE).withValues(alpha: 0.55 * glow),
              const Color(0xFFFF6FAE).withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: gr)),
      );
    }

    if (burst <= 0) return;

    final Offset origin = c.translate(0, -s * 0.12);

    // white flash
    final double flashT = (burst / 0.22).clamp(0.0, 1.0);
    if (flashT < 1) {
      final double fr = s * (0.35 + 1.0 * flashT);
      canvas.drawCircle(
        origin,
        fr,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.95 * (1 - flashT)),
              const Color(0xFFFF9BC4).withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromCircle(center: origin, radius: fr)),
      );
    }

    // shock rings
    final double e = Curves.easeOut.transform(burst);
    canvas.drawCircle(
      origin,
      s * (0.3 + 1.5 * e),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.06 * (1 - burst) + 1
        ..color = Colors.white.withValues(alpha: (1 - burst) * 0.9),
    );
    final double e2 = ((burst - 0.12) / 0.88).clamp(0.0, 1.0);
    if (e2 > 0) {
      canvas.drawCircle(
        origin,
        s * (0.25 + 1.2 * Curves.easeOut.transform(e2)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.04 * (1 - e2) + 1
          ..color = const Color(0xFFFF6FAE).withValues(alpha: (1 - e2) * 0.8),
      );
    }

    // flying particles
    final double pe = Curves.easeOutCubic.transform(burst);
    for (final _Particle p in particles) {
      final double dist = p.speed * s * 0.9 * pe;
      final Offset pos = Offset(
        origin.dx + cos(p.angle) * dist,
        origin.dy + sin(p.angle) * dist + s * 0.45 * burst * burst,
      );
      final double alpha = (1 - burst * burst).clamp(0.0, 1.0);
      final double sz = p.size * (1 - 0.35 * burst);
      final Paint paint = Paint()
        ..color = _burstColors[p.color].withValues(alpha: alpha);

      switch (p.shape) {
        case 0:
          canvas.drawCircle(pos, sz, paint);
          break;
        case 1:
          canvas.drawPath(_sparklePath(pos, sz * 1.6), paint);
          break;
        default:
          canvas.drawPath(
            _heartPath(pos, sz * 0.9),
            Paint()..color = const Color(0xFFFF6FAE).withValues(alpha: alpha),
          );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GiftBurstPainter old) => true;
}

class _RewardCard extends StatelessWidget {
  final GiftReward reward;
  final double bob;

  const _RewardCard({required this.reward, required this.bob});

  @override
  Widget build(BuildContext context) {
    // One reward inside the shared card (no card of its own any more).
    return SizedBox(
      width: 80,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.translate(
            offset: Offset(0, bob),
            child: Container(
              width: 62,
              height: 62,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0xFFFFF7FB), Color(0xFFFFD0E4)],
                ),
              ),
              child: SizedBox(
                width: 44,
                height: 44,
                child: CustomPaint(
                  painter: reward.isCoins
                      ? const _CoinPainter()
                      : BoosterIconPainter(reward.booster!),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '+${reward.amount}',
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: _gPink,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              reward.label,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: _gInkSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoinPainter extends CustomPainter {
  const _CoinPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double r = min(size.width, size.height) / 2;

    canvas.drawCircle(
      c.translate(0, r * 0.08),
      r * 0.96,
      Paint()
        ..color = const Color(0x33B56B00)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(
      c,
      r * 0.94,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.4, -0.5),
          colors: [Color(0xFFFFF0A8), Color(0xFFFFC43D), Color(0xFFE09A12)],
          stops: [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
      c,
      r * 0.94,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.10
        ..color = const Color(0xFFD98A00),
    );
    canvas.drawCircle(
      c,
      r * 0.66,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.06
        ..color = const Color(0xFFFFE08A),
    );
    canvas.drawPath(
      _sparklePath(c, r * 0.42),
      Paint()..color = Colors.white.withValues(alpha: 0.95),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: c.translate(-r * 0.4, -r * 0.5),
        width: r * 0.4,
        height: r * 0.2,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.6),
    );
  }

  @override
  bool shouldRepaint(covariant _CoinPainter old) => false;
}

class _OutlinedText extends StatelessWidget {
  final String text;
  final double size;

  const _OutlinedText({required this.text, required this.size});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          text,
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size * 0.22
              ..strokeJoin = StrokeJoin.round
              ..color = _gPink,
          ),
        ),
        Text(
          text,
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: Colors.white,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 6,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CollectButton extends StatefulWidget {
  final VoidCallback onTap;

  const _CollectButton({required this.onTap});

  @override
  State<_CollectButton> createState() => _CollectButtonState();
}

class _CollectButtonState extends State<_CollectButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: () {
        SoundService.instance.click();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _down ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: Container(
          width: 220,
          padding: const EdgeInsets.symmetric(vertical: 14),
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
              const BoxShadow(color: Color(0xFFB0206B), offset: Offset(0, 4)),
              BoxShadow(
                color: _gPink.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_rounded, color: Colors.white, size: 24),
              SizedBox(width: 7),
              Text(
                'COLLECT',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
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