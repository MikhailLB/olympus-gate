import 'package:flutter/material.dart';

import '../core/app_assets.dart';
import '../core/app_theme.dart';

/// A small pill showing the player's gold balance with the coin icon.
class CoinPill extends StatelessWidget {
  const CoinPill({super.key, required this.amount, this.fontSize = 18});

  final int amount;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 16, 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.gold, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(AppAssets.coin, width: fontSize + 10, height: fontSize + 10),
          const SizedBox(width: 6),
          Text(
            _format(amount),
            style: AppTheme.title(fontSize, color: AppColors.goldLight),
          ),
        ],
      ),
    );
  }

  static String _format(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 10000) return '${(v / 1000).toStringAsFixed(1)}K';
    return '$v';
  }
}
