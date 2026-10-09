import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

import 'booster_service.dart';

const Color _plum = Color(0xFF6B3A55);
const Color _plumDark = Color(0xFF4A1F38);
const Color _rose = Color(0xFFFF4D96);
const Color _roseDeep = Color(0xFFE0287F);

// ================================================================
// BOOSTER BAR  (sits BELOW the game area, never over the shooter)
// ================================================================

class BoosterBar extends StatelessWidget {
  final BoosterService service;
  final BoosterId? armed;
  final ValueChanged<BoosterDef> onTap;

  const BoosterBar({
    super.key,
    required this.service,
    required this.onTap,
    this.armed,
  });

  @override
  Widget build(BuildContext context) {
    final double w = MediaQuery.sizeOf(context).width;
    final double orb = ((w - 24 - 12) / 5 - 10).clamp(44.0, 58.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
      child: ListenableBuilder(
        listenable: service,
        builder: (context, _) {
          return Container(
            padding: const EdgeInsets.fromLTRB(4, 13, 4, 8),
            decoration: BoxDecoration(
              // Deeper pink -> purple so the bar stands out from the screen.
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFFB3D6),
                  Color(0xFFFF8FC2),
                  Color(0xFFC49BF2),
                ],
              ),
              borderRadius: BorderRadius.circular(34),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: _roseDeep.withValues(alpha: 0.38),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // glossy highlight along the top edge
                Positioned(
                  top: -9,
                  left: 30,
                  right: 30,
                  height: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                // little sparkles in the corners
                Positioned(
                  top: -7,
                  left: 14,
                  child: Icon(
                    Icons.auto_awesome,
                    size: 12,
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
                ),
                Positioned(
                  top: -7,
                  right: 14,
                  child: Icon(
                    Icons.auto_awesome,
                    size: 12,
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final BoosterDef def in kBoosters)
                      _BoosterSlot(
                        def: def,
                        size: orb,
                        qty: service.quantity(def.id),
                        unlocked: service.isUnlocked(def),
                        ready: service.loaded,
                        armed: armed == def.id,
                        onTap: () => onTap(def),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

ColorFilter _saturation(double s) {
  const double lr = 0.2126, lg = 0.7152, lb = 0.0722;
  return ColorFilter.matrix(<double>[
    lr * (1 - s) + s, lg * (1 - s), lb * (1 - s), 0, 0, //
    lr * (1 - s), lg * (1 - s) + s, lb * (1 - s), 0, 0, //
    lr * (1 - s), lg * (1 - s), lb * (1 - s) + s, 0, 0, //
    0, 0, 0, 1, 0,
  ]);
}

String _shortName(BoosterId id) {
  switch (id) {
    case BoosterId.bloomSwap:
      return 'Swap';
    case BoosterId.bloomBomb:
      return 'Bomb';
    case BoosterId.rainbowBloom:
      return 'Rainbow';
    case BoosterId.bloomLightning:
      return 'Lightning';
    case BoosterId.flowerBlast:
      return 'Blast';
  }
}

/// Each booster gets its own saturated colour so they read clearly
/// against the pink bar.
class _Tint {
  final Color mid, deep, glow;
  const _Tint(this.mid, this.deep, this.glow);
}

_Tint _tintFor(BoosterId id) {
  switch (id) {
    case BoosterId.bloomSwap:
      return const _Tint(
        Color(0xFFBFDDFF),
        Color(0xFF6FA8FF),
        Color(0xFF3F86E6),
      );
    case BoosterId.bloomBomb:
      return const _Tint(
        Color(0xFFFFA3C8),
        Color(0xFFFF4D96),
        Color(0xFFE0287F),
      );
    case BoosterId.rainbowBloom:
      return const _Tint(
        Color(0xFFE3D4FF),
        Color(0xFFB894FF),
        Color(0xFF8A62D8),
      );
    case BoosterId.bloomLightning:
      return const _Tint(
        Color(0xFFBBD3FF),
        Color(0xFF6F8CFF),
        Color(0xFF4F6BE8),
      );
    case BoosterId.flowerBlast:
      return const _Tint(
        Color(0xFFFFC9A8),
        Color(0xFFFF8A5C),
        Color(0xFFFF7A59),
      );
  }
}

class _BoosterSlot extends StatefulWidget {
  final BoosterDef def;
  final double size;
  final int qty;
  final bool unlocked;
  final bool ready;
  final bool armed;
  final VoidCallback onTap;

  const _BoosterSlot({
    required this.def,
    required this.size,
    required this.qty,
    required this.unlocked,
    required this.ready,
    required this.armed,
    required this.onTap,
  });

  @override
  State<_BoosterSlot> createState() => _BoosterSlotState();
}

class _BoosterSlotState extends State<_BoosterSlot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _gain = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  bool _down = false;
  int _gainAmount = 0;

  @override
  void didUpdateWidget(covariant _BoosterSlot old) {
    super.didUpdateWidget(old);
    // small "+n" animation when a booster is earned
    if (widget.ready &&
        old.ready &&
        widget.unlocked &&
        old.unlocked &&
        widget.qty > old.qty) {
      _gainAmount = widget.qty - old.qty;
      _gain.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _gain.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool usable = widget.unlocked && widget.qty > 0;
    final double s = widget.size;
    final _Tint tint = _tintFor(widget.def.id);

    Widget icon = SizedBox.expand(
      child: CustomPaint(painter: BoosterIconPainter(widget.def.id)),
    );
    if (!usable) {
      // dimmed, but still clearly coloured (not washed out)
      icon = Opacity(
        opacity: widget.unlocked ? 0.85 : 0.50,
        child: ColorFiltered(
          colorFilter: _saturation(widget.unlocked ? 0.70 : 0.12),
          child: icon,
        ),
      );
    }

    final List<Color> orbColors = usable
        ? [Colors.white, tint.mid, tint.deep]
        : widget.unlocked
        ? [
            Colors.white,
            Color.lerp(tint.mid, const Color(0xFFEDE6EB), 0.40)!,
            Color.lerp(tint.deep, const Color(0xFFD9CCD5), 0.45)!,
          ]
        : const [Color(0xFFFBF6F9), Color(0xFFE9DEE5), Color(0xFFD2C4CD)];

    final String label = widget.unlocked
        ? _shortName(widget.def.id)
        : 'Lv ${widget.def.unlockLevel}';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.90 : (widget.armed ? 1.07 : 1.0),
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: SizedBox(
          width: s + 8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: s,
                height: s,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // the round glossy orb
                    Positioned.fill(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            center: const Alignment(-0.3, -0.45),
                            radius: 1.0,
                            colors: orbColors,
                            stops: const [0.0, 0.6, 1.0],
                          ),
                          border: Border.all(
                            color: Colors.white,
                            width: widget.armed ? 4 : 3,
                          ),
                          boxShadow: [
                            if (widget.armed)
                              BoxShadow(
                                color: tint.glow.withValues(alpha: 0.75),
                                blurRadius: 18,
                                spreadRadius: 3,
                              ),
                            BoxShadow(
                              color: (usable ? tint.glow : _plum).withValues(
                                alpha: usable ? 0.50 : 0.15,
                              ),
                              blurRadius: usable ? 14 : 6,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // small glossy shine on the orb
                    Positioned(
                      top: s * 0.07,
                      left: s * 0.20,
                      child: Container(
                        width: s * 0.30,
                        height: s * 0.12,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(
                            alpha: usable ? 0.75 : 0.45,
                          ),
                          borderRadius: BorderRadius.circular(s),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Padding(
                        padding: EdgeInsets.all(s * 0.13),
                        child: icon,
                      ),
                    ),
                    if (!widget.unlocked)
                      Positioned(right: -3, bottom: -3, child: _lockBadge())
                    else
                      Positioned(
                        right: -4,
                        bottom: -4,
                        child: _qtyBadge(usable),
                      ),
                    Positioned(
                      top: -20,
                      left: -10,
                      right: -10,
                      child: IgnorePointer(
                        child: AnimatedBuilder(
                          animation: _gain,
                          builder: (context, _) {
                            final double v = _gain.value;
                            if (v <= 0 || v >= 1) {
                              return const SizedBox.shrink();
                            }
                            final double o = v < 0.7
                                ? 1.0
                                : 1 - (v - 0.7) / 0.3;
                            return Opacity(
                              opacity: o.clamp(0.0, 1.0),
                              child: Transform.translate(
                                offset: Offset(0, -14 * v),
                                child: Center(
                                  child: Text(
                                    '+$_gainAmount',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                      color: _roseDeep,
                                      shadows: [
                                        Shadow(
                                          color: Colors.white,
                                          blurRadius: 5,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                  color: usable
                      ? _plumDark
                      : _plumDark.withValues(
                          alpha: widget.unlocked ? 0.75 : 0.55,
                        ),
                  shadows: const [
                    Shadow(color: Colors.white54, blurRadius: 3),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _qtyBadge(bool usable) {
    return Container(
      constraints: const BoxConstraints(minWidth: 24),
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: usable
              ? const [Color(0xFFFF9BC4), _roseDeep]
              : const [Color(0xFFA68A9B), Color(0xFF86697B)],
        ),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        '${widget.qty}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w900,
          height: 1.0,
        ),
      ),
    );
  }

  Widget _lockBadge() {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFA88BC0), Color(0xFF7C5C96)],
        ),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: const Icon(Icons.lock_rounded, size: 12, color: Colors.white),
    );
  }
}

// ================================================================
// BOOSTER ICONS  (drawn in code - no image assets needed)
// ================================================================

class BoosterIconPainter extends CustomPainter {
  final BoosterId id;
  const BoosterIconPainter(this.id);

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double r = min(size.width, size.height) / 2;

    switch (id) {
      case BoosterId.bloomSwap:
        _swap(canvas, c, r);
      case BoosterId.bloomBomb:
        _bomb(canvas, c, r);
      case BoosterId.rainbowBloom:
        _rainbow(canvas, c, r);
      case BoosterId.bloomLightning:
        _lightning(canvas, c, r);
      case BoosterId.flowerBlast:
        _flowerBlast(canvas, c, r);
    }
  }

  // ---------- helpers ----------

  void _bubble(Canvas canvas, Offset c, double r, Color light, Color deep) {
    canvas.drawCircle(
      c.translate(0, r * 0.10),
      r,
      Paint()
        ..color = deep.withValues(alpha: 0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.45),
          radius: 0.95,
          colors: [Colors.white.withValues(alpha: 0.80), light, deep],
          stops: const [0.0, 0.35, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: c.translate(-r * 0.30, -r * 0.50),
        width: r * 0.55,
        height: r * 0.28,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.60),
    );
  }

  void _flower(
    Canvas canvas,
    Offset c,
    double r,
    int petals,
    Color light,
    Color deep, {
    double petalW = 0.6,
    double petalH = 0.9,
    double dist = 0.5,
    double rotate = 0,
  }) {
    for (int i = 0; i < petals; i++) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(rotate + 2 * pi * i / petals);
      final Rect rect = Rect.fromCenter(
        center: Offset(0, -r * dist),
        width: r * petalW,
        height: r * petalH,
      );
      canvas.drawOval(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [light, deep],
          ).createShader(rect),
      );
      canvas.drawOval(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.04
          ..color = Colors.white.withValues(alpha: 0.55),
      );
      canvas.restore();
    }
  }

  void _gold(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: [Color(0xFFFFF4C2), Color(0xFFFFC857)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  void _arc(
    Canvas canvas,
    Offset c,
    double radius,
    double start,
    double sweep,
    Color color,
    double w,
  ) {
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: radius),
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
    final double a = start + sweep;
    final Offset p = c + Offset(cos(a), sin(a)) * radius;
    final Offset d = Offset(-sin(a), cos(a));
    final Offset n = Offset(-d.dy, d.dx);
    final double s = w * 1.5;
    final Path head = Path()
      ..moveTo(p.dx + d.dx * s, p.dy + d.dy * s)
      ..lineTo(p.dx + n.dx * s * 0.8, p.dy + n.dy * s * 0.8)
      ..lineTo(p.dx - n.dx * s * 0.8, p.dy - n.dy * s * 0.8)
      ..close();
    canvas.drawPath(head, Paint()..color = color);
  }

  // ---------- the five icons ----------

  void _swap(Canvas canvas, Offset c, double r) {
    _bubble(
      canvas,
      c.translate(-r * 0.36, r * 0.10),
      r * 0.50,
      const Color(0xFFFFB3D4),
      _rose,
    );
    _bubble(
      canvas,
      c.translate(r * 0.36, -r * 0.10),
      r * 0.50,
      const Color(0xFFBFDDFF),
      const Color(0xFF5B9BF0),
    );
    _arc(canvas, c, r * 0.86, -pi * 0.80, pi * 0.55, _roseDeep, r * 0.13);
    _arc(
      canvas,
      c,
      r * 0.86,
      pi * 0.20,
      pi * 0.55,
      const Color(0xFF3F86E6),
      r * 0.13,
    );
  }

  void _bomb(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(
      c,
      r * 0.96,
      Paint()
        ..color = _rose.withValues(alpha: 0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    _bubble(canvas, c, r * 0.88, const Color(0xFFFFC2DC), _rose);
    _flower(
      canvas,
      c,
      r * 0.80,
      6,
      const Color(0xFFFFF0F7),
      const Color(0xFFFF8FBE),
      petalW: 0.55,
      petalH: 0.80,
      dist: 0.42,
    );
    _gold(canvas, c, r * 0.19);
    final Paint sparkle = Paint()..color = Colors.white.withValues(alpha: 0.9);
    canvas.drawCircle(c.translate(r * 0.62, -r * 0.62), r * 0.07, sparkle);
    canvas.drawCircle(c.translate(-r * 0.66, r * 0.50), r * 0.05, sparkle);
  }

  void _rainbow(Canvas canvas, Offset c, double r) {
    final Rect rect = Rect.fromCircle(center: c, radius: r * 0.88);
    canvas.drawCircle(
      c.translate(0, r * 0.10),
      r * 0.88,
      Paint()
        ..color = const Color(0xFF8A62D8).withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(
      c,
      r * 0.88,
      Paint()
        ..shader = const SweepGradient(
          colors: [
            Color(0xFFFF8FB8),
            Color(0xFFFFC37A),
            Color(0xFFFFF08A),
            Color(0xFF9BE8B5),
            Color(0xFF8FD0FF),
            Color(0xFFC3A3FF),
            Color(0xFFFF8FB8),
          ],
        ).createShader(rect),
    );
    canvas.drawCircle(
      c,
      r * 0.88,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.45),
          radius: 0.95,
          colors: [
            Colors.white.withValues(alpha: 0.70),
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: 0.12),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(rect),
    );
    _flower(
      canvas,
      c,
      r * 0.62,
      5,
      Colors.white,
      const Color(0xFFFFE4F0),
      petalW: 0.60,
      petalH: 0.85,
      dist: 0.50,
    );
    _gold(canvas, c, r * 0.14);
  }

  void _lightning(Canvas canvas, Offset c, double r) {
    _bubble(
      canvas,
      c,
      r * 0.88,
      const Color(0xFFFFA3CB),
      const Color(0xFF6FA8FF),
    );
    const List<Offset> pts = [
      Offset(0.12, -0.66),
      Offset(-0.34, 0.06),
      Offset(-0.04, 0.06),
      Offset(-0.14, 0.66),
      Offset(0.34, -0.12),
      Offset(0.04, -0.12),
    ];
    final Path bolt = Path();
    for (int i = 0; i < pts.length; i++) {
      final Offset p = c + pts[i] * r;
      if (i == 0) {
        bolt.moveTo(p.dx, p.dy);
      } else {
        bolt.lineTo(p.dx, p.dy);
      }
    }
    bolt.close();
    canvas.drawPath(
      bolt.shift(Offset(0, r * 0.05)),
      Paint()..color = const Color(0xFF3F4FB0).withValues(alpha: 0.30),
    );
    canvas.drawPath(bolt, Paint()..color = Colors.white);
    canvas.drawPath(
      bolt,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.05
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFFFF8FBE),
    );
  }

  void _flowerBlast(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(
      c,
      r * 0.95,
      Paint()
        ..color = const Color(0xFFC8A8FF).withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    _flower(
      canvas,
      c,
      r * 0.98,
      8,
      const Color(0xFFFFD1E6),
      const Color(0xFFFF6FAE),
      petalW: 0.50,
      petalH: 0.82,
      dist: 0.60,
    );
    _flower(
      canvas,
      c,
      r * 0.74,
      8,
      Colors.white,
      const Color(0xFFFFB3D4),
      petalW: 0.46,
      petalH: 0.72,
      dist: 0.50,
      rotate: pi / 8,
    );
    _gold(canvas, c, r * 0.24);
    final Paint dot = Paint()..color = const Color(0xFFFFF4CC);
    for (int i = 0; i < 6; i++) {
      final double a = i * pi / 3;
      canvas.drawCircle(
        c.translate(cos(a) * r * 0.12, sin(a) * r * 0.12),
        r * 0.025,
        dot,
      );
    }
  }

  @override
  bool shouldRepaint(covariant BoosterIconPainter old) => old.id != id;
}

// ================================================================
// LOCKED POPUP  ("Reach Level 50 to unlock Rainbow Bloom.")
// ================================================================

Future<void> showBoosterLockedPopup(BuildContext context, BoosterDef def) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (ctx) {
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 44),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
          decoration: _cardDecoration(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 70,
                height: 70,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.55,
                        child: ColorFiltered(
                          colorFilter: _saturation(0.15),
                          child: CustomPaint(
                            painter: BoosterIconPainter(def.id),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFFA88BC0), Color(0xFF7C5C96)],
                          ),
                          border: Border.all(color: Colors.white, width: 2.5),
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          size: 15,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Locked',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: _plum,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Reach Level ${def.unlockLevel} to unlock ${def.name}.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                  color: _plum.withValues(alpha: 0.80),
                ),
              ),
              const SizedBox(height: 16),
              _PillButton(label: 'OK', onTap: () => Navigator.of(ctx).pop()),
            ],
          ),
        ),
      );
    },
  );
}

BoxDecoration _cardDecoration(double radius) {
  return BoxDecoration(
    gradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFFFEAF3), Color(0xFFFFD9E8)],
    ),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: Colors.white, width: 4),
    boxShadow: [
      BoxShadow(
        color: _rose.withValues(alpha: 0.28),
        blurRadius: 28,
        offset: const Offset(0, 12),
      ),
    ],
  );
}

class _PillButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PillButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        width: 130,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(21),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFF7DB8), _roseDeep],
          ),
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: const [
            BoxShadow(color: Color(0xFFB81A68), offset: Offset(0, 3)),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 15,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

// ================================================================
// UNLOCK / REWARD CELEBRATION  (short, tap anywhere to skip)
// ================================================================

Future<void> showBoosterRewardDialog(BuildContext context, BoosterGrant grant) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => _RewardCard(grant: grant),
  );
}

