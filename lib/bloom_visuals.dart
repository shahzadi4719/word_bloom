import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'game_mode.dart';

/// Shared opaque, glassy bubble finish for the board, launcher and previews.
void paintBloomBubble(
  Canvas canvas,
  Offset center,
  double radius,
  Color color, {
  double shimmer = 0,
}) {
  final rect = Rect.fromCircle(center: center, radius: radius);
  canvas.drawCircle(
    center.translate(0, radius * .10),
    radius * .96,
    Paint()
      ..color = const Color(0x260F1640)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * .12),
  );
  final light = Color.lerp(color, Colors.white, .52)!;
  final dark = Color.lerp(color, const Color(0xFF40124B), .38)!;
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-.32, -.42),
        radius: 1.08,
        colors: [light, color, dark],
        stops: const [0, .46, 1],
      ).createShader(rect),
  );
  canvas.drawCircle(
    center,
    radius * .965,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * .045
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xDDFFFFFF), Color(0x10FFFFFF), Color(0x99FFFFFF)],
        stops: [0, .55, 1],
      ).createShader(rect),
  );
  canvas.drawOval(
    Rect.fromCenter(
      center: center.translate(-radius * .25, -radius * .46),
      width: radius * .93,
      height: radius * .40,
    ),
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xF2FFFFFF), Color(0x33FFFFFF)],
      ).createShader(rect),
  );
  canvas.drawArc(
    Rect.fromCircle(center: center, radius: radius * .81),
    .24,
    1.18,
    false,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = radius * .07
      ..color = Colors.white.withValues(alpha: .30),
  );
  canvas.drawCircle(
    center.translate(radius * .42, -radius * .23),
    radius * .085,
    Paint()..color = Colors.white.withValues(alpha: .75),
  );
  if (shimmer > 0) {
    final p = center.translate(radius * .60, -radius * .65);
    final r = radius * .16 * shimmer;
    final paint = Paint()..color = Colors.white.withValues(alpha: shimmer);
    canvas.drawOval(
      Rect.fromCenter(center: p, width: r * .55, height: r * 2.5),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: p, width: r * 2.5, height: r * .55),
      paint,
    );
  }
}

class BloomGoalAnimation extends StatefulWidget {
  final GameMode mode;
  final double height;
  const BloomGoalAnimation({super.key, required this.mode, this.height = 104});
  @override
  State<BloomGoalAnimation> createState() => _BloomGoalAnimationState();
}

class _BloomGoalAnimationState extends State<BloomGoalAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _controller.stop();
      _controller.value = .5;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.mode.description,
    child: SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, _) => CustomPaint(
          size: Size.infinite,
          painter: _GoalPainter(widget.mode, _controller.value),
        ),
      ),
    ),
  );
}

