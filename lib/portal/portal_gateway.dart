import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../bridge/attribution_bridge.dart';
import '../bridge/herald_dispatcher.dart';
import '../bridge/network_sentinel.dart';
import '../bridge/oracle_messenger.dart';
import '../bridge/vault_keeper.dart';
import '../core/app_assets.dart';
import '../core/app_theme.dart';
import '../screens/loading_screen.dart';
import '../types/gate_state.dart';
import 'herald_consent_page.dart';
import 'offline_olympus.dart';
import 'oracle_view.dart' deferred as oracle;

// ============================================================
// PORTAL GATEWAY — first-screen routing brain
// ============================================================
// Drives the gray/white decision tree exactly once per launch:
//
//   GateState.awaiting (first launch)
//     ► no internet            → OfflineOlympus (retry → back here)
//     ► boot AttributionBridge, wait for conversion + deep link
//     ► POST attribution body to the bridge
//       · ok + url → state=webPortal → herald consent or OracleView
//       · else     → state=arcade   → native game (LoadingScreen)
//
//   GateState.webPortal (returning user, was in WebView)
//     ► no internet            → OfflineOlympus
//     ► pending push URL       → OracleView(pendingUrl)   [priority]
//     ► refresh attribution (10 s budget)
//     ► POST → reply.url → OracleView(reply.url)
//     ► reply failed but cached URL exists → OracleView(cached)
//     ► nothing usable → OfflineOlympus
//
//   GateState.arcade (returning user, was in game)
//     ► straight to LoadingScreen — never call the bridge again
// ============================================================

class PortalGateway extends StatefulWidget {
  const PortalGateway({
    super.key,
    required this.vault,
    required this.sentinel,
    required this.attribution,
    required this.messenger,
    required this.herald,
  });

  final VaultKeeper vault;
  final NetworkSentinel sentinel;
  final AttributionBridge attribution;
  final OracleMessenger messenger;
  final HeraldDispatcher herald;

  @override
  State<PortalGateway> createState() => _PortalGatewayState();
}

class _PortalGatewayState extends State<PortalGateway> {
  double _progress = 0;
  bool _routed = false;

  @override
  void initState() {
    super.initState();
    _allowAllOrientations();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    WidgetsBinding.instance.addPostFrameCallback((_) => _walkTheTree());
  }

