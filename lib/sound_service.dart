import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// All the short sound effects of the game.
enum Sfx { click, pop, shoot, land, word, coin, confetti, gift, giftUnlock, collect, fail, reward, bonusPop, bonusCoin, success }

/// One place for ALL game audio (button clicks, pops, confetti, music).
///
/// Files live in  assets/sounds/  (see pubspec.yaml).
/// Background music is a calm NATURE ambience (wind, water, soft birds):
/// no instruments and no singing.
class SoundService with WidgetsBindingObserver {
  SoundService._();
  static final SoundService instance = SoundService._();

  static const String _kSound = 'sound_on';
  static const String _kMusic = 'music_on';

  bool _soundOn = true;
  bool _musicOn = true;
  bool _started = false;
  bool _ready = false; // saved switches loaded
  bool _inForeground = true;

  /// Problems are printed in the Debug Console (look for "SoundService").
  static void _log(Object e) => debugPrint('SoundService: $e');

  bool get soundOn => _soundOn;
  bool get musicOn => _musicOn;

  static const Map<Sfx, String> _files = <Sfx, String>{
    Sfx.click: 'audio/click.wav',
    Sfx.pop: 'audio/pop.wav',
    Sfx.shoot: 'audio/shoot.wav',
    Sfx.land: 'audio/land.wav',
    Sfx.word: 'audio/word.wav',
    Sfx.coin: 'audio/coin.wav',
    Sfx.confetti: 'audio/confetti.wav',
    Sfx.gift: 'audio/gift.wav',
    Sfx.giftUnlock: 'audio/gift_unlock.wav',
    Sfx.collect: 'audio/collect.wav',
    Sfx.fail: 'audio/fail.wav',
    Sfx.reward: 'audio/reward.wav',
    Sfx.bonusPop: 'audio/bonus_pop.wav',
    Sfx.bonusCoin: 'audio/bonus_coin.wav',
    Sfx.success: 'audio/success.wav',
  };

  static const Map<Sfx, double> _volume = <Sfx, double>{
    Sfx.click: 1.0,
    Sfx.pop: 1.0,
    Sfx.shoot: 1.0,
    Sfx.land: 0.85,
    Sfx.word: 1.0,
    Sfx.coin: 0.9,
    Sfx.confetti: 1.0,
    Sfx.gift: 1.0,
    Sfx.giftUnlock: 1.0,
    Sfx.collect: 1.0,
    Sfx.fail: 1.0,
    Sfx.reward: 1.0,
    Sfx.bonusPop: 0.9,
    Sfx.bonusCoin: 0.9,
    Sfx.success: 1.0,
  };

  /// Every effect has a few players that are loaded ONCE (ready to go), so
  /// a tap only has to press "play" - no loading delay, and it can repeat.
  static const int _poolSize = 3;
  final Map<Sfx, List<AudioPlayer>> _pools = <Sfx, List<AudioPlayer>>{};
  final Map<Sfx, int> _next = <Sfx, int>{};
  final Map<Sfx, DateTime> _last = <Sfx, DateTime>{};
  bool _sfxReady = false;

  /// Sounds that keep repeating while something is happening (e.g. leftover
  /// bubbles leaving the ring). Same instant, pre-loaded players as every
  /// other effect - they are just re-triggered until [stopLoop].
  static const Map<Sfx, int> _loopEveryMs = <Sfx, int>{
    Sfx.bonusPop: 300, // length of bonus_pop.wav
    Sfx.bonusCoin: 2000, // length of bonus_coin.wav
  };
  final Map<Sfx, Timer> _loopTimers = <Sfx, Timer>{};

  /// Plays [sfx] now and keeps repeating it until [stopLoop] is called.
  void startLoop(Sfx sfx) {
    debugPrint('SoundService: startLoop $sfx');
    _loopTimers.remove(sfx)?.cancel();
    if (!_soundOn) return;
    _playNow(sfx);
    final int every = _loopEveryMs[sfx] ?? 500;
    _loopTimers[sfx] = Timer.periodic(Duration(milliseconds: every), (_) {
      _playNow(sfx);
    });
  }

  /// Stops repeating [sfx] and cuts any sound of it that is still playing.
  void stopLoop(Sfx sfx) {
    debugPrint('SoundService: stopLoop $sfx');
    _loopTimers.remove(sfx)?.cancel();
    final List<AudioPlayer>? pool = _pools[sfx];
    if (pool == null) return;
    for (final AudioPlayer p in pool) {
      unawaited(p.stop().catchError(_log));
    }
  }

  /// Plays [sfx] right away (no 40 ms de-dupe) on the next free player.
  void _playNow(Sfx sfx) {
    final List<AudioPlayer>? pool = _pools[sfx];
    if (pool == null || pool.isEmpty) {
      _log('no loaded sound for $sfx (is its .wav in assets/audio/?)');
      return;
    }
    final int i = (_next[sfx] ?? 0) % pool.length;
    _next[sfx] = i + 1;
    final AudioPlayer pl = pool[i];
    unawaited(() async {
      try {
        await pl.stop();
        await pl.resume();
      } catch (e) {
        _log(e);
      }
    }());
  }

  Future<void>? _loading;

