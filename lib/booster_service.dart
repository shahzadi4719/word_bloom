import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ================================================================
// BOOSTER DEFINITIONS  (add a new booster = add one line here)
// ================================================================

enum BoosterId {
  bloomSwap,
  bloomBomb,
  rainbowBloom,
  bloomLightning,
  flowerBlast,
}

class BoosterDef {
  final BoosterId id;
  final String name;
  final String description;
  final int unlockLevel;
  final int startQuantity;

  const BoosterDef({
    required this.id,
    required this.name,
    required this.description,
    required this.unlockLevel,
    this.startQuantity = 0,
  });
}

const List<BoosterDef> kBoosters = [
  BoosterDef(
    id: BoosterId.bloomSwap,
    name: 'Bloom Swap',
    description: 'Swap the current and next bubble.',
    unlockLevel: 1,
    startQuantity: 3,
  ),
  BoosterDef(
    id: BoosterId.bloomBomb,
    name: 'Bloom Bomb',
    description: 'A flower burst clears nearby bubbles.',
    unlockLevel: 15,
  ),
  BoosterDef(
    id: BoosterId.rainbowBloom,
    name: 'Rainbow Bloom',
    description: 'A wild bubble that matches any color.',
    unlockLevel: 50,
  ),
  BoosterDef(
    id: BoosterId.bloomLightning,
    name: 'Bloom Lightning',
    description: 'Clears bubbles along its path.',
    unlockLevel: 100,
  ),
  BoosterDef(
    id: BoosterId.flowerBlast,
    name: 'Flower Blast',
    description: 'A large area burst.',
    unlockLevel: 250,
  ),
];

BoosterDef boosterDef(BoosterId id) =>
    kBoosters.firstWhere((b) => b.id == id);

// ================================================================
// REWARDS
// ================================================================

class BoosterReward {
  final BoosterId id;
  final int amount;
  const BoosterReward(this.id, this.amount);
}

/// Given when the player finishes the level just BEFORE a booster's
/// unlock level (i.e. the moment it unlocks).
const int kUnlockPackAmount = 2;

const int kBloomMasterLevel = 2000;

/// Key = level the player just COMPLETED.
/// (Unlock packs for levels 15 / 50 / 100 / 250 are handled automatically.)
const Map<int, List<BoosterReward>> kMilestoneRewards = {
  10: [BoosterReward(BoosterId.bloomSwap, 1)],
  30: [BoosterReward(BoosterId.bloomSwap, 1)],
  75: [BoosterReward(BoosterId.bloomBomb, 1)],
  150: [BoosterReward(BoosterId.rainbowBloom, 1)],
  300: [BoosterReward(BoosterId.bloomBomb, 1)],
  500: [
    BoosterReward(BoosterId.bloomSwap, 2),
    BoosterReward(BoosterId.bloomBomb, 1),
  ],
  750: [
    BoosterReward(BoosterId.rainbowBloom, 1),
    BoosterReward(BoosterId.bloomBomb, 1),
  ],
  1000: [
    BoosterReward(BoosterId.bloomSwap, 2),
    BoosterReward(BoosterId.rainbowBloom, 1),
    BoosterReward(BoosterId.bloomLightning, 1),
  ],
  1250: [
    BoosterReward(BoosterId.bloomBomb, 2),
    BoosterReward(BoosterId.bloomLightning, 1),
    BoosterReward(BoosterId.flowerBlast, 1),
  ],
  1500: [
    BoosterReward(BoosterId.rainbowBloom, 2),
    BoosterReward(BoosterId.bloomLightning, 2),
    BoosterReward(BoosterId.flowerBlast, 1),
  ],
  1750: [
    BoosterReward(BoosterId.bloomSwap, 3),
    BoosterReward(BoosterId.bloomBomb, 2),
    BoosterReward(BoosterId.rainbowBloom, 2),
    BoosterReward(BoosterId.bloomLightning, 1),
    BoosterReward(BoosterId.flowerBlast, 1),
  ],
  2000: [
    BoosterReward(BoosterId.bloomSwap, 3),
    BoosterReward(BoosterId.bloomBomb, 3),
    BoosterReward(BoosterId.rainbowBloom, 3),
    BoosterReward(BoosterId.bloomLightning, 3),
    BoosterReward(BoosterId.flowerBlast, 3),
  ],
};

class BoosterGrant {
  final List<BoosterReward> rewards;
  final List<BoosterDef> newlyUnlocked;
  final bool bloomMaster;

