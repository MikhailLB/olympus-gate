import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_assets.dart';
import '../core/app_theme.dart';
import 'main_menu_screen.dart';

/// Splash screen shown on launch. Precaches every image while displaying the
/// hero loading artwork, then routes to the main menu.
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  double _progress = 0;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    // The native game (white part) is portrait-only — re-lock here
    // in case we arrived from a both-orientation gray-flow screen.
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _boot();
    }
  }

  Future<void> _boot() async {
    final start = DateTime.now();
    final assets = AppAssets.all;
    for (var i = 0; i < assets.length; i++) {
      try {
        await precacheImage(AssetImage(assets[i]), context);
      } catch (_) {
        // Ignore individual asset failures so the game can still launch.
      }
      if (!mounted) return;
      setState(() => _progress = (i + 1) / assets.length);
    }

    // Keep the splash visible for a graceful minimum duration.
    final elapsed = DateTime.now().difference(start);
    const minSplash = Duration(milliseconds: 1700);
    if (elapsed < minSplash) {
      await Future.delayed(minSplash - elapsed);
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (context, animation, secondary) => const MainMenuScreen(),
        transitionsBuilder: (context, anim, secondary, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(AppAssets.loadingVertical, fit: BoxFit.cover),
            // Dark gradient at the bottom for the progress bar legibility.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 56, left: 40, right: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ProgressBar(value: _progress),
                    const SizedBox(height: 14),
                    Text(
                      'Opening the gate...  ${(_progress * 100).round()}%',
                      style: AppTheme.body(14, color: AppColors.goldLight),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 16,
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.gold, width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.skyBlue, AppColors.stormBlue],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
