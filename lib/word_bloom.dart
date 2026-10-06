import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';

import 'game_engine.dart';
import 'bubble.dart';
import 'progress_service.dart';
import 'word_dictionary.dart';

class WordBloom extends StatefulWidget {
  final int startLevel;

  /// Called the moment a level is actually won (not just visited),
  /// with the level number that was completed and the number of
  /// stars earned (1-3).
  final void Function(int level, int stars)? onLevelComplete;

  const WordBloom({super.key, this.startLevel = 1, this.onLevelComplete});

  @override
  State<WordBloom> createState() => _WordBloomState();
}

class _WordBloomState extends State<WordBloom> with TickerProviderStateMixin {
  final GameEngine _engine = GameEngine();

  late final AnimationController _gameLoopController;
  late final ConfettiController _confettiController;

  // Board bubbles: bottom -> ceiling entrance, once per level start.
  late final AnimationController _entranceController;

  // Flying/shot bubble: gentle glow pulse.
  late final AnimationController _flyingGlowController;
  double _aimX = 0.50;
  double _aimY = 0.12;

  final double _launcherX = 0.50;
  final double _launcherY = 0.90;

  /// Single muzzle point used by BOTH the aim preview and the real
  /// shot, so the line and the bubble always start from the same place.
  Offset get _muzzle => Offset(_launcherX, _launcherY - 0.10);

  bool _initialized = false;
  bool _confettiPlayed = false;
  bool _winSaved = false;

  bool _showTutorial = false;
  bool _isAiming = false;
  bool _isPaused = false;

  int _shotTrigger = 0;
  int _swapTrigger = 0;

  @override
  void initState() {
    super.initState();

    loadWordList().then((words) {
      debugPrint('Dictionary loaded: ${words.length} words');
      _engine.setDictionary(words);
    });

    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );

    _gameLoopController = AnimationController(
      vsync: this,
      duration: const Duration(days: 1),
    )..addListener(_gameLoopControllerListener);

