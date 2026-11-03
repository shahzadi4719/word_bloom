import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game_mode.dart';
import 'gift_service.dart';
import 'store_service.dart';

/// One real-money coin bundle. [productId] must match a CONSUMABLE
/// in-app product created in Google Play Console.
class CoinPack {
  final String productId;
  final int coins;
  final int pricePkr; // shown until Google Play returns the localized price
  const CoinPack(this.productId, this.coins, this.pricePkr);
}

const List<CoinPack> kCoinPacks = [
  CoinPack('coins_1000', 1000, 200),
  CoinPack('coins_2000', 2000, 300),
  CoinPack('coins_5000', 5000, 600),
  CoinPack('coins_10000', 10000, 1000),
  CoinPack('coins_15000', 15000, 1400),
  CoinPack('coins_20000', 20000, 1800),
];

/// Remove Ads: ONE-TIME real-money purchase. In Play Console create it as a
/// NON-CONSUMABLE (one-time) in-app product with exactly this id.
const String kRemoveAdsProductId = 'remove_ads';
const int kRemoveAdsPricePkr = 3000;

CoinPack? coinPackFor(String productId) {
  for (final CoinPack p in kCoinPacks) {
    if (p.productId == productId) return p;
  }
  return null;
}

/// Google Play Billing for coin bundles and Remove Ads.
///
/// Safety rules:
///  * coins / ad removal are granted ONLY from a purchase reported by Google
///    Play with status purchased/restored - never from a button tap;
///  * every coin purchase id is stored, so redelivery (app restart, restore,
///    flaky network) can never grant the same purchase twice;
///  * a purchase is only completed (consumed / acknowledged) after the reward
///    was saved, so if saving fails Google Play delivers it again next launch;
///  * Remove Ads is restored automatically on a new install / new phone.
///
/// NOTE: this checks purchases on the device. For a production release,
/// also verify purchase tokens on your own server (Google Play Developer
/// API) before granting rewards.
class BillingService extends ChangeNotifier {
  BillingService._();
  static final BillingService instance = BillingService._();

  static const String _kProcessed = 'processed_purchase_ids';

  final Map<String, ProductDetails> products = {};
  bool available = false;
  bool loadingProducts = false;
  String? purchasingProductId;
  String? _message;

  /// Coin wallet that receives delivered purchases.
  GameMode activeMode = GameMode.wordBloom;

  StreamSubscription<List<PurchaseDetails>>? _sub;
  Future<void>? _init;
  final Set<String> _inFlight = {};

  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Returns the latest message once, then clears it.
  String? takeMessage() {
    final String? m = _message;
    _message = null;
    return m;
  }

  void _say(String text) {
    _message = text;
    notifyListeners();
  }

  /// Safe to call many times. Call once at app start (main.dart) so purchases
  /// interrupted by a crash or restart are delivered right away.
  Future<void> init() => _init ??= _doInit();

  Future<void> _doInit() async {
    if (!supported) return;
    try {
      _sub ??= InAppPurchase.instance.purchaseStream.listen(
        _onPurchases,
        onError: (Object error) {
          purchasingProductId = null;
          _say('Purchase failed. Please try again.');
        },
      );
      available = await InAppPurchase.instance.isAvailable();
      notifyListeners();
      if (available) {
        await loadProducts();
        // Brings back a previous Remove Ads purchase (reinstall / new phone).
        try {
          await InAppPurchase.instance.restorePurchases();
        } catch (error) {
          debugPrint('Billing: restore failed: $error');
        }
      }
    } catch (error) {
      debugPrint('Billing init failed: $error');
      available = false;
      _init = null; // allow a retry
      notifyListeners();
    }
  }

  Future<void> loadProducts() async {
    if (!available) return;
    loadingProducts = true;
    notifyListeners();
    try {
      final ProductDetailsResponse r = await InAppPurchase.instance
          .queryProductDetails({
            ...kCoinPacks.map((p) => p.productId),
            kRemoveAdsProductId,
          });
      products
        ..clear()
        ..addEntries(r.productDetails.map((d) => MapEntry(d.id, d)));
      if (r.notFoundIDs.isNotEmpty) {
        debugPrint(
          'Billing: products not found in Play Console: ${r.notFoundIDs}',
        );
      }
    } catch (error) {
      debugPrint('Billing: could not load products: $error');
    } finally {
      loadingProducts = false;
      notifyListeners();
    }
  }

  /// Price text for a coin pack: Google's localized price when known.
  String priceLabel(CoinPack pack) =>
      products[pack.productId]?.price ?? 'Rs. ${pack.pricePkr}';

