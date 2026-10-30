import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

enum TestAdResult {
  rewarded,
  skipped,
  unavailable,
  rewardFailed,
  unsupported,
  busy,
}

/// Android development ads only. Both IDs belong to Google's sample app.
/// Initialize lazily on the first explicit Watch Ad tap; no main.dart edit.
class TestAdsService {
  TestAdsService._();
  static final instance = TestAdsService._();
  static const androidInterstitialId = 'ca-app-pub-3940256099942544/1033173712';
  static const androidRewardedId = 'ca-app-pub-3940256099942544/5224354917';

  Future<InitializationStatus>? _initialization;
  bool _busy = false;

  InterstitialAd? _interstitial;
  bool _loadingInterstitial = false;

  /// Cache a test interstitial without blocking gameplay.
  Future<void> preloadInterstitial() async {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        _interstitial != null ||
        _loadingInterstitial) {
      return;
    }
    _loadingInterstitial = true;
    try {
      _initialization ??= MobileAds.instance.initialize();
      await _initialization!.timeout(const Duration(seconds: 35));
      final loaded = Completer<InterstitialAd?>();
      await InterstitialAd.load(
        adUnitId: androidInterstitialId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            if (loaded.isCompleted) {
              ad.dispose();
            } else {
              loaded.complete(ad);
            }
          },
          onAdFailedToLoad: (error) {
            debugPrint('Test interstitial load failed: $error');
            if (!loaded.isCompleted) loaded.complete(null);
          },
        ),
      );
      _interstitial = await loaded.future.timeout(
        const Duration(seconds: 25),
        onTimeout: () {
          if (!loaded.isCompleted) loaded.complete(null);
          return null;
        },
      );
    } catch (error) {
      debugPrint('Test interstitial unavailable: $error');
      _initialization = null;
    } finally {
      _loadingInterstitial = false;
    }
  }

  /// Only at Next Level after levels 2, 4, 6, ... in every mode.
  /// If not ready, continue immediately; never show a late ad mid-level.
  Future<bool> showInterstitialAfterLevel(int completedLevel) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android || _busy) {
      return false;
    }
    if (completedLevel < 1 || completedLevel.isOdd) {
      unawaited(preloadInterstitial());
      return false;
    }
    final ad = _interstitial;
    if (ad == null) {
      unawaited(preloadInterstitial());
      return false;
    }
    _interstitial = null;
    _busy = true;
    try {
      final dismissed = Completer<bool>();
      ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
        onAdDismissedFullScreenContent: (_) {
          if (!dismissed.isCompleted) dismissed.complete(true);
        },
        onAdFailedToShowFullScreenContent: (_, error) {
          debugPrint('Test interstitial show failed: $error');
          if (!dismissed.isCompleted) dismissed.complete(false);
        },
      );
      await ad.show();
      return await dismissed.future;
    } catch (error) {
      debugPrint('Could not show test interstitial: $error');
      return false;
    } finally {
      ad.dispose();
      _busy = false;
      unawaited(preloadInterstitial());
    }
  }

  Future<TestAdResult> showRewarded({
    required Future<void> Function() grantReward,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return TestAdResult.unsupported;
    }
    if (_busy) return TestAdResult.busy;
    _busy = true;
    RewardedAd? loadedAd;
    try {
      _initialization ??= MobileAds.instance.initialize();
      await _initialization!.timeout(const Duration(seconds: 35));
      final loaded = Completer<RewardedAd?>();
      await RewardedAd.load(
        adUnitId: androidRewardedId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            if (loaded.isCompleted) {
              ad.dispose();
            } else {
              loaded.complete(ad);
            }
          },
          onAdFailedToLoad: (error) {
            debugPrint('Test rewarded ad load failed: $error');
            if (!loaded.isCompleted) loaded.complete(null);
          },
        ),
      );
      final ad = await loaded.future.timeout(
        const Duration(seconds: 25),
        onTimeout: () {
          // Close the completer so a late success disposes its native ad.
          if (!loaded.isCompleted) loaded.complete(null);
          return null;
        },
      );
      if (ad == null) return TestAdResult.unavailable;
      loadedAd = ad;
      final dismissed = Completer<bool>();
      var earned = false;
      var rewardFailed = false;
      Future<void> rewardSaved = Future<void>.value();
      ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
        onAdDismissedFullScreenContent: (_) {
          if (!dismissed.isCompleted) dismissed.complete(true);
        },
        onAdFailedToShowFullScreenContent: (_, error) {
          debugPrint('Test rewarded ad show failed: $error');
          if (!dismissed.isCompleted) dismissed.complete(false);
        },
      );
      await ad.show(
        onUserEarnedReward: (_, reward) {
          if (earned) return; // Never grant twice for the same ad.
          earned = true;
          rewardSaved = Future<void>.sync(grantReward).catchError((
            Object error,
          ) {
            rewardFailed = true;
            debugPrint('Could not save ad reward: $error');
          });
        },
      );
      final shown = await dismissed.future;
      await rewardSaved;
      if (rewardFailed) return TestAdResult.rewardFailed;
      if (earned) return TestAdResult.rewarded;
      return shown ? TestAdResult.skipped : TestAdResult.unavailable;
    } catch (error) {
      debugPrint('Test rewarded ad unavailable: $error');
      _initialization = null;
      return TestAdResult.unavailable;
    } finally {
      loadedAd?.dispose();
      _busy = false;
    }
  }
}
