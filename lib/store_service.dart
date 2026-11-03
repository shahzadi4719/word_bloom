import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'booster_service.dart';
import 'game_mode.dart';
import 'gift_service.dart';

enum PurchaseOutcome { success, insufficientCoins, alreadyOwned, busy, failed }

/// Coin-priced booster purchases + the permanent Remove Ads flag.
///
/// Remove Ads is a REAL-MONEY purchase (Google Play, see BillingService).
/// BillingService calls [markAdsRemoved] after Google confirms the purchase;
/// the flag is saved forever and ads never come back.
///
/// Booster rules this class guarantees:
///  * coins are only deducted after the player confirmed (callers confirm
///    first, this method is the confirmed action);
///  * a purchase is a single guarded operation - a second tap while one is
///    running returns [PurchaseOutcome.busy] and spends nothing;
///  * if the booster cannot be saved after coins were spent, the coins are
///    refunded, so a failure never costs the player anything.
class StoreService extends ChangeNotifier {
  StoreService._();
  static final StoreService instance = StoreService._();

  static const String adsRemovedKey = 'remove_ads_purchased';

  bool _adsRemoved = false;
  bool _loaded = false;
  bool _busy = false;
  Future<void>? _loading;

  /// True once Remove Ads was bought. Persisted forever.
  bool get adsRemoved => _adsRemoved;
  bool get busy => _busy;

  Future<void> load() {
    if (_loaded) return Future<void>.value();
    return _loading ??= _read();
  }

  Future<void> _read() async {
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      _adsRemoved = p.getBool(adsRemovedKey) ?? false;
      _loaded = true;
      notifyListeners();
    } finally {
      _loading = null;
    }
  }

  /// Called once Google Play confirmed the Remove Ads purchase.
  /// Safe to call many times (restore / redelivery).
  Future<void> markAdsRemoved() async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    if (!await p.setBool(adsRemovedKey, true)) {
      throw StateError('Could not save Remove Ads');
    }
    _adsRemoved = true;
    _loaded = true;
    notifyListeners();
  }

  Future<PurchaseOutcome> buyBooster(
    BoosterId id, {
    GameMode mode = GameMode.wordBloom,
  }) async {
    if (_busy) return PurchaseOutcome.busy;
    _busy = true;
    try {
      final int price = boosterCoinPrice(id);
      await BoosterService.instance.load();

      final bool spent;
      try {
        spent = await GiftService.spendCoins(price, mode: mode);
      } catch (_) {
        return PurchaseOutcome.failed; // nothing was written
      }
      if (!spent) return PurchaseOutcome.insufficientCoins;

      try {
        await BoosterService.instance.addPurchased(id);
      } catch (_) {
        await _refund(price, mode);
        return PurchaseOutcome.failed;
      }
      return PurchaseOutcome.success;
    } finally {
      _busy = false;
    }
  }

  Future<void> _refund(int amount, GameMode mode) async {
    // Retry once: a refund must not be lost to a transient write failure.
    if (await GiftService.addCoins(amount, mode: mode)) return;
    await GiftService.addCoins(amount, mode: mode);
  }
}