class _RewardCard extends StatefulWidget {
  final BoosterGrant grant;
  const _RewardCard({required this.grant});

  @override
  State<_RewardCard> createState() => _RewardCardState();
}

class _RewardCardState extends State<_RewardCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..forward();
  Timer? _auto;

  @override
  void initState() {
    super.initState();
    _auto = Timer(const Duration(milliseconds: 3800), () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  void dispose() {
    _auto?.cancel();
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final BoosterGrant g = widget.grant;

    final String title = g.bloomMaster
        ? 'BLOOM MASTER!'
        : g.newlyUnlocked.isNotEmpty
        ? 'NEW BOOSTER!'
        : 'BLOOM REWARD';
    final String subtitle = g.bloomMaster
        ? 'Every booster mastered'
        : g.newlyUnlocked.isNotEmpty
        ? '${g.newlyUnlocked.map((b) => b.name).join(' & ')} Unlocked'
        : 'A little magic for you';

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 36),
      child: GestureDetector(
        onTap: () => Navigator.of(context).maybePop(),
        child: AnimatedBuilder(
          animation: _in,
          builder: (context, _) {
            final double e = Curves.easeOutBack.transform(_in.value);
            return Opacity(
              opacity: Curves.easeOut.transform(_in.value.clamp(0.0, 1.0)),
              child: Transform.scale(
                scale: 0.85 + 0.15 * e,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
                  decoration: _cardDecoration(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: 18,
                            color: _rose.withValues(alpha: 0.5 + 0.5 * e),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                              color: _roseDeep,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.auto_awesome,
                            size: 18,
                            color: _rose.withValues(alpha: 0.5 + 0.5 * e),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _plum,
                        ),
                      ),
                      const SizedBox(height: 14),
                      for (int i = 0; i < g.rewards.length; i++)
                        _rewardRow(g.rewards[i], i),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to continue',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: _plum.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _rewardRow(BoosterReward r, int index) {
    final double t = ((_in.value - 0.25 - index * 0.10) / 0.30).clamp(0.0, 1.0);
    final BoosterDef def = boosterDef(r.id);

    return Opacity(
      opacity: t,
      child: Transform.translate(
        offset: Offset(0, 10 * (1 - t)),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 42,
                height: 42,
                child: CustomPaint(painter: BoosterIconPainter(r.id)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '+${r.amount}  ${def.name}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: _plum,
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