  Future<void> _allowAllOrientations() async {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  void _setProgress(double v) {
    if (!mounted) return;
    setState(() => _progress = v.clamp(0.0, 1.0));
  }

  Future<void> _walkTheTree() async {
    widget.herald.onTokenRotated = _resendBridgeOnTokenChange;
    await widget.herald.boot();
    _setProgress(0.15);

    final state = widget.vault.readGateState();
    switch (state) {
      case GateState.webPortal:
        await _resumeWebPortalUser();
        break;
      case GateState.arcade:
        await _resumeArcadeUser();
        break;
      case GateState.awaiting:
        await _bootstrapFirstLaunch();
        break;
    }
  }

  Future<void> _bootstrapFirstLaunch() async {
    final online = await widget.sentinel.reachable();
    if (!online) {
      _openOfflineScreen();
      return;
    }
    _setProgress(0.35);

    await widget.attribution.boot();
    await Future.wait([
      widget.attribution.awaitConversion(),
      widget.attribution.awaitDeepLink(),
    ]);
    _setProgress(0.7);

    final body = await widget.attribution.composeBridgeBody(
      locale: _locale(),
      pushToken: widget.herald.currentToken,
    );
    final reply = await widget.messenger.dispatch(body);
    _setProgress(0.9);

    if (reply.ok && reply.hasUrl) {
      await widget.vault.writeGateState(GateState.webPortal);
      await _settleAndOpenContent(reply.url!);
    } else {
      await widget.vault.writeGateState(GateState.arcade);
      await _settleAndOpenGame();
    }
  }

  Future<void> _resumeWebPortalUser() async {
    final online = await widget.sentinel.reachable();
    if (!online) {
      _openOfflineScreen();
      return;
    }
    _setProgress(0.4);

    final pushUrl = await widget.vault.drainPendingHeraldUrl();
    if (pushUrl != null && pushUrl.isNotEmpty) {
      _setProgress(1.0);
      await Future.delayed(const Duration(milliseconds: 250));
      await _openContentDirect(pushUrl);
      return;
    }

    final cached = await widget.vault.readBridgeUrl();

    await widget.attribution.boot();
    await Future.wait([
      widget.attribution.awaitConversion(
          timeoutSeconds: 10),
      widget.attribution.awaitDeepLink(),
    ]);

    final body = await widget.attribution.composeBridgeBody(
      locale: _locale(),
      pushToken: widget.herald.currentToken,
    );
    final reply = await widget.messenger.dispatch(body);
    _setProgress(1.0);
    await Future.delayed(const Duration(milliseconds: 300));

    if (reply.ok && reply.hasUrl) {
      await _settleAndOpenContent(reply.url!);
      return;
    }
    if (cached != null && cached.isNotEmpty) {
      await _openContentDirect(cached);
      return;
    }
    _openOfflineScreen();
  }

  Future<void> _resumeArcadeUser() async {
    _setProgress(0.5);
    await Future.delayed(const Duration(milliseconds: 300));
    _setProgress(1.0);
    await Future.delayed(const Duration(milliseconds: 250));
    _openGameDirect();
  }

  String _locale() => Platform.localeName.replaceAll('-', '_');

  Future<void> _resendBridgeOnTokenChange(String _) async {
    try {
      final body = await widget.attribution.composeBridgeBody(
        locale: _locale(),
        pushToken: widget.herald.currentToken,
      );
      await widget.messenger.dispatch(body);
    } catch (_) {}
  }

  Future<void> _settleAndOpenContent(String url) async {
    _setProgress(1.0);
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    await _openContentDirect(url);
  }

  Future<void> _settleAndOpenGame() async {
    _setProgress(1.0);
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    _openGameDirect();
  }

  Future<void> _openContentDirect(String url) async {
    if (_routed) return;
    _routed = true;
    await oracle.loadLibrary();
    if (!mounted) return;

    if (widget.vault.shouldOpenHeraldConsentPage()) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HeraldConsentPage(
            vault: widget.vault,
            herald: widget.herald,
            sentinel: widget.sentinel,
            destinationUrl: url,
          ),
        ),
      );
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => oracle.OracleView(
          url: url,
          vault: widget.vault,
          herald: widget.herald,
          sentinel: widget.sentinel,
        ),
      ),
    );
  }

  void _openGameDirect() {
    if (_routed) return;
    _routed = true;
    // White-part (the actual game) is portrait-only.
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoadingScreen()),
    );
  }

  void _openOfflineScreen() {
    if (_routed) return;
    _routed = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => OfflineOlympus(
          rebuildOnRetry: (_) => PortalGateway(
            vault: widget.vault,
            sentinel: widget.sentinel,
            attribution: widget.attribution,
            messenger: widget.messenger,
            herald: widget.herald,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    widget.herald.onTokenRotated = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final art = isLandscape
        ? AppAssets.loadingHorizontal
        : AppAssets.loadingVertical;

    return Scaffold(
      backgroundColor: AppColors.nightBottom,
      body: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(art, fit: BoxFit.cover),
            // Bottom darken so the progress bar stays readable
            // regardless of the underlying art.
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
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 48,
                  left: isLandscape ? 120 : 40,
                  right: isLandscape ? 120 : 40,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _GatewayProgressBar(value: _progress),
                    const SizedBox(height: 14),
                    Text(
                      'Opening the gate…  ${(_progress * 100).round()}%',
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

class _GatewayProgressBar extends StatelessWidget {
  const _GatewayProgressBar({required this.value});
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
