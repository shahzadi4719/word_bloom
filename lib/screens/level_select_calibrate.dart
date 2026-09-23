// ================================================================
// CALIBRATION TOOL - temporary screen, not part of the final game.
//
// HOW TO USE:
// 1. Add this file to your project (e.g. lib/screens/
//    level_select_calibrate.dart).
// 2. Temporarily open it instead of LevelSelectScreen (or add a
//    button somewhere that pushes it) so you can see it on your
//    actual device / the same screen size your players will use.
// 3. Tap directly on the stone path, in order, starting from
//    LEVEL 1 (bottom of the path) up to LEVEL 10 (top). Each tap
//    drops a numbered pink dot exactly where you tapped, and adds
//    one line to the list at the bottom of the screen.
// 4. If you tap the wrong spot, hit "Undo last tap".
// 5. Once all 10 are placed, scroll the bottom panel, select all
//    the generated text, copy it, and paste it directly in place
//    of the `positions` list inside `pathX()` and `pathY()` in
//    level_select_screen.dart.
// 6. Delete this file (or stop using it) once you're done - it's
//    a dev tool only.
// ================================================================

import 'package:flutter/material.dart';

class LevelSelectCalibrateScreen extends StatefulWidget {
  const LevelSelectCalibrateScreen({super.key});

  @override
  State<LevelSelectCalibrateScreen> createState() =>
      _LevelSelectCalibrateScreenState();
}

class _LevelSelectCalibrateScreenState
    extends State<LevelSelectCalibrateScreen> {
  // Map height is based on screen height so it always fills the
  // screen and leaves a bit of room to scroll. This MUST match
  // level_select_screen.dart exactly, or the values you calibrate
  // here won't line up over there.
  static const double _mapHeightMultiplier = 1.15;
  static const int _totalLevels = 10;

  final ScrollController _scrollController = ScrollController();

  // Each tap: (levelNumber, xFraction 0-1, yPixelsInMapHeight)
  final List<_TapPoint> _taps = [];

  void _handleTap(TapUpDetails details, double screenWidth) {
    if (_taps.length >= _totalLevels) return;

    // details.localPosition is already relative to the top-left of
    // the tapped widget (the SizedBox holding the map content), and
    // Flutter's hit-testing already accounts for however far the
    // SingleChildScrollView has been scrolled - so this is already
    // the correct absolute Y inside the mapHeight-tall content.
    final double localY = details.localPosition.dy;
    final double xFraction = (details.localPosition.dx / screenWidth)
        .clamp(0.0, 1.0);

    setState(() {
      _taps.add(
        _TapPoint(
          level: _taps.length + 1,
          xFraction: xFraction,
          yPixels: localY,
        ),
      );
    });
  }

  void _undo() {
    if (_taps.isEmpty) return;
    setState(() => _taps.removeLast());
  }

  void _reset() {
    setState(() => _taps.clear());
  }

  String get _generatedCode {
    final List<String> xLines = _taps
        .map((t) => '      ${t.xFraction.toStringAsFixed(2)}, // ${t.level}')
        .toList();
    final List<String> yLines = _taps
        .map((t) => '      ${t.yPixels.round()}, // ${t.level}')
        .toList();

    return 'double pathX(int levelNumber) {\n'
        '  const List<double> positions = [\n'
        '${xLines.join('\n')}\n'
        '  ];\n'
        '  return positions[levelNumber - 1];\n'
        '}\n\n'
        'double pathY(int levelNumber) {\n'
        '  const List<double> positions = [\n'
        '${yLines.join('\n')}\n'
        '  ];\n'
        '  return positions[levelNumber - 1];\n'
        '}';
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    final double mapHeight = screenHeight * _mapHeightMultiplier;

    return Scaffold(
      backgroundColor: const Color(0xFFDCEFE0),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: Colors.black87,
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _taps.length < _totalLevels
                          ? 'Tap LEVEL ${_taps.length + 1} on the path'
                          : 'All $_totalLevels placed - scroll down to copy the code',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _undo,
                    child: const Text(
                      'Undo',
                      style: TextStyle(color: Colors.orangeAccent),
                    ),
                  ),
                  TextButton(
                    onPressed: _reset,
                    child: const Text(
                      'Reset',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              flex: 3,
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                child: GestureDetector(
                  onTapUp: (details) => _handleTap(details, screenWidth),
                  child: SizedBox(
                    width: double.infinity,
                    height: mapHeight,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Image.asset(
                            'assets/images/world_1_misty_cliff.png',
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: const Color(0xFFDCEFE0),
                                alignment: Alignment.center,
                                child: const Text('Map image not found'),
                              );
                            },
                          ),
                        ),

                        for (final t in _taps)
                          Positioned(
                            left: (t.xFraction * screenWidth) - 18,
                            top: t.yPixels - 18,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFFF4D96),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black45,
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${t.level}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Generated code panel - select all + copy once done.
            Expanded(
              flex: 2,
              child: Container(
                width: double.infinity,
                color: const Color(0xFF1E1E1E),
                padding: const EdgeInsets.all(10),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _taps.isEmpty
                        ? '// Tap on the path above to start placing\n'
                              '// level 1 ... level $_totalLevels in order.'
                        : _generatedCode,
                    style: const TextStyle(
                      color: Color(0xFF9CDCFE),
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TapPoint {
  final int level;
  final double xFraction;
  final double yPixels;

  const _TapPoint({
    required this.level,
    required this.xFraction,
    required this.yPixels,
  });
}