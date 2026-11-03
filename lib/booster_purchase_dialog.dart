import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'booster_bar.dart' show BoosterIconPainter;
import 'booster_service.dart';
import 'game_mode.dart';
import 'gift_service.dart';
import 'store_service.dart';

const Color _plum = Color(0xFF6B3A55);
const Color _rose = Color(0xFFFF4D96);
const Color _roseDeep = Color(0xFFE0287F);
const Color _gold = Color(0xFFF3B728);

enum BoosterPurchaseResult { bought, cancelled, openShop }

String formatCoinCount(int n) {
  final String s = n.abs().toString();
  final StringBuffer b = StringBuffer(n < 0 ? '-' : '');
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

/// Purchase popup shown when the player taps a booster they don't own.
/// Resolves to [BoosterPurchaseResult.bought] only after coins were spent
/// and the booster was saved to the inventory.
Future<BoosterPurchaseResult> showBoosterPurchaseDialog(
  BuildContext context,
  BoosterDef def, {
  GameMode mode = GameMode.wordBloom,
}) async {
  final BoosterPurchaseResult? result = await showDialog<BoosterPurchaseResult>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => _PurchaseDialog(def: def, mode: mode),
  );
  return result ?? BoosterPurchaseResult.cancelled;
}

class _PurchaseDialog extends StatefulWidget {
  final BoosterDef def;
  final GameMode mode;
  const _PurchaseDialog({required this.def, required this.mode});

  @override
  State<_PurchaseDialog> createState() => _PurchaseDialogState();
}

