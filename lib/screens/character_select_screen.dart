import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/app_theme.dart';
import '../models/god.dart';
import '../services/game_storage.dart';
import '../widgets/coin_pill.dart';
import '../widgets/olympus_button.dart';

class CharacterSelectScreen extends StatefulWidget {
  const CharacterSelectScreen({super.key});

  @override
  State<CharacterSelectScreen> createState() => _CharacterSelectScreenState();
}

class _CharacterSelectScreenState extends State<CharacterSelectScreen> {
  late final PageController _page;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    final selected = God.all.indexWhere(
      (g) => g.id == AppScope.read(context).selectedGodId,
    );
    _index = selected < 0 ? 0 : selected;
    _page = PageController(initialPage: _index, viewportFraction: 1);
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  Future<void> _onAction(GameStorage storage, God god) async {
    if (storage.isUnlocked(god.id)) {
      await storage.selectGod(god.id);
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final ok = await storage.unlockGod(god);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Text(
            'Not enough gold to free ${god.name}.',
            style: AppTheme.body(15),
          ),
        ),
      );
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final storage = AppScope.of(context);
    final God god = God.all[_index];

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: Image.asset(
              god.background,
              key: ValueKey(god.id),
              fit: BoxFit.cover,
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.55),
                  Colors.black.withValues(alpha: 0.2),
                  Colors.black.withValues(alpha: 0.9),
                ],
                stops: const [0.0, 0.4, 1.0],
              ),
            ),
          ),
          PageView.builder(
            controller: _page,
            itemCount: God.all.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => _GodCard(god: God.all[i]),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  OlympusIconButton(
                    icon: Icons.arrow_back,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  CoinPill(amount: storage.coins),
                ],
              ),
            ),
          ),
          _bottomPanel(storage, god),
        ],
      ),
    );
  }

  Widget _bottomPanel(GameStorage storage, God god) {
    final bool unlocked = storage.isUnlocked(god.id);
    final bool selected = storage.selectedGodId == god.id;

    String label;
    if (selected) {
      label = 'SELECTED';
    } else if (unlocked) {
      label = 'CHOOSE';
    } else {
      label = 'UNLOCK  ${god.cost}';
    }

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dots(),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: god.accent.withValues(alpha: 0.8),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, color: god.accent, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(god.perk, style: AppTheme.body(14)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              OlympusButton(
                label: label,
                width: double.infinity,
                icon: unlocked ? Icons.check_circle : Icons.lock_open,
                enabled: !selected,
                onTap: () => _onAction(storage, god),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(God.all.length, (i) {
        final active = i == _index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? AppColors.gold : Colors.white38,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

class _GodCard extends StatelessWidget {
  const _GodCard({required this.god});
  final God god;

  @override
  Widget build(BuildContext context) {
    final storage = AppScope.of(context);
    final bool unlocked = storage.isUnlocked(god.id);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 64, bottom: 230),
        child: Column(
          children: [
            Text(god.name, style: AppTheme.title(36)),
            Text(god.title, style: AppTheme.body(16, color: god.accent)),
            const SizedBox(height: 6),
            Expanded(
              child: ColorFiltered(
                colorFilter: unlocked
                    ? const ColorFilter.mode(
                        Colors.transparent, BlendMode.multiply)
                    : const ColorFilter.matrix(<double>[
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0, 0, 0, 1, 0,
                      ]),
                child: Image.asset(god.asset, fit: BoxFit.contain),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
              child: Text(
                god.lore,
                textAlign: TextAlign.center,
                style: AppTheme.body(13, color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
