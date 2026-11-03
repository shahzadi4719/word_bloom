import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'booster_service.dart';
import 'game_mode.dart';
import 'progress_service.dart';

enum GiftRewardKind { coins, booster }

/// The single thing that came out of a gift box.
class GiftReward {
  final GiftRewardKind kind;
  final int amount;
  final BoosterId? booster;

  const GiftReward.coins(this.amount)
    : kind = GiftRewardKind.coins,
      booster = null;

  const GiftReward.booster(BoosterId id, this.amount)
    : kind = GiftRewardKind.booster,
      booster = id;

  bool get isCoins => kind == GiftRewardKind.coins;

  String get label {
    if (isCoins) return 'Coins';
    switch (booster) {
      case BoosterId.bloomSwap:
        return 'Bloom Swap';
      case BoosterId.bloomBomb:
        return 'Bloom Bomb';
      case BoosterId.rainbowBloom:
        return 'Rainbow Bloom';
      case BoosterId.bloomLightning:
        return 'Bloom Lightning';
      case BoosterId.flowerBlast:
        return 'Flower Blast';
      default:
        return 'Booster';
    }
  }

  /// "100 Coins" / "Bloom Bomb ×1"
  String get description => isCoins ? '$amount Coins' : '$label ×$amount';
}

class _Drop {
  final BoosterId? booster; // null = coins
  final int amount;
  final int weight; // percent
  const _Drop(this.booster, this.amount, this.weight);
}

/// Gift box rules + coin wallet.
class GiftService {
  GiftService._();

  /// A gift unlocks after every 20 completed levels (20, 40, 60, 80 ...).
  static const int everyNLevels = 20;

  /// Kept only so older screens that still read it compile. No extra gifts.
  static const Set<int> extraGiftLevels = <int>{};

  /// Exactly ONE of these is given per gift. Weights add up to 100.
  static const List<_Drop> _drops = [
    _Drop(BoosterId.bloomSwap, 1, 30),
    _Drop(BoosterId.bloomBomb, 1, 25),
    _Drop(BoosterId.rainbowBloom, 1, 15),
    _Drop(BoosterId.bloomLightning, 1, 10),
    _Drop(BoosterId.flowerBlast, 1, 10),
    _Drop(null, 100, 7),
    _Drop(null, 200, 3),
  ];

  static const String _kOpened = 'opened_gifts';
  static String _coinsKey(GameMode mode) =>
      mode == GameMode.wordBloom ? 'player_coins' : '${mode.name}_player_coins';
  static String _openedKey(GameMode mode) =>
      mode == GameMode.wordBloom ? _kOpened : '${mode.name}_opened_gifts';

  static bool _busy = false;

  /// Bumps after every successful coin change so screens can refresh.
  static final ValueNotifier<int> coinTick = ValueNotifier<int>(0);

  static bool hasGiftAfter(int level) =>
      level >= everyNLevels && level % everyNLevels == 0;

