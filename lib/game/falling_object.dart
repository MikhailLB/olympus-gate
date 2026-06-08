import 'package:flutter/material.dart';

import '../core/app_assets.dart';

enum FallingType { coin, lightning, rock }

/// A single object falling down the arena.
class FallingObject {
  FallingObject({
    required this.type,
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.asset,
    this.spin = 0,
    this.spinSpeed = 0,
    this.drift = 0,
  });

  final FallingType type;
  double x; // center x in logical px
  double y; // center y in logical px
  final double size; // diameter in logical px
  double speed; // px per second (vertical)
  final String asset;
  double spin; // current rotation (radians)
  final double spinSpeed; // radians per second
  final double drift; // horizontal px per second

  bool collected = false;

  double get radius => size / 2;

  void update(double dt) {
    y += speed * dt;
    x += drift * dt;
    spin += spinSpeed * dt;
  }

  static String assetFor(FallingType type, int variant) {
    switch (type) {
      case FallingType.coin:
        return AppAssets.coin;
      case FallingType.lightning:
        return AppAssets.lightnings[variant % AppAssets.lightnings.length];
      case FallingType.rock:
        return AppAssets.rocks[variant % AppAssets.rocks.length];
    }
  }
}

/// A short-lived floating score/gold popup shown when objects are collected.
class FloatingText {
  FloatingText({
    required this.text,
    required this.x,
    required this.y,
    required this.color,
  });

  final String text;
  double x;
  double y;
  final Color color;
  double life = 0; // 0..1 elapsed fraction

  void update(double dt) {
    life += dt / 0.9; // ~0.9s lifetime
    y -= 40 * dt;
  }

  bool get dead => life >= 1;
}
