import 'package:flutter/material.dart';

import '../bridge/herald_dispatcher.dart';
import '../bridge/network_sentinel.dart';
import '../bridge/vault_keeper.dart';
import '../core/app_assets.dart';
import '../core/app_theme.dart';
import '../env/gate_config.dart';
import 'oracle_view.dart' deferred as oracle;

/// Push-permission promo page. Shown exactly once per cooldown
/// period before opening the WebView for users routed into the
/// gray flow. Uses static project artwork (vertical + landscape)
/// instead of a video — keeps the APK light and orientation
/// transitions instant.
class HeraldConsentPage extends StatefulWidget {
  const HeraldConsentPage({
    super.key,
    required this.vault,
    required this.herald,
    required this.sentinel,
    required this.destinationUrl,
  });

  final VaultKeeper vault;
  final HeraldDispatcher herald;
  final NetworkSentinel sentinel;
  final String destinationUrl;

  @override
  State<HeraldConsentPage> createState() => _HeraldConsentPageState();
}

class _HeraldConsentPageState extends State<HeraldConsentPage> {
  bool _busy = false;

  Future<void> _onAllow() async {
    if (_busy) return;
    setState(() => _busy = true);
    final granted = await widget.herald.askForPermission();
    if (!mounted) return;
    if (!granted) {
      final retryAt = DateTime.now().millisecondsSinceEpoch ~/ 1000 +
          GateConfig.notificationCooldownSeconds;
      await widget.vault.writeHeraldRetryAt(retryAt);
    }
    await _enterOracle();
  }

  Future<void> _onLater() async {
    if (_busy) return;
    setState(() => _busy = true);
    final retryAt = DateTime.now().millisecondsSinceEpoch ~/ 1000 +
        GateConfig.notificationCooldownSeconds;
    await widget.vault.writeHeraldRetryAt(retryAt);
    if (!mounted) return;
    await _enterOracle();
  }

  Future<void> _enterOracle() async {
    await oracle.loadLibrary();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => oracle.OracleView(
          url: widget.destinationUrl,
          vault: widget.vault,
          herald: widget.herald,
          sentinel: widget.sentinel,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final art = landscape
        ? AppAssets.heraldHorizontal
        : AppAssets.heraldVertical;

    return Scaffold(
      backgroundColor: AppColors.nightBottom,
      body: SizedBox(
        width: size.width,
        height: size.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(art, fit: BoxFit.cover),
            // Soft bottom darken so the buttons stay readable on
            // very light or busy artwork.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
            _ButtonStack(
              landscape: landscape,
              busy: _busy,
              onAllow: _onAllow,
              onLater: _onLater,
            ),
          ],
        ),
      ),
    );
  }
}

class _ButtonStack extends StatelessWidget {
  const _ButtonStack({
    required this.landscape,
    required this.busy,
    required this.onAllow,
    required this.onLater,
  });

  final bool landscape;
  final bool busy;
  final VoidCallback onAllow;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    if (landscape) {
      return Positioned(
        left: 0,
        right: 0,
        bottom: size.height * 0.07,
        child: Center(
          child: SizedBox(
            width: size.width * 0.36,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MarbleButton(
                  label: busy ? 'Opening…' : 'Accept',
                  onTap: busy ? null : onAllow,
                  compact: true,
                ),
                const SizedBox(height: 10),
                _SkipLink(
                  label: 'Skip',
                  onTap: busy ? null : onLater,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Positioned(
      left: size.width * 0.10,
      right: size.width * 0.10,
      bottom: size.height * 0.08,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MarbleButton(
            label: busy ? 'Opening…' : 'Accept',
            onTap: busy ? null : onAllow,
          ),
          const SizedBox(height: 16),
          _SkipLink(
            label: 'Skip',
            onTap: busy ? null : onLater,
          ),
        ],
      ),
    );
  }
}

/// Olympus signature button — chiseled marble face with a bronze
/// rim and almost-square corners (no rounded pill). Visually
/// distinct from the gold-gradient buttons used by neighbouring
/// projects.
class MarbleButton extends StatefulWidget {
  const MarbleButton({
    super.key,
    required this.label,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool compact;

  @override
  State<MarbleButton> createState() => _MarbleButtonState();
}

class _MarbleButtonState extends State<MarbleButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null;
    return GestureDetector(
      onTapDown: disabled ? null : (_) => setState(() => _down = true),
      onTapUp: disabled
          ? null
          : (_) {
              setState(() => _down = false);
              widget.onTap?.call();
            },
      onTapCancel:
          disabled ? null : () => setState(() => _down = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        padding: EdgeInsets.symmetric(
          vertical: widget.compact ? 12 : 16,
          horizontal: 24,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _down
                ? const [Color(0xFFD8D9DE), Color(0xFFB4B5BC)]
                : const [AppColors.marble, Color(0xFFC8C9D2)],
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.goldDark,
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _down ? 0.25 : 0.55),
              blurRadius: _down ? 4 : 10,
              offset: Offset(0, _down ? 2 : 5),
            ),
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.25),
              blurRadius: 0,
              spreadRadius: 1.2,
              offset: const Offset(0, 0),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _GreekTick(color: AppColors.goldDark),
            const SizedBox(width: 12),
            Text(
              widget.label.toUpperCase(),
              style: TextStyle(
                fontFamily: AppTheme.displayFont,
                color: AppColors.nightTop,
                fontSize: widget.compact ? 15 : 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
                shadows: const [
                  Shadow(
                    color: Color(0x33000000),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _GreekTick(color: AppColors.goldDark, flip: true),
          ],
        ),
      ),
    );
  }
}

class _GreekTick extends StatelessWidget {
  const _GreekTick({required this.color, this.flip = false});
  final Color color;
  final bool flip;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: flip ? 3.14159 : 0,
      child: CustomPaint(
        size: const Size(14, 14),
        painter: _GreekTickPainter(color),
      ),
    );
  }
}

class _GreekTickPainter extends CustomPainter {
  _GreekTickPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;
    final path = Path()
      ..moveTo(0, size.height * 0.5)
      ..lineTo(size.width * 0.55, size.height * 0.5)
      ..lineTo(size.width * 0.55, size.height * 0.05)
      ..lineTo(size.width, size.height * 0.05);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _GreekTickPainter old) => old.color != color;
}

class _SkipLink extends StatefulWidget {
  const _SkipLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  State<_SkipLink> createState() => _SkipLinkState();
}

class _SkipLinkState extends State<_SkipLink> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null;
    return GestureDetector(
      onTapDown: disabled ? null : (_) => setState(() => _down = true),
      onTapUp: disabled
          ? null
          : (_) {
              setState(() => _down = false);
              widget.onTap?.call();
            },
      onTapCancel:
          disabled ? null : () => setState(() => _down = false),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 90),
        opacity: _down ? 0.45 : 0.85,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          child: Text(
            widget.label,
            style: TextStyle(
              fontFamily: AppTheme.displayFont,
              color: AppColors.marble,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.gold.withValues(alpha: 0.55),
              decorationThickness: 1.4,
              shadows: const [
                Shadow(
                  color: Colors.black87,
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
