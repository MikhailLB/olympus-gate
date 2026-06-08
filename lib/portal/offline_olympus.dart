import 'package:flutter/material.dart';

import '../core/app_assets.dart';
import '../core/app_theme.dart';
import 'herald_consent_page.dart' show MarbleButton;

/// "No internet" screen for the gray flow. Uses the project's
/// custom static artwork (vertical + landscape variants) instead
/// of a video — see custom_screens.md in the template guide for
/// the asset-file contract.
class OfflineOlympus extends StatefulWidget {
  const OfflineOlympus({super.key, required this.rebuildOnRetry});

  final WidgetBuilder rebuildOnRetry;

  @override
  State<OfflineOlympus> createState() => _OfflineOlympusState();
}

class _OfflineOlympusState extends State<OfflineOlympus> {
  bool _checking = false;

  Future<void> _onRetry() async {
    if (_checking) return;
    setState(() => _checking = true);
    // Tiny delay so the user sees the press feedback and the
    // spinner before the screen vanishes.
    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: widget.rebuildOnRetry),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final art = landscape
        ? AppAssets.offlineHorizontal
        : AppAssets.offlineVertical;

    return Scaffold(
      backgroundColor: AppColors.nightBottom,
      body: SizedBox(
        width: size.width,
        height: size.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(art, fit: BoxFit.cover),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.5),
                  ],
                ),
              ),
            ),
            Positioned(
              left: landscape ? size.width * 0.30 : size.width * 0.10,
              right: landscape ? size.width * 0.30 : size.width * 0.10,
              bottom:
                  landscape ? size.height * 0.08 : size.height * 0.09,
              child: Center(
                child: _checking
                    ? const _ConnectingPlate()
                    : MarbleButton(
                        label: 'Retry',
                        onTap: _onRetry,
                        compact: landscape,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectingPlate extends StatelessWidget {
  const _ConnectingPlate();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
      decoration: BoxDecoration(
        color: AppColors.nightTop.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.goldDark, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor:
                  AlwaysStoppedAnimation<Color>(AppColors.goldLight),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              'CONNECTING…',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTheme.displayFont,
                color: AppColors.goldLight,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