  static Future<Set<int>> getOpenedGifts({
    GameMode mode = GameMode.wordBloom,
  }) async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    final List<String> raw =
        p.getStringList(_openedKey(mode)) ?? const <String>[];
    return raw.map(int.tryParse).whereType<int>().toSet();
  }

  // ---------------------------------------------------------------
  // COINS
  // ---------------------------------------------------------------

  // Legacy aliases retained for compatibility with older screens.
  static Future<int> getScore({GameMode mode = GameMode.wordBloom}) =>
      getCoins(mode: mode);
  /// Playing levels only gives SCORE, never coins. Older screens may still
  /// call this; it intentionally does nothing so no score becomes coins.
  static Future<void> addScore(
    int n, {
    GameMode mode = GameMode.wordBloom,
  }) async {}

  static Future<int> getCoins({GameMode mode = GameMode.wordBloom}) async {
    // Wait for queued writes so a read right after a purchase is exact.
    await _coinQueue;
    final SharedPreferences p = await SharedPreferences.getInstance();
    return p.getInt(_coinsKey(mode)) ?? 0;
  }

  // Every coin read-modify-write runs one after another, so two quick
  // operations (purchase + gift, double tap ...) can never overwrite each
  // other or spend the same coins twice.
  static Future<void> _coinQueue = Future<void>.value();

  static Future<T> _enqueue<T>(Future<T> Function() job) {
    final Completer<T> done = Completer<T>();
    _coinQueue = _coinQueue.then((_) async {
      try {
        done.complete(await job());
      } catch (error, stack) {
        done.completeError(error, stack);
      }
    });
    return done.future;
  }

  /// Adds coins. Returns true only if the new balance was saved.
  static Future<bool> addCoins(
    int n, {
    GameMode mode = GameMode.wordBloom,
  }) async {
    if (n <= 0) return true;
    try {
      final bool ok = await _enqueue<bool>(() async {
        final SharedPreferences p = await SharedPreferences.getInstance();
        final String key = _coinsKey(mode);
        return p.setInt(key, (p.getInt(key) ?? 0) + n);
      });
      if (ok) coinTick.value++;
      return ok;
    } catch (_) {
      return false;
    }
  }

  /// Spends coins. Returns false (and changes nothing) when the balance is
  /// too low. Throws only if the save itself fails (nothing was spent).
  static Future<bool> spendCoins(
    int amount, {
    GameMode mode = GameMode.wordBloom,
  }) async {
    if (amount <= 0) return false;
    final bool ok = await _enqueue<bool>(() async {
      final SharedPreferences p = await SharedPreferences.getInstance();
      final String key = _coinsKey(mode);
      final int balance = p.getInt(key) ?? 0;
      if (balance < amount) return false;
      if (!await p.setInt(key, balance - amount)) {
        throw StateError('Could not save coin balance');
      }
      return true;
    });
    if (ok) coinTick.value++;
    return ok;
  }

  /// Legacy API retained for older callers. Booster purchases now go
  /// through StoreService.buyBooster (with a confirmation popup).
  static Future<bool> buyBooster(
    BoosterId id, {
    GameMode mode = GameMode.wordBloom,
  }) async => false;

  // ---------------------------------------------------------------
  // GIFTS
  // ---------------------------------------------------------------

  /// Opens a gift. Pays out ONE random reward, saves it right away and marks
  /// the gift as opened. Returns an empty list if the gift is not unlocked
  /// yet, was already opened, or another gift is being opened right now.
  static Future<List<GiftReward>> open(
    int giftLevel, {
    GameMode mode = GameMode.wordBloom,
  }) async {
    if (!hasGiftAfter(giftLevel) || _busy) return const <GiftReward>[];
    _busy = true;
    try {
      // The level must really be completed (progress unlocks level+1).
      final int unlocked = await ProgressService.getUnlockedLevel(mode: mode);
      if (unlocked <= giftLevel) return const <GiftReward>[];

      final SharedPreferences p = await SharedPreferences.getInstance();
      final Set<int> opened = await getOpenedGifts(mode: mode);
      if (opened.contains(giftLevel)) return const <GiftReward>[];

      await BoosterService.instance.load();
      final List<GiftReward> rewards = roll(giftLevel);

      // Mark as opened FIRST, so a double tap or crash can never pay twice.
      final Set<int> withThis = {...opened, giftLevel};
      final bool marked = await p.setStringList(
        _openedKey(mode),
        withThis.map((int e) => e.toString()).toList(),
      );
      if (!marked) return const <GiftReward>[];

      try {
        for (final GiftReward r in rewards) {
          if (r.isCoins) {
            if (!await addCoins(r.amount, mode: mode)) {
              throw StateError('Could not save gift coins');
            }
          } else {
            await BoosterService.instance.addPurchased(
              r.booster!,
              amount: r.amount,
            );
          }
        }
      } catch (_) {
        // Nothing was paid: reopen the gift so the player can try again.
        await p.setStringList(
          _openedKey(mode),
          opened.map((int e) => e.toString()).toList(),
        );
        rethrow;
      }
      return rewards;
    } finally {
      _busy = false;
    }
  }

  /// Exactly one reward per gift, by the drop table above.
  static List<GiftReward> roll(int giftLevel, [Random? random]) {
    final Random rnd = random ?? Random();
    int pick = rnd.nextInt(_drops.fold<int>(0, (n, d) => n + d.weight));
    for (final _Drop d in _drops) {
      if (pick < d.weight) {
        return [
          d.booster == null
              ? GiftReward.coins(d.amount)
              : GiftReward.booster(d.booster!, d.amount),
        ];
      }
      pick -= d.weight;
    }
    return const [GiftReward.coins(100)]; // unreachable
  }
}
