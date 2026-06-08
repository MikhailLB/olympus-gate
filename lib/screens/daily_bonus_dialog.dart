import 'package:flutter/material.dart';

import '../core/app_assets.dart';
import '../core/app_scope.dart';
import '../core/app_theme.dart';
import '../widgets/olympus_button.dart';

const int kDailyReward = 250;

/// Shows the once-per-day gold reward popup.
Future<void> showDailyBonusDialog(BuildContext context) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black87,
    builder: (_) => const _DailyBonusDialog(),
  );
}

class _DailyBonusDialog extends StatelessWidget {
  const _DailyBonusDialog();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 40),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        decoration: BoxDecoration(
          gradient: AppTheme.menuGradient,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.gold, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.3),
              blurRadius: 24,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('DAILY BLESSING', style: AppTheme.title(24)),
            const SizedBox(height: 6),
            Text(
              'The gods reward your return.',
              style: AppTheme.body(14, color: Colors.white70),
            ),
            const SizedBox(height: 18),
            Image.asset(AppAssets.coin, width: 96, height: 96),
            const SizedBox(height: 10),
            Text('+$kDailyReward Gold', style: AppTheme.title(28)),
            const SizedBox(height: 22),
            OlympusButton(
              label: 'CLAIM',
              width: double.infinity,
              onTap: () {
                AppScope.read(context).claimDaily(kDailyReward);
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}
