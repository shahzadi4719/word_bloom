part of '../word_bloom.dart';

class _LevelCompleteOverlay extends StatefulWidget {
  final ConfettiController confettiController;
  final int score;
  final int stars;
  final List<String> completedWords;
  final Map<String, Color> letterColors;
  final VoidCallback onPressed;

  const _LevelCompleteOverlay({
    required this.confettiController,
    required this.score,
    required this.stars,
    required this.completedWords,
    required this.letterColors,
    required this.onPressed,
  });

  @override
  State<_LevelCompleteOverlay> createState() => _LevelCompleteOverlayState();
}

class _LevelCompleteOverlayState extends State<_LevelCompleteOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final AnimationController _loop;

  @override
  void initState() {
    super.initState();

    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..forward();

    _loop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.confettiController.play();
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    super.dispose();
  }

  /// 0..1 progress of the intro between [a] and [b] (fractions of the intro).
  double _seg(double a, double b) =>
      ((_intro.value - a) / (b - a)).clamp(0.0, 1.0);

  /// Tiny 5-petal flower used as the confetti particle.
  static Path _flowerPath(Size size) {
    final double r = min(size.width, size.height) / 2;
    final Offset c = Offset(size.width / 2, size.height / 2);
    final Path path = Path();
    for (int i = 0; i < 5; i++) {
      final double a = 2 * pi * i / 5 - pi / 2;
      final Offset p = c + Offset(cos(a), sin(a)) * (r * 0.55);
      path.addOval(Rect.fromCircle(center: p, radius: r * 0.45));
    }
    path.addOval(Rect.fromCircle(center: c, radius: r * 0.3));
    return path;
  }

  Color _wordColor(String word) {
    if (word.isEmpty) return const Color(0xFFFF72B6);
    return widget.letterColors[word[0].toUpperCase()] ??
        const Color(0xFFFF72B6);
  }

  @override
  Widget build(BuildContext context) {

    return Stack(
      children: [
        // Dark backdrop
        Container(color: Colors.black.withValues(alpha: 0.58)),

        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: AnimatedBuilder(
                  animation: Listenable.merge([_intro, _loop]),
                  builder: (context, _) {
                    final double cardT = Curves.easeOutBack.transform(
                      _seg(0.0, 0.14),
                    );
                    final double titleT = _seg(0.04, 0.30);
                    final double scoreT = Curves.easeOutCubic.transform(
                      _seg(0.30, 0.46),
                    );
                    final double btnT = Curves.easeOut.transform(
                      _seg(0.68, 0.86),
                    );
                    final double float = sin(_loop.value * pi) * 4;

                    return Opacity(
                      opacity: cardT.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: 0.8 + 0.2 * cardT,
                        child: Container(
                          width: double.infinity,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFFFFEAF3), Color(0xFFFFD9E8)],
                            ),
                            borderRadius: BorderRadius.circular(36),
                            border: Border.all(
                              color: const Color(0xFFFF9BC4),
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFFFF4D96,
                                ).withValues(alpha: 0.40),
                                blurRadius: 30,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // ---- PINK HEADER: YOU WIN! + STARS ----
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  24,
                                  16,
                                  20,
                                ),
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0xFFFF9BC4),
                                      Color(0xFFFF4D96),
                                    ],
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Transform.translate(
                                      offset: Offset(0, float),
                                      child: Transform.scale(
                                        scale: Curves.elasticOut
                                            .transform(titleT)
                                            .clamp(0.0, 1.4),
                                        child: const FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: _WinTitle(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    _WinStars(
                                      stars: widget.stars,
                                      progress: _seg(0.20, 0.52),
                                    ),
                                  ],
                                ),
                              ),

                              // ---- BODY: SCORE + WORDS + BUTTON ----
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  18,
                                  18,
                                  20,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Opacity(
                                      opacity: scoreT.clamp(0.0, 1.0),
                                      child: Transform.translate(
                                        offset: Offset(0, 12 * (1 - scoreT)),
                                        child: _WinScorePill(
                                          score: widget.score,
                                        ),
                                      ),
                                    ),

                                    if (widget.completedWords.isNotEmpty) ...[
                                      const SizedBox(height: 18),
                                      const BloomAnimatedLabel(
                                        'Words Found',
                                        size: 18,
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        alignment: WrapAlignment.center,
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: List.generate(
                                          widget.completedWords.length,
                                          (i) {
                                            final String w =
                                                widget.completedWords[i];
                                            return _WinWordChip(
                                              key: ValueKey('win_word_$i'),
                                              word: w,
                                              color: _wordColor(w),
                                              delay: 700 + i * 240,
                                            );
                                          },
                                        ),
                                      ),
                                    ],

                                    const SizedBox(height: 22),
                                    Opacity(
                                      opacity: btnT,
                                      child: Transform.translate(
                                        offset: Offset(0, 20 * (1 - btnT)),
                                        child: IgnorePointer(
                                          ignoring: btnT < 0.6,
                                          child: _NextLevelButton(
                                            onPressed: widget.onPressed,
                                          ),
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
                    );
                  },
                ),
              ),
            ),
          ),
        ),

        // Confetti - drawn AFTER the card so it falls in FRONT of it.
        Positioned.fill(
          child: IgnorePointer(
            child: ConfettiWidget(
              confettiController: widget.confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              numberOfParticles: 30,
              gravity: 0.14,
              emissionFrequency: 0.03,
              maxBlastForce: 24,
              minBlastForce: 8,
              minimumSize: const Size(9, 9),
              maximumSize: const Size(15, 15),
              createParticlePath: _flowerPath,
              colors: const [
                Color(0xFFFF72B6),
                Color(0xFFFF9BC4),
                Color(0xFFFFB3D4),
                Color(0xFFFFD4E5),
                Color(0xFFFFC857),
                Color(0xFFC9A7FF),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Score pill: star badge + counting-up number.
class _WinScorePill extends StatelessWidget {
  final int score;
  const _WinScorePill({required this.score});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: score.toDouble()),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        return Container(
          padding: const EdgeInsets.fromLTRB(8, 7, 20, 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFFFFD4E5), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF4D96).withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CoinIcon(size: 34),
              const SizedBox(width: 10),
              Text(
                '${v.round()}',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: Color(0xFFE0287F),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Big outlined "YOU WIN!" text.
class _WinTitle extends StatelessWidget {
  const _WinTitle();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          'YOU WIN!',
          style: TextStyle(
            fontSize: 58,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 14
              ..strokeJoin = StrokeJoin.round
              ..color = const Color(0xFFE0287F),
          ),
        ),
        Text(
          'YOU WIN!',
          style: TextStyle(
            fontSize: 58,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: Colors.white,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 3 stars that pop in one after another.
class _WinStars extends StatelessWidget {
  final int stars;

  /// 0..1 progress of the whole star animation.
  final double progress;

  const _WinStars({required this.stars, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(3, (i) {
        final bool filled = i < stars;
        final double start = i * 0.28;
        final double local = ((progress - start) / 0.44).clamp(0.0, 1.0);
        final double scale = Curves.elasticOut.transform(local);
        final double size = i == 1 ? 64 : 52;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Transform.scale(
            scale: scale,
            child: Icon(
              Icons.star_rounded,
              size: size,
              color: filled
                  ? const Color(0xFFFFC62E)
                  : Colors.white.withValues(alpha: 0.30),
              shadows: filled
                  ? const [
                      Shadow(color: Color(0xFFFFE08A), blurRadius: 16),
                      Shadow(color: Colors.black26, blurRadius: 4),
                    ]
                  : null,
            ),
          ),
        );
      }),
    );
  }
}

/// One found word: pops in with a bounce, check badge in its letter colour.
class _WinWordChip extends StatefulWidget {
  final String word;
  final Color color;
  final int delay;

  const _WinWordChip({
    super.key,
    required this.word,
    required this.color,
    required this.delay,
  });

  @override
  State<_WinWordChip> createState() => _WinWordChipState();
}

class _WinWordChipState extends State<_WinWordChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final double pop = Curves.easeOutBack.transform(_c.value);
        return Opacity(
          opacity: Curves.easeOut.transform(_c.value.clamp(0.0, 1.0)),
          child: Transform.translate(
            offset: Offset(0, 22 * (1 - pop)),
            child: Transform.scale(scale: 0.6 + 0.4 * pop, child: child),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: widget.color.withValues(alpha: 0.55),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.40),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color,
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            BloomAnimatedLabel(widget.word, size: 19),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// NEXT LEVEL BUTTON
// ================================================================

class _NextLevelButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _NextLevelButton({required this.onPressed});

  @override
  State<_NextLevelButton> createState() => _NextLevelButtonState();
}

class _NextLevelButtonState extends State<_NextLevelButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double pulse = Curves.easeInOut.transform(_controller.value);

        return Transform.scale(
          scale: 1.0 + (pulse * 0.018),
          child: Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xFFFF9BCB),
                  Color(0xFFFF67AD),
                  Color(0xFFE94F98),
                ],
              ),
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF67AD).withValues(alpha: 0.45),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  SoundService.instance.click();
                  widget.onPressed();
                },
                borderRadius: BorderRadius.circular(28),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'NEXT LEVEL',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.3,
                          ),
                        ),
                        SizedBox(width: 9),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ],
                    ),

                    // Moving shine
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Align(
                          alignment: Alignment(
                            -1.5 + (_controller.value * 3.0),
                            0,
                          ),
                          child: Container(
                            width: 42,
                            height: 80,
                            transform: Matrix4.rotationZ(0.25),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ================================================================
// ANIMATED SHOOTER BUBBLE
// ================================================================

class _GameOverOverlay extends StatelessWidget {
  final VoidCallback onPressed;
  final String message;
  const _GameOverOverlay({
    required this.onPressed,
    this.message = 'You ran out of shots',
  });

  @override
  Widget build(BuildContext context) {
    const Color plum = Color(0xFF6B3A55);

    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      child: SafeArea(
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutBack,
            builder: (context, t, child) => Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Transform.scale(scale: 0.8 + 0.2 * t, child: child),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Container(
                  width: double.infinity,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFFEAF3), Color(0xFFFFD9E8)],
                    ),
                    borderRadius: BorderRadius.circular(36),
                    border: Border.all(
                      color: const Color(0xFFFF9BC4),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF4D96).withValues(alpha: 0.40),
                        blurRadius: 30,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ---- PINK HEADER: badge + TRY AGAIN ----
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFFFF9BC4), Color(0xFFFF4D96)],
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.22),
                              ),
                              child: const Icon(
                                Icons.sentiment_dissatisfied_rounded,
                                color: Colors.white,
                                size: 46,
                                shadows: [
                                  Shadow(color: Colors.black26, blurRadius: 6),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Text(
                                    'TRY AGAIN',
                                    style: TextStyle(
                                      fontSize: 40,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.5,
                                      foreground: Paint()
                                        ..style = PaintingStyle.stroke
                                        ..strokeWidth = 10
                                        ..strokeJoin = StrokeJoin.round
                                        ..color = const Color(0xFFE0287F),
                                    ),
                                  ),
                                  Text(
                                    'TRY AGAIN',
                                    style: TextStyle(
                                      fontSize: 40,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.5,
                                      color: Colors.white,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.22,
                                          ),
                                          blurRadius: 6,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ---- BODY: message + RETRY ----
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              message,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                height: 1.35,
                                color: plum.withValues(alpha: 0.85),
                              ),
                            ),
                            const SizedBox(height: 22),
                            _PauseButton3D(
                              label: 'RETRY',
                              icon: Icons.refresh_rounded,
                              primary: true,
                              height: 56,
                              onTap: onPressed,
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
}

class _CollectedLettersReveal extends StatefulWidget {
  final List<String> letters;
  final Map<String, Color> colors;

  const _CollectedLettersReveal({required this.letters, required this.colors});

  @override
  State<_CollectedLettersReveal> createState() =>
      _CollectedLettersRevealState();
}

class _CollectedLettersRevealState extends State<_CollectedLettersReveal> {
  int _visibleCount = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 130), (timer) {
      if (!mounted) return;
      setState(() {
        _visibleCount++;
      });
      if (_visibleCount >= widget.letters.length) {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: List.generate(widget.letters.length, (i) {
        final String letter = widget.letters[i];
        final Color color =
            widget.colors[letter.toUpperCase()] ?? const Color(0xFF7E8CFF);
        final bool visible = i < _visibleCount;

        return AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 220),
          child: AnimatedScale(
            scale: visible ? 1 : 0.3,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              alignment: Alignment.center,
              child: Text(
                letter,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
