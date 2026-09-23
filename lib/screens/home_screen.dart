import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'level_select_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-bleed background artwork. Its own "START BLOOMING"
          // pill is already drawn into this image - we do NOT draw a
          // second button on top of it.
          Image.asset(
            'assets/images/word_bloom_bg.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF7EC8F5), Color(0xFFFFD9EA)],
                  ),
                ),
              );
            },
          ),
          Align(
            alignment: const Alignment(0, -0.45),
            child: Image.asset(
              'assets/images/word_bloom_logo.png',
              width: width * 0.85,
              fit: BoxFit.contain,
            ),
          ),
          // A real, visible Flutter button - not just an invisible
          // tap area. Positioned roughly where the artwork's own
          // button sits, styled to match it.
          Align(
            alignment: const Alignment(0, 0.40),
            child: _StartButton(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const LevelSelectScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// START BUTTON - recreated to match the pink pill button drawn in
// the reference artwork: 3-stop pink->magenta gradient, thick white
// border, glossy top highlight, drop shadow, and small flower icons
// either side of the label (rather than a plain emoji button).
// ================================================================

class _StartButton extends StatefulWidget {
  final VoidCallback onTap;
  const _StartButton({required this.onTap});

  @override
  State<_StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends State<_StartButton>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    // A gentle continuous "breathing" pulse so the button invites a
    // tap even when nobody's touching it - on top of the existing
    // press-down animation.
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final double pulse = 1.0 + (_pulseController.value * 0.045);
          final double glow = 0.40 + (_pulseController.value * 0.30);

          return Transform.scale(
            scale: (_pressed ? 0.95 : 1.0) * pulse,
            child: Container(
              height: 74,
              padding: const EdgeInsets.symmetric(horizontal: 34),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFF7FD1),
                    Color(0xFFF61FA8),
                    Color(0xFFC20B76),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: const Color(
                      0xFFC90E7E,
                    ).withValues(alpha: _pressed ? 0.30 : glow),
                    blurRadius: _pressed
                        ? 10
                        : 22 + (_pulseController.value * 8),
                    offset: Offset(0, _pressed ? 3 : 10),
                  ),
                ],
              ),
              child: child,
            ),
          );
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _MiniFlower(size: 28),
            const SizedBox(width: 12),
            Text(
              'START BLOOMING',
              style: GoogleFonts.fredoka(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 19,
                letterSpacing: 1.0,
                shadows: const [
                  Shadow(
                    color: Color(0x4D000000),
                    blurRadius: 3,
                    offset: Offset(0, 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const _MiniFlower(size: 28),
          ],
        ),
      ),
    );
  }
}

/// Small 5-petal flower icon (white petals, pink outline, golden
/// center) matching the little flower marks on the reference button
/// - closer to the source art than a generic emoji.
class _MiniFlower extends StatelessWidget {
  final double size;
  const _MiniFlower({required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _MiniFlowerPainter());
  }
}

class _MiniFlowerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);

    final double petalLength = size.width * 0.42;
    final double petalWidth = size.width * 0.27;

    // Plain, flat pale-pink petals - no outline stroke at all (a
    // stroke here was rendering as a thick dark ring, which is what
    // looked wrong). Simple ovals, evenly spaced.
    final Paint petalPaint = Paint()..color = const Color(0xFFFFDCF3);

    for (int i = 0; i < 5; i++) {
      final double angle = (pi * 2 / 5) * i - pi / 2;

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);

      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, -petalLength * 0.42),
          width: petalWidth,
          height: petalLength,
        ),
        petalPaint,
      );

      canvas.restore();
    }

    // Center: a THIN pink-red ring around a yellow core - "thin" is
    // just a small gap between two flat circles, not a stroke, so
    // it can't render as an oversized outline.
    canvas.drawCircle(
      center,
      size.width * 0.16,
      Paint()..color = const Color(0xFFE01890),
    );
    canvas.drawCircle(
      center,
      size.width * 0.115,
      Paint()..color = const Color(0xFFFFDE5C),
    );
  }

  @override
  bool shouldRepaint(covariant _MiniFlowerPainter oldDelegate) => false;
}
