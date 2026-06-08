import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/app_theme.dart';
import '../widgets/olympus_button.dart';
import 'webview_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _openWeb(BuildContext context, String title, String url) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WebViewScreen(title: title, url: url)),
    );
  }

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
                    Text('SETTINGS', style: AppTheme.title(26)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _SwitchTile(
                icon: Icons.vibration,
                label: 'Haptics',
                value: storage.hapticsOn,
                onChanged: storage.setHaptics,
              ),
              const Spacer(),
              _linkRow(
                context,
                Icons.privacy_tip,
                'Privacy Policy',
                'https://ollympusgates.com/privacy-policy.html',
              ),
              _linkRow(
                context,
                Icons.support_agent,
                'Support',
                'https://ollympusgates.com/support.html',
              ),
              const SizedBox(height: 16),
              Text(
                'Olympus Gate  •  v1.0.0',
                style: AppTheme.body(13, color: Colors.white54),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _linkRow(
      BuildContext context, IconData icon, String label, String url) {
    return ListTile(
      leading: Icon(icon, color: AppColors.goldLight),
      title: Text(label, style: AppTheme.body(16)),
      trailing: const Icon(Icons.open_in_new, color: Colors.white54, size: 18),
      onTap: () => _openWeb(context, label, url),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.goldLight),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: AppTheme.body(16))),
            Switch(
              value: value,
              activeThumbColor: AppColors.gold,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