    _gameLoopController.repeat();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _flyingGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);
  }

  void _gameLoopControllerListener() {
    if (!mounted) return;
    if (_isPaused) return;

    _engine.update();

    // Save the win the moment the last word is found, so leaving during
    // the bonus animation never loses it.
    if (_engine.goalReached && !_winSaved) {
      _winSaved = true;
      final int? completed = _engine.currentLevel?.number;
      if (completed != null) {
        final int stars = _engine.starsEarned;

        debugPrint('WordBloom: saving level $completed with $stars stars');
        ProgressService.saveLevelResult(completed, stars);

        widget.onLevelComplete?.call(completed, stars);
      }
    }

    // Confetti + result card once the leftover shots have flown out.
    if (_engine.levelComplete && !_confettiPlayed) {
      _confettiPlayed = true;
      _confettiController.play();
    }

    setState(() {});
  }

  @override
  void dispose() {
    _gameLoopController.dispose();
    _confettiController.dispose();
    _entranceController.dispose();
    _flyingGlowController.dispose();
    super.dispose();
  }

  void _updateAim(Offset localPosition, Size size) {
    double x = localPosition.dx / size.width;
    double y = localPosition.dy / size.height;

    x = x.clamp(0.04, 0.96);
    y = y.clamp(0.05, 0.78);

    setState(() {
      _aimX = x;
      _aimY = y;
    });
  }

  void _shoot() {
    // CHANGED: no shooting while the board is sliding down.
    if (_engine.shooting ||
        _engine.gameOver ||
        _engine.levelComplete ||
        _engine.goalReached ||
        _engine.isScrolling) {
      return;
    }

    final String letter = _engine.getNextLetter();

    _engine.shoot(
      letter: letter,
      startX: _muzzle.dx,
      startY: _muzzle.dy,
      targetX: _aimX,
      targetY: _aimY,
    );

    setState(() => _shotTrigger++);
  }

  void _handleSwap() {
    if (_engine.swapNextTwo()) {
      setState(() => _swapTrigger++);
    }
  }

  Color _bubbleColor(String letter) {
    return _engine.letterColors[letter.toUpperCase()] ??
        const Color(0xFF7E8CFF);
  }

  void _restartAndRetry() {
    _confettiPlayed = false;
    _winSaved = false;
    _engine.retryLevel();
    setState(() {});
  }

  void _goNext() {
    _confettiPlayed = false;
    _winSaved = false;
    _engine.goToNextLevel();
    setState(() {});
  }

  void _openPauseMenu() {
    if (_engine.gameOver || _engine.levelComplete) return;

    setState(() => _isPaused = true);

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (dialogContext) => _PauseDialog(
        score: _engine.score,
        onResume: () {
          Navigator.of(dialogContext).pop();
          if (mounted) setState(() => _isPaused = false);
        },
        onRetry: () {
          Navigator.of(dialogContext).pop();
          if (mounted) {
            setState(() => _isPaused = false);
            _restartAndRetry();
          }
        },
        onExit: () {
          Navigator.of(dialogContext).pop();
          Navigator.of(context).maybePop();
        },
      ),
    ).then((_) {
      if (mounted && _isPaused) setState(() => _isPaused = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F3ED),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final Size size = Size(constraints.maxWidth, constraints.maxHeight);

            if (!_initialized) {
              _engine.configureForScreen(size);
              _engine.startLevel(widget.startLevel);
              _initialized = true;
              _aimY = _engine.boardTopY + 0.05;
              _showTutorial = widget.startLevel == 1;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _entranceController.forward(from: 0);
              });
            }

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (details) {
                if (_isPaused) return;
                _updateAim(details.localPosition, size);
                setState(() {
                  _isAiming = true;
                  _showTutorial = false;
                });
              },
              onPanUpdate: (details) {
                if (_isPaused) return;
                _updateAim(details.localPosition, size);
              },
              onPanEnd: (_) {
                if (_isPaused) return;
                if (_isAiming) _shoot();
                setState(() => _isAiming = false);
              },
              onPanCancel: () {
                if (_isPaused) return;
                setState(() => _isAiming = false);
              },
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFCDEFFF), Color(0xFFF7F3ED)],
                        ),
                      ),
                    ),
                  ),

                  // GAME BOARD (board bubbles + bubbles that are falling off)
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([
                        _entranceController,
                        _flyingGlowController,
                      ]),
                      builder: (context, _) {
                        return CustomPaint(
                          painter: _GameBoardPainter(
                            bubbles: [
                              ..._engine.bubbles,
                              ..._engine.fallingBubbles,
                            ],
                            flyingBubble: _engine.flyingBubble,
                            stoneIds: _engine.stoneIds,
                            lockHits: _engine.lockHits,
                            iceIds: _engine.iceIds,
                            hiddenIds: _engine.hiddenIds,
                            bombIds: _engine.bombIds,
                            wildIds: _engine.wildIds,
                            entranceProgress: _entranceController.value,
                            flyingPulse: _flyingGlowController.value,
                          ),
                        );
                      },
                    ),
                  ),

                  // BUBBLE POP EFFECT
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _FlyingPopPainter(pops: _engine.flyingPops),
                    ),
                  ),

                  // AIMING LINE - drawn from the engine's own simulation,
                  // so it is exactly the path (and landing slot) of the shot.
                  if (_isAiming &&
                      !_engine.gameOver &&
                      !_engine.levelComplete &&
                      !_engine.shooting)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _AimingLinePainter(
                          points: _engine
                              .previewShot(
                                letter: _engine.getNextLetterPreview(),
                                startX: _muzzle.dx,
                                startY: _muzzle.dy,
                                targetX: _aimX,
                                targetY: _aimY,
                              )
                              .path,
                          color: _bubbleColor(_engine.getNextLetterPreview()),
                        ),
                      ),
                    ),

                  // SOLID HEADER band (hides board bubbles behind the top bar)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: size.height * GameEngine.headerY,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            const Color(0xFFCDEFFF),
                            Color.lerp(
                              const Color(0xFFCDEFFF),
                              const Color(0xFFF7F3ED),
                              GameEngine.headerY,
                            )!,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // TOP UI (now above the board and the header band)
                  Positioned(
                    top: 12,
                    left: 14,
                    right: 14,
                    child: _TopBar(
                      level: _engine.currentLevel?.number ?? 1,
                      score: _engine.score,
                      onBack: () => Navigator.of(context).maybePop(),
                      onPause: _openPauseMenu,
                    ),
                  ),

                  // BUBBLE LAUNCHER RING
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: SizedBox(
                      height: 210,
                      child: _LauncherRing(
                        currentLetter: _engine.getNextLetterPreview(),
                        nextLetter: _engine.getLetterAfterNextPreview(),
                        currentColor: _bubbleColor(
                          _engine.getNextLetterPreview(),
                        ),
                        nextColor: _bubbleColor(
                          _engine.getLetterAfterNextPreview(),
                        ),
                        shotsRemaining: _remainingShots,
                        shotTrigger: _shotTrigger,
                        swapTrigger: _swapTrigger,
                        onSwapTap: _handleSwap,
                      ),
                    ),
                  ),

                  // LEFTOVER SHOTS flying out of the ring after a win
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _BonusShotPainter(
                          shots: _engine.bonusShots,
                          radiusFrac: _engine.bubbleRadius,
                        ),
                      ),
                    ),
                  ),

                  // STATUS CHIPS: words goal (+ letter rule), timer, board drop
                  Positioned(
                    top: 62,
                    left: 14,
                    right: 14,
                    child: IgnorePointer(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _InfoChip(
                            icon: Icons.flag_rounded,
                            text:
                                'Words ${_engine.completedWords.length}/${_engine.currentLevel?.words.length ?? 1} · ${_engine.lengthRuleText}',
                            color: const Color(0xFFFF4D96),
                          ),
                          if (_engine.timeLimit > 0)
                            _InfoChip(
                              icon: Icons.timer_rounded,
                              text: _formatTime(_engine.timeLeft),
                              color: _engine.timeLeft <= 10
                                  ? const Color(0xFFE0554C)
                                  : const Color(0xFF292929),
                            ),
                          if (_engine.shotsUntilDescend > 0)
                            _InfoChip(
                              icon: Icons.south_rounded,
                              text: 'Drop ${_engine.shotsUntilDescend}',
                              color: _engine.shotsUntilDescend <= 3
                                  ? const Color(0xFFE0554C)
                                  : const Color(0xFFF2A93B),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // SWAPS LEFT
                  if (_engine.swapsLeft >= 0)
                    Positioned(
                      right: 14,
                      bottom: 22,
                      child: IgnorePointer(
                        child: _InfoChip(
                          icon: Icons.swap_horiz_rounded,
                          text: '${_engine.swapsLeft}',
                          color: _engine.swapsLeft == 0
                              ? const Color(0xFFE0554C)
                              : const Color(0xFF7A4A3A),
                        ),
                      ),
                    ),

                  // TOAST: why a word didn't count
                  if (_engine.toastMessage != null)
                    Positioned(
                      top: 118,
                      left: 24,
                      right: 24,
                      child: IgnorePointer(
                        child: Center(
                          child: _ToastPill(text: _engine.toastMessage!),
                        ),
                      ),
                    ),

                  // FOUND WORD
                  if (_engine.foundWord != null)
                    Positioned(
                      top: 150,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: _FoundWord(
                          word: _engine.foundWord!,
                          done: _engine.completedWords.length,
                          total: _engine.currentLevel?.words.length ?? 1,
                        ),
                      ),
                    ),

                  // GAME OVER
                  if (_engine.gameOver)
                    Positioned.fill(
                      child: _GameOverOverlay(
                        onPressed: _restartAndRetry,
                        message: _engine.timeUp
                            ? "Time's up!"
                            : 'You ran out of shots',
                      ),
                    ),

                  // LEVEL COMPLETE
                  if (_engine.levelComplete)
                    Positioned.fill(
                      child: _LevelCompleteOverlay(
                        confettiController: _confettiController,
                        score: _engine.score,
                        stars: _engine.starsEarned,
                        completedWords: _engine.completedWords,
                        letterColors: _engine.letterColors,
                        onPressed: _goNext,
                      ),
                    ),
                  // FIRST-SHOT TUTORIAL
                  if (_showTutorial)
                    Positioned.fill(
                      child: IgnorePointer(
                        ignoring: true,
                        child: _TutorialOverlay(),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _formatTime(double seconds) {
    final int total = seconds.ceil();
    final int m = total ~/ 60;
    final int sec = total % 60;
    return '$m:${sec.toString().padLeft(2, '0')}';
  }

  int get _remainingShots {
    final int maxShots = _engine.currentLevel?.maxShots ?? 0;
    return max(0, maxShots - _engine.shotsUsed);
  }
}

// ================================================================
// FIRST-SHOT TUTORIAL
// ================================================================

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
    return _GlassBox(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF292929).withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: Color(0xFFFFD23F),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final int level;
  final int score;
  final VoidCallback onBack;
  final VoidCallback onPause;

  const _TopBar({
    required this.level,
    required this.score,
    required this.onBack,
    required this.onPause,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _GlassBox(
          padding: const EdgeInsets.all(9),
          child: GestureDetector(
            onTap: onBack,
            child: const Icon(
              Icons.arrow_back_rounded,
              size: 18,
              color: Color(0xFF292929),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: _GlassBox(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.auto_awesome,
                  size: 19,
                  color: Color(0xFFFF6FAE),
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'LEVEL $level',
                      maxLines: 1,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: _GlassBox(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.star_rounded,
                  size: 20,
                  color: Color(0xFFFFB84D),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$score',
                      maxLines: 1,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        _GlassBox(
          padding: const EdgeInsets.all(9),
          child: GestureDetector(
            onTap: onPause,
            child: const Icon(
              Icons.pause_rounded,
              size: 18,
              color: Color(0xFF292929),
            ),
          ),
        ),
      ],
    );
  }
}

// ================================================================
// PAUSE DIALOG
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

class _PauseDialogState extends State<_PauseDialog> {
  bool _musicOn = true;
  bool _soundOn = true;
  bool _vibrateOn = true;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFDCEA), Color(0xFFFFC2DC)],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Pause',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF7A4A3A),
                    shadows: [Shadow(color: Colors.white, blurRadius: 4)],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Score: ${widget.score}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF9C6E5C),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      _PauseToggleRow(
                        icon: Icons.music_note_rounded,
                        label: 'Music',
                        value: _musicOn,
                        onChanged: (v) => setState(() => _musicOn = v),
                      ),
                      const SizedBox(height: 14),
                      _PauseToggleRow(
                        icon: Icons.volume_up_rounded,
                        label: 'Sound',
                        value: _soundOn,
                        onChanged: (v) => setState(() => _soundOn = v),
                      ),
                      const SizedBox(height: 14),
                      _PauseToggleRow(
                        icon: Icons.vibration_rounded,
                        label: 'Vibrate',
                        value: _vibrateOn,
                        onChanged: (v) => setState(() => _vibrateOn = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: _PauseActionButton(
                    label: 'Play',
                    icon: Icons.play_arrow_rounded,
                    colors: const [Color(0xFF8EE6B0), Color(0xFF3FBF7F)],
                    onTap: widget.onResume,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _PauseActionButton(
                        label: 'Retry',
                        colors: const [Color(0xFFFF9BC4), Color(0xFFFF4D96)],
                        onTap: widget.onRetry,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PauseActionButton(
                        label: 'Exit',
                        colors: const [Color(0xFFEE8A7C), Color(0xFFE0554C)],
                        onTap: widget.onExit,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            top: -14,
            right: -8,
            child: GestureDetector(
              onTap: widget.onResume,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE0554C),
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
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
  final ValueChanged<bool> onChanged;

  const _PauseToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFE7D6), Color(0xFFFFC79B)],
            ),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: const Color(0xFF7A4A3A), size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF7A4A3A),
              letterSpacing: 0.3,
            ),
          ),
        ),
        GestureDetector(
          onTap: () => onChanged(!value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: 68,
            height: 34,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: value
                    ? const [Color(0xFFFF9BC4), Color(0xFFFF4D96)]
                    : const [Color(0xFFBFA093), Color(0xFF9C7C6E)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedAlign(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  alignment: value
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: value ? 6 : 0,
                      right: value ? 0 : 6,
                    ),
                    child: Text(
                      value ? 'On' : 'Off',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
                AnimatedAlign(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  alignment: value
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PauseActionButton extends StatelessWidget {
  final String label;
  final List<Color> colors;
  final VoidCallback onTap;
  final IconData? icon;

  const _PauseActionButton({
    required this.label,
    required this.colors,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.20),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
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
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ================================================================
// POP EFFECT
// ================================================================
class _BonusShotPainter extends CustomPainter {
  final List<BonusShotBubble> shots;
  final double radiusFrac;

  const _BonusShotPainter({required this.shots, required this.radiusFrac});

  @override
  void paint(Canvas canvas, Size size) {
    final double r = radiusFrac * size.width;

    for (final BonusShotBubble s in shots) {
      final double p = s.progress.clamp(0.0, 1.0);
      const double flightEnd = 0.7;

      if (p < flightEnd) {
        // flying out of the ring
        final double t = Curves.easeOut.transform(p / flightEnd);
        final Offset pos = Offset(
          (s.startX + (s.endX - s.startX) * t) * size.width,
          (s.startY + (s.endY - s.startY) * t) * size.height,
        );
        _drawBubble(canvas, pos, r * (1.0 - 0.30 * t), s);
      } else {
        // pop: ring + "+10" rising and fading
        final double t = (p - flightEnd) / (1 - flightEnd);
        final Offset pos = Offset(s.endX * size.width, s.endY * size.height);

        canvas.drawCircle(
          pos,
          r * (0.7 + t * 1.5),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.16
            ..color = s.color.withValues(alpha: (1 - t) * 0.75),
        );

        final TextPainter tp = TextPainter(
          text: TextSpan(
            text: '+${s.points}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 1 - t),
              fontSize: r * 0.8,
              fontWeight: FontWeight.w900,
              shadows: [
                Shadow(color: s.color.withValues(alpha: 1 - t), blurRadius: 8),
                Shadow(
                  color: Colors.black.withValues(alpha: 0.35 * (1 - t)),
                  blurRadius: 3,
                ),
              ],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        tp.paint(
          canvas,
          Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2 - t * r * 1.4),
        );
      }
    }
  }

  void _drawBubble(Canvas canvas, Offset c, double radius, BonusShotBubble s) {
    canvas.drawCircle(
      c,
      radius * 1.3,
      Paint()
        ..shader = RadialGradient(
          colors: [
            s.color.withValues(alpha: 0.30),
            s.color.withValues(alpha: 0.0),
          ],
          stops: const [0.7, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: radius * 1.3)),
    );

    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.45),
          radius: 0.9,
          colors: [
            Colors.white.withValues(alpha: 0.48),
            s.color,
            s.color.withValues(alpha: 0.78),
          ],
          stops: const [0.0, 0.30, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: radius)),
    );

    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: s.letter,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.92,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _BonusShotPainter oldDelegate) => true;
}

class _FlyingPopPainter extends CustomPainter {
  final List<FlyingPopBubble> pops;

  const _FlyingPopPainter({required this.pops});

  @override
  void paint(Canvas canvas, Size size) {
    for (final fp in pops) {
      final double t = Curves.easeOut.transform(fp.progress.clamp(0, 1));

      final Offset origin = Offset(
        fp.startX * size.width,
        fp.startY * size.height,
      );

      final double baseRadius = 0.052 * size.width;

      final double ringRadius = baseRadius * (0.4 + t * 2.2);
      final double ringOpacity = (1 - t) * 0.55;
      if (ringOpacity > 0) {
        final Paint ringPaint = Paint()
          ..color = fp.color.withValues(alpha: ringOpacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = baseRadius * 0.22;
        canvas.drawCircle(origin, ringRadius, ringPaint);
      }

      const int particleCount = 8;
      final int seed = fp.letter.codeUnitAt(0);

      for (int i = 0; i < particleCount; i++) {
        final double angle = (2 * pi * i / particleCount) + (seed % 7) * 0.35;

        final double travel = baseRadius * (1.6 + (i % 3) * 0.5) * t;

        final Offset particleCenter = Offset(
          origin.dx + cos(angle) * travel,
          origin.dy + sin(angle) * travel,
        );

        final double particleRadius =
            baseRadius * 0.22 * (1 - t).clamp(0.0, 1.0);
        final double particleOpacity = (1 - t).clamp(0.0, 1.0);

        if (particleRadius <= 0) continue;

        final Paint particlePaint = Paint()
          ..color = fp.color.withValues(alpha: particleOpacity);
        canvas.drawCircle(particleCenter, particleRadius, particlePaint);
      }

      final double flashOpacity = (1 - t * 1.6).clamp(0.0, 1.0);
      if (flashOpacity > 0) {
        final Paint flashPaint = Paint()
          ..color = Colors.white.withValues(alpha: flashOpacity * 0.8);
        canvas.drawCircle(origin, baseRadius * (1 - t * 0.6), flashPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FlyingPopPainter oldDelegate) => true;
}

// ================================================================
// GLOSSY BUBBLE
// ================================================================

class _GlossyBubble extends StatelessWidget {
  final String letter;
  final Color color;
  final double size;

  const _GlossyBubble({
    required this.letter,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _GlossyBubblePainter(color: color),
      child: SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Text(
            letter,
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.42,
              fontWeight: FontWeight.w900,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlossyBubblePainter extends CustomPainter {
  final Color color;
  const _GlossyBubblePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = min(size.width, size.height) / 2;
    final Offset center = Offset(size.width / 2, size.height / 2);

    final Paint shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawCircle(center.translate(0, 3), radius * 0.90, shadowPaint);

    final Paint bubblePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.45),
        radius: 0.9,
        colors: [
          Colors.white.withValues(alpha: 0.48),
          color,
          color.withValues(alpha: 0.82),
        ],
        stops: const [0.0, 0.28, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius * 0.90, bubblePaint);

    final Paint shine = Paint()..color = Colors.white.withValues(alpha: 0.60);
    canvas.drawOval(
      Rect.fromLTWH(
        size.width * 0.23,
        size.height * 0.15,
        size.width * 0.27,
        size.height * 0.16,
      ),
      shine,
    );
  }

  @override
  bool shouldRepaint(covariant _GlossyBubblePainter oldDelegate) =>
      oldDelegate.color != color;
}

// ================================================================
// GAME BOARD PAINTER
// ================================================================

class _GameBoardPainter extends CustomPainter {
  final List<Bubble> bubbles;
  final Bubble? flyingBubble;
  final Set<int> stoneIds;
  final Map<int, int> lockHits;
  final Set<int> iceIds;
  final Set<int> hiddenIds;
  final Set<int> bombIds;
  final Set<int> wildIds;
  final double entranceProgress;
  final double flyingPulse;

  const _GameBoardPainter({
    required this.bubbles,
    required this.flyingBubble,
    this.stoneIds = const {},
    this.lockHits = const {},
    this.iceIds = const {},
    this.hiddenIds = const {},
    this.bombIds = const {},
    this.wildIds = const {},
    this.entranceProgress = 1.0,
    this.flyingPulse = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // No hard clip here any more: a clip slices bubbles in half.
    // Bubbles near the top bar fade out instead (see the loop below),
    // and the solid header band in the UI hides whatever is left.

    final double t = Curves.easeOutBack.transform(
      entranceProgress.clamp(0.0, 1.0),
    );

    const double travelDistance = 0.9;
    final double offsetY = (1 - t) * travelDistance;

    void drawBubble(
      Canvas canvas,
      Size size,
      Bubble bubble, {
      double? overrideY,
      double pulse = 0.0,
      bool boostSize = false,
    }) {
      final double y = overrideY ?? bubble.y;
      final Offset center = Offset(bubble.x * size.width, y * size.height);

      final double radius = bubble.radius * size.width;
      if (radius <= 0) return;

      final double haloRadius = radius * 1.35;
      final double haloAlpha = boostSize ? 0.28 + pulse * 0.12 : 0.20;
      canvas.drawCircle(
        center,
        haloRadius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              bubble.color.withValues(alpha: haloAlpha),
              bubble.color.withValues(alpha: 0.0),
            ],
            stops: const [0.72, 1.0],
          ).createShader(Rect.fromCircle(center: center, radius: haloRadius)),
      );

      final Offset shadowCenter = center.translate(0, 3);
      canvas.drawCircle(
        shadowCenter,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.black.withValues(alpha: 0.16),
              Colors.black.withValues(alpha: 0.0),
            ],
            stops: const [0.70, 1.0],
          ).createShader(Rect.fromCircle(center: shadowCenter, radius: radius)),
      );

      // STONE: grey rock with cracks, no letter.
      if (stoneIds.contains(bubble.id)) {
        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..shader = const RadialGradient(
              center: Alignment(-0.35, -0.45),
              radius: 0.95,
              colors: [Color(0xFFC3C8D1), Color(0xFF7D8491), Color(0xFF4F5560)],
              stops: [0.0, 0.45, 1.0],
            ).createShader(Rect.fromCircle(center: center, radius: radius)),
        );

        final Paint crack = Paint()
          ..color = Colors.black.withValues(alpha: 0.38)
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.07
          ..strokeCap = StrokeCap.round;
        final Offset mid = center.translate(radius * 0.12, -radius * 0.05);
        canvas.drawLine(
          center.translate(-radius * 0.10, -radius * 0.55),
          mid,
          crack,
        );
        canvas.drawLine(
          mid,
          center.translate(-radius * 0.20, radius * 0.45),
          crack,
        );
        canvas.drawLine(
          mid,
          center.translate(radius * 0.50, radius * 0.20),
          crack,
        );

        canvas.drawOval(
          Rect.fromCenter(
            center: center.translate(-radius * 0.25, -radius * 0.38),
            width: radius * 0.42,
            height: radius * 0.24,
          ),
          Paint()..color = Colors.white.withValues(alpha: 0.35),
        );
        return;
      }

      final Color bodyColor = hiddenIds.contains(bubble.id)
          ? const Color(0xFF6D6A94)
          : bubble.color;

      final Paint paint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.45),
          radius: 0.9,
          colors: [
            Colors.white.withValues(alpha: 0.48),
            bodyColor,
            bodyColor.withValues(alpha: 0.78),
          ],
          stops: const [0.0, 0.30, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);

      canvas.drawOval(
        Rect.fromCenter(
          center: center.translate(-radius * 0.25, -radius * 0.38),
          width: radius * 0.48,
          height: radius * 0.28,
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.58),
      );

      // Letter (layout() is required before measuring/painting).
      final TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: _displayLetter(bubble),
          style: TextStyle(
            color: Colors.white,
            fontSize: radius * 0.92,
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.20),
                blurRadius: 3,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(
          center.dx - textPainter.width / 2,
          center.dy - textPainter.height / 2,
        ),
      );

      // ICE: frosted cover with a snowflake.
      if (iceIds.contains(bubble.id)) {
        canvas.drawCircle(
          center,
          radius,
          Paint()..color = const Color(0xFFBFE9FF).withValues(alpha: 0.62),
        );
        final Paint flake = Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.09
          ..strokeCap = StrokeCap.round;
        for (int k = 0; k < 3; k++) {
          final double a = k * pi / 3;
          canvas.drawLine(
            center.translate(cos(a) * radius * 0.72, sin(a) * radius * 0.72),
            center.translate(-cos(a) * radius * 0.72, -sin(a) * radius * 0.72),
            flake,
          );
        }
        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.85)
            ..style = PaintingStyle.stroke
            ..strokeWidth = radius * 0.08,
        );
      }

      // BOMB: dark ring and a lit fuse spark.
      if (bombIds.contains(bubble.id)) {
        canvas.drawCircle(
          center,
          radius * 0.96,
          Paint()
            ..color = const Color(0xFF2B2B3A)
            ..style = PaintingStyle.stroke
            ..strokeWidth = radius * 0.16,
        );
        final Offset spark = center.translate(radius * 0.72, -radius * 0.72);
        canvas.drawCircle(
          spark,
          radius * 0.24,
          Paint()..color = const Color(0xFFFF8A3D),
        );
        canvas.drawCircle(
          spark,
          radius * 0.11,
          Paint()..color = const Color(0xFFFFE28A),
        );
      }

      // LOCK: a steel chain around the bubble + a padlock badge.
      // Full chain = 2 hits needed. Half-broken chain and a cracked, open
      // padlock = 1 hit left. No numbers needed.
      final int? hitsLeft = lockHits[bubble.id];
      if (hitsLeft != null) {
        final bool damaged = hitsLeft < GameEngine.lockStrength;

        // slightly greyed so it reads as "not usable yet", letter stays visible
        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..color = const Color(
              0xFF3A3F55,
            ).withValues(alpha: damaged ? 0.20 : 0.30),
        );

        // chain links around the edge
        const int linkCount = 10;
        const Set<int> missing = {1, 2, 6, 7};
        final double chainR = radius * 0.86;

        for (int k = 0; k < linkCount; k++) {
          if (damaged && missing.contains(k)) continue;

          final double a = (2 * pi * k / linkCount) - pi / 2;
          final Offset p = center.translate(cos(a) * chainR, sin(a) * chainR);

          canvas.save();
          canvas.translate(p.dx, p.dy);
          canvas.rotate(a + pi / 2);

          if (k.isEven) {
            // link seen from the front (an open oval)
            final RRect link = RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset.zero,
                width: radius * 0.50,
                height: radius * 0.22,
              ),
              Radius.circular(radius * 0.11),
            );
            canvas.drawRRect(
              link.shift(Offset(0, radius * 0.04)),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = radius * 0.07
                ..color = Colors.black.withValues(alpha: 0.35),
            );
            canvas.drawRRect(
              link,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = radius * 0.07
                ..color = const Color(0xFFD5DBE6),
            );
          } else {
            // link seen from the side (a short bar)
            final RRect link = RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset.zero,
                width: radius * 0.30,
                height: radius * 0.12,
              ),
              Radius.circular(radius * 0.06),
            );
            canvas.drawRRect(
              link.shift(Offset(0, radius * 0.04)),
              Paint()..color = Colors.black.withValues(alpha: 0.35),
            );
            canvas.drawRRect(link, Paint()..color = const Color(0xFF9AA3B5));
          }

          canvas.restore();
        }

        // padlock badge at the bottom
        final Offset badge = center.translate(0, radius * 0.78);
        final double badgeR = radius * 0.30;

        canvas.drawCircle(
          badge.translate(0, radius * 0.04),
          badgeR,
          Paint()..color = Colors.black.withValues(alpha: 0.30),
        );
        canvas.drawCircle(
          badge,
          badgeR,
          Paint()
            ..shader = const RadialGradient(
              center: Alignment(-0.3, -0.4),
              colors: [Color(0xFF4A5390), Color(0xFF1B1F3B)],
            ).createShader(Rect.fromCircle(center: badge, radius: badgeR)),
        );
        canvas.drawCircle(
          badge,
          badgeR,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = radius * 0.05
            ..color = const Color(0xFFFFD23F),
        );

        // shackle (pops open a little when the lock is damaged)
        final double lift = damaged ? radius * 0.07 : 0;
        canvas.drawArc(
          Rect.fromCenter(
            center: badge.translate(
              damaged ? radius * 0.05 : 0,
              -radius * 0.07 - lift,
            ),
            width: radius * 0.22,
            height: radius * 0.26,
          ),
          pi,
          pi,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = radius * 0.05
            ..strokeCap = StrokeCap.round
            ..color = const Color(0xFFE6EAF2),
        );
        // lock body + keyhole
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: badge.translate(0, radius * 0.05),
              width: radius * 0.30,
              height: radius * 0.22,
            ),
            Radius.circular(radius * 0.05),
          ),
          Paint()..color = const Color(0xFFFFD23F),
        );
        canvas.drawCircle(
          badge.translate(0, radius * 0.04),
          radius * 0.035,
          Paint()..color = const Color(0xFF1B1F3B),
        );

        // crack across the badge when damaged
        if (damaged) {
          final Path crack = Path()
            ..moveTo(badge.dx - badgeR * 0.5, badge.dy - badgeR * 0.7)
            ..lineTo(badge.dx - badgeR * 0.05, badge.dy - badgeR * 0.1)
            ..lineTo(badge.dx + badgeR * 0.25, badge.dy + badgeR * 0.15)
            ..lineTo(badge.dx + badgeR * 0.55, badge.dy + badgeR * 0.7);
          canvas.drawPath(
            crack,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = radius * 0.04
              ..strokeCap = StrokeCap.round
              ..color = Colors.white.withValues(alpha: 0.9),
          );
        }
      }
    }

    final double headerLine = size.height * GameEngine.headerY;

    for (final bubble in bubbles) {
      final double animatedY = bubble.y + offsetY;

      final double r = bubble.radius * size.width;
      final double topEdge = animatedY * size.height - r;

      // 1 = fully below the header, 0 = fully hidden. A bubble sliding
      // under the header fades out instead of being cut in half.
      final double fade = r <= 0
          ? 1.0
          : (1 + (topEdge - headerLine) / r).clamp(0.0, 1.0);

      if (fade <= 0) continue;

      if (fade < 1) {
        canvas.saveLayer(
          Offset.zero & size,
          Paint()..color = Colors.white.withValues(alpha: fade),
        );
        drawBubble(canvas, size, bubble, overrideY: animatedY);
        canvas.restore();
      } else {
        drawBubble(canvas, size, bubble, overrideY: animatedY);
      }
    }

    if (flyingBubble != null) {
      drawBubble(
        canvas,
        size,
        flyingBubble!,
        pulse: flyingPulse,
        boostSize: true,
      );
    }
  }

  String _displayLetter(Bubble b) {
    if (hiddenIds.contains(b.id)) return '?';
    if (wildIds.contains(b.id)) return '★';
    return b.letter;
  }

  // The engine mutates the same list and the glow controller ticks
  // every frame, so always repainting is the safe choice here.
  @override
  bool shouldRepaint(covariant _GameBoardPainter old) => true;
}

