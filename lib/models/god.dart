import 'package:flutter/material.dart';

import '../core/app_assets.dart';
import '../core/app_theme.dart';

/// A playable deity. Each god has a unique passive perk that changes how a run
/// plays out, plus its own arena background.
class God {
  final String id;
  final String name;
  final String title;
  final String asset;
  final String background;
  final String perk;
  final String lore;
  final int cost; // 0 = unlocked from the start
  final Color accent;

  // Gameplay modifiers
  final int baseHearts; // starting lives
  final double coinMultiplier; // gold gained per coin
  final double wrathGain; // how fast the wrath meter fills per bolt
  final bool reviveOnce; // revive a single time per run

  const God({
    required this.id,
    required this.name,
    required this.title,
    required this.asset,
    required this.background,
    required this.perk,
    required this.lore,
    required this.cost,
    required this.accent,
    this.baseHearts = 3,
    this.coinMultiplier = 1.0,
    this.wrathGain = 1.0,
    this.reviveOnce = false,
  });

  static const God zeus = God(
    id: 'zeus',
    name: 'ZEUS',
    title: 'King of Olympus',
    asset: AppAssets.zeus,
    background: AppAssets.zeusBg,
    perk: 'Storm Surge: bolts charge Wrath 30% faster.',
    lore:
        'Ruler of the sky and thunder. His grip on the storm fills the Wrath '
        'of Olympus quicker than any other god.',
    cost: 0,
    accent: AppColors.skyBlue,
    baseHearts: 3,
    coinMultiplier: 1.0,
    wrathGain: 1.3,
  );

  static const God poseidon = God(
    id: 'poseidon',
    name: 'POSEIDON',
    title: 'Lord of the Seas',
    asset: AppAssets.poseidon,
    background: AppAssets.poseidonBg,
    perk: 'Tidal Guard: begins every run with an extra heart.',
    lore:
        'Master of oceans and earthquakes. The tides shield him, granting one '
        'more heart to weather the falling rocks.',
    cost: 1500,
    accent: Color(0xFF35C7C0),
    baseHearts: 4,
    coinMultiplier: 1.0,
    wrathGain: 1.0,
  );

  static const God prometheus = God(
    id: 'prometheus',
    name: 'PROMETHEUS',
    title: 'Bringer of Fire',
    asset: AppAssets.prometheus,
    background: AppAssets.prometheusBg,
    perk: 'Golden Flame: every coin is worth double gold.',
    lore:
        'The titan who gifted fire to mankind. His flame transmutes Olympian '
        'coins, doubling all the gold you collect.',
    cost: 3000,
    accent: Color(0xFFE8852E),
    baseHearts: 3,
    coinMultiplier: 2.0,
    wrathGain: 1.0,
  );

  static const God hades = God(
    id: 'hades',
    name: 'HADES',
    title: 'King of the Underworld',
    asset: AppAssets.hades,
    background: AppAssets.hadesBg,
    perk: 'Second Life: rises once from defeat with full hearts.',
    lore:
        'Sovereign of the dead. Once per run, when all hearts are lost, Hades '
        'returns from the underworld to fight again.',
    cost: 5000,
    accent: Color(0xFFB061E0),
    baseHearts: 3,
    coinMultiplier: 1.0,
    wrathGain: 1.0,
    reviveOnce: true,
  );

  static const List<God> all = [zeus, poseidon, prometheus, hades];

  static God byId(String id) =>
      all.firstWhere((g) => g.id == id, orElse: () => zeus);
}
