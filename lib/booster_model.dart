import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum BoosterId { bloomSwap, bloomBomb, rainbowBloom, bloomLightning, flowerBlast }

class BoosterDef {
  final BoosterId id;
  final String name;
  final String description;
  final int unlockLevel;
  final int startQuantity;
  const BoosterDef(this.id, this.name, this.description, this.unlockLevel,
      {this.startQuantity = 0});
}

const kBoosters = <BoosterDef>[
  BoosterDef(BoosterId.bloomSwap, 'Bloom Swap',
      'Swap the current and next bubble.', 1, startQuantity: 3),
  BoosterDef(BoosterId.bloomBomb, 'Bloom Bomb',
      'A flower burst clears nearby bubbles.', 15),
  BoosterDef(BoosterId.rainbowBloom, 'Rainbow Bloom',
      'A wild bubble that matches any color.', 50),
  BoosterDef(BoosterId.bloomLightning, 'Bloom Lightning',
      'Clears bubbles along its path.', 100),
  BoosterDef(BoosterId.flowerBlast, 'Flower Blast',
      'A large area burst.', 250),
];

class BoosterService extends ChangeNotifier {
  final Map<BoosterId, int> _qty = {};
  int unlockedLevel = 1; // update this from ProgressService

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final firstRun = !(p.getBool('booster_init') ?? false);
    for (final b in kBoosters) {
      _qty[b.id] = p.getInt('booster_${b.id.name}') ?? (firstRun ? b.startQuantity : 0);
    }
    await p.setBool('booster_init', true);
    notifyListeners();
  }

  bool isUnlocked(BoosterDef b) => unlockedLevel >= b.unlockLevel;
  int quantity(BoosterId id) => _qty[id] ?? 0;
  bool canUse(BoosterDef b) => isUnlocked(b) && quantity(b.id) > 0;

  Future<void> add(BoosterId id, int n) async {
    _qty[id] = quantity(id) + n;
    await _save(id);
  }

  Future<bool> use(BoosterId id) async {
    if (quantity(id) <= 0) return false;
    _qty[id] = quantity(id) - 1;
    await _save(id);
    return true;
  }

  Future<void> _save(BoosterId id) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('booster_${id.name}', quantity(id));
    notifyListeners();
  }
}