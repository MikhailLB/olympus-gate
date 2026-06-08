import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'vault_keeper.dart';
import 'web_courier.dart';

// ============================================================
// HERALD DISPATCHER — Firebase Messaging + local notifications
// ============================================================
// Push behaviour follows the gray-flow spec:
//
//   COLD (app was killed, user taps push)
//     Firebase returns the message via getInitialMessage() at boot.
//     We persist the URL via VaultKeeper.writePendingHeraldUrl() so
//     the splash can drain it before its normal routing logic.
//
//   WARM-BG (app backgrounded, user taps push)
//     onMessageOpenedApp fires. We hand the URL to the live
//     OracleView via [onDeepLink]. We DO NOT persist it — saved
//     URLs survive launches and the spec says push URLs are
//     one-shot.
//
//   FOREGROUND (push arrives while app is visible)
//     We render a local notification (Android-only — iOS shows its
//     own banner). When the user taps that local notification we
//     hand the URL to [onDeepLink], same as the warm-bg case.
//
// OS-denied flag:
//   When the user dismisses the system permission dialog with
//   "Don't allow", Android refuses to show that dialog again.
//   We record this in VaultKeeper so the in-app promo screen
//   does not keep popping up uselessly.
// ============================================================

@pragma('vm:entry-point')
Future<void> _heraldBackgroundEntry(RemoteMessage message) async {
  // Intentionally empty — the OS shows the system notification
  // for us; the tap is replayed via onMessageOpenedApp /
  // getInitialMessage when the user resumes the app.
}

class HeraldDispatcher {
  HeraldDispatcher(this._vault);

  final VaultKeeper _vault;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  FirebaseMessaging? _fcm;
  String? _token;
  bool _booted = false;

  /// Forwarded to OracleView when a live push (warm-bg or
  /// foreground tap) carries a URL. Reset to null on dispose.
  void Function(String url)? onDeepLink;

  /// Notified when FCM rotates the token. Splash uses this to
  /// re-POST to the bridge with the freshest token.
  void Function(String token)? onTokenRotated;

  String? get currentToken => _token;

  Future<void> boot() async {
    if (_booted) return;
    try {
      await Firebase.initializeApp();
      _fcm = FirebaseMessaging.instance;

      FirebaseMessaging.onBackgroundMessage(_heraldBackgroundEntry);

      await _initLocalPlugin();

      _token = await _fcm!.getToken();

      _fcm!.onTokenRefresh.listen((fresh) {
        _token = fresh;
        onTokenRotated?.call(fresh);
      });

      FirebaseMessaging.onMessage.listen(_onForegroundPush);
      FirebaseMessaging.onMessageOpenedApp.listen(_onWarmTap);

      final cold = await _fcm!.getInitialMessage();
      if (cold != null) await _onColdTap(cold);

      _booted = true;
    } catch (e) {
      if (kDebugMode) debugPrint('[HeraldDispatcher] boot failed: $e');
    }
  }

  Future<void> _initLocalPlugin() async {
    const androidInit = AndroidInitializationSettings(
      // matches AndroidManifest.xml meta-data
      'ic_olympus_herald',
    );
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) {
        final raw = response.payload;
        if (raw == null || raw.isEmpty) return;
        try {
          final decoded = jsonDecode(raw) as Map<String, dynamic>;
          final url = decoded['url'] as String?;
          if (url != null && url.isNotEmpty) onDeepLink?.call(url);
        } catch (_) {}
      },
    );

    if (Platform.isAndroid) {
      final androidPlugin = _local.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          // must match AndroidManifest default channel id
          'olympus_herald_channel',
          'Olympus Herald',
          description: 'Messages from the Pantheon',
          importance: Importance.high,
        ),
      );
    }
  }

  /// Request the system push permission. Returns true on grant.
  /// Sets the OS-blocked flag when the user explicitly denies.
  Future<bool> askForPermission() async {
    if (_fcm == null) return false;
    final settings = await _fcm!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    final status = settings.authorizationStatus;
    final granted = status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;

    if (granted) {
      await _vault.setHeraldGranted(true);
    } else if (status == AuthorizationStatus.denied) {
      // Android will never re-prompt — record it so the in-app
      // promo screen stops showing up.
      await _vault.markHeraldOsBlocked();
    }
    return granted;
  }

  Future<void> _onForegroundPush(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    if (!Platform.isAndroid) return;

    final imageUrl = notification.android?.imageUrl;
    AndroidNotificationDetails? details;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      final bytes = await _downloadBytes(imageUrl);
      if (bytes != null) {
        details = AndroidNotificationDetails(
          'olympus_herald_channel',
          'Olympus Herald',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_olympus_herald',
          styleInformation: BigPictureStyleInformation(
            ByteArrayAndroidBitmap(bytes),
            largeIcon:
                const DrawableResourceAndroidBitmap('ic_olympus_herald'),
          ),
        );
      }
    }

    details ??= const AndroidNotificationDetails(
      'olympus_herald_channel',
      'Olympus Herald',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_olympus_herald',
    );

    final payload =
        message.data.isNotEmpty ? jsonEncode(message.data) : null;

    await _local.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(android: details),
      payload: payload,
    );
  }

  Future<void> _onColdTap(RemoteMessage message) async {
    final url = message.data['url'];
    if (url is String && url.isNotEmpty) {
      await _vault.writePendingHeraldUrl(url);
    }
  }

  void _onWarmTap(RemoteMessage message) {
    final url = message.data['url'];
    if (url is String && url.isNotEmpty) onDeepLink?.call(url);
  }

  Future<Uint8List?> _downloadBytes(String url) async {
    try {
      final reply = await olympusCourier
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (reply.statusCode == 200) return reply.bodyBytes;
    } catch (_) {}
    return null;
  }
}