  /// Price text for Remove Ads (Rs. 3,000 until Google Play answers).
  String get removeAdsPriceLabel =>
      products[kRemoveAdsProductId]?.price ?? 'Rs. 3,000';

  Future<void> buy(CoinPack pack) => _start(pack.productId, consumable: true);

  Future<void> buyRemoveAds() async {
    if (StoreService.instance.adsRemoved) {
      _say('Ads are already removed.');
      return;
    }
    await _start(kRemoveAdsProductId, consumable: false);
  }

  Future<void> _start(String productId, {required bool consumable}) async {
    if (purchasingProductId != null) return; // one purchase at a time
    if (!supported) {
      _say('Purchases are available on Android only.');
      return;
    }
    await init();
    if (!available) {
      _say('Google Play is not available. Please try again later.');
      return;
    }
    ProductDetails? details = products[productId];
    if (details == null) {
      await loadProducts();
      details = products[productId];
    }
    if (details == null) {
      _say('This item is not available right now.');
      return;
    }
    purchasingProductId = productId;
    notifyListeners();
    try {
      final PurchaseParam param = PurchaseParam(productDetails: details);
      final bool started = consumable
          ? await InAppPurchase.instance.buyConsumable(purchaseParam: param)
          : await InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
      if (!started) {
        purchasingProductId = null;
        _say('Could not start the purchase.');
      }
    } catch (error) {
      debugPrint('Billing: buy failed: $error');
      purchasingProductId = null;
      _say('Purchase failed. Please try again.');
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final PurchaseDetails p in list) {
      switch (p.status) {
        case PurchaseStatus.pending:
          _say('Payment pending…');
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _deliver(p);
        case PurchaseStatus.error:
          purchasingProductId = null;
          _say('Purchase failed. You were not charged for this item.');
          await _complete(p);
          // "Already owned": the player has Remove Ads already -> restore it.
          if (p.productID == kRemoveAdsProductId) {
            try {
              await InAppPurchase.instance.restorePurchases();
            } catch (_) {}
          }
        case PurchaseStatus.canceled:
          purchasingProductId = null;
          _say('Purchase cancelled.');
          await _complete(p);
      }
    }
  }

  Future<void> _complete(PurchaseDetails p) async {
    if (!p.pendingCompletePurchase) return;
    try {
      await InAppPurchase.instance.completePurchase(p);
    } catch (error) {
      debugPrint('Billing: completePurchase failed: $error');
    }
  }

  Future<void> _deliver(PurchaseDetails p) async {
    if (p.productID == kRemoveAdsProductId) {
      await _deliverRemoveAds(p);
      return;
    }
    final CoinPack? pack = coinPackFor(p.productID);
    if (pack == null) {
      await _complete(p); // not one of ours
      return;
    }
    final String id = p.purchaseID ?? '${p.productID}:${p.transactionDate}';
    if (!_inFlight.add(id)) return; // already being handled
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String> done =
          prefs.getStringList(_kProcessed) ?? const <String>[];

      if (!done.contains(id)) {
        // Record the id BEFORE paying out, so a crash can never double-pay.
        final List<String> withThis = [...done, id];
        final List<String> trimmed = withThis.length > 300
            ? withThis.sublist(withThis.length - 300)
            : withThis;
        if (!await prefs.setStringList(_kProcessed, trimmed)) {
          // Not completed -> Google Play redelivers it later.
          _say('Could not save your coins yet. They will be added shortly.');
          return;
        }
        final bool paid = await GiftService.addCoins(
          pack.coins,
          mode: activeMode,
        );
        if (!paid) {
          await prefs.setStringList(_kProcessed, done);
          _say('Could not save your coins yet. They will be added shortly.');
          return;
        }
        _say('+${pack.coins} coins added!');
      }
      await _complete(p);
    } catch (error) {
      debugPrint('Billing: delivery failed: $error');
      _say('Could not save your coins yet. They will be added shortly.');
    } finally {
      _inFlight.remove(id);
      if (purchasingProductId == p.productID) purchasingProductId = null;
      notifyListeners();
    }
  }

  Future<void> _deliverRemoveAds(PurchaseDetails p) async {
    try {
      final bool wasRemoved = StoreService.instance.adsRemoved;
      await StoreService.instance.markAdsRemoved();
      if (!wasRemoved) _say('Ads removed. Thank you!');
      await _complete(p); // acknowledges the one-time purchase
    } catch (error) {
      debugPrint('Billing: remove ads delivery failed: $error');
      // Not completed -> Google Play redelivers it later.
      _say('Could not save your purchase yet. It will be applied shortly.');
    } finally {
      if (purchasingProductId == p.productID) purchasingProductId = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
