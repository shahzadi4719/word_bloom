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

// UI-only price previews. Replace with localized store ProductDetails prices
// when billing is integrated. Never grant a paid pack on a button tap.
const _previewPrices = [100, 200, 300];
const _singlePackAmounts = [3, 7, 12];

class _BoosterShopState extends State<_BoosterShop> {
  int _coins = 0;
  // 0 = mixed bundles, 1 = coins, 2..6 = the five booster categories.
  int _category = 0;
  BoosterId _adBooster = BoosterId.bloomBomb;
  bool _loading = true, _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    final selected = widget.selected;
    if (selected != null) {
      _category = selected.index + 2;
      _adBooster = selected;
    }
    _load();
  }

  Future<void> _load() async {
    try {
      await BoosterService.instance.load();
      final coins = await GiftService.getCoins(mode: widget.mode);
      if (mounted)
        setState(() {
          _coins = coins;
          _loading = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _loading = false;
          _message = 'Could not load balance. Please reopen the shop.';
        });
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

  void _select(int index) {
    if (_busy) return;
    setState(() {
      _category = index;
      if (index >= 2) _adBooster = BoosterId.values[index - 2];
    });
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bloom Shop',
                            style: TextStyle(
                              fontFamily: 'Fredoka',
                              fontSize: 28,
                              color: _rose,
                            ),
                          ),
                          Text(
                            'Little boosts for beautiful blooms',
                            style: TextStyle(fontSize: 12, color: _ink),
                          ),
                        ],
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
                    _icon(null, 24),
                    const SizedBox(width: 6),
                    Text(
                      _loading ? '…' : '$_coins',
                      style: const TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 19,
                        color: _ink,
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'YOUR BALANCE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _rose,
                      ),
                    ),
                  ],
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
                child: Row(
                  children: [
                    for (var i = 0; i < 7; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 7),
                        child: ChoiceChip(
                          selected: _category == i,
                          onSelected: _busy ? null : (_) => _select(i),
                          showCheckmark: false,
                          avatar: i < 2
                              ? Icon(
                                  i == 0
                                      ? Icons.card_giftcard_rounded
                                      : Icons.monetization_on_rounded,
                                  size: 18,
                                  color: _category == i ? Colors.white : _rose,
                                )
                              : _icon(BoosterId.values[i - 2], 22),
                          label: Text(
                            i == 0
                                ? 'Bundles'
                                : i == 1
                                ? 'Coins'
                                : _name(BoosterId.values[i - 2]),
                          ),
                          labelStyle: TextStyle(
                            fontFamily: 'Fredoka',
                            color: _category == i ? Colors.white : _rose,
                          ),
                          selectedColor: _rose,
                          backgroundColor: Colors.white,
                          side: BorderSide(
                            color: _category == i
                                ? _rose
                                : const Color(0xFFECC6DC),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
                  child: Column(
                    children: [
                      _adCard(),
                      const SizedBox(height: 18),
                      const Row(
                        children: [
                          Expanded(
                            child: Text(
                              'BUNDLE OFFERS',
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
                      AnimatedSwitcher(
                        duration: Duration(
                          milliseconds: reduceMotion ? 0 : 240,
                        ),
                        child: Column(
                          key: ValueKey(_category),
                          children: [for (var i = 0; i < 3; i++) _pack(i)],
                        ),
                      ),
                      if (_busy)
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

  Widget _adCard() => Container(
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

  Widget _reward(BoosterId? id, int amount) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .94),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _icon(id, 25),
        const SizedBox(width: 6),
        Text(
          '$amount ${id == null ? 'Coins' : _name(id)}',
          style: const TextStyle(
            color: _ink,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  Widget _pack(int index) {
    final isMixed = _category == 0;
    final isCoins = _category == 1;
    final id = _category >= 2 ? BoosterId.values[_category - 2] : null;
    final accent = index == 1
        ? const Color(0xFFA651BD)
        : const Color(0xFFCA367E);
    final title = isMixed
        ? ['Starter Bundle', 'Bloom Bundle', 'Garden Bundle'][index]
        : '${isCoins ? 'Coin' : _name(id!)} Pack';
    final coinAmount = isMixed ? (index + 1) * 100 : [500, 1200, 2000][index];
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
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 22,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (isMixed || isCoins) _reward(null, coinAmount),
                      if (isMixed)
                        for (final booster in BoosterId.values)
                          _reward(booster, index + 1),
                      if (id != null) _reward(id, _singlePackAmounts[index]),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 92,
                  height: 108,
                  child: Stack(
                    children: [
                      const Positioned.fill(
                        child: CustomPaint(painter: _TreasurePainter()),
                      ),
                      if (!isCoins)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: _icon(id ?? BoosterId.flowerBlast, 38),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            _ShinyBuyButton(
              label: 'BUY · PKR ${_previewPrices[index]}',
              onTap: _busy
                  ? null
                  : () => showDialog<void>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        backgroundColor: const Color(0xFFFFF0F7),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        title: const Text(
                          'Bloom Shop',
                          style: TextStyle(fontFamily: 'Fredoka', color: _rose),
                        ),
                        content: const Text(
                          'Purchases aren’t available yet.',
                          style: TextStyle(color: _ink),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text(
                              'OK',
                              style: TextStyle(color: _rose),
                            ),
                          ),
                        ],
                      ),
                    ),
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

/// Small code-drawn treasure illustration: open chest, gold rim and coin piles.
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
    void coin(double x, double y, double r) {
      final rect = Rect.fromCircle(center: Offset(x, y), radius: r);
      p.shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFF6A1), Color(0xFFFFCA35), Color(0xFFECA11B)],
      ).createShader(rect);
      canvas.drawCircle(Offset(x, y), r, p);
      p.shader = null;
      canvas.drawCircle(
        Offset(x, y),
        r * .73,
        p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = const Color(0xFFD99418),
      );
      p.style = PaintingStyle.fill;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(x, y), radius: r * .78),
        3.4,
        1.4,
        false,
        p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..color = const Color(0xFFFFF8CD),
      );
      p.style = PaintingStyle.fill;
    }

    for (final c in const [
      [30.0, 43.0, 10.0],
      [48.0, 39.0, 12.0],
      [65.0, 44.0, 10.0],
      [40.0, 49.0, 9.0],
      [62.0, 52.0, 10.0],
      [17.0, 90.0, 11.0],
      [34.0, 96.0, 10.0],
      [51.0, 92.0, 11.0],
      [69.0, 98.0, 9.0],
      [5.0, 98.0, 7.0],
    ]) {
      coin(c[0], c[1], c[2]);
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
