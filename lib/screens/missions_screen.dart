import 'package:flutter/material.dart';

import '../core/app_assets.dart';
import '../core/app_scope.dart';
import '../core/app_theme.dart';
import '../models/mission.dart';
import '../services/game_storage.dart';
import '../widgets/coin_pill.dart';
import '../widgets/olympus_button.dart';

class MissionsScreen extends StatelessWidget {
  const MissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = AppScope.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.menuGradient),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    OlympusIconButton(
                      icon: Icons.arrow_back,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                    Text('QUESTS', style: AppTheme.title(26)),
                    const Spacer(),
                    CoinPill(amount: storage.coins),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: Mission.all.length,
                  itemBuilder: (_, i) =>
                      _MissionTile(mission: Mission.all[i], storage: storage),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MissionTile extends StatelessWidget {
  const _MissionTile({required this.mission, required this.storage});
  final Mission mission;
  final GameStorage storage;

  @override
  Widget build(BuildContext context) {
    final int progress = storage.stat(mission.statKey);
    final bool complete = progress >= mission.target;
    final bool claimed = storage.isMissionClaimed(mission.id);
    final double ratio = (progress / mission.target).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: claimed
              ? Colors.white24
              : complete
                  ? AppColors.gold
                  : Colors.white24,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(mission.title, style: AppTheme.title(18)),
              ),
              if (claimed)
                const Icon(Icons.verified, color: AppColors.gold)
              else
                Row(
                  children: [
                    Image.asset(AppAssets.coin, width: 20, height: 20),
                    const SizedBox(width: 4),
                    Text('+${mission.reward}',
                        style: AppTheme.body(15, color: AppColors.goldLight)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            mission.description,
            style: AppTheme.body(13, color: Colors.white70),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 10,
                    backgroundColor: Colors.black38,
                    valueColor: AlwaysStoppedAnimation(
                      complete ? AppColors.gold : AppColors.stormBlue,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${progress.clamp(0, mission.target)}/${mission.target}',
                style: AppTheme.body(13, color: Colors.white70),
              ),
            ],
          ),
          if (complete && !claimed) ...[
            const SizedBox(height: 12),
            OlympusButton(
              label: 'CLAIM REWARD',
              height: 44,
              fontSize: 16,
              width: double.infinity,
              onTap: () => storage.claimMission(mission.id, mission.reward),
            ),
          ],
        ],
      ),
    );
  }
}
