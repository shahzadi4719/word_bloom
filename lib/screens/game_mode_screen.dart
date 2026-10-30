import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game_mode.dart';
import '../bloom_visuals.dart';
import '../sound_service.dart';
import 'level_select_screen.dart';

class GameModeScreen extends StatelessWidget {
  const GameModeScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/bg_level_select.png',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFDAD5F3), Color(0xFFFFDDEB)],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(26, 76, 26, 26),
            child: LayoutBuilder(
              builder: (context, page) {
                final gap = (page.maxHeight * .028).clamp(10.0, 20.0);
                final headingHeight = math.min(104.0, page.maxHeight * .22);
                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      children: [
                        SizedBox(
                          height: headingHeight,
                          child: const _ModeHeading(),
                        ),
                        SizedBox(height: gap),
                        for (final mode in GameMode.values) ...[
                          if (mode.index > 0) SizedBox(height: gap),
                          Expanded(
                            child: SizedBox(
                              width: double.infinity,
                              child: _ModeButton(
                                mode: mode,
                                onTap: () {
                                  SoundService.instance.click();
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          LevelSelectScreen(mode: mode),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          left: 14,
          child: BloomBackButton(onTap: () => Navigator.of(context).maybePop()),
        ),
      ],
    ),
  );
}

class _ModeButton extends StatefulWidget {
  final GameMode mode;
  final VoidCallback onTap;
  const _ModeButton({required this.mode, required this.onTap});
  @override
  State<_ModeButton> createState() => _ModeButtonState();
}

class _ModeButtonState extends State<_ModeButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shine = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4800),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _shine.stop();
    } else if (!_shine.isAnimating) {
      _shine.repeat();
    }
  }

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.mode.title,
    child: BloomPressButton(
      onTap: widget.onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x25A72F71),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xEEFFFFFF), width: 1.8),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF58FC4), Color(0xFFE857A3), Color(0xFFD6388B)],
              stops: [0, .48, 1],
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(27),
            child: LayoutBuilder(
              builder: (context, size) {
                final previewWidth = (size.maxWidth * .32).clamp(82.0, 112.0);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned(
                      right: 18,
                      top: 14,
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white.withValues(alpha: .24),
                        size: 15,
                      ),
                    ),
                    Positioned(
                      right: 42,
                      bottom: 17,
                      child: Icon(
                        Icons.local_florist_rounded,
                        color: Colors.white.withValues(alpha: .10),
                        size: 30,
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      height: size.maxHeight * .48,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: .19),
                              Colors.white.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (!MediaQuery.of(context).disableAnimations)
                      AnimatedBuilder(
                        animation: _shine,
                        builder: (_, __) {
                          final phase =
                              ((_shine.value + widget.mode.index * .18) % 1);
                          return Positioned(
                            left:
                                -size.maxWidth * .3 +
                                phase * size.maxWidth * 1.6,
                            top: -12,
                            bottom: -12,
                            width: size.maxWidth * .18,
                            child: IgnorePointer(
                              child: Transform.rotate(
                                angle: -.35,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withValues(alpha: 0),
                                        Colors.white.withValues(alpha: .10),
                                        Colors.white.withValues(alpha: 0),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: Row(
                        children: [
                          Container(
                            width: previewWidth,
                            height: math.min(70.0, size.maxHeight - 20),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: .18),
                              ),
                            ),
                            child: BloomGoalAnimation(
                              mode: widget.mode,
                              height: 68,
                            ),
                          ),
                          const SizedBox(width: 28),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.center,
                                  child: _AnimatedModeName(
                                    title: widget.mode.title,
                                    animation: _shine,
                                    multiline: size.maxHeight >= 118,
                                  ),
                                ),
                                if (size.maxHeight >= 86)
                                  const SizedBox(height: 10),
                                if (size.maxHeight >= 86)
                                  Text(
                                    widget.mode.isWordMode
                                        ? 'Connect letters'
                                        : widget.mode == GameMode.colorMatch
                                        ? 'Match colors'
                                        : 'Match letters',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white.withValues(alpha: .9),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}

class _ModeHeading extends StatefulWidget {
  const _ModeHeading();
  @override
  State<_ModeHeading> createState() => _ModeHeadingState();
}

class _ModeHeadingState extends State<_ModeHeading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _motion.stop();
    } else if (!_motion.isAnimating) {
      _motion.repeat();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    label: 'Choose Game Mode',
    excludeSemantics: true,
    child: AnimatedBuilder(
      animation: _motion,
      builder: (_, __) {
        final reduced = MediaQuery.of(context).disableAnimations;
        final wave = reduced ? 0.0 : math.sin(_motion.value * math.pi * 2);
        Widget headingText(String text, double size) {
          final style = TextStyle(
            fontFamily: 'Fredoka',
            fontSize: size,
            height: 1.06,
            fontWeight: FontWeight.w700,
            letterSpacing: .3,
          );
          return Stack(
            alignment: Alignment.center,
            children: [
              Text(
                text,
                style: style.copyWith(
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 2.8
                    ..color = Colors.white.withValues(alpha: .9),
                ),
              ),
              ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (rect) => LinearGradient(
                  begin: Alignment(-1 + wave * .18, -1),
                  end: Alignment(1 + wave * .18, 1),
                  colors: const [
                    Color(0xFFD6388B),
                    Color(0xFFF079BB),
                    Color(0xFFAD55AC),
                  ],
                  stops: const [0, .52, 1],
                ).createShader(rect),
                child: Text(text, style: style.copyWith(color: Colors.white)),
              ),
            ],
          );
        }

        return Transform.translate(
          offset: Offset(0, wave * 1.5),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                headingText('Choose', 26),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.rotate(
                      angle: wave * .08,
                      child: const Icon(
                        Icons.local_florist_rounded,
                        color: Color(0xFFE879B4),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    headingText('Game Mode', 38),
                    const SizedBox(width: 12),
                    Transform.rotate(
                      angle: -wave * .08,
                      child: const Icon(
                        Icons.local_florist_rounded,
                        color: Color(0xFFE879B4),
                        size: 22,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _AnimatedModeName extends StatelessWidget {
  final String title;
  final Animation<double> animation;
  final bool multiline;
  const _AnimatedModeName({
    required this.title,
    required this.animation,
    required this.multiline,
  });
  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.of(context).disableAnimations;
    return Semantics(
      label: title,
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: animation,
        builder: (_, __) {
          final parts = multiline ? title.split(' ') : [title];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (var i = 0; i < parts.length; i++)
                  Transform.translate(
                    offset: Offset(
                      0,
                      reduced
                          ? 0
                          : math.sin(
                                  (animation.value + i * .18) * math.pi * 2,
                                ) *
                                2.5,
                    ),
                    child: Text(
                      parts[i],
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: multiline ? 36 : 28,
                        height: 1.08,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: .3,
                        shadows: [
                          const Shadow(
                            color: Color(0x553E0730),
                            blurRadius: 3,
                            offset: Offset(0, 2),
                          ),
                          Shadow(
                            color: Colors.white.withValues(
                              alpha: reduced
                                  ? .08
                                  : .08 +
                                        (math.sin(
                                                  animation.value * math.pi * 2,
                                                ) +
                                                1) *
                                            .07,
                            ),
                            blurRadius: 9,
                          ),
                        ],
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
}