// ================================================================
// AIMING LINE
// ================================================================

class _AimingLinePainter extends CustomPainter {
  /// Normalized 0-1 polyline from the engine: wall bounces included,
  /// last point is the exact slot where the bubble will land.
  final List<Offset> points;
  final Color color;

  const _AimingLinePainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final Paint dotPaint = Paint()..color = color;
    final Paint dotOutline = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    const double dotRadius = 4.2;
    const double gap = 14;

    double carryOver = 0;

    for (int i = 0; i < points.length - 1; i++) {
      final Offset segStart = Offset(
        points[i].dx * size.width,
        points[i].dy * size.height,
      );
      final Offset segEnd = Offset(
        points[i + 1].dx * size.width,
        points[i + 1].dy * size.height,
      );

      final Offset segVector = segEnd - segStart;
      final double segLength = segVector.distance;
      if (segLength < 0.5) continue;

      final Offset segDir = segVector / segLength;

      double travelled = carryOver > 0 ? gap - carryOver : 0;
      if (carryOver == 0) travelled = 0;

      while (travelled < segLength) {
        final Offset p = segStart + segDir * travelled;
        canvas.drawCircle(p, dotRadius, dotPaint);
        canvas.drawCircle(p, dotRadius, dotOutline);
        travelled += gap;
      }

      carryOver = travelled - segLength;
    }

