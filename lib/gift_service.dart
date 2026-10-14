import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'booster_service.dart';

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
  static const String _kCoins = 'player_coins';

  static bool _busy = false;

  static bool hasGiftAfter(int level) =>
      level >= 1 &&
      (level % everyNLevels == 0 || extraGiftLevels.contains(level));

  static Future<Set<int>> getOpenedGifts() async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    final List<String> raw = p.getStringList(_kOpened) ?? const <String>[];
    return raw.map(int.parse).toSet();
  }

  // NOTE: if you already keep coins somewhere else, change these two
  // methods to read / write your own coins and everything else keeps working.
  static Future<int> getCoins() async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    return p.getInt(_kCoins) ?? 0;
  }

  // Calls are queued one after another so two quick additions
  // (e.g. word score + gift) can never overwrite each other.
  static Future<void> _coinQueue = Future<void>.value();

  static Future<void> addCoins(int n) {
    if (n == 0) return _coinQueue;
    _coinQueue = _coinQueue.then((_) async {
      final SharedPreferences p = await SharedPreferences.getInstance();
      await p.setInt(_kCoins, (p.getInt(_kCoins) ?? 0) + n);
    }).catchError((Object _) {});
    return _coinQueue;
  }

  /// Opens a gift: picks random rewards, SAVES them to the player right away
  /// and marks the gift as opened. Returns an empty list if it was
  /// already opened.
  static Future<List<GiftReward>> open(int giftLevel) async {
    if (_busy) return const <GiftReward>[];
    _busy = true;
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      final Set<int> opened = await getOpenedGifts();
      if (opened.contains(giftLevel)) return const <GiftReward>[];

      // Mark first, so a double tap can never pay twice.
      opened.add(giftLevel);
      await p.setStringList(
        _kOpened,
        opened.map((int e) => e.toString()).toList(),
      );

      final List<GiftReward> rewards = roll(giftLevel);

      await BoosterService.instance.load();
      for (final GiftReward r in rewards) {
        if (r.isCoins) {
          await addCoins(r.amount);
        } else {
          await BoosterService.instance.add(r.booster!, r.amount);
        }
      }
      return rewards;
    } finally {
      _busy = false;
    }
  }

  /// Random reward: every gift box holds exactly ONE thing (coins OR a booster).
  static List<GiftReward> roll(int giftLevel, [Random? random]) {
    final Random rnd = random ?? Random();

    final List<_PoolEntry> pool = <_PoolEntry>[
      const _PoolEntry(null, 40), // coins
      const _PoolEntry(BoosterId.bloomSwap, 25),
      const _PoolEntry(BoosterId.bloomBomb, 20),
      const _PoolEntry(BoosterId.rainbowBloom, 8),
      const _PoolEntry(BoosterId.bloomLightning, 5),
      const _PoolEntry(BoosterId.flowerBlast, 2),
    ].where((_PoolEntry e) {
      if (e.booster == null) return true;
      final int unlock = _boosterUnlockLevel[e.booster] ?? 1;
      return unlock <= giftLevel + _boosterLookAhead;
    }).toList();

    const int slots = 1; // one reward per box
    final List<GiftReward> out = <GiftReward>[];

    for (int i = 0; i < slots && pool.isNotEmpty; i++) {
      final int total = pool.fold<int>(0, (int s, _PoolEntry e) => s + e.weight);
      int pick = rnd.nextInt(total);
      _PoolEntry picked = pool.last;
      for (final _PoolEntry e in pool) {
        if (pick < e.weight) {
          picked = e;
          break;
        }
        pick -= e.weight;
      }
      pool.remove(picked);

      if (picked.booster == null) {
        final int bonus = min(giftLevel ~/ everyNLevels, 30) * 5;
        out.add(GiftReward.coins(25 + rnd.nextInt(16) * 5 + bonus));
      } else {
        int amount = 1;
        if (picked.booster == BoosterId.bloomSwap && rnd.nextInt(100) < 35) {
          amount = 2;
        }
        out.add(GiftReward.booster(picked.booster!, amount));
      }
    }

    out.sort(
      (GiftReward a, GiftReward b) =>
          (a.isCoins ? 0 : 1) - (b.isCoins ? 0 : 1),
    );
    return out;
  }
}