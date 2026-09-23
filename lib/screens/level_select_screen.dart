import 'package:flutter/material.dart';

import '../levels.dart';
import '../word_bloom.dart';

class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({super.key});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  // ==============================================================
  // PLAYER PROGRESS
  // ==============================================================

  int _unlockedLevel = 1;

  final ScrollController _scrollController = ScrollController();

  // ==============================================================
  // WORLD 1
  // ==============================================================

  static const int _world1Levels = 10;

  // Map height is based on screen height so it always fills the
  // screen and leaves a bit of room to scroll. BoxFit.cover below
  // will crop the image slightly left/right to fill this box, but
  // since this is close to the image's natural proportions the
  // crop stays minimal.
  static const double _mapHeightMultiplier = 1.15;

  // ==============================================================
  // INIT
  // ==============================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  // ==============================================================
  // DISPOSE
  // ==============================================================

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ==============================================================
  // OPEN LEVEL
  // ==============================================================

  void _openLevel(int levelNumber) async {
    if (levelNumber > _unlockedLevel) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WordBloom(
          startLevel: levelNumber,
          onLevelComplete: (completedLevel) {
            if (!mounted) return;

            setState(() {
              if (completedLevel >= _unlockedLevel &&
                  completedLevel < _world1Levels &&
                  completedLevel < levels.length) {
                _unlockedLevel = completedLevel + 1;
              }
            });
          },
        ),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  // ==============================================================
  // BUILD
  // ==============================================================

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    final double mapHeight = screenHeight * _mapHeightMultiplier;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFFDCEFE0)),

          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // ==================================================
                // HEADER
                // ==================================================

                // Padding(
                //   padding: const EdgeInsets.symmetric(
                //     horizontal: 14,
                //     vertical: 10,
                //   ),
                //   child: Row(
                //     children: [
                //       _RoundIconButton(
                //         icon: Icons.arrow_back_rounded,
                //         onTap: () {
                //           Navigator.of(context).maybePop();
                //         },
                //       ),

                //       const SizedBox(width: 12),

                //       const Expanded(
                //         child: Column(
                //           crossAxisAlignment: CrossAxisAlignment.start,
                //           children: [
                //             Text(
                //               'World 1',
                //               style: TextStyle(
                //                 fontSize: 20,
                //                 fontWeight: FontWeight.w900,
                //                 color: Color(0xFF2E3A2E),
                //                 shadows: [
                //                   Shadow(color: Colors.white, blurRadius: 6),
                //                 ],
                //               ),
                //             ),
                //             Text(
                //               'Misty Cliff',
                //               style: TextStyle(
                //                 fontSize: 12,
                //                 fontWeight: FontWeight.w600,
                //                 color: Color(0xFF5B6B58),
                //                 shadows: [
                //                   Shadow(color: Colors.white, blurRadius: 6),
                //                 ],
                //               ),
                //             ),
                //           ],
                //         ),
                //       ),

                //       _RoundIconButton(
                //         icon: Icons.settings_rounded,
                //         onTap: () {},
                //       ),
                //     ],
                //   ),
                // ),

                // ==================================================
                // SCROLLABLE MAP
                // ==================================================
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    child: SizedBox(
                      width: double.infinity,
                      height: mapHeight,
                      child: Stack(
                        children: [
                          // ========================================
                          // MAP IMAGE
                          // ========================================

                          Positioned.fill(
                            child: Image.asset(
                              'assets/images/world_1_misty_cliff.png',
                              fit: BoxFit.fitHeight,
                              alignment: Alignment.center,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: const Color(0xFFDCEFE0),
                                  alignment: Alignment.center,
                                  child: const Text(
                                    'Map image not found',
                                    style: TextStyle(
                                      color: Colors.black54,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          // ========================================
                          // 10 LEVELS
                          // ========================================
                          for (int i = 0; i < _world1Levels; i++)
                            Positioned(
                              left: (pathX(i + 1) * screenWidth) - 20,
                              top: pathY(i + 1) - 20,

                              child: _LevelNode(
                                number: i + 1,
                                unlocked: (i + 1) <= _unlockedLevel,
                                current: (i + 1) == _unlockedLevel,
                                onTap: () {
                                  _openLevel(i + 1);
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // ACTUAL MAP PATH COORDINATES
  //
  // Calibrated against mapHeight = screenHeight * 1.15 with
  // BoxFit.cover. Follows the visible stone path.
  // ==============================================================

  double pathX(int levelNumber) {
    const List<double> positions = [
      0.56, // 1
      0.82, // 2
      0.64, // 3
      0.82, // 4
      0.60, // 5
      0.88, // 6
      0.59, // 7
      0.87, // 8
      0.55, // 9
      0.84, // 10
    ];

    return positions[levelNumber - 1];
  }

  double pathY(int levelNumber) {
    const List<double> positions = [
      910, // 1
      896, // 2
      817, // 3
      762, // 4
      704, // 5
      639, // 6
      559, // 7
      491, // 8
      422, // 9
      351, // 10
    ];

    return positions[levelNumber - 1];
  }
}

// ================================================================
// LEVEL NODE
// ================================================================

class _LevelNode extends StatelessWidget {
  final int number;
  final bool unlocked;
  final bool current;
  final VoidCallback onTap;

  const _LevelNode({
    required this.number,
    required this.unlocked,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: unlocked ? onTap : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (current)
            const Padding(
              padding: EdgeInsets.only(bottom: 3),
              child: Text('👑', style: TextStyle(fontSize: 16)),
            ),

          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,

              gradient: unlocked
                  ? const LinearGradient(
                      colors: [Color(0xFFFF9AC7), Color(0xFFFF559F)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : const LinearGradient(
                      colors: [Color(0xFFC9C9C9), Color(0xFF9E9E9E)],
                    ),

              border: Border.all(
                color: current ? const Color(0xFFFFD15C) : Colors.white,
                width: current ? 3 : 2,
              ),

              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),

            child: Center(
              child: unlocked
                  ? Text(
                      '$number',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    )
                  : const Icon(
                      Icons.lock_rounded,
                      color: Colors.white,
                      size: 15,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// ROUND ICON BUTTON
// ================================================================

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.85),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 20, color: const Color(0xFF2E3A2E)),
        ),
      ),
    );
  }
}
