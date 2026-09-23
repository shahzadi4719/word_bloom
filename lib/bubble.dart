import 'package:flutter/material.dart';

/// A single letter bubble, either sitting on the board or currently
/// flying through the air after being shot.
class Bubble {
  static int _nextId = 0;

  /// Stable identity for this bubble, independent of its position.
  final int id;

  double x;
  double y;
  String letter;
  Color color;

  /// Bubble radius in the same normalized (0-1) coordinate space as
  /// x/y.
  double radius;

  Bubble({
    required this.x,
    required this.y,
    required this.letter,
    required this.color,
    this.radius = 0.052,
  }) : id = _nextId++;

  @override
  bool operator ==(Object other) => other is Bubble && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
