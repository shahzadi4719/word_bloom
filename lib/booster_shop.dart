import 'package:flutter/material.dart';

import 'bloom_visuals.dart';

import 'billing_service.dart';
import 'booster_bar.dart';
import 'booster_purchase_dialog.dart' show formatCoinCount;
import 'booster_service.dart';
import 'game_mode.dart';
import 'gift_service.dart';
import 'store_service.dart';
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
  final BillingService _billing = BillingService.instance;
  final StoreService _store = StoreService.instance;

  int _coins = 0;
  BoosterId _adBooster = BoosterId.bloomBomb;
  bool _loading = true, _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    final selected = widget.selected;
    if (selected != null) _adBooster = selected;
    _billing.activeMode = widget.mode;
    GiftService.coinTick.addListener(_refreshCoins);
    _billing.addListener(_onBilling);
    _store.addListener(_onStore);
    _load();
    _billing.init();
  }

  @override
  void dispose() {
    GiftService.coinTick.removeListener(_refreshCoins);
    _billing.removeListener(_onBilling);
    _store.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  void _onBilling() {
    if (!mounted) return;
    final String? m = _billing.takeMessage();
    setState(() {
      if (m != null) _message = m;
    });
  }

  Future<void> _refreshCoins() async {
    try {
      final coins = await GiftService.getCoins(mode: widget.mode);
      if (mounted) setState(() => _coins = coins);
    } catch (_) {}
  }

  Future<void> _load() async {
    try {
      await BoosterService.instance.load();
      await _store.load();
      final coins = await GiftService.getCoins(mode: widget.mode);
      if (mounted) {
        setState(() {
          _coins = coins;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _message = 'Could not load balance. Please reopen the shop.';
        });
      }
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

  // ---- Remove Ads: real money (Google Play), one time ----

  Future<void> _removeAds() async {
    if (_busy || _loading || _store.adsRemoved) return;
    await _billing.buyRemoveAds();
  }

  static const _rose = Color(0xFFB72C79);
  static const _ink = Color(0xFF74425D);

  String _name(BoosterId id) => switch (id) {
    BoosterId.bloomSwap => 'Super Swap',
    BoosterId.bloomBomb => 'Bomb',
    BoosterId.rainbowBloom => 'Rainbow',
    BoosterId.bloomLightning => 'Lightning',
    BoosterId.flowerBlast => 'Blast',
  };

  Widget _icon(BoosterId? id, double size) => SizedBox(
    width: size,
    height: size,
    child: id == null
        ? Icon(
            Icons.monetization_on_rounded,
            size: size,
            color: const Color(0xFFF3B728),
          )
        : CustomPaint(painter: BoosterIconPainter(id)),
  );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: SafeArea(
        child: Container(
          height: MediaQuery.of(context).size.height * .92,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: Colors.white, width: 2),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFF4FA), Color(0xFFF5DBED)],
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 14, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Bloom Shop',
                        style: TextStyle(
                          fontFamily: 'Fredoka',
                          fontSize: 28,
                          color: _rose,
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
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFECC6DC)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _icon(null, 24),
                          const SizedBox(width: 6),
                          Text(
                            _loading ? '…' : formatCoinCount(_coins),
                            style: const TextStyle(
                              fontFamily: 'Fredoka',
                              fontSize: 19,
                              color: _ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 22),
                  child: Column(
                    children: [
                      _removeAdsCard(),
                      const SizedBox(height: 18),
                      const Row(
                        children: [
                          Expanded(
                            child: Text(
                              'COIN BUNDLES',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: _rose,
                              ),
                            ),
                          ),
                          Text(
                            'Real-money packs',
                            style: TextStyle(fontSize: 11, color: _ink),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      for (var i = 0; i < kCoinPacks.length; i++)
                        _coinPack(i),
                      const SizedBox(height: 4),
                      _adCard(),
                      if (_busy || _billing.purchasingProductId != null)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: LinearProgressIndicator(color: _rose),
                        ),
                      if (_message != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              _message!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: _rose,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _removeAdsCard() {
    final bool owned = _store.adsRemoved;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white, width: 2),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: owned
              ? const [Color(0xFFBFEBD3), Color(0xFF6FCB9C)]
              : const [Color(0xFFFFD6EA), Color(0xFFE98BC3)],
        ),
        boxShadow: [
          BoxShadow(
            color: _rose.withValues(alpha: .16),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: Icon(
              owned ? Icons.check_rounded : Icons.block_rounded,
              color: owned ? const Color(0xFF2E9E62) : _rose,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  owned ? 'Ads Removed' : 'Remove Ads',
                  style: const TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 20,
                    color: Colors.white,
                    shadows: [Shadow(color: Color(0x66000000), blurRadius: 3)],
                  ),
                ),
                Text(
                  owned
                      ? 'Thank you! No more ads, forever.'
                      : 'One-time purchase. No more ads, forever.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (!owned) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 118,
              child: _ShinyBuyButton(
                label: _billing.purchasingProductId == kRemoveAdsProductId
                    ? 'WAIT…'
                    : _billing.removeAdsPriceLabel,
                onTap: (_busy || _loading || _billing.purchasingProductId != null)
                    ? null
                    : _removeAds,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _adCard() => Container(
    margin: const EdgeInsets.only(top: 6),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFE9C6E5)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'WATCH & COLLECT',
          style: TextStyle(
            color: _rose,
            fontSize: 11,
            letterSpacing: 1.1,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _icon(_adBooster, 46),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Get 1 ${_name(_adBooster)}',
                style: const TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: 20,
                  color: _ink,
                ),
              ),
            ),
            const Text(
              'FREE',
              style: TextStyle(
                fontSize: 12,
                color: _rose,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final id in BoosterId.values)
              ChoiceChip(
                selected: _adBooster == id,
                showCheckmark: false,
                onSelected: _busy
                    ? null
                    : (_) => setState(() => _adBooster = id),
                avatar: _icon(id, 22),
                label: Text(_name(id), style: const TextStyle(fontSize: 11)),
                selectedColor: const Color(0xFFFFD8EC),
                backgroundColor: const Color(0xFFFFF6FA),
                side: const BorderSide(color: Color(0xFFECC6DC)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _busy || _loading
                ? null
                : () => _watchAd(boosterDef(_adBooster)),
            icon: const Icon(Icons.ondemand_video_rounded, size: 20),
            label: const Text('Watch test ad · Collect 1'),
            style: FilledButton.styleFrom(
              backgroundColor: _rose,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const Text(
          'Complete the ad to receive one selected booster.',
          style: TextStyle(fontSize: 11, color: _ink),
        ),
      ],
    ),
  );

  Widget _coinPack(int index) {
    final CoinPack pack = kCoinPacks[index];
    final bool buying = _billing.purchasingProductId == pack.productId;
    final bool anyBuying = _billing.purchasingProductId != null;
    final accent = index.isOdd
        ? const Color(0xFFA651BD)
        : const Color(0xFFCA367E);
    final String? tag = index == 2
        ? 'POPULAR'
        : (index == kCoinPacks.length - 1 ? 'BEST VALUE' : null);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white, width: 2),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFFF69CCB), accent],
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: .20),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (tag != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE27A),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            tag,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                              color: Color(0xFF7A4A00),
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          _icon(null, 30),
                          const SizedBox(width: 8),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                formatCoinCount(pack.coins),
                                style: const TextStyle(
                                  fontFamily: 'Fredoka',
                                  fontSize: 34,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      color: Color(0x66000000),
                                      blurRadius: 3,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Text(
                        'COINS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 92,
                  height: 108,
                  child: const CustomPaint(painter: _TreasurePainter()),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _ShinyBuyButton(
              label: buying ? 'WAITING…' : 'BUY · ${_billing.priceLabel(pack)}',
              onTap: (_busy || anyBuying) ? null : () => _billing.buy(pack),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShinyBuyButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  const _ShinyBuyButton({required this.label, required this.onTap});
  @override
  State<_ShinyBuyButton> createState() => _ShinyBuyButtonState();
}

class _ShinyBuyButtonState extends State<_ShinyBuyButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shine = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );
  bool _pressed = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _shine.stop();
    } else {
      _shine.repeat();
    }
  }

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: widget.onTap != null,
    child: AnimatedScale(
      scale: _pressed ? .97 : 1,
      duration: Duration(
        milliseconds: MediaQuery.of(context).disableAnimations ? 0 : 110,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(color: Color(0xFF9A1D65), offset: Offset(0, 4)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: (value) => setState(() => _pressed = value),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white, width: 1.5),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFF7CC4),
                    Color(0xFFE52791),
                    Color(0xFFBC126F),
                  ],
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _shine,
                        builder: (context, child) => FractionallySizedBox(
                          widthFactor: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment(-3 + _shine.value * 6, -1),
                                end: Alignment(-1.8 + _shine.value * 6, 1),
                                colors: [
                                  Colors.white.withValues(alpha: 0),
                                  Colors.white.withValues(alpha: .22),
                                  Colors.white.withValues(alpha: 0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 13,
                    ),
                    child: Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 18,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Color(0xFF9C2A69),
                            offset: Offset(0, 1),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Booster chest with glossy pink gems.
class _TreasurePainter extends CustomPainter {
  const _TreasurePainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 110);
    final p = Paint();
    void box(Rect r, List<Color> colors, double radius) {
      p.shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      ).createShader(r);
      canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(radius)), p);
      p.shader = null;
    }

    canvas.drawOval(
      const Rect.fromLTWH(0, 94, 96, 12),
      p..color = const Color(0x337A235D),
    );
    canvas.save();
    canvas.translate(46, 41);
    canvas.rotate(-.20);
    box(const Rect.fromLTWH(-30, -31, 67, 35), [
      const Color(0xFFFFDA57),
      const Color(0xFFC77413),
    ], 7);
    box(const Rect.fromLTWH(-23, -24, 53, 21), [
      const Color(0xFF8D3765),
      const Color(0xFF4E2350),
    ], 4);
    canvas.restore();
    box(const Rect.fromLTWH(15, 48, 70, 45), [
      const Color(0xFFC669BD),
      const Color(0xFF793B9F),
    ], 6);
    box(const Rect.fromLTWH(15, 48, 10, 45), [
      const Color(0xFFFFE991),
      const Color(0xFFE7A32A),
    ], 2);
    box(const Rect.fromLTWH(74, 48, 11, 45), [
      const Color(0xFFFFE991),
      const Color(0xFFE7A32A),
    ], 2);
    box(const Rect.fromLTWH(12, 46, 77, 9), [
      const Color(0xFFFFF1A0),
      const Color(0xFFFFBE32),
    ], 3);
    for (final gem in const [
      [28.0, 43.0],
      [45.0, 37.0],
      [62.0, 43.0],
      [16.0, 96.0],
      [34.0, 98.0],
    ]) {
      final rect = Rect.fromCircle(center: Offset(gem[0], gem[1]), radius: 9);
      p.shader = const RadialGradient(
        colors: [Color(0xFFFFEAF8), Color(0xFFEC69B4), Color(0xFF9250BE)],
      ).createShader(rect);
      canvas.drawCircle(rect.center, 9, p);
      p.shader = null;
      canvas.drawOval(
        Rect.fromLTWH(gem[0] - 5, gem[1] - 6, 7, 3),
        p..color = Colors.white,
      );
    }
    box(const Rect.fromLTWH(46, 61, 12, 16), [
      const Color(0xFFFFEF9D),
      const Color(0xFFFFBD24),
    ], 3);
    canvas.drawCircle(
      const Offset(52, 67),
      2,
      p..color = const Color(0xFF8D4A56),
    );
    for (final point in const [Offset(8, 35), Offset(91, 22), Offset(91, 68)]) {
      p.color = const Color(0xFFFFF4C5);
      final path = Path()
        ..moveTo(point.dx, point.dy - 5)
        ..lineTo(point.dx + 1.5, point.dy - 1.5)
        ..lineTo(point.dx + 5, point.dy)
        ..lineTo(point.dx + 1.5, point.dy + 1.5)
        ..lineTo(point.dx, point.dy + 5)
        ..lineTo(point.dx - 1.5, point.dy + 1.5)
        ..lineTo(point.dx - 5, point.dy)
        ..lineTo(point.dx - 1.5, point.dy - 1.5)
        ..close();
      canvas.drawPath(path, p);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TreasurePainter oldDelegate) => false;
}
