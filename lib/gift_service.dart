import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'booster_service.dart';
import 'game_mode.dart';

enum GiftRewardKind { coins, booster }

/// One thing that came out of a gift box.
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
}

class _PoolEntry {
  final BoosterId? booster; // null = coins
  final int weight;
  const _PoolEntry(this.booster, this.weight);
}

/// Gift box rules + saving. Rewards are RANDOM every time.
class GiftService {
  GiftService._();

  /// A gift box appears after every N-th level (11, 22, 33 ...).
  static const int everyNLevels = 11;

  /// Extra gift boxes on a few other levels. Add / remove numbers freely.
  /// (A gift "after level 5" sits on the road between level 5 and 6.)
  static const Set<int> extraGiftLevels = {5, 19, 30, 41, 57, 73, 88, 105};

  /// A booster can drop only if it unlocks within this many levels
  /// of the gift (so a gift at level 11 can give a Bomb, which unlocks at 15).
  static const int _boosterLookAhead = 15;

  static const Map<BoosterId, int> _boosterUnlockLevel = {
    BoosterId.bloomSwap: 1,
    BoosterId.bloomBomb: 15,
    BoosterId.rainbowBloom: 50,
    BoosterId.bloomLightning: 100,
    BoosterId.flowerBlast: 250,
  };

  static const String _kOpened = 'opened_gifts';
  static String _coinsKey(GameMode mode) =>
      mode == GameMode.wordBloom ? 'player_coins' : '${mode.name}_player_coins';
  static String _openedKey(GameMode mode) =>
      mode == GameMode.wordBloom ? _kOpened : '${mode.name}_opened_gifts';

  static bool _busy = false;

  static bool hasGiftAfter(int level) =>
      level >= 1 &&
      (level % everyNLevels == 0 || extraGiftLevels.contains(level));

  static Future<Set<int>> getOpenedGifts({
    GameMode mode = GameMode.wordBloom,
  }) async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    final List<String> raw =
        p.getStringList(_openedKey(mode)) ?? const <String>[];
    return raw.map(int.parse).toSet();
  }

  // NOTE: if you already keep coins somewhere else, change these two
  // methods to read / write your own coins and everything else keeps working.
  static Future<int> getCoins({GameMode mode = GameMode.wordBloom}) async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    return p.getInt(_coinsKey(mode)) ?? 0;
  }

  // Calls are queued one after another so two quick additions
  // (e.g. word score + gift) can never overwrite each other.
  static Future<void> _coinQueue = Future<void>.value();

  static Future<void> addCoins(int n, {GameMode mode = GameMode.wordBloom}) {
    if (n == 0) return _coinQueue;
    _coinQueue = _coinQueue
        .then((_) async {
          final SharedPreferences p = await SharedPreferences.getInstance();
          await p.setInt(_coinsKey(mode), (p.getInt(_coinsKey(mode)) ?? 0) + n);
        })
        .catchError((Object _) {});
    return _coinQueue;
  }

  /// Serialized with coin earnings so rapid purchases cannot overspend.
  static Future<bool> buyBooster(
    BoosterId id, {
    GameMode mode = GameMode.wordBloom,
  }) {
    final result = _coinQueue.then((_) async {
      await BoosterService.instance.load();
      final p = await SharedPreferences.getInstance();
      final balance = p.getInt(_coinsKey(mode)) ?? 0;
      final price = boosterCoinPrice(id);
      if (balance < price) return false;
      if (!await p.setInt(_coinsKey(mode), balance - price)) {
        throw StateError('Could not save coins');
      }
      try {
        await BoosterService.instance.addPurchased(id);
      } catch (_) {
        await p.setInt(_coinsKey(mode), balance);
        rethrow;
      }
      return true;
    });
    // A failed purchase must not block later earnings or purchases.
    _coinQueue = result.then<void>((_) {}).catchError((Object _) {});
    return result;
  }

  /// Opens a gift: picks random rewards, SAVES them to the player right away
  /// and marks the gift as opened. Returns an empty list if it was
  /// already opened.
  static Future<List<GiftReward>> open(
    int giftLevel, {
    GameMode mode = GameMode.wordBloom,
  }) async {
    if (_busy) return const <GiftReward>[];
    _busy = true;
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      final Set<int> opened = await getOpenedGifts(mode: mode);
      if (opened.contains(giftLevel)) return const <GiftReward>[];

      // Mark first, so a double tap can never pay twice.
      opened.add(giftLevel);
      await p.setStringList(
        _openedKey(mode),
        opened.map((int e) => e.toString()).toList(),
      );

      final List<GiftReward> rewards = roll(giftLevel);

      await BoosterService.instance.load();
      for (final GiftReward r in rewards) {
        if (r.isCoins) {
          await addCoins(r.amount, mode: mode);
        } else {
          await BoosterService.instance.add(r.booster!, r.amount);
        }
      }
      return rewards;
    } finally {
      _busy = false;
    }
  }

  /// Exactly one reward per gift. Early gifts: 90% coins, 10% booster.
  /// After level 100, path gifts give coins only.
  static List<GiftReward> roll(int giftLevel, [Random? random]) {
    final rnd = random ?? Random();
    if (giftLevel <= 100 && rnd.nextInt(100) >= 90) {
      final pool =
          <_PoolEntry>[
                const _PoolEntry(BoosterId.bloomBomb, 6),
                const _PoolEntry(BoosterId.bloomSwap, 3),
                const _PoolEntry(BoosterId.rainbowBloom, 1),
                const _PoolEntry(BoosterId.bloomLightning, 1),
              ]
              .where(
                (e) =>
                    (_boosterUnlockLevel[e.booster] ?? 1) <=
                    giftLevel + _boosterLookAhead,
              )
              .toList();
      var pick = rnd.nextInt(pool.fold<int>(0, (n, e) => n + e.weight));
      for (final entry in pool) {
        if (pick < entry.weight) {
          return [GiftReward.booster(entry.booster!, 1)];
        }
        pick -= entry.weight;
      }
    }
    final bonus = min(giftLevel ~/ everyNLevels, 30) * 10;
    return [GiftReward.coins(150 + rnd.nextInt(9) * 25 + bonus)];
  }
}
