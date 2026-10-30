part of '../word_bloom.dart';

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 5, 13, 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.20),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color.lerp(color, Colors.white, 0.35)!, color],
              ),
            ),
            child: Icon(icon, size: 13, color: Colors.white),
          ),
          const SizedBox(width: 7),
          Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12.5,
              letterSpacing: 0.2,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToastPill extends StatelessWidget {
  final String text;
  const _ToastPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 18, 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFFFFEAF3)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFFB6D3), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF4D96).withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFF9BC4), Color(0xFFFF4D96)],
              ),
            ),
            child: const Icon(
              Icons.priority_high_rounded,
              size: 17,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF6B3A55),
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// TOP BAR: round pause button | level + star progress | score
// The progress fill only ever moves forward (see _shownProgress).
// ================================================================

class _TopBar extends StatelessWidget {
  final VoidCallback onPause;
  final double progress;
  final int collectedStars;
  final int? completedWords;
  final int totalWords;
  const _TopBar({
    required this.onPause,
    required this.progress,
    this.collectedStars = 0,
    this.completedWords,
    this.totalWords = 1,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 64,
    child: Row(
      children: [
        BloomBackButton(
          onTap: onPause,
          icon: Icons.pause_rounded,
          label: 'Pause',
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0x99FFE8F3),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (completedWords != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      'WORDS  $completedWords / $totalWords',
                      style: const TextStyle(
                        fontFamily: 'Fredoka',
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: Color(0xFFBB3482),
                      ),
                    ),
                  ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (_, box) => Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          height: 9,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE9C6DC),
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: progress.clamp(0.0, 1.0),
                            child: Container(
                              height: 9,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(9),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFF9CCF),
                                    Color(0xFFE0388C),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        for (var i = 0; i < 3; i++)
                          Positioned(
                            left:
                                (box.maxWidth - 25) * const [0.5, 0.75, 1.0][i],
                            child: AnimatedScale(
                              scale: collectedStars > i ? 1.12 : 1,
                              duration: const Duration(milliseconds: 250),
                              child: Icon(
                                Icons.star_rounded,
                                size: 25,
                                color: collectedStars > i
                                    ? const Color(0xFFFFC74C)
                                    : const Color(0xFFDABACE),
                                shadows: const [
                                  Shadow(color: Colors.white, blurRadius: 3),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

/// The ONE coin icon used everywhere (game screen, level select, ...).
class CoinIcon extends StatelessWidget {
  final double size;
  const CoinIcon({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const CustomPaint(painter: _CoinIconPainter()),
    );
  }

  /// Draws the same coin on any canvas, centred at [c] with radius [r].
  static void paint(Canvas canvas, Offset c, double r, {double alpha = 1}) {
    canvas.drawCircle(
      c + Offset(0, r * 0.12),
      r,
      Paint()
        ..color = const Color(0xFFFFA726).withValues(alpha: 0.35 * alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.25),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFE680), Color(0xFFFFA726)],
        ).createShader(Rect.fromCircle(center: c, radius: r))
        ..color = Colors.white.withValues(alpha: alpha),
    );
    canvas.drawCircle(
      c,
      r * 0.74,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.16
        ..color = const Color(0xFFD9820F).withValues(alpha: 0.85 * alpha),
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.5),
      3.4,
      1.3,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = r * 0.14
        ..color = Colors.white.withValues(alpha: 0.85 * alpha),
    );
  }
}

class _CoinIconPainter extends CustomPainter {
  const _CoinIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    CoinIcon.paint(canvas, size.center(Offset.zero), size.shortestSide / 2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PraisePopup extends StatelessWidget {
  final String text;

  const _PraisePopup({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1400),
      builder: (context, t, child) {
        final double scale = t < 0.2
            ? Curves.easeOutBack.transform(t / 0.2)
            : 1.0 + (t - 0.2) * 0.06;
        final double opacity = t < 0.75 ? 1.0 : 1.0 - (t - 0.75) / 0.25;

        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, -36 * t),
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 46,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 9
                ..strokeJoin = StrokeJoin.round
                ..color = const Color(0xFFFF4D96),
            ),
          ),
          Text(
            text,
            style: TextStyle(
              fontSize: 46,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
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
      ),
    );
  }
}

// ================================================================
// PAUSE DIALOG (same style as the Settings card)
// ================================================================

class _FoundWord extends StatelessWidget {
  final String word;
  final int done;
  final int total;
  const _FoundWord({
    required this.word,
    required this.done,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BloomAnimatedLabel('$word ✓', size: 22, textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(
            '$done / $total',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF7A4A3A),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// GAME OVER OVERLAY
// ================================================================
