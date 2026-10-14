part of '../word_bloom.dart';

class _TutorialOverlay extends StatefulWidget {
  @override
  State<_TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<_TutorialOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.32),
      child: Stack(
        children: [
          Align(
            alignment: const Alignment(0, -0.62),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 36),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Drag to aim, let go to shoot!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF292929),
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Connect the letters to make a word',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B6B6B),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final double t = Curves.easeInOut.transform(_controller.value);
              final double dy = 0.72 - (t * 0.46);
              final double dx = 0.5 + (sin(t * pi) * 0.10);
              final double opacity = t < 0.9 ? 1.0 : (1.0 - (t - 0.9) * 10);

              return Align(
                alignment: Alignment((dx - 0.5) * 2, (dy - 0.5) * 2),
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: const Icon(
                    Icons.touch_app_rounded,
                    color: Colors.white,
                    size: 46,
                    shadows: [Shadow(color: Colors.black45, blurRadius: 8)],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}