  Future<void> _loadSfx() {
    return _loading ??= () async {
      for (final MapEntry<Sfx, String> e in _files.entries) {
        final List<AudioPlayer> list = <AudioPlayer>[];
        for (int i = 0; i < _poolSize; i++) {
          try {
            final AudioPlayer pl = AudioPlayer();
            await pl.setReleaseMode(ReleaseMode.stop);
            await pl.setVolume(_volume[e.key] ?? 1.0);
            await pl.setSource(AssetSource(e.value));
            list.add(pl);
          } catch (err) {
            _log('could not load ${e.value}: $err');
          }
        }
        if (list.isNotEmpty) _pools[e.key] = list;
        // the click is needed first: allow it as soon as it is ready
        if (e.key == Sfx.click) _sfxReady = true;
      }
      _sfxReady = true;
      debugPrint('SoundService: ${_pools.length} sound effects loaded');
    }();
  }

  static const String _menuTrack = 'audio/bg_menu.mp3';
  static const String _gameTrack = 'audio/bg_game.mp3';

  AudioPlayer? _music;
  bool _musicPlaying = false;
  String _track = _menuTrack; // which loop should play
  String? _loadedTrack; // which loop the player currently holds

  /// Calm lake + birds (level select).
  void playMenuMusic() => _setTrack(_menuTrack);

  /// Livelier garden + brook + more birds (while playing a level).
  void playGameMusic() => _setTrack(_gameTrack);

  void _setTrack(String t) {
    if (_track == t) return;
    _track = t;
    if (_musicPlaying) {
      // switch the loop that is playing right now
      _musicPlaying = false;
      _loadedTrack = null;
      unawaited(
        (_music?.stop().catchError(_log) ?? Future<void>.value())
            .then((_) => _applyMusic()),
      );
    }
  }

  /// Call once (safe to call many times), e.g. from the level screen.
  Future<void> ensureStarted() async {
    if (_started) {
      _applyMusic();
      return;
    }
    _started = true;
    WidgetsBinding.instance.addObserver(this);

    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      _soundOn = p.getBool(_kSound) ?? true;
      _musicOn = p.getBool(_kMusic) ?? true;
    } catch (e) {
      _log(e);
    }
    _ready = true;
    unawaited(_loadSfx());
    debugPrint('SoundService: started (sound=$_soundOn, music=$_musicOn)');

    // Do not stop other apps' audio (e.g. the player's own recitation).
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build(),
      );
    } catch (e) {
      _log(e);
    }

    _applyMusic();
  }

  // ------------------------------------------------------------------
  // Sound effects
  // ------------------------------------------------------------------
  void play(Sfx sfx) {
    if (!_soundOn) return;

    // Not loaded yet (only possible right at app start): load, then play it
    // the moment it is ready - the tap is never lost.
    if (!_sfxReady) {
      if (!_started) unawaited(ensureStarted());
      unawaited(_loadSfx().then((_) => play(sfx)));
      return;
    }

    // ignore the same sound firing again within 40 ms (frame bursts)
    final DateTime now = DateTime.now();
    final DateTime? last = _last[sfx];
    if (last != null && now.difference(last).inMilliseconds < 40) return;
    _last[sfx] = now;

    final List<AudioPlayer>? pool = _pools[sfx];
    if (pool == null || pool.isEmpty) return;
    try {
      final int i = (_next[sfx] ?? 0) % pool.length;
      _next[sfx] = i + 1;
      final AudioPlayer pl = pool[i];
      // rewind (source stays loaded) and play at once
      unawaited(() async {
        try {
          await pl.stop();
          await pl.resume();
        } catch (e) {
          _log(e);
        }
      }());
    } catch (e) {
      _log(e);
    }
  }

  void click() => play(Sfx.click);

  // ------------------------------------------------------------------
  // Settings
  // ------------------------------------------------------------------
  Future<void> setSoundOn(bool v) async {
    _soundOn = v;
    if (v) play(Sfx.click);
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      await p.setBool(_kSound, v);
    } catch (e) {
      _log(e);
    }
  }

  Future<void> setMusicOn(bool v) async {
    _musicOn = v;
    _applyMusic();
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      await p.setBool(_kMusic, v);
    } catch (e) {
      _log(e);
    }
  }

  // ------------------------------------------------------------------
  // Background music (nature ambience, loops)
  // ------------------------------------------------------------------
  void _applyMusic() {
    if (!_ready) return;
    final bool shouldPlay = _musicOn && _inForeground;
    try {
      if (shouldPlay && !_musicPlaying) {
        final AudioPlayer m = _music ??= AudioPlayer();
        _musicPlaying = true;
        unawaited(() async {
          try {
            await m.setReleaseMode(ReleaseMode.loop);
            if (_loadedTrack == _track) {
              await m.resume();
            } else {
              _loadedTrack = _track;
              await m.play(AssetSource(_track), volume: 0.35);
              debugPrint('SoundService: music playing -> $_track');
            }
          } catch (e) {
            _log(e);
            _musicPlaying = false;
          }
        }());
      } else if (!shouldPlay && _musicPlaying) {
        _musicPlaying = false;
        unawaited(_music?.pause().catchError(_log) ?? Future<void>.value());
      }
    } catch (e) {
      _log(e);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _inForeground = state == AppLifecycleState.resumed;
    if (!_inForeground) {
      // pause (not stop) so it continues from the same place
      if (_musicPlaying) {
        _musicPlaying = false;
        unawaited(_music?.pause().catchError(_log) ?? Future<void>.value());
      }
    } else {
      _applyMusic();
    }
  }
}