class _GoalPainter extends CustomPainter {
  final GameMode mode;
  final double t;
  _GoalPainter(this.mode, this.t);
  @override
  void paint(Canvas canvas, Size size) {
    final r = math.min(24.0, math.min(size.width / 8, size.height / 3));
    for (var i = 0; i < 3; i++) {
      final center = Offset(
        size.width / 2 + (i - 1) * r * 2.18,
        size.height / 2 + bloomPreviewBob(t, i, r * .42),
      );
      final color = mode.isWordMode
          ? const [Color(0xFFFF61AB), Color(0xFFAA83EE), Color(0xFF5BCDEB)][i]
          : mode == GameMode.colorMatch
          ? const Color(0xFFFF61AB)
          : const Color(0xFFAA83EE);
      paintBloomBubble(
        canvas,
        center,
        r,
        color,
        shimmer: math.max(0.0, math.sin(t * math.pi * 2)),
      );
      if (mode.showLetters) {
        final text = TextPainter(
          text: TextSpan(
            text: mode.isWordMode ? 'CAT'[i] : 'A',
            style: TextStyle(
              fontSize: r * .95,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              shadows: const [
                Shadow(
                  color: Color(0x66401955),
                  offset: Offset(0, 2),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        text.paint(canvas, center - Offset(text.width / 2, text.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GoalPainter old) =>
      old.t != t || old.mode != mode;
}

/// Each bubble gets one distinct up/down turn in every repeating cycle.
double bloomPreviewBob(double phase, int index, double amplitude) {
  final local = (phase * 3 - index);
  if (local < 0 || local > 1) return 0;
  return -math.sin(local * math.pi) * amplitude;
}

class BloomBackButton extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final String label;
  const BloomBackButton({
    super.key,
    required this.onTap,
    this.icon = Icons.arrow_back_rounded,
    this.label = 'Back',
  });
  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: Material(
      color: const Color(0xFFF5A9D0),
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: const Color(0x44B0206B),
      child: Ink(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFB8D8), Color(0xFFE0388C)],
          ),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 46,
            height: 46,
            child: Icon(icon, color: Colors.white, size: 26),
          ),
        ),
      ),
    ),
  );
}

class BloomPressButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const BloomPressButton({super.key, required this.child, required this.onTap});
  @override
  State<BloomPressButton> createState() => _BloomPressButtonState();
}

class _BloomPressButtonState extends State<BloomPressButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: _pressed ? .965 : 1,
    duration: MediaQuery.of(context).disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 160),
    curve: Curves.easeOutCubic,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: Semantics(button: true, child: widget.child),
    ),
  );
}

class BloomCloseButton extends StatelessWidget {
  final VoidCallback onTap;
  const BloomCloseButton({super.key, required this.onTap});
  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Close',
    child: Material(
      shape: const CircleBorder(),
      color: const Color(0xFFE957A5),
      elevation: 2,
      child: Ink(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFA6D2), Color(0xFFE0388C)],
          ),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const SizedBox(
            width: 38,
            height: 38,
            child: Icon(Icons.close_rounded, color: Colors.white, size: 22),
          ),
        ),
      ),
    ),
  );
}

class BloomDialogTitle extends StatelessWidget {
  final String text;
  final double size;
  const BloomDialogTitle(this.text, {super.key, this.size = 28});
  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.srcIn,
    shaderCallback: (rect) => const LinearGradient(
      colors: [Color(0xFFCF2F84), Color(0xFF9856AE)],
    ).createShader(rect),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: 'Fredoka',
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
  );
}

/// Shared rose/lavender lettering for rewards, Settings and Pause.
class BloomAnimatedLabel extends StatefulWidget {
  final String text;
  final double size;
  final TextAlign textAlign;
  const BloomAnimatedLabel(
    this.text, {
    super.key,
    this.size = 20,
    this.textAlign = TextAlign.start,
  });
  @override
  State<BloomAnimatedLabel> createState() => _BloomAnimatedLabelState();
}

class _BloomAnimatedLabelState extends State<BloomAnimatedLabel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow;
  @override
  void initState() {
    super.initState();
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _glow.stop();
      _glow.value = .5;
    } else if (!_glow.isAnimating) {
      _glow.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _glow,
    builder: (context, child) => Transform.translate(
      offset: Offset(0, -1.2 * _glow.value),
      child: ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (rect) => LinearGradient(
          begin: Alignment(-1 + _glow.value, -1),
          end: Alignment(1, 1 - _glow.value),
          colors: const [
            Color(0xFFBF297B),
            Color(0xFFDD579F),
            Color(0xFF9963B8),
            Color(0xFFBF297B),
          ],
        ).createShader(rect),
        child: child,
      ),
    ),
    child: Text(
      widget.text,
      textAlign: widget.textAlign,
      style: TextStyle(
        fontFamily: 'Fredoka',
        fontWeight: FontWeight.w700,
        fontSize: widget.size,
        color: Colors.white,
        shadows: const [
          Shadow(color: Color(0x33C83B87), blurRadius: 5, offset: Offset(0, 1)),
        ],
      ),
    ),
  );
}
