import 'package:flutter/material.dart';

import '../core/app_assets.dart';
import '../core/app_scope.dart';
import '../core/app_theme.dart';
import '../models/god.dart';
import '../widgets/coin_pill.dart';
import '../widgets/olympus_button.dart';
import 'character_select_screen.dart';
import 'daily_bonus_dialog.dart';
import 'game_screen.dart';
import 'missions_screen.dart';
import 'settings_screen.dart';
import 'webview_screen.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  bool _checkedDaily = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_checkedDaily) {
      _checkedDaily = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowDaily());
    }
  }

  Future<void> _maybeShowDaily() async {
    final storage = AppScope.read(context);
    if (storage.canClaimDaily && mounted) {
      await showDailyBonusDialog(context);
    }
  }

  void _push(Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  void _openWeb(String title, String url) {
    _push(WebViewScreen(title: title, url: url));
  }

  @override
  Widget build(BuildContext context) {
    final storage = AppScope.of(context);
    final God god = storage.selectedGod;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Selected god's arena as the menu backdrop.
          Image.asset(god.background, fit: BoxFit.cover),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.55),
                  Colors.black.withValues(alpha: 0.25),
                  Colors.black.withValues(alpha: 0.85),
                ],
                stops: const [0.0, 0.4, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _topBar(storage.coins),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Image.asset(AppAssets.gameName, height: 96),
                ),
                Expanded(
                  child: _GodPreview(god: god),
                ),
                _menuButtons(),
                const SizedBox(height: 10),
                _footer(),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar(int coins) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          CoinPill(amount: coins),
          const Spacer(),
          OlympusIconButton(
            icon: Icons.settings,
            onTap: () => _push(const SettingsScreen()),
          ),
        ],
      ),
    );
  }

  Widget _menuButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        children: [
          OlympusButton(
            label: 'PLAY',
            icon: Icons.bolt,
            height: 68,
            fontSize: 26,
            width: double.infinity,
            onTap: () => _push(const GameScreen()),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OlympusButton(
                  label: 'GODS',
                  icon: Icons.shield_moon,
                  primary: false,
                  fontSize: 16,
                  onTap: () => _push(const CharacterSelectScreen()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OlympusButton(
                  label: 'QUESTS',
                  icon: Icons.flag,
                  primary: false,
                  fontSize: 16,
                  onTap: () => _push(const MissionsScreen()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 18,
      children: [
        _footerLink(
          'Privacy Policy',
          () => _openWeb(
            'Privacy Policy',
            'https://ollympusgates.com/privacy-policy.html',
          ),
        ),
        Text('•', style: AppTheme.body(14, color: AppColors.goldLight)),
        _footerLink(
          'Support',
          () => _openWeb('Support', 'https://ollympusgates.com/support.html'),
        ),
      ],
    );
  }

  Widget _footerLink(String label, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.open_in_new, size: 16, color: AppColors.goldLight),
      label: Text(
        label,
        style: AppTheme.body(14, color: AppColors.goldLight),
      ),
    );
  }
}

/// Animated floating preview of the currently selected god.
class _GodPreview extends StatefulWidget {
  const _GodPreview({required this.god});
  final God god;

  @override
  State<_GodPreview> createState() => _GodPreviewState();
}

class _GodPreviewState extends State<_GodPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, child) {
              final dy = (_c.value - 0.5) * 14;
              return Transform.translate(offset: Offset(0, dy), child: child);
            },
            child: Image.asset(widget.god.asset, fit: BoxFit.contain),
          ),
        ),
        const SizedBox(height: 6),
        Text(widget.god.name, style: AppTheme.title(30)),
        Text(
          widget.god.title,
          style: AppTheme.body(15, color: widget.god.accent),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}
