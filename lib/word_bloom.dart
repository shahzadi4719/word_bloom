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

    if (_engine.levelComplete && !_confettiPlayed) {
      _confettiPlayed = true;
      _confettiController.play();
      final int? completed = _engine.currentLevel?.number;
      if (completed != null) {
        final int stars = _engine.starsEarned;

        debugPrint('WordBloom: saving level $completed with $stars stars');
        ProgressService.saveLevelResult(completed, stars);

        widget.onLevelComplete?.call(completed, stars);
      }
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
    _engine.retryLevel();
    setState(() {});
  }

  void _goNext() {
    _confettiPlayed = false;
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

                  // TOP UI
                  Positioned(
                    top: 12,
                    left: 14,
                    right: 14,
                    child: _TopBar(
                      level: _engine.currentLevel?.number ?? 1,
                      score: _engine.score,
                      lives: _remainingShots,
                      onBack: () => Navigator.of(context).maybePop(),
                      onPause: _openPauseMenu,
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

                  // STATUS CHIPS: words goal, timer, board-drop countdown
                  Positioned(
                    top: 62,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _InfoChip(
                            icon: Icons.flag_rounded,
                            text:
                                'Words ${_engine.completedWords.length}/${_engine.currentLevel?.words.length ?? 1}',
                            color: const Color(0xFFFF4D96),
                          ),
                          if (_engine.timeLimit > 0) ...[
                            const SizedBox(width: 8),
                            _InfoChip(
                              icon: Icons.timer_rounded,
                              text: _formatTime(_engine.timeLeft),
                              color: _engine.timeLeft <= 10
                                  ? const Color(0xFFE0554C)
                                  : const Color(0xFF292929),
                            ),
                          ],
                          if (_engine.shotsUntilDescend > 0) ...[
                            const SizedBox(width: 8),
                            _InfoChip(
                              icon: Icons.south_rounded,
                              text: 'Drop ${_engine.shotsUntilDescend}',
                              color: _engine.shotsUntilDescend <= 3
                                  ? const Color(0xFFE0554C)
                                  : const Color(0xFFF2A93B),
                            ),
                          ],
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
                        collectedLetters: _engine.collectedLetters,
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

class _TopBar extends StatelessWidget {
  final int level;
  final int score;
  final int lives;
  final VoidCallback onBack;
  final VoidCallback onPause;

  const _TopBar({
    required this.level,
    required this.score,
    required this.lives,
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
        _GlassBox(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.favorite_rounded,
                size: 18,
                color: Color(0xFFFF5C87),
              ),
              const SizedBox(width: 5),
              Text(
                '$lives',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ],
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

  const _PauseActionButton({
    required this.label,
    required this.colors,
    required this.onTap,
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
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
          ),
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
    // CHANGED: rows still hidden above the screen must not draw over
    // the top bar, so everything above this line is clipped away.
    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(0, size.height * 0.115, size.width, size.height),
    );

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
        canvas.drawLine(center.translate(-radius * 0.10, -radius * 0.55), mid, crack);
        canvas.drawLine(mid, center.translate(-radius * 0.20, radius * 0.45), crack);
        canvas.drawLine(mid, center.translate(radius * 0.50, radius * 0.20), crack);

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

      // LOCK: dimmed letter, steel ring, small "padlock + shots left" pill.
      final int? hitsLeft = lockHits[bubble.id];
      if (hitsLeft != null) {
        canvas.drawCircle(
          center,
          radius,
          Paint()..color = const Color(0xFF3A3F55).withValues(alpha: 0.42),
        );

        // brushed steel ring
        canvas.drawCircle(
          center,
          radius * 0.93,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = radius * 0.13
            ..shader = const SweepGradient(
              colors: [
                Color(0xFFF1F4FA),
                Color(0xFF8A93A6),
                Color(0xFFFFFFFF),
                Color(0xFF7B8497),
                Color(0xFFF1F4FA),
              ],
            ).createShader(Rect.fromCircle(center: center, radius: radius)),
        );

        // pill at the bottom of the bubble
        final Offset pillCenter = center.translate(0, radius * 0.62);
        final RRect pill = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: pillCenter,
            width: radius * 1.0,
            height: radius * 0.46,
          ),
          Radius.circular(radius * 0.23),
        );
        canvas.drawRRect(
          pill.shift(Offset(0, radius * 0.04)),
          Paint()..color = Colors.black.withValues(alpha: 0.30),
        );
        canvas.drawRRect(
          pill,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF3B4378), Color(0xFF1B1F3B)],
            ).createShader(pill.outerRect),
        );
        canvas.drawRRect(
          pill,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = radius * 0.05
            ..color = const Color(0xFFFFD23F),
        );

        // tiny padlock
        final Offset lockC = pillCenter.translate(-radius * 0.22, radius * 0.02);
        canvas.drawArc(
          Rect.fromCenter(
            center: lockC.translate(0, -radius * 0.07),
            width: radius * 0.17,
            height: radius * 0.20,
          ),
          pi,
          pi,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = radius * 0.04
            ..strokeCap = StrokeCap.round
            ..color = const Color(0xFFE6EAF2),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: lockC.translate(0, radius * 0.03),
              width: radius * 0.25,
              height: radius * 0.17,
            ),
            Radius.circular(radius * 0.04),
          ),
          Paint()..color = const Color(0xFFFFD23F),
        );

        // shots still needed to open it
        final TextPainter hitPainter = TextPainter(
          text: TextSpan(
            text: '$hitsLeft',
            style: TextStyle(
              color: Colors.white,
              fontSize: radius * 0.34,
              fontWeight: FontWeight.w900,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        hitPainter.paint(
          canvas,
          Offset(
            pillCenter.dx + radius * 0.17 - hitPainter.width / 2,
            pillCenter.dy - hitPainter.height / 2,
          ),
        );
      }
    }

    for (final bubble in bubbles) {
      final double animatedY = bubble.y + offsetY;
      drawBubble(canvas, size, bubble, overrideY: animatedY);
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

    // CHANGED: closes the clip opened at the top of paint().
    canvas.restore();
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

class _LevelCompleteOverlay extends StatelessWidget {
  final ConfettiController confettiController;
  final int score;
  final int stars;
  final List<String> collectedLetters;
  final Map<String, Color> letterColors;
  final VoidCallback onPressed;

  const _LevelCompleteOverlay({
    required this.confettiController,
    required this.score,
    required this.stars,
    required this.collectedLetters,
    required this.letterColors,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.40),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              numberOfParticles: 26,
              gravity: 0.25,
              colors: const [
                Color(0xFFFF6FAE),
                Color(0xFFFFD15C),
                Color(0xFF63D6B0),
                Color(0xFF5DABFF),
                Color(0xFFC08BFF),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 28),
            padding: const EdgeInsets.all(28),
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
                const Text('🌸', style: TextStyle(fontSize: 44)),
                const SizedBox(height: 4),
                const Text(
                  'LEVEL COMPLETE!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF292929),
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 14),
                _StarRow(stars: stars),
                const SizedBox(height: 14),
                _CollectedLettersReveal(
                  letters: collectedLetters,
                  colors: letterColors,
                ),
                const SizedBox(height: 10),
                TweenAnimationBuilder<int>(
                  tween: IntTween(begin: 0, end: score),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Text(
                      '$value pts',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFF4D96),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 22),
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
                      'NEXT LEVEL',
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
        ],
      ),
    );
  }
}

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
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: filled ? 1 : 0.6),
            duration: Duration(milliseconds: 400 + i * 150),
            curve: Curves.elasticOut,
            builder: (context, scale, child) {
              return Transform.scale(
                scale: scale,
                child: Icon(
                  filled ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 40,
                  color: filled ? const Color(0xFFFFC857) : Colors.black26,
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