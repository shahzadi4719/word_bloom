import 'package:flutter/material.dart';

import 'bloom_visuals.dart';

import 'booster_service.dart';
import 'booster_bar.dart';
import 'gift_service.dart';
import 'game_mode.dart';
import 'test_ads_service.dart';

Future<void> showBoosterShop(
  BuildContext context, {
  BoosterId? selected,
  GameMode mode = GameMode.wordBloom,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  isDismissible: false,
  enableDrag: false,
  backgroundColor: Colors.transparent,
  builder: (_) => _BoosterShop(selected: selected, mode: mode),
);

class _BoosterShop extends StatefulWidget {
  final BoosterId? selected;
  final GameMode mode;
  const _BoosterShop({this.selected, required this.mode});
  @override
  State<_BoosterShop> createState() => _BoosterShopState();
}

class _BoosterShopState extends State<_BoosterShop> {
  int _coins = 0;
  bool _loading = true, _busy = false;
  String? _message;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await BoosterService.instance.load();
    final coins = await GiftService.getCoins(mode: widget.mode);
    if (mounted) {
      setState(() {
        _coins = coins;
        _loading = false;
      });
    }
  }

  Future<void> _buy(BoosterDef def) async {
    if (_busy || _loading) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final bought = await GiftService.buyBooster(def.id, mode: widget.mode);
      final coins = await GiftService.getCoins(mode: widget.mode);
      if (mounted) {
        setState(() {
          _coins = coins;
          _message = bought ? '${def.name} added!' : 'Not enough coins';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Could not save purchase. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _watchAd(BoosterDef def) async {
    if (_busy || _loading) return;
    setState(() {
      _busy = true;
      _message = 'Loading test ad…';
    });
    try {
      final result = await TestAdsService.instance.showRewarded(
        grantReward: () => BoosterService.instance.addPurchased(def.id),
      );
      if (!mounted) return;
      setState(() {
        _message = switch (result) {
          TestAdResult.rewarded => '${def.name} +1 added!',
          TestAdResult.skipped => 'Ad closed before reward was earned.',
          TestAdResult.rewardFailed =>
            'Reward could not be saved. Please try again.',
          TestAdResult.unsupported => 'Test ads are set up for Android only.',
          TestAdResult.busy => 'Another ad is already open.',
          TestAdResult.unavailable =>
            'Ad unavailable. Check your internet and try again.',
        };
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final defs = [...kBoosters];
    if (widget.selected != null) {
      defs.sort(
        (a, b) => (a.id == widget.selected ? -1 : a.id.index).compareTo(
          b.id == widget.selected ? -1 : b.id.index,
        ),
      );
    }
    return PopScope(
      canPop: !_busy,
      child: SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * .83,
          ),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
            border: Border.all(color: Colors.white, width: 3),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFF5FA), Color(0xFFFFDCEC)],
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: AnimatedBuilder(
              animation: BoosterService.instance,
              builder: (_, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8ABC9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Bloom Shop',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF70465A),
                          ),
                        ),
                      ),
                      BloomCloseButton(
                        onTap: () {
                          if (!_busy) Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.monetization_on_rounded,
                        color: Color(0xFFFFB52E),
                        size: 30,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _loading ? '…' : '$_coins',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF70465A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'TEST ADS · Watch an ad for one booster',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 12,
                      color: Color(0xFFBA3A87),
                    ),
                  ),
                  if (_busy) ...[
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(color: Color(0xFFE0388C)),
                  ],
                  const SizedBox(height: 12),
                  for (final def in defs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .87),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 48,
                              height: 48,
                              child: CustomPaint(
                                painter: BoosterIconPainter(def.id),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    def.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF70465A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Owned: ${BoosterService.instance.quantity(def.id)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF9A607A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FilledButton(
                                  onPressed: _busy || _loading
                                      ? null
                                      : () => _buy(def),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFFE0388C),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 13,
                                      vertical: 12,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'BUY +1',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.monetization_on_rounded,
                                            color: Color(0xFFFFDE71),
                                            size: 16,
                                          ),
                                          const SizedBox(width: 3),
                                          Text('${boosterCoinPrice(def.id)}'),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 5),
                                TextButton.icon(
                                  onPressed: _busy || _loading
                                      ? null
                                      : () => _watchAd(def),
                                  icon: const Icon(
                                    Icons.ondemand_video_rounded,
                                    size: 16,
                                  ),
                                  label: const Text(
                                    'Watch Ad · +1',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFFAB3C91),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _message!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFB0206B),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
