import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'bridge/attribution_bridge.dart';
import 'bridge/herald_dispatcher.dart';
import 'bridge/network_sentinel.dart';
import 'bridge/oracle_messenger.dart';
import 'bridge/vault_keeper.dart';
import 'bridge/web_courier.dart';
import 'core/app_scope.dart';
import 'core/app_theme.dart';
import 'portal/portal_gateway.dart';
import 'services/game_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase + AppCheck — both wrapped so a missing
  // google-services.json never aborts the launch. The push
  // service ships its own try/catch too.
  try {
    await Firebase.initializeApp();
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode
          ? AndroidProvider.debug
          : AndroidProvider.playIntegrity,
    );
  } catch (_) {}

  // Portal screens (splash, no-internet, herald promo, WebView)
  // must support both orientations. Game screens override this
  // and lock themselves to portrait inside initState.
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  await olympusCourier.warmUp();

  final vault = await VaultKeeper.open();
  final sentinel = NetworkSentinel();
  final attribution = AttributionBridge();
  final messenger = OracleMessenger(vault);
  final herald = HeraldDispatcher(vault);

  final gameStorage = await GameStorage.create();

  runApp(OlympusApp(
    gameStorage: gameStorage,
    vault: vault,
    sentinel: sentinel,
    attribution: attribution,
    messenger: messenger,
    herald: herald,
  ));
}

class OlympusApp extends StatelessWidget {
  const OlympusApp({
    super.key,
    required this.gameStorage,
    required this.vault,
    required this.sentinel,
    required this.attribution,
    required this.messenger,
    required this.herald,
  });

  final GameStorage gameStorage;
  final VaultKeeper vault;
  final NetworkSentinel sentinel;
  final AttributionBridge attribution;
  final OracleMessenger messenger;
  final HeraldDispatcher herald;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      storage: gameStorage,
      child: MaterialApp(
        title: 'Olympus Gate',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        home: PortalGateway(
          vault: vault,
          sentinel: sentinel,
          attribution: attribution,
          messenger: messenger,
          herald: herald,
        ),
      ),
    );
  }
}