    // Ring at the landing slot.
    final Offset last = Offset(
      points.last.dx * size.width,
      points.last.dy * size.height,
    );
    final Paint ring = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    canvas.drawCircle(last, 9, ring);
  }

  @override
  bool shouldRepaint(covariant _AimingLinePainter oldDelegate) {
    if (oldDelegate.color != color) return true;
    if (oldDelegate.points.length != points.length) return true;
    for (int i = 0; i < points.length; i++) {
      if (oldDelegate.points[i] != points[i]) return true;
    }
    return false;
  }
}

// ================================================================
// ANIMATED LAUNCHER RING
// ================================================================

enum _RingSpin { shot, swap }

class _LauncherRing extends StatefulWidget {
  final String currentLetter;
  final String nextLetter;
  final Color currentColor;
  final Color nextColor;
  final int shotsRemaining;
  final int shotTrigger;
  final int swapTrigger;
  final VoidCallback onSwapTap;

  const _LauncherRing({
    required this.currentLetter,
    required this.nextLetter,
    required this.currentColor,
    required this.nextColor,
    required this.shotsRemaining,
    required this.shotTrigger,
    required this.swapTrigger,
    required this.onSwapTap,
  });

  @override
  State<_LauncherRing> createState() => _LauncherRingState();
}

class _LauncherRingState extends State<_LauncherRing>
    with TickerProviderStateMixin {
  late final AnimationController _ringController;
  late final AnimationController _transitionController;
  late final Animation<double> _transition;

  _RingSpin _spinKind = _RingSpin.shot;

  static const double _topAngle = -pi / 2;
  static const double _nextAngle = pi / 6;

  @override
  void initState() {
    super.initState();

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      value: 1.0,
    );
    _transition = CurvedAnimation(
      parent: _transitionController,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void didUpdateWidget(covariant _LauncherRing oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.shotTrigger != oldWidget.shotTrigger) {
      _spinKind = _RingSpin.shot;
      _transitionController.forward(from: 0);
    } else if (widget.swapTrigger != oldWidget.swapTrigger) {
      _spinKind = _RingSpin.swap;
      _transitionController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ringController.dispose();
    _transitionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final Size size = Size(constraints.maxWidth, constraints.maxHeight);

        final Offset center = Offset(size.width / 2, size.height * 0.42);
        final double ringRadius = min(size.width, size.height) * 0.37;

        Offset onRing(double angle) {
          return Offset(
            center.dx + cos(angle) * ringRadius,
            center.dy + sin(angle) * ringRadius,
          );
        }

        return AnimatedBuilder(
          animation: Listenable.merge([_ringController, _transitionController]),
          builder: (context, child) {
            final double t = _transition.value;
            final double rotation = _ringController.value * pi * 2;

            final double currentAngle =
                _nextAngle + (_topAngle - _nextAngle) * t;
            final Offset currentPos = onRing(currentAngle);

            Offset nextPos;

            if (_spinKind == _RingSpin.swap) {
              final double angle = _topAngle + (_nextAngle - _topAngle) * t;
              nextPos = onRing(angle);
            } else {
              nextPos = onRing(_nextAngle);
            }

            final double nextOpacity = _spinKind == _RingSpin.shot
                ? Curves.easeOut.transform(t)
                : 1.0;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _LauncherRingPainter(
                      rotation: rotation,
                      pulse: sin(rotation) * 0.5 + 0.5,
                      color: widget.currentColor,
                    ),
                  ),
                ),
                Positioned(
                  left: center.dx - 35,
                  top: center.dy - 18,
                  width: 70,
                  height: 36,
                  child: Center(
                    child: Text(
                      '${widget.shotsRemaining}',
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF7A4A3A),
                        shadows: [Shadow(color: Colors.white, blurRadius: 5)],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: currentPos.dx - 36,
                  top: currentPos.dy - 36,
                  child: IgnorePointer(
                    child: _AnimatedShooterBubble(
                      letter: widget.currentLetter,
                      color: widget.currentColor,
                      size: 72,
                    ),
                  ),
                ),
                Positioned(
                  left: nextPos.dx - 21,
                  top: nextPos.dy - 21,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onSwapTap,
                    child: Opacity(
                      opacity: nextOpacity.clamp(0.0, 1.0),
                      child: _GlossyBubble(
                        letter: widget.nextLetter,
                        color: widget.nextColor,
                        size: 42,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ================================================================
// ANIMATED SHOOTER BUBBLE
// ================================================================

class _AnimatedShooterBubble extends StatefulWidget {
  final String letter;
  final Color color;
  final double size;

  const _AnimatedShooterBubble({
    required this.letter,
    required this.color,
    required this.size,
  });

  @override
  State<_AnimatedShooterBubble> createState() => _AnimatedShooterBubbleState();
}

class _AnimatedShooterBubbleState extends State<_AnimatedShooterBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
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
        final double t = Curves.easeInOut.transform(_controller.value);
        final double scale = 1.0 + (0.035 * t);

        return Transform.scale(
          scale: scale,
          child: CustomPaint(
            size: Size.square(widget.size),
            painter: _ShooterBubblePainter(color: widget.color, glow: t),
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: Center(
                child: Text(
                  widget.letter,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: widget.size * 0.42,
                    fontWeight: FontWeight.w900,
                    shadows: const [
                      Shadow(
                        color: Colors.black45,
                        blurRadius: 3,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ShooterBubblePainter extends CustomPainter {
  final Color color;
  final double glow;

  const _ShooterBubblePainter({required this.color, required this.glow});

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = min(size.width, size.height) / 2;
    final Offset center = Offset(size.width / 2, size.height / 2);

    final Paint glowPaint = Paint()
      ..color = color.withValues(alpha: 0.16 + glow * 0.10)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 + glow * 4);
    canvas.drawCircle(center, radius * 0.94, glowPaint);

    final Paint shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.20)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawCircle(center.translate(0, 4), radius * 0.88, shadow);

    final Paint bubblePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.45),
        radius: 0.95,
        colors: [
          Colors.white.withValues(alpha: 0.70),
          color,
          color.withValues(alpha: 0.72),
        ],
        stops: const [0.0, 0.30, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius * 0.90, bubblePaint);

    final Paint shine = Paint()..color = Colors.white.withValues(alpha: 0.72);
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(-radius * 0.24, -radius * 0.38),
        width: radius * 0.52,
        height: radius * 0.28,
      ),
      shine,
    );

    final Paint smallShine = Paint()
      ..color = Colors.white.withValues(alpha: 0.38);
    canvas.drawCircle(
      center.translate(radius * 0.34, -radius * 0.28),
      radius * 0.09,
      smallShine,
    );
  }

  @override
  bool shouldRepaint(covariant _ShooterBubblePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.glow != glow;
  }
}

// ================================================================
// RING PAINTER
// ================================================================

class _LauncherRingPainter extends CustomPainter {
  final double rotation;
  final double pulse;
  final Color color;

  const _LauncherRingPainter({
    required this.rotation,
    required this.pulse,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height * 0.42);
    final double ringRadius = min(size.width, size.height) * 0.37;

    final Paint shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, size.height * 0.91),
        width: ringRadius * 1.65,
        height: ringRadius * 0.25,
      ),
      shadowPaint,
    );

    final Paint outerGlow = Paint()
      ..color = color.withValues(alpha: 0.12 + pulse * 0.08)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 18 + pulse * 5);
    canvas.drawCircle(center, ringRadius * 0.98, outerGlow);

    final Paint innerGlow = Paint()
      ..color = Colors.white.withValues(alpha: 0.12 + pulse * 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    canvas.drawCircle(center, ringRadius, innerGlow);

    final Paint ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..shader = SweepGradient(
        transform: GradientRotation(rotation),
        colors: [
          Colors.white.withValues(alpha: 0.25),
          color.withValues(alpha: 0.95),
          Colors.white.withValues(alpha: 0.95),
          color.withValues(alpha: 0.35),
          Colors.white.withValues(alpha: 0.25),
        ],
        stops: const [0.00, 0.20, 0.32, 0.62, 1.00],
      ).createShader(Rect.fromCircle(center: center, radius: ringRadius));
    canvas.drawCircle(center, ringRadius, ringPaint);

    final Paint movingArc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 8
      ..color = Colors.white.withValues(alpha: 0.72 + pulse * 0.20)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    final Rect arcRect = Rect.fromCircle(
      center: center,
      radius: ringRadius + 1,
    );
    canvas.drawArc(arcRect, rotation - 0.55, 0.75, false, movingArc);

    final Paint highlight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.72);
    canvas.drawCircle(center, ringRadius - 5, highlight);
  }

  @override
  bool shouldRepaint(covariant _LauncherRingPainter oldDelegate) {
    return oldDelegate.rotation != rotation ||
        oldDelegate.pulse != pulse ||
        oldDelegate.color != color;
  }
}

// ================================================================
// FOUND WORD
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

class _GameOverOverlay extends StatelessWidget {
  final VoidCallback onPressed;
  final String message;
  const _GameOverOverlay({
    required this.onPressed,
    this.message = 'You ran out of shots',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.34),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 28),
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFDF9),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🌸', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 8),
              const Text(
                'TRY AGAIN',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF292929),
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black.withValues(alpha: 0.58),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: onPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF292929),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    'RETRY',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
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

// ================================================================
// LEVEL COMPLETE OVERLAY
// ================================================================

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
  late final AnimationController _cardController;
  late final AnimationController _floatController;
  late final AnimationController _buttonController;

  @override
  void initState() {
    super.initState();

    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _buttonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _cardController.dispose();
    _floatController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size screen = MediaQuery.sizeOf(context);

    return Container(
      color: Colors.black.withValues(alpha: 0.48),
      child: Stack(
        children: [
          // ==========================================================
          // CONFETTI
          // ==========================================================

          Positioned.fill(
            child: IgnorePointer(
              child: ConfettiWidget(
                confettiController: widget.confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                numberOfParticles: 34,
                gravity: 0.22,
                emissionFrequency: 0.04,
                colors: const [
                  Color(0xFFFF6FAE),
                  Color(0xFFFFC857),
                  Color(0xFF63D6B0),
                  Color(0xFF5DABFF),
                  Color(0xFFC08BFF),
                ],
              ),
            ),
          ),

          // ==========================================================
          // MAIN CARD
          // ==========================================================
          Center(
            child: AnimatedBuilder(
              animation: _cardController,
              builder: (context, child) {
                final double t = Curves.easeOutBack.transform(
                  _cardController.value,
                );

                return Opacity(
                  opacity: _cardController.value.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 0.88 + (0.12 * t),
                    child: child,
                  ),
                );
              },
              child: Container(
                constraints: BoxConstraints(maxWidth: 430),

                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8FC),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.9),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF5D3B4A).withValues(alpha: 0.20),
                      blurRadius: 42,
                      spreadRadius: 2,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Stack(
                    children: [
                      // ==================================================
                      // SOFT BACKGROUND GLOW
                      // ==================================================

                      Positioned(
                        top: -70,
                        right: -55,
                        child: Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(
                              0xFFFFA9CD,
                            ).withValues(alpha: 0.16),
                          ),
                        ),
                      ),

                      Positioned(
                        bottom: -70,
                        left: -60,
                        child: Container(
                          width: 190,
                          height: 190,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(
                              0xFFFFD76A,
                            ).withValues(alpha: 0.10),
                          ),
                        ),
                      ),

                      // ==================================================
                      // DECORATIVE PETALS
                      // ==================================================
                      AnimatedBuilder(
                        animation: _floatController,
                        builder: (context, child) {
                          final double t = Curves.easeInOut.transform(
                            _floatController.value,
                          );

                          return Stack(
                            children: [
                              Positioned(
                                top: 24 + (t * 7),
                                left: 25,
                                child: Transform.rotate(
                                  angle: -0.25 + (t * 0.15),
                                  child: const _FloatingPetal(
                                    size: 13,
                                    color: Color(0xFFFFB4D1),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 75 - (t * 8),
                                right: 25,
                                child: Transform.rotate(
                                  angle: 0.35 - (t * 0.18),
                                  child: const _FloatingPetal(
                                    size: 10,
                                    color: Color(0xFFFFD36A),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 135 + (t * 6),
                                left: 17,
                                child: Transform.rotate(
                                  angle: 0.45,
                                  child: const _FloatingPetal(
                                    size: 8,
                                    color: Color(0xFFFFC4DC),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      // ==================================================
                      // CONTENT
                      // ==================================================
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // ============================================
                            // BLOOM DECORATION
                            // ============================================

                            const _CompletionBloom(),

                            const SizedBox(height: 8),

                            // ============================================
                            // TITLE
                            // ============================================
                            const Text(
                              'LEVEL COMPLETE',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF3B2932),
                                letterSpacing: 0.7,
                                height: 1.0,
                              ),
                            ),

                            const SizedBox(height: 10),

                            // ============================================
                            // SUBTITLE
                            // ============================================

                            // ============================================
                            // STARS
                            // ============================================
                            _StarRow(stars: widget.stars),

                            const SizedBox(height: 10),

                            // ============================================
                            // WORDS
                            // ============================================
                            _WordsFoundCard(
                              words: widget.completedWords,
                              letterColors: widget.letterColors,
                            ),

                            const SizedBox(height: 9),

                            // ============================================
                            // SCORE
                            // ============================================
                            _ScoreReward(score: widget.score),

                            const SizedBox(height: 10),

                            // ============================================
                            // NEXT LEVEL
                            // ============================================
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: _NextLevelButton(
                                onPressed: widget.onPressed,
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
          ),
        ],
      ),
    );
  }
}

// ================================================================
// FLOATING PETAL
// ================================================================

class _FloatingPetal extends StatelessWidget {
  final double size;
  final Color color;

  const _FloatingPetal({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size * 0.65,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.75),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(size),
          topRight: Radius.circular(size),
          bottomLeft: Radius.circular(size * 0.2),
          bottomRight: Radius.circular(size),
        ),
      ),
    );
  }
}

// ================================================================
// COMPLETION BLOOM
// ================================================================

class _CompletionBloom extends StatefulWidget {
  const _CompletionBloom();

  @override
  State<_CompletionBloom> createState() => _CompletionBloomState();
}

class _CompletionBloomState extends State<_CompletionBloom>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
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
        final double t = Curves.easeInOut.transform(_controller.value);

        return Transform.translate(
          offset: Offset(0, -2 * t),
          child: Transform.scale(
            scale: 0.96 + (t * 0.04),
            child: SizedBox(
              width: 92,
              height: 70,
              child: CustomPaint(painter: _BloomPainter(glow: t)),
            ),
          ),
        );
      },
    );
  }
}

// ================================================================
// BLOOM PAINTER
// ================================================================

class _BloomPainter extends CustomPainter {
  final double glow;

  const _BloomPainter({required this.glow});

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2 + 5);

    final Paint glowPaint = Paint()
      ..color = const Color(0xFFFF6FAE).withValues(alpha: 0.10 + glow * 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    canvas.drawCircle(center, 27, glowPaint);

    final Paint petalPaint = Paint()..color = const Color(0xFFFFA9C9);

    final Paint petalLightPaint = Paint()..color = const Color(0xFFFFC4DB);

    final Paint centerPaint = Paint()..color = const Color(0xFFFFC857);

    for (int i = 0; i < 8; i++) {
      final double angle = (i * pi / 4) - (pi / 2);

      final double x = center.dx + cos(angle) * 23;

      final double y = center.dy + sin(angle) * 23;

      final Paint paint = i.isEven ? petalPaint : petalLightPaint;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);

      final Path petal = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(11, -7, 14, 0)
        ..quadraticBezierTo(11, 8, 0, 0);

      canvas.drawPath(petal, paint);
      canvas.restore();
    }

    canvas.drawCircle(center, 11, centerPaint);

    final Paint dotPaint = Paint()..color = const Color(0xFFFFF4CC);

    for (int i = 0; i < 6; i++) {
      final double angle = i * pi / 3;

      canvas.drawCircle(
        Offset(center.dx + cos(angle) * 6, center.dy + sin(angle) * 6),
        1.7,
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BloomPainter oldDelegate) {
    return oldDelegate.glow != glow;
  }
}

// ================================================================
// WORDS FOUND CARD
// ================================================================

// ================================================================
// WORDS FOUND
// ================================================================

class _WordsFoundCard extends StatelessWidget {
  final List<String> words;
  final Map<String, Color> letterColors;

  const _WordsFoundCard({required this.words, required this.letterColors});

  @override
  Widget build(BuildContext context) {
    if (words.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFD5E6), width: 1),
      ),
      child: Column(
        children: [
          // --------------------------------------------------------
          // HEADER
          // --------------------------------------------------------

          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                size: 18,
                color: Color(0xFFFF4D96),
              ),

              const SizedBox(width: 7),

              const Text(
                'WORDS FOUND',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF6E4C5B),
                  letterSpacing: 1.35,
                ),
              ),

              const Spacer(),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEEF5),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  '${words.length}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFFF4D96),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 9),

          // --------------------------------------------------------
          // WORD CHIPS
          // --------------------------------------------------------
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: List.generate(words.length, (index) {
              final String word = words[index].toUpperCase();

              return _AnimatedWordChip(
                word: word,
                index: index,
                color: _wordColor(word),
              );
            }),
          ),
        ],
      ),
    );
  }

  Color _wordColor(String word) {
    if (word.isEmpty) {
      return const Color(0xFFFF6FAE);
    }

    return letterColors[word[0].toUpperCase()] ?? const Color(0xFFFF6FAE);
  }
}