  const BoosterGrant({
    this.rewards = const [],
    this.newlyUnlocked = const [],
    this.bloomMaster = false,
  });

  bool get isEmpty => rewards.isEmpty && newlyUnlocked.isEmpty && !bloomMaster;
}

// ================================================================
// SERVICE  (inventory + unlock state, saved with SharedPreferences)
// ================================================================

class BoosterService extends ChangeNotifier {
  BoosterService._();
  static final BoosterService instance = BoosterService._();

  final Map<BoosterId, int> _qty = {};
  final Set<int> _claimed = {};
  int _unlockedLevel = 1;
  bool _loaded = false;

  bool get loaded => _loaded;
  int get unlockedLevel => _unlockedLevel;

  int quantity(BoosterId id) => _qty[id] ?? 0;
  bool isUnlocked(BoosterDef b) => _unlockedLevel >= b.unlockLevel;
  bool canUse(BoosterDef b) => isUnlocked(b) && quantity(b.id) > 0;

  Future<void> load() async {
    if (_loaded) return;
    final SharedPreferences p = await SharedPreferences.getInstance();

    final bool first = !(p.getBool('booster_init') ?? false);
    for (final BoosterDef b in kBoosters) {
      _qty[b.id] =
          p.getInt('booster_qty_${b.id.name}') ??
          (first ? b.startQuantity : 0);
    }

    _claimed
      ..clear()
      ..addAll(
        (p.getStringList('booster_claimed') ?? const <String>[])
            .map(int.tryParse)
            .whereType<int>(),
      );

    // TEMPORARY: replace with ProgressService's unlocked level later.
    _unlockedLevel = p.getInt('booster_max_level') ?? 1;

    if (first) {
      await _saveQty(p);
      await p.setBool('booster_init', true);
    }

    _loaded = true;
    notifyListeners();
  }

  /// Call with the highest level the player has reached.
  Future<void> setUnlockedLevel(int level) async {
    if (level <= _unlockedLevel) return;
    _unlockedLevel = level;
    notifyListeners();
    final SharedPreferences p = await SharedPreferences.getInstance();
    await p.setInt('booster_max_level', _unlockedLevel);
  }

  Future<void> add(BoosterId id, int amount) async {
    _qty[id] = quantity(id) + amount;
    notifyListeners();
    final SharedPreferences p = await SharedPreferences.getInstance();
    await p.setInt('booster_qty_${id.name}', quantity(id));
  }

  /// Uses one booster. The UI updates immediately; saving happens after.
  Future<bool> use(BoosterId id) async {
    if (quantity(id) <= 0) return false;
    _qty[id] = quantity(id) - 1;
    notifyListeners();
    final SharedPreferences p = await SharedPreferences.getInstance();
    await p.setInt('booster_qty_${id.name}', quantity(id));
    return true;
  }

  /// Call once when a level is won. Gives milestone rewards (only once per
  /// level, even if the player replays it) and reports new unlocks.
  Future<BoosterGrant> onLevelCompleted(int level) async {
    await load();
    await setUnlockedLevel(level + 1);

    if (_claimed.contains(level)) return const BoosterGrant();

    final List<BoosterReward> rewards = [];
    final List<BoosterDef> unlocked = [];

    for (final BoosterDef b in kBoosters) {
      if (b.unlockLevel > 1 && b.unlockLevel == level + 1) {
        unlocked.add(b);
        rewards.add(BoosterReward(b.id, kUnlockPackAmount));
      }
    }
    rewards.addAll(kMilestoneRewards[level] ?? const <BoosterReward>[]);

    final bool master = level == kBloomMasterLevel;
    if (rewards.isEmpty && !master) return const BoosterGrant();

    for (final BoosterReward r in rewards) {
      _qty[r.id] = quantity(r.id) + r.amount;
    }
    _claimed.add(level);
    notifyListeners();

    final SharedPreferences p = await SharedPreferences.getInstance();
    await _saveQty(p);
    await p.setStringList(
      'booster_claimed',
      _claimed.map((e) => e.toString()).toList(),
    );

    return BoosterGrant(
      rewards: rewards,
      newlyUnlocked: unlocked,
      bloomMaster: master,
    );
  }

  Future<void> _saveQty(SharedPreferences p) async {
    for (final BoosterDef b in kBoosters) {
      await p.setInt('booster_qty_${b.id.name}', quantity(b.id));
    }
  }
}