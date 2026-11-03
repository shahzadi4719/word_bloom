import 'dart:math';

import 'package:flutter/material.dart';

import 'booster_bar.dart' show BoosterIconPainter;
import 'gift_service.dart';

const Color _plum = Color(0xFF6B3A55);
const Color _rose = Color(0xFFFF4D96);
const Color _roseDeep = Color(0xFFE0287F);

/// Shows the gift opening animation and the ONE reward it contained.
/// Call it with the result of `GiftService.open(...)` (a non-empty list).
Future<void> showGiftRewardDialog(BuildContext context, GiftReward reward) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (_) => _GiftRewardCard(reward: reward),
  );
}

class _GiftRewardCard extends StatefulWidget {
  final GiftReward reward;
  const _GiftRewardCard({required this.reward});

  @override
  State<_GiftRewardCard> createState() => _GiftRewardCardState();
}

class _GiftRewardCardState extends State<_GiftRewardCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.of(context).disableAnimations) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final GiftReward r = widget.reward;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 34),
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final double v = _c.value;
          // 0 - .45 : the box shakes. .45 - 1 : it opens and the reward pops.
          final double shake = v < .45 ? sin(v * 70) * (1 - v / .45) * .22 : 0;
          final double boxScale = v < .45
              ? 1 + sin(v / .45 * pi) * .12
              : (1 - ((v - .45) / .2).clamp(0.0, 1.0));
          final double reveal = ((v - .5) / .5).clamp(0.0, 1.0);
          final double pop = Curves.easeOutBack.transform(reveal);
          return Container(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFEAF3), Color(0xFFFFD0E4)],
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(
                  color: _rose.withValues(alpha: 0.32),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  reveal > 0 ? 'YOU GOT' : 'GIFT UNLOCKED',
                  style: const TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 22,
                    letterSpacing: 1,
                    color: _roseDeep,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 150,
                  width: 200,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (reveal > 0)
                        CustomPaint(
                          size: const Size(200, 150),
                          painter: _SparklePainter(reveal),
                        ),
                      if (boxScale > 0)
                        Transform.rotate(
                          angle: shake,
                          child: Transform.scale(
                            scale: boxScale,
                            child: Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const RadialGradient(
                                  center: Alignment(-.3, -.45),
                                  colors: [
                                    Colors.white,
                                    Color(0xFFFFB3D4),
                                    Color(0xFFE0287F),
                                  ],
                                  stops: [0, .55, 1],
                                ),
                                border: Border.all(color: Colors.white, width: 4),
                              ),
                              child: const Icon(
                                Icons.card_giftcard_rounded,
                                color: Colors.white,
                                size: 62,
                              ),
                            ),
                          ),
                        ),
                      if (reveal > 0)
                        Transform.scale(
                          scale: pop,
                          child: Opacity(
                            opacity: reveal.clamp(0.0, 1.0),
                            child: _rewardIcon(r),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Opacity(
                  opacity: reveal,
                  child: Column(
                    children: [
                      Text(
                        r.isCoins ? '+${r.amount} Coins' : r.label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Fredoka',
                          fontSize: 26,
                          color: _plum,
                        ),
                      ),
                      if (!r.isCoins)
                        Text(
                          '×${r.amount} added to your boosters',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _plum.withValues(alpha: .75),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Opacity(
                  opacity: reveal >= 1 ? 1 : 0.0,
                  child: GestureDetector(
                    onTap: reveal >= 1 ? () => Navigator.of(context).pop() : null,
                    child: Container(
                      height: 46,
                      width: 160,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(23),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFFF7DB8), _roseDeep],
                        ),
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0xFFB81A68),
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Text(
                        'Awesome!',
                        style: TextStyle(
                          fontFamily: 'Fredoka',
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _rewardIcon(GiftReward r) {
    if (r.isCoins) {
      return Container(
        width: 116,
        height: 116,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            center: Alignment(-.3, -.45),
            colors: [Color(0xFFFFF4C2), Color(0xFFFFC857), Color(0xFFE59A1E)],
            stops: [0, .55, 1],
          ),
          border: Border.all(color: Colors.white, width: 4),
        ),
        child: const Icon(
          Icons.monetization_on_rounded,
          size: 74,
          color: Colors.white,
        ),
      );
    }
    return Container(
      width: 116,
      height: 116,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-.3, -.45),
          colors: [Colors.white, Color(0xFFFFC7E0), Color(0xFFFF86BC)],
          stops: [0, .6, 1],
        ),
        border: Border.all(color: Colors.white, width: 4),
      ),
      child: CustomPaint(painter: BoosterIconPainter(r.booster!)),
    );
  }
}

class _SparklePainter extends CustomPainter {
  final double t; // 0 -> 1
  const _SparklePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final Paint p = Paint();
    for (int i = 0; i < 12; i++) {
      final double a = i * pi / 6 + .3;
      final double dist = 56 + 34 * Curves.easeOut.transform(t);
      final Offset o = c + Offset(cos(a), sin(a)) * dist;
      final double s = (i.isEven ? 6.0 : 4.0) * (1 - t * .4);
      p.color = (i.isEven ? const Color(0xFFFFE27A) : Colors.white)
          .withValues(alpha: (1 - t * .5).clamp(0.0, 1.0));
      final Path star = Path()
        ..moveTo(o.dx, o.dy - s * 1.6)
        ..lineTo(o.dx + s * .45, o.dy - s * .45)
        ..lineTo(o.dx + s * 1.6, o.dy)
        ..lineTo(o.dx + s * .45, o.dy + s * .45)
        ..lineTo(o.dx, o.dy + s * 1.6)
        ..lineTo(o.dx - s * .45, o.dy + s * .45)
        ..lineTo(o.dx - s * 1.6, o.dy)
        ..lineTo(o.dx - s * .45, o.dy - s * .45)
        ..close();
      canvas.drawPath(star, p);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklePainter old) => old.t != t;
}
