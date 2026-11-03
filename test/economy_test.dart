import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Package name matches your pubspec.yaml (my_first_app).
import 'package:my_first_app/billing_service.dart';
import 'package:my_first_app/booster_service.dart';
import 'package:my_first_app/gift_service.dart';
import 'package:my_first_app/store_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('prices and tables', () {
    test('booster coin prices', () {
      expect(boosterCoinPrice(BoosterId.bloomSwap), 300);
      expect(boosterCoinPrice(BoosterId.bloomBomb), 500);
      expect(boosterCoinPrice(BoosterId.rainbowBloom), 800);
      expect(boosterCoinPrice(BoosterId.bloomLightning), 1200);
      expect(boosterCoinPrice(BoosterId.flowerBlast), 1500);
    });

    test('coin bundles', () {
      expect(
        kCoinPacks.map((p) => [p.coins, p.pricePkr]).toList(),
        [
          [1000, 200],
          [2000, 300],
          [5000, 600],
          [10000, 1000],
          [15000, 1400],
          [20000, 1800],
        ],
      );
      expect(kRemoveAdsPricePkr, 3000);
      expect(kRemoveAdsProductId, 'remove_ads');
    });
  });

  group('gifts', () {
    test('a gift unlocks after every 20 levels only', () {
      for (final l in [20, 40, 60, 80, 100, 2000]) {
        expect(GiftService.hasGiftAfter(l), isTrue, reason: '$l');
      }
      for (final l in [0, 1, 5, 11, 19, 21, 22, 30, 105]) {
        expect(GiftService.hasGiftAfter(l), isFalse, reason: '$l');
      }
    });

    test('roll gives exactly one reward with the requested odds', () {
      final rnd = Random(7);
      const n = 200000;
      final counts = <String, int>{};
      for (var i = 0; i < n; i++) {
        final r = GiftService.roll(20, rnd);
        expect(r.length, 1);
        final key = r.single.isCoins
            ? 'coins${r.single.amount}'
            : r.single.booster!.name;
        expect(r.single.isCoins ? 1 : r.single.amount, 1);
        counts[key] = (counts[key] ?? 0) + 1;
      }
      const expected = {
        'bloomSwap': .30,
        'bloomBomb': .25,
        'rainbowBloom': .15,
        'bloomLightning': .10,
        'flowerBlast': .10,
        'coins100': .07,
        'coins200': .03,
      };
      expect(counts.keys.toSet(), expected.keys.toSet());
      expected.forEach((k, p) {
        expect(counts[k]! / n, closeTo(p, .01), reason: k);
      });
    });

    test('a gift pays once, only after the level is completed', () async {
      SharedPreferences.setMockInitialValues({
        'word_bloom_unlocked_level': 20, // level 20 not completed yet
      });
      expect(await GiftService.open(20), isEmpty);
      expect(await GiftService.getCoins(), 0);

      SharedPreferences.setMockInitialValues({
        'word_bloom_unlocked_level': 21, // level 20 completed
      });
      final first = await GiftService.open(20);
      expect(first.length, 1);
      final second = await GiftService.open(20);
      expect(second, isEmpty);
      expect(await GiftService.getOpenedGifts(), contains(20));

      // Not a gift level -> nothing.
      expect(await GiftService.open(21), isEmpty);
    });
  });

  group('coins', () {
    test('spending never goes below zero or double-spends', () async {
      SharedPreferences.setMockInitialValues({'player_coins': 500});
      expect(await GiftService.spendCoins(501), isFalse);
      expect(await GiftService.getCoins(), 500);

      // Two simultaneous spends of 300: only one can succeed.
      final results = await Future.wait([
        GiftService.spendCoins(300),
        GiftService.spendCoins(300),
      ]);
      expect(results.where((r) => r).length, 1);
      expect(await GiftService.getCoins(), 200);
    });
  });

  group('purchases', () {
    test('booster: nothing happens without enough coins', () async {
      SharedPreferences.setMockInitialValues({'player_coins': 799});
      await BoosterService.instance.load();
      final before = BoosterService.instance.quantity(BoosterId.rainbowBloom);
      final outcome = await StoreService.instance.buyBooster(
        BoosterId.rainbowBloom,
      );
      expect(outcome, PurchaseOutcome.insufficientCoins);
      expect(await GiftService.getCoins(), 799);
      expect(BoosterService.instance.quantity(BoosterId.rainbowBloom), before);
    });

    test('booster: coins deducted once and booster added once', () async {
      SharedPreferences.setMockInitialValues({'player_coins': 1000});
      await BoosterService.instance.load();
      final before = BoosterService.instance.quantity(BoosterId.bloomBomb);
      final outcome = await StoreService.instance.buyBooster(
        BoosterId.bloomBomb,
      );
      expect(outcome, PurchaseOutcome.success);
      expect(await GiftService.getCoins(), 500);
      expect(
        BoosterService.instance.quantity(BoosterId.bloomBomb),
        before + 1,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('player_coins'), 500);
      expect(prefs.getInt('booster_qty_bloomBomb'), before + 1);

      // A double tap must not buy twice.
      final both = await Future.wait([
        StoreService.instance.buyBooster(BoosterId.bloomSwap),
        StoreService.instance.buyBooster(BoosterId.bloomSwap),
      ]);
      expect(both.where((o) => o == PurchaseOutcome.success).length, 1);
      expect(await GiftService.getCoins(), 200);
    });

    test('remove ads: saved permanently once Google confirms', () async {
      SharedPreferences.setMockInitialValues({'player_coins': 5000});
      expect(StoreService.instance.adsRemoved, isFalse);

      await StoreService.instance.markAdsRemoved();
      expect(StoreService.instance.adsRemoved, isTrue);
      // Real-money purchase: coins are never touched.
      expect(await GiftService.getCoins(), 5000);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(StoreService.adsRemovedKey), isTrue);

      // Restoring again is harmless.
      await StoreService.instance.markAdsRemoved();
      expect(StoreService.instance.adsRemoved, isTrue);
    });

    test('playing a level never adds coins', () async {
      SharedPreferences.setMockInitialValues({'player_coins': 40});
      await GiftService.addScore(500);
      expect(await GiftService.getCoins(), 40);
    });
  });
}