// ================================================================
// ANIMATED WORD CHIP
// ================================================================

class _AnimatedWordChip extends StatefulWidget {
  final String word;
  final int index;
  final Color color;

  const _AnimatedWordChip({
    required this.word,
    required this.index,
    required this.color,
  });

  @override
  State<_AnimatedWordChip> createState() => _AnimatedWordChipState();
}

class _AnimatedWordChipState extends State<_AnimatedWordChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    Future.delayed(Duration(milliseconds: 100 + widget.index * 70), () {
      if (mounted) {
        _controller.forward();
      }
    });
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
        final double t = Curves.easeOutBack.transform(_controller.value);

        return Opacity(
          opacity: _controller.value.clamp(0.0, 1.0),
          child: Transform.scale(scale: 0.82 + (0.18 * t), child: child),
        );
      },
      child: Container(
        constraints: const BoxConstraints(minWidth: 72),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: widget.color.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(alpha: 0.13),
              ),
              child: Icon(Icons.check_rounded, size: 11, color: widget.color),
            ),

            const SizedBox(width: 5),

            Text(
              widget.word,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: Color(0xFF45333B),
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// SCORE REWARD
// ================================================================

class _ScoreReward extends StatelessWidget {
  final int score;

  const _ScoreReward({required this.score});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.stars_rounded, size: 22, color: Color(0xFFFFB92E)),

        const SizedBox(width: 7),

        const Text(
          'SCORE',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: Color(0xFF947481),
            letterSpacing: 1.4,
          ),
        ),

        const SizedBox(width: 9),

        TweenAnimationBuilder<int>(
          tween: IntTween(begin: 0, end: score),
          duration: const Duration(milliseconds: 850),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Text(
              '+$value',
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
                color: Color(0xFFFF4D96),
              ),
            );
          },
        ),
      ],
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
      duration: const Duration(milliseconds: 1500),
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
        final double t = Curves.easeInOut.transform(_controller.value);

        return GestureDetector(
          onTap: widget.onPressed,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFF8FBE), Color(0xFFFF4D96)],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF4D96).withValues(alpha: 0.25),
                  blurRadius: 15 + (t * 5),
                  spreadRadius: 1,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Stack(
              children: [
                // ==============================================
                // SHINE
                // ==============================================

                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: FractionallySizedBox(
                      widthFactor: 0.30,
                      alignment: Alignment(-1.8 + (t * 5.6), 0),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.0),
                              Colors.white.withValues(alpha: 0.20),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // ==============================================
                // CONTENT
                // ==============================================
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'NEXT LEVEL',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.15,
                        ),
                      ),

                      const SizedBox(width: 10),

                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 19,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ================================================================
// STARS
// ================================================================

class _StarRow extends StatelessWidget {
  final int stars;

  const _StarRow({required this.stars});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final bool filled = i < stars;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: filled ? 1.0 : 0.78),
            duration: Duration(milliseconds: 500 + i * 180),
            curve: Curves.elasticOut,
            builder: (context, scale, child) {
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: filled
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFFFF7DF), Color(0xFFFFE7A5)],
                          )
                        : null,
                    color: filled ? null : const Color(0xFFF3F0ED),
                    boxShadow: filled
                        ? [
                            BoxShadow(
                              color: const Color(
                                0xFFFFC857,
                              ).withValues(alpha: 0.22),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    filled ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 35,
                    color: filled
                        ? const Color(0xFFFFB92E)
                        : const Color(0xFFC9C1BC),
                  ),
                ),
              );
            },
          ),
        );
      }),
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
