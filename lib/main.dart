import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/app_scope.dart';
import 'core/app_theme.dart';
import 'screens/loading_screen.dart';
import 'services/game_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
  );
  final storage = await GameStorage.create();
  runApp(OlympusApp(storage: storage));
}

class OlympusApp extends StatelessWidget {
  const OlympusApp({super.key, required this.storage});

  final GameStorage storage;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      storage: storage,
      child: MaterialApp(
        title: 'Olympus Gate',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        home: const LoadingScreen(),
      ),
    );
  }
}
