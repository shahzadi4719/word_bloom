import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';

import 'game_engine.dart';
import 'bubble.dart';
import 'progress_service.dart';
import 'word_dictionary.dart';
import 'booster_service.dart';
import 'gift_service.dart';
import 'sound_service.dart';
import 'booster_bar.dart';

part 'word_bloom/tutorial.dart';
part 'word_bloom/hud.dart';
part 'word_bloom/pause.dart';
part 'word_bloom/painters.dart';
part 'word_bloom/launcher.dart';
part 'word_bloom/overlays.dart';

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

  /// How much of this level's score is already saved into the real coins.
  int _creditedScore = 0;
  int _coins = 0; // the player's REAL total (same number as the level screen)
  // Game-loop timing (frame-rate independent stepping).
  static const bool _kFixedTimestep = true; // false karo agar bubbles tez lagen
  static const int _kStepMicros = 16667; // 60 updates per second
  final Stopwatch _loopClock = Stopwatch()..start();
  Duration? _lastTick;
  int _accMicros = 0;

  // for sound effects (detect landing / popping / game over)
  bool _prevShooting = false;
  int _prevBubbleCount = 0;
  int _prevFalling = 0;
  int _prevBonusLeft = 0;
  bool _bonusSoundOn = false;
  bool _prevGameOver = false;

  bool _showTutorial = false;
  bool _isAiming = false;
  bool _isPaused = false;

  int _shotTrigger = 0;
  int _swapTrigger = 0;

  // ---- BOOSTERS ----
  final BoosterService _boosters = BoosterService.instance;
  BoosterId? _armed;
  BoosterGrant? _pendingGrant;

  /// Top star bar value: only ever goes forward during a level.
  double _shownProgress = 0;

  ShotSpecial get _armedSpecial {
    switch (_armed) {
      case BoosterId.bloomBomb:
        return ShotSpecial.bomb;
      case BoosterId.rainbowBloom:
        return ShotSpecial.rainbow;
      case BoosterId.bloomLightning:
        return ShotSpecial.lightning;
      case BoosterId.flowerBlast:
        return ShotSpecial.flower;
      default:
        return ShotSpecial.none;
    }
  }

  // ---- NEW: praise popup ("Nice!", "Great!" ...) ----
  int _lastWordCount = 0;
  String? _praise;
  int _praiseId = 0;
  Timer? _praiseTimer;

  static const List<String> _praises = [
    'Nice!',
    'Great!',
    'Sweet!',
    'Awesome!',
    'Lovely!',
    'Well done!',
  ];

  void _showPraise(int done, int total) {
    final String text = done >= total
        ? 'Amazing!'
        : _praises[(done - 1) % _praises.length];
    _praiseTimer?.cancel();
    _praise = text;
    _praiseId++;
    _praiseTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _praise = null);
    });
  }

  @override
  void initState() {
    super.initState();

    SoundService.instance.ensureStarted();
    SoundService.instance.playGameMusic(); // livelier loop while playing

    // top-bar coins = the saved total, not this level's score
    GiftService.getCoins().then((int v) {
      if (mounted) setState(() => _coins = v);
    });

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

    // BOOSTERS: load saved quantities + unlock state.
    _boosters.load().then((_) {
      _boosters.setUnlockedLevel(widget.startLevel);
    });
  }

  void _gameLoopControllerListener() {
    if (!mounted) return;
    if (_isPaused) {
      _lastTick = null;
      return;
    }

    // SPEED FIX: engine ko fixed 60 steps/second par chalao, chahe phone ka
    // FPS kam ho ya zyada. Is se bubbles slow nahi lagte.
    if (_kFixedTimestep) {
      final Duration now = _loopClock.elapsed;
      final Duration last = _lastTick ?? now;
      _lastTick = now;
      _accMicros += (now - last).inMicroseconds.clamp(0, 100000);
      int steps = 0;
      while (_accMicros >= _kStepMicros && steps < 4) {
        _engine.update();
        _accMicros -= _kStepMicros;
        steps++;
      }
      if (steps == 0) return;
      if (_accMicros > _kStepMicros) _accMicros = 0;
    } else {
      _engine.update();
    }

    // SOUNDS: landing, popping, game over.
    final bool shootingNow = _engine.shooting;
    if (_prevShooting && !shootingNow) SoundService.instance.play(Sfx.land);
    _prevShooting = shootingNow;
    final int bubblesNow = _engine.bubbles.length;
    final int fallingNow = _engine.fallingBubbles.length;
    if (bubblesNow < _prevBubbleCount || fallingNow > _prevFalling) {
      SoundService.instance.play(Sfx.pop);
    }
    _prevBubbleCount = bubblesNow;
    _prevFalling = fallingNow;
    // Leftover shots leaving the ring after a win:
    //  1) the POP sound runs while the bubbles come out of the ring,
    //  2) the COIN sound follows when their "+10" coins appear (a bubble
    //     takes about half a second to fly), and ends after the last one.
    final int bonusLeftNow = _engine.bonusShotsLeft;
    if (bonusLeftNow < _prevBonusLeft && !_bonusSoundOn) {
      _bonusSoundOn = true;
      debugPrint('Bonus shots started: $bonusLeftNow left');
      SoundService.instance.startLoop(Sfx.bonusPop);
      Future<void>.delayed(const Duration(milliseconds: 420), () {
        if (mounted) SoundService.instance.startLoop(Sfx.bonusCoin);
      });
    }
    if (_bonusSoundOn && bonusLeftNow == 0) {
      _bonusSoundOn = false;
      Future<void>.delayed(const Duration(milliseconds: 250), () {
        SoundService.instance.stopLoop(Sfx.bonusPop);
      });
      Future<void>.delayed(const Duration(milliseconds: 700), () {
        SoundService.instance.stopLoop(Sfx.bonusCoin);
      });
    }
    _prevBonusLeft = bonusLeftNow;
    if (_engine.gameOver && !_prevGameOver)
      SoundService.instance.play(Sfx.fail);
    _prevGameOver = _engine.gameOver;

    // NEW: praise when a word has just been completed.
    final int wordCount = _engine.completedWords.length;
    if (wordCount > _lastWordCount) {
      SoundService.instance.play(Sfx.word);
      _showPraise(wordCount, _engine.currentLevel?.words.length ?? 1);
    }
    _lastWordCount = wordCount;

    final double wordProgress =
        wordCount / max(1, _engine.currentLevel?.words.length ?? 1);
    if (wordProgress > _shownProgress) _shownProgress = wordProgress;

    // COINS: every point scored is saved into the player's real coins right
    // away (words + leftover-shot bonus), so closing the app never loses them.
    final int nowScore = _engine.score;
    if (nowScore > _creditedScore) {
      // leftover shots flying out after the win: one coin tick per +points
      if (_engine.goalReached) SoundService.instance.play(Sfx.coin);
      GiftService.addCoins(nowScore - _creditedScore);
      _coins += nowScore - _creditedScore;
      _creditedScore = nowScore;
    } else if (nowScore < _creditedScore) {
      _creditedScore = nowScore; // score was reset (retry / next level)
    }

    // Save the win the moment the last word is found, so leaving during
    // the bonus animation never loses it.
    if (_engine.goalReached && !_winSaved) {
      _winSaved = true;
      final int? completed = _engine.currentLevel?.number;
      if (completed != null) {
        final int stars = _engine.starsEarned;

        debugPrint('WordBloom: saving level $completed with $stars stars');
        ProgressService.saveLevelResult(completed, stars);

        // BOOSTERS: milestone rewards + unlocks for this level.
        _claimBoosterRewards(completed);

        widget.onLevelComplete?.call(completed, stars);
      }
    }

    // Confetti + result card once the leftover shots have flown out.
    if (_engine.levelComplete && !_confettiPlayed) {
      _confettiPlayed = true;
      SoundService.instance.play(Sfx.confetti);
      _confettiController.play();
      _showPendingGrant();
    }

    setState(() {});
  }

  @override
  void dispose() {
    SoundService.instance.playMenuMusic(); // back to the calm loop
    SoundService.instance.stopLoop(Sfx.bonusPop);
    SoundService.instance.stopLoop(Sfx.bonusCoin);
    _praiseTimer?.cancel();
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

    // Booster shot: no letter is taken from the queue.
    final ShotSpecial special = _armedSpecial;
    if (special != ShotSpecial.none) {
      _engine.shoot(
        letter: ' ',
        startX: _muzzle.dx,
        startY: _muzzle.dy,
        targetX: _aimX,
        targetY: _aimY,
        special: special,
      );
      if (_engine.shooting) {
        SoundService.instance.play(Sfx.shoot);
        _boosters.use(_armed!); // quantity -1, saved
        setState(() => _armed = null);
      }
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

    if (_engine.shooting) SoundService.instance.play(Sfx.shoot);
    setState(() => _shotTrigger++);
  }

  void _handleSwap() {
    if (_engine.swapNextTwo()) {
      SoundService.instance.click();
      setState(() => _swapTrigger++);
    }
  }

  // ---- BOOSTER HANDLERS ----

  Future<void> _claimBoosterRewards(int completed) async {
    final BoosterGrant grant = await _boosters.onLevelCompleted(completed);
    if (!grant.isEmpty) _pendingGrant = grant;
  }

  void _showPendingGrant() {
    final BoosterGrant? g = _pendingGrant;
    if (g == null) return;
    _pendingGrant = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showBoosterRewardDialog(context, g);
    });
  }

  void _onBoosterTap(BoosterDef def) {
    if (_isPaused) return;
    SoundService.instance.click();

    // Locked: show the "Reach Level X" popup.
    if (!_boosters.isUnlocked(def)) {
      showBoosterLockedPopup(context, def);
      return;
    }
    if (_boosters.quantity(def.id) <= 0) return;
    if (_engine.gameOver || _engine.levelComplete || _engine.goalReached) {
      return;
    }

    if (def.id == BoosterId.bloomSwap) {
      if (_engine.swapNextTwo(ignoreLimit: true)) {
        _boosters.use(def.id);
        setState(() => _swapTrigger++);
      }
      return;
    }

    // The other 4: tap to arm, tap again to cancel, then shoot normally.
    setState(() => _armed = (_armed == def.id) ? null : def.id);
  }

  Color _bubbleColor(String letter) {
    return _engine.letterColors[letter.toUpperCase()] ??
        const Color(0xFF7E8CFF);
  }

  void _restartAndRetry() {
    _confettiPlayed = false;
    _winSaved = false;
    _lastWordCount = 0;
    _praise = null;
    _armed = null;
    _pendingGrant = null;
    _shownProgress = 0;
    _engine.retryLevel();
    setState(() {});
  }

  void _goNext() {
    _confettiPlayed = false;
    _winSaved = false;
    _lastWordCount = 0;
    _praise = null;
    _armed = null;
    _pendingGrant = null;
    _shownProgress = 0;
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-screen background picture (also behind status bar / bottom)
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg_game.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
              gaplessPlayback: true,
              errorBuilder: (context, error, stack) => const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFCDEFFF), Color(0xFFF7F3ED)],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final Size size = Size(
                        constraints.maxWidth,
                        constraints.maxHeight,
                      );

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
                        // FIX: every child of this Stack has a stable key, so when
                        // conditional widgets (aim line, toast, praise ...) appear
                        // or disappear, the top bar / launcher keep their state
                        // and the star bar no longer restarts from zero.
                        child: Stack(
                          children: [
                            Positioned.fill(
                              key: const ValueKey('bg'),
                              child: const SizedBox.shrink(),
                            ),

                            // GAME BOARD (board bubbles + bubbles that are falling off)
                            Positioned.fill(
                              key: const ValueKey('board'),
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
                                      flyingSpecial: _engine.flyingSpecial,
                                      stoneIds: _engine.stoneIds,
                                      lockHits: _engine.lockHits,
                                      iceIds: _engine.iceIds,
                                      hiddenIds: _engine.hiddenIds,
                                      bombIds: _engine.bombIds,
                                      wildIds: _engine.wildIds,
                                      entranceProgress:
                                          _entranceController.value,
                                      flyingPulse: _flyingGlowController.value,
                                    ),
                                  );
                                },
                              ),
                            ),

                            // BUBBLE POP EFFECT
                            Positioned.fill(
                              key: const ValueKey('pops'),
                              child: CustomPaint(
                                painter: _FlyingPopPainter(
                                  pops: _engine.flyingPops,
                                ),
                              ),
                            ),

                            // BOOSTER EFFECTS (glow, petals, lightning beam)
                            Positioned.fill(
                              key: const ValueKey('booster_fx'),
                              child: IgnorePointer(
                                child: CustomPaint(
                                  painter: _BoosterEffectPainter(
                                    effects: _engine.boosterEffects,
                                  ),
                                ),
                              ),
                            ),

                            // AIMING LINE - drawn from the engine's own simulation,
                            // so it is exactly the path (and landing slot) of the shot.
                            if (_isAiming &&
                                !_engine.gameOver &&
                                !_engine.levelComplete &&
                                !_engine.shooting)
                              Positioned.fill(
                                key: const ValueKey('aim_line'),
                                child: CustomPaint(
                                  painter: _AimingLinePainter(
                                    points: _engine
                                        .previewShot(
                                          letter: _engine
                                              .getNextLetterPreview(),
                                          startX: _muzzle.dx,
                                          startY: _muzzle.dy,
                                          targetX: _aimX,
                                          targetY: _aimY,
                                          special: _armedSpecial,
                                        )
                                        .path,
                                    color: _armedSpecial == ShotSpecial.none
                                        ? _bubbleColor(
                                            _engine.getNextLetterPreview(),
                                          )
                                        : GameEngine.specialColor(
                                            _armedSpecial,
                                          ),
                                  ),
                                ),
                              ),

                            // (header band removed: the background picture shows
                            // behind the top bar now)

                            // TOP UI: pause | level + star progress | score
                            Positioned(
                              key: const ValueKey('top_bar'),
                              top: 12,
                              left: 14,
                              right: 14,
                              child: _TopBar(
                                level: _engine.currentLevel?.number ?? 1,
                                score: _coins,
                                progress: _shownProgress,
                                onPause: _openPauseMenu,
                              ),
                            ),

                            // BUBBLE LAUNCHER RING
                            Positioned(
                              key: const ValueKey('launcher'),
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: SizedBox(
                                height: 210,
                                child: _LauncherRing(
                                  currentLetter: _engine.getNextLetterPreview(),
                                  nextLetter: _engine
                                      .getLetterAfterNextPreview(),
                                  currentColor:
                                      _armedSpecial == ShotSpecial.none
                                      ? _bubbleColor(
                                          _engine.getNextLetterPreview(),
                                        )
                                      : GameEngine.specialColor(_armedSpecial),
                                  armed: _armedSpecial == ShotSpecial.none
                                      ? null
                                      : _armed,
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
                              key: const ValueKey('bonus_shots'),
                              child: IgnorePointer(
                                child: CustomPaint(
                                  painter: _BonusShotPainter(
                                    shots: _engine.bonusShots,
                                    radiusFrac: _engine.bubbleRadius,
                                  ),
                                ),
                              ),
                            ),

                            // WORD GOAL + OPTIONAL TIMER
                            Positioned(
                              key: const ValueKey('word_goal'),
                              top: 68,
                              left: 14,
                              right: 14,
                              child: IgnorePointer(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _WordGoalChip(
                                      completed: _engine.completedWords.length,
                                      total:
                                          _engine.currentLevel?.words.length ??
                                          1,
                                    ),
                                    if (_engine.timeLimit > 0) ...[
                                      const SizedBox(width: 8),
                                      _InfoChip(
                                        icon: Icons.timer_rounded,
                                        text: _formatTime(_engine.timeLeft),
                                        color: _engine.timeLeft <= 10
                                            ? const Color(0xFFE0554C)
                                            : const Color(0xFF7A4A3A),
                                      ),
                                    ],
                                    if (_armed != null) ...[
                                      const SizedBox(width: 8),
                                      _InfoChip(
                                        icon: Icons.auto_awesome,
                                        text:
                                            '${boosterDef(_armed!).name} ready',
                                        color: const Color(0xFFE0287F),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),

                            // TOAST: why a word didn't count
                            if (_engine.toastMessage != null)
                              Positioned(
                                key: const ValueKey('toast'),
                                top: 118,
                                left: 24,
                                right: 24,
                                child: IgnorePointer(
                                  child: Center(
                                    child: _ToastPill(
                                      text: _engine.toastMessage!,
                                    ),
                                  ),
                                ),
                              ),

                            // FOUND WORD
                            if (_engine.foundWord != null)
                              Positioned(
                                key: const ValueKey('found_word'),
                                top: 150,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: _FoundWord(
                                    word: _engine.foundWord!,
                                    done: _engine.completedWords.length,
                                    total:
                                        _engine.currentLevel?.words.length ?? 1,
                                  ),
                                ),
                              ),

                            // PRAISE ("Nice!", "Great!" ...)
                            if (_praise != null)
                              Positioned.fill(
                                key: const ValueKey('praise_slot'),
                                child: IgnorePointer(
                                  child: Align(
                                    alignment: const Alignment(0, -0.2),
                                    child: _PraisePopup(
                                      key: ValueKey(_praiseId),
                                      text: _praise!,
                                    ),
                                  ),
                                ),
                              ),

                            // GAME OVER
                            if (_engine.gameOver)
                              Positioned.fill(
                                key: const ValueKey('game_over'),
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
                                key: const ValueKey('level_complete'),
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
                                key: const ValueKey('tutorial'),
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

                // BOOSTER BAR - below the game area, never over the shooter.
                BoosterBar(
                  service: _boosters,
                  armed: _armed,
                  onTap: _onBoosterTap,
                ),
              ],
            ),
          ),
        ],
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
