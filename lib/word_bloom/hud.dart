part of '../word_bloom.dart';

class _WordGoalChip extends StatelessWidget {
  final int completed;
  final int total;

  const _WordGoalChip({required this.completed, required this.total});

  @override
  Widget build(BuildContext context) {
    final int safeTotal = total <= 0 ? 1 : total;
    final int safeCompleted = completed.clamp(0, safeTotal);
    final double progress = safeCompleted / safeTotal;

    return Container(
      padding: const EdgeInsets.fromLTRB(9, 7, 12, 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFFD4E5), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF4D96).withValues(alpha: 0.16),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 29,
            height: 29,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFA9CD), Color(0xFFFF4D96)],
              ),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'WORDS',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.15,
                      color: Color(0xFF8B6170),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '$safeCompleted / $safeTotal',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFE0287F),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 112,
                height: 5,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(color: const Color(0xFFFFE5EF)),
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: progress,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFFFA9CD), Color(0xFFFF4D96)],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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
  final int level;
  final int score;

  /// 0..1 = words found / words needed (never goes backwards)
  final double progress;
  final VoidCallback onPause;

  const _TopBar({
    required this.level,
    required this.score,
    required this.progress,
    required this.onPause,
  });

  static const List<double> _starAt = [0.5, 0.75, 1.0];

  @override
  Widget build(BuildContext context) {
    final double p = progress.clamp(0.0, 1.0);

    return SizedBox(
      height: 46,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PauseButton(onTap: onPause),
          const SizedBox(width: 10),

          // LEVEL + STAR PROGRESS
          Expanded(
            child: _GlassBox(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Center(
                child: Row(
                  children: [
                    const _BadgeIcon(
                      icon: Icons.auto_awesome,
                      colors: [Color(0xFFFF9BC4), Color(0xFFFF4D96)],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'LEVEL $level',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 11.5,
                              letterSpacing: 0.9,
                              height: 1.1,
                              color: Color(0xFF7A4A3A),
                            ),
                          ),
                          const SizedBox(height: 3),
                          SizedBox(
                            height: 22,
                            child: LayoutBuilder(
                              builder: (context, c) {
                                final double w = c.maxWidth;
                                // FIX: begin == end, so even if this widget is
                                // ever rebuilt from scratch it starts AT the
                                // current progress instead of zero. Later value
                                // changes still animate smoothly (current -> new).
                                return TweenAnimationBuilder<double>(
                                  // new level = brand new bar, starting at 0 (no
                                  // slide back from the previous level's fill)
                                  key: ValueKey<int>(level),
                                  tween: Tween<double>(begin: p, end: p),
                                  duration: const Duration(milliseconds: 650),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, v, _) {
                                    return Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        // track
                                        Positioned(
                                          left: 0,
                                          right: 0,
                                          top: 6,
                                          height: 12,
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFE3EF),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: const Color(0xFFFFD0E4),
                                              ),
                                            ),
                                          ),
                                        ),
                                        // fill (glossy gradient)
                                        Positioned(
                                          left: 0,
                                          top: 6,
                                          height: 12,
                                          width: (w * v).clamp(0.0, w),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            child: Stack(
                                              fit: StackFit.expand,
                                              children: [
                                                const DecoratedBox(
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: [
                                                        Color(0xFFFF9BC4),
                                                        Color(0xFFFF4D96),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                Positioned(
                                                  top: 1.5,
                                                  left: 4,
                                                  right: 4,
                                                  height: 3,
                                                  child: DecoratedBox(
                                                    decoration: BoxDecoration(
                                                      color: Colors.white
                                                          .withValues(
                                                            alpha: 0.5,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            2,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        // glowing head of the fill
                                        if (v > 0.02)
                                          Positioned(
                                            left: (w * v - 7).clamp(
                                              0.0,
                                              w - 14,
                                            ),
                                            top: 5,
                                            child: Container(
                                              width: 14,
                                              height: 14,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.white,
                                                border: Border.all(
                                                  color: const Color(
                                                    0xFFFF4D96,
                                                  ),
                                                  width: 2.5,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: const Color(
                                                      0xFFFF4D96,
                                                    ).withValues(alpha: 0.5),
                                                    blurRadius: 6,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        // the 3 stars light up as the fill reaches them
                                        for (final double at in _starAt)
                                          Positioned(
                                            left: (w * at - 11).clamp(
                                              0.0,
                                              w - 22,
                                            ),
                                            top: 0,
                                            child: AnimatedScale(
                                              scale: v >= at - 0.001
                                                  ? 1.25
                                                  : 1.0,
                                              duration: const Duration(
                                                milliseconds: 350,
                                              ),
                                              curve: Curves.easeOutBack,
                                              child: Icon(
                                                Icons.star_rounded,
                                                size: 22,
                                                color: v >= at - 0.001
                                                    ? const Color(0xFFFFB92E)
                                                    : const Color(0xFFE8CCD8),
                                                shadows: [
                                                  Shadow(
                                                    color: v >= at - 0.001
                                                        ? const Color(
                                                            0xFFFFD76A,
                                                          )
                                                        : Colors.white
                                                              .withValues(
                                                                alpha: 0.95,
                                                              ),
                                                    blurRadius: v >= at - 0.001
                                                        ? 8
                                                        : 2,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                );
                              },
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
          const SizedBox(width: 10),

          // SCORE
          _GlassBox(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Center(
              child: ConstrainedBox(
                // Fixed minimum width: the score box must NOT change size
                // when the score changes, otherwise the level bar next to it
                // gets a few px wider/narrower and the fill "jumps".
                constraints: const BoxConstraints(minWidth: 82),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CoinIcon(size: 28),
                    const SizedBox(width: 7),
                    Text(
                      '$score',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: Color(0xFF7A4A3A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
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

class _BadgeIcon extends StatelessWidget {
  final IconData icon;
  final List<Color> colors;

  const _BadgeIcon({required this.icon, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, size: 16, color: Colors.white),
    );
  }
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

class _GlassBox extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const _GlassBox({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        // see-through glass so the background picture shows behind it
        color: Colors.white.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
      ),
      child: child,
    );
  }
}

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
          Text(
            '$word ✓',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFFFF4D96),
              letterSpacing: 2,
            ),
          ),
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