part of '../word_bloom.dart';

/// Round glossy pause button (same look as the settings badge).
class _PauseButton extends StatefulWidget {
  final VoidCallback onTap;

  const _PauseButton({required this.onTap});

  @override
  State<_PauseButton> createState() => _PauseButtonState();
}

class _PauseButtonState extends State<_PauseButton> {
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
        scale: _down ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFF9BC4), Color(0xFFE0287F)],
            ),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF4D96).withValues(alpha: 0.40),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: 4,
                left: 8,
                child: Container(
                  width: 15,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const Icon(Icons.pause_rounded, color: Colors.white, size: 26),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// PRAISE POPUP: "Nice!", "Great!" ... when a word is completed
// ================================================================

class _PauseDialog extends StatefulWidget {
  final int score;
  final VoidCallback onResume;
  final VoidCallback onRetry;
  final VoidCallback onExit;

  const _PauseDialog({
    required this.score,
    required this.onResume,
    required this.onRetry,
    required this.onExit,
  });

  @override
  State<_PauseDialog> createState() => _PauseDialogState();
}

class _PauseDialogState extends State<_PauseDialog>
    with TickerProviderStateMixin {
  bool _musicOn = SoundService.instance.musicOn;
  bool _soundOn = SoundService.instance.soundOn;
  bool _vibrateOn = true;

  late final AnimationController _enter;
  late final AnimationController _loop;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..forward();
    _loop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _enter.dispose();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22),
      child: AnimatedBuilder(
        animation: Listenable.merge([_enter, _loop]),
        builder: (context, _) {
          final double e = Curves.easeOutBack.transform(_enter.value);
          final double l = Curves.easeInOut.transform(_loop.value);

          return Opacity(
            opacity: Curves.easeOut.transform(_enter.value),
            child: Transform.scale(scale: 0.85 + 0.15 * e, child: _card(l)),
          );
        },
      ),
    );
  }

  Widget _card(double l) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        // CARD
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 46),
          padding: const EdgeInsets.fromLTRB(18, 62, 18, 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFEAF3), Color(0xFFFFD9E8)],
            ),
            borderRadius: BorderRadius.circular(36),
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF4D96).withValues(alpha: 0.28),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BloomDialogTitle('Paused', size: 30),
              const SizedBox(height: 18),
              _PauseToggleRow(
                icon: Icons.music_note_rounded,
                label: 'Music',
                value: _musicOn,
                colors: const [Color(0xFFFF9BC4), Color(0xFFE0287F)],
                onChanged: (v) {
                  setState(() => _musicOn = v);
                  SoundService.instance.setMusicOn(v);
                },
              ),
              const SizedBox(height: 12),
              _PauseToggleRow(
                icon: Icons.volume_up_rounded,
                label: 'Sound',
                value: _soundOn,
                colors: const [Color(0xFFC8A8FF), Color(0xFF8A62D8)],
                onChanged: (v) {
                  setState(() => _soundOn = v);
                  SoundService.instance.setSoundOn(v);
                },
              ),
              const SizedBox(height: 12),
              _PauseToggleRow(
                icon: Icons.vibration_rounded,
                label: 'Vibrate',
                value: _vibrateOn,
                colors: const [Color(0xFFFFA77A), Color(0xFFFF7A59)],
                onChanged: (v) => setState(() => _vibrateOn = v),
              ),
              const SizedBox(height: 20),
              _PauseButton3D(
                label: 'RESUME',
                icon: Icons.play_arrow_rounded,
                primary: true,
                height: 58,
                onTap: widget.onResume,
              ),
              const SizedBox(height: 12),
              _PauseButton3D(
                label: 'RETRY',
                icon: Icons.refresh_rounded,
                textColor: const Color(0xFFE0287F),
                height: 48,
                onTap: widget.onRetry,
              ),
            ],
          ),
        ),

        // CLOSE
        Positioned(
          top: 64,
          right: 14,
          child: BloomCloseButton(onTap: widget.onResume),
        ),

        // BADGE (breathes gently)
        Positioned(
          top: 0,
          child: Transform.scale(
            scale: 1.0 + 0.035 * l,
            child: const _PauseBadge(),
          ),
        ),
      ],
    );
  }
}

class _PauseBadge extends StatelessWidget {
  const _PauseBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFF9BC4), Color(0xFFE0287F)],
        ),
        border: Border.all(color: Colors.white, width: 5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF4D96).withValues(alpha: 0.40),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 9,
            left: 16,
            child: Container(
              width: 36,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.32),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const Icon(
            Icons.pause_rounded,
            color: Colors.white,
            size: 46,
            shadows: [Shadow(color: Colors.black26, blurRadius: 6)],
          ),
        ],
      ),
    );
  }
}

class _PauseToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final List<Color> colors;
  final ValueChanged<bool> onChanged;

  const _PauseToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.colors,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF4D96).withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: colors,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.last.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BloomAnimatedLabel(label, size: 20),
                const SizedBox(height: 3),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Text(
                    value ? 'On' : 'Off',
                    key: ValueKey(value),
                    style: TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: value
                          ? const Color(0xFFC3458D)
                          : const Color(0xFF9C8A95),
                    ),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              SoundService.instance.click();
              onChanged(!value);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: 66,
              height: 38,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(19),
                gradient: LinearGradient(
                  colors: value
                      ? const [Color(0xFFFF9BC4), Color(0xFFFF4D96)]
                      : const [Color(0xFFEBD5DE), Color(0xFFD3B8C6)],
                ),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(
                      color: value
                          ? const Color(0xFFE0287F)
                          : const Color(0xFFBFA3B2),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pill button with a solid "3D" bottom edge that presses down on tap.
class _PauseButton3D extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;
  final double height;
  final Color textColor;

  const _PauseButton3D({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.height,
    this.primary = false,
    this.textColor = Colors.white,
  });

  @override
  State<_PauseButton3D> createState() => _PauseButton3DState();
}

class _PauseButton3DState extends State<_PauseButton3D> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final bool p = widget.primary;
    final double edge = _down ? 2 : 5;

    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: () {
        SoundService.instance.click();
        widget.onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        transform: Matrix4.translationValues(0, _down ? 3 : 0, 0),
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.height / 2),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: p
                ? const [Color(0xFFFF7DB8), Color(0xFFE0287F)]
                : const [Color(0xFFFFFFFF), Color(0xFFFFEEF5)],
          ),
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: p ? const Color(0xFFB81A68) : const Color(0xFFFFB6D3),
              offset: Offset(0, edge),
            ),
            if (p)
              BoxShadow(
                color: const Color(0xFFFF4D96).withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.icon,
              color: widget.textColor,
              size: p ? 30 : 22,
              shadows: p
                  ? const [Shadow(color: Colors.black26, blurRadius: 4)]
                  : null,
            ),
            const SizedBox(width: 8),
            Text(
              widget.label,
              style: TextStyle(
                fontFamily: 'Fredoka',
                color: widget.textColor,
                fontSize: p ? 21 : 15,
                fontWeight: FontWeight.w900,
                letterSpacing: p ? 1.6 : 1.0,
                shadows: p
                    ? const [Shadow(color: Colors.black26, blurRadius: 4)]
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// GLASS BOX
// ================================================================