class _PurchaseDialogState extends State<_PurchaseDialog>
    with TickerProviderStateMixin {
  // Entrance: card pops in, then each line slides up one after another.
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );
  // Endless gentle loop: floating icon, shimmer on the title, coin pulse.
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  );
  bool _started = false;
  bool _reduce = false;

  int? _coins;
  bool _busy = false;
  bool _done = false;
  String? _message;
  Timer? _closeTimer;

  int get _price => boosterCoinPrice(widget.def.id);
  bool get _enough => (_coins ?? 0) >= _price;

  @override
  void initState() {
    super.initState();
    _loadCoins();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reduce = MediaQuery.of(context).disableAnimations;
    if (_reduce) {
      _in.value = 1;
    } else {
      _in.forward();
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    _in.dispose();
    _loop.dispose();
    super.dispose();
  }

  Future<void> _loadCoins() async {
    try {
      final int c = await GiftService.getCoins(mode: widget.mode);
      if (mounted) setState(() => _coins = c);
    } catch (_) {
      if (mounted) {
        setState(() {
          _coins = 0;
          _message = 'Could not read your coins. Please try again.';
        });
      }
    }
  }

  Future<void> _buy() async {
    if (_busy || _done || _coins == null) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final PurchaseOutcome outcome = await StoreService.instance.buyBooster(
      widget.def.id,
      mode: widget.mode,
    );
    if (!mounted) return;
    await _loadCoins();
    if (!mounted) return;
    switch (outcome) {
      case PurchaseOutcome.success:
        setState(() {
          _busy = false;
          _done = true;
        });
        _closeTimer = Timer(const Duration(milliseconds: 1300), () {
          if (mounted) Navigator.of(context).pop(BoosterPurchaseResult.bought);
        });
      case PurchaseOutcome.insufficientCoins:
        setState(() {
          _busy = false;
          _message = 'Not enough coins.';
        });
      case PurchaseOutcome.busy:
      case PurchaseOutcome.alreadyOwned:
      case PurchaseOutcome.failed:
        setState(() {
          _busy = false;
          _message = 'Purchase failed. No coins were spent.';
        });
    }
  }

  /// Fades + slides a child up while the entrance runs between [a] and [b].
  Widget _stagger(double a, double b, Widget child) {
    final double t = Curves.easeOutCubic.transform(
      ((_in.value - a) / (b - a)).clamp(0.0, 1.0),
    );
    return Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, 18 * (1 - t)), child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int shortBy = _price - (_coins ?? 0);
    return PopScope(
      canPop: !_busy && !_done,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 30),
        child: AnimatedBuilder(
          animation: Listenable.merge([_in, _loop]),
          builder: (context, _) {
            final double pop = _reduce
                ? 1
                : Curves.easeOutBack.transform((_in.value / .45).clamp(0.0, 1.0));
            return Opacity(
              opacity: (_in.value / .25).clamp(0.0, 1.0),
              child: Transform.scale(
                scale: 0.86 + 0.14 * pop,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFFEAF3), Color(0xFFFFD0E4)],
                    ),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: _rose.withValues(alpha: 0.30),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _stagger(0.05, 0.40, _orb()),
                      const SizedBox(height: 12),
                      _stagger(0.15, 0.50, _title()),
                      const SizedBox(height: 4),
                      _stagger(
                        0.22,
                        0.57,
                        Text(
                          widget.def.description,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Fredoka',
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            height: 1.25,
                            color: _plum.withValues(alpha: 0.78),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _stagger(
                        0.32,
                        0.67,
                        _row('Price', _price, highlight: true),
                      ),
                      const SizedBox(height: 8),
                      _stagger(
                        0.40,
                        0.75,
                        _row(
                          'Your coins',
                          _coins,
                          bad: _coins != null && !_enough,
                        ),
                      ),
                      const SizedBox(height: 12),
                      AnimatedSwitcher(
                        duration: Duration(milliseconds: _reduce ? 0 : 220),
                        child: _statusLine(shortBy),
                      ),
                      const SizedBox(height: 14),
                      _stagger(0.55, 1.0, _buttons()),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Booster name with a glossy shimmer that keeps sweeping across it.
  Widget _title() {
    final double p = _loop.value;
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (Rect r) => LinearGradient(
        begin: Alignment(-2.4 + 5 * p, 0),
        end: Alignment(-1.2 + 5 * p, 0),
        colors: const [_roseDeep, Color(0xFFFFB3D6), _roseDeep],
      ).createShader(r),
      child: Text(
        widget.def.name,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'Fredoka',
          fontSize: 28,
          letterSpacing: 0.4,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _orb() {
    final double bob = _reduce ? 0 : sin(_loop.value * 2 * pi) * 3.5;
    final double glow = _reduce ? .35 : .30 + .15 * sin(_loop.value * 2 * pi);
    return Transform.translate(
      offset: Offset(0, bob),
      child: SizedBox(
        width: 104,
        height: 104,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  center: Alignment(-0.3, -0.45),
                  colors: [Colors.white, Color(0xFFFFC7E0), Color(0xFFFF86BC)],
                  stops: [0, 0.6, 1],
                ),
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: _roseDeep.withValues(alpha: glow),
                    blurRadius: 20,
                    spreadRadius: 1,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: CustomPaint(
                size: const Size.square(68),
                painter: BoosterIconPainter(widget.def.id),
              ),
            ),
            if (_done)
              Positioned(
                right: 2,
                bottom: 2,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 380),
                  curve: Curves.easeOutBack,
                  builder: (_, v, child) =>
                      Transform.scale(scale: v, child: child),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF3DBE7A),
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    String label,
    int? amount, {
    bool highlight = false,
    bool bad = false,
  }) {
    final double pulse = _reduce ? 1 : 1 + .07 * sin(_loop.value * 2 * pi);
    final Color valueColor = bad
        ? const Color(0xFFD6334E)
        : (highlight ? _roseDeep : _plum);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFC2DC), width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Fredoka',
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: _plum,
              ),
            ),
          ),
          Transform.scale(
            scale: pulse,
            child: const Icon(
              Icons.monetization_on_rounded,
              color: _gold,
              size: 24,
            ),
          ),
          const SizedBox(width: 6),
          // The number counts up when it appears and counts down after a buy.
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: (amount ?? 0).toDouble()),
            duration: Duration(milliseconds: _reduce ? 0 : 750),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => Text(
              amount == null ? '…' : formatCoinCount(v.round()),
              style: TextStyle(
                fontFamily: 'Fredoka',
                fontWeight: FontWeight.w700,
                fontSize: highlight ? 22 : 19,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusLine(int shortBy) {
    if (_done) {
      return Text(
        '${widget.def.name} added to your boosters!',
        key: const ValueKey('done'),
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'Fredoka',
          fontWeight: FontWeight.w700,
          fontSize: 16,
          color: Color(0xFF2E9E62),
        ),
      );
    }
    final String? text =
        _message ??
        (_coins != null && !_enough
            ? 'Not enough coins. You need ${formatCoinCount(shortBy)} more.'
            : null);
    if (text == null) return const SizedBox(key: ValueKey('none'), height: 18);
    return Text(
      text,
      key: ValueKey(text),
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontFamily: 'Fredoka',
        fontWeight: FontWeight.w700,
        fontSize: 15,
        color: Color(0xFFD6334E),
      ),
    );
  }

  Widget _buttons() {
    final bool locked = _busy || _done;
    final bool needShop = _coins != null && !_enough;
    return Row(
      children: [
        Expanded(
          child: _PopupButton(
            label: 'Cancel',
            primary: false,
            onTap: locked
                ? null
                : () =>
                      Navigator.of(context).pop(BoosterPurchaseResult.cancelled),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: needShop
              ? _PopupButton(
                  label: 'Coin Shop',
                  primary: true,
                  onTap: locked
                      ? null
                      : () => Navigator.of(
                          context,
                        ).pop(BoosterPurchaseResult.openShop),
                )
              : _PopupButton(
                  label: _busy ? '…' : 'Buy',
                  primary: true,
                  onTap: (locked || _coins == null) ? null : _buy,
                ),
        ),
      ],
    );
  }
}

class _PopupButton extends StatefulWidget {
  final String label;
  final bool primary;
  final VoidCallback? onTap;
  const _PopupButton({
    required this.label,
    required this.primary,
    required this.onTap,
  });

  @override
  State<_PopupButton> createState() => _PopupButtonState();
}

class _PopupButtonState extends State<_PopupButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onTap != null;
    final bool primary = widget.primary;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.95 : 1,
          duration: const Duration(milliseconds: 90),
          child: AnimatedOpacity(
            opacity: enabled ? 1 : 0.55,
            duration: const Duration(milliseconds: 120),
            child: Container(
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: primary
                    ? const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFFF7DB8), _roseDeep],
                      )
                    : const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.white, Color(0xFFF6DDE9)],
                      ),
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: primary
                        ? const Color(0xFFB81A68)
                        : const Color(0xFFD9B5C8),
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                widget.label,
                style: TextStyle(
                  fontFamily: 'Fredoka',
                  fontSize: 18,
                  letterSpacing: 0.6,
                  color: primary ? Colors.white : _plum,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
