import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';

import '../env/gate_config.dart';
import '../env/tracker_keys.dart';
import 'web_courier.dart';

// ============================================================
// ATTRIBUTION BRIDGE — AppsFlyer SDK wrapper
// ============================================================
// Responsibilities:
//   1. Boot AppsFlyer and subscribe to attribution / deep-link
//      / app-open callbacks.
//   2. When the conversion data reports `Organic` on the very
//      first callback (a known SDK timing bug for paid installs),
//      wait a short cooldown and re-query the GCD endpoint to
//      get the real attribution.
//   3. Merge attribution + deep link + app-open data and append
//      the device-side fields the backend always needs (af_id,
//      bundle_id, os, store_id, locale, push_token, sender_id).
//
// The merge order is deliberate:
//   conversion data        → overwriting allowed
//   deep link payload      → only fields not yet present
//   app-open payload       → only fields not yet present
//   device-side fields     → always overwrite
//
// Backend parsing depends on this contract; do not reshape it.
// ============================================================

class AttributionBridge {
  AppsflyerSdk? _sdk;

  Map<String, dynamic>? _conversion;
  Map<String, dynamic>? _deepLink;
  Map<String, dynamic>? _appOpen;

  final Completer<Map<String, dynamic>> _conversionReady = Completer();
  final Completer<void> _deepLinkReady = Completer();

  bool _booted = false;

  /// Boot AppsFlyer with all three callbacks wired. Safe to call
  /// repeatedly — the second call is a no-op.
  Future<void> boot() async {
    if (_booted) return;
    _booted = true;

    final options = AppsFlyerOptions(
      afDevKey: GateConfig.appsFlyerDevKey,
      appId: GateConfig.iosStoreNumericId,
      showDebug: kDebugMode,
      timeToWaitForATTUserAuthorization: 10,
    );

    _sdk = AppsflyerSdk(options);

    _sdk!.onInstallConversionData((dynamic raw) async {
      final payload = _extractPayload(raw);
      if (kDebugMode) {
        debugPrint('[AttributionBridge] onInstallConversionData: $payload');
      }

      if (payload['af_status'] == 'Organic') {
        await Future.delayed(
          Duration(seconds: GateConfig.gcdRetryDelaySeconds),
        );
        final refreshed = await _refreshViaGcd();
        _conversion = refreshed ?? payload;
      } else {
        _conversion = payload;
      }

      if (!_conversionReady.isCompleted) {
        _conversionReady.complete(_conversion ?? <String, dynamic>{});
      }
    });

    _sdk!.onAppOpenAttribution((dynamic raw) {
      _appOpen = _extractPayload(raw);
    });

    _sdk!.onDeepLinking((DeepLinkResult result) {
      try {
        final click = result.deepLink?.clickEvent;
        if (click != null) {
          _deepLink = Map<String, dynamic>.from(click);
        }
      } catch (_) {}
      if (!_deepLinkReady.isCompleted) _deepLinkReady.complete();
    });

    try {
      await _sdk!.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: true,
        registerOnDeepLinkingCallback: true,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[AttributionBridge] initSdk failed: $e');
      if (!_conversionReady.isCompleted) {
        _conversionReady.complete(<String, dynamic>{});
      }
      if (!_deepLinkReady.isCompleted) _deepLinkReady.complete();
    }
  }

  Map<String, dynamic> _extractPayload(dynamic raw) {
    if (raw is Map) {
      final inner = raw['payload'];
      if (inner is Map) {
        return Map<String, dynamic>.from(inner);
      }
      return Map<String, dynamic>.from(raw);
    }
    return <String, dynamic>{};
  }

  /// Re-query the GCD endpoint to resolve the AppsFlyer
  /// "first-callback Organic" false positive. Returns null on any
  /// failure (the caller falls back to the original payload).
  Future<Map<String, dynamic>?> _refreshViaGcd() async {
    final uid = await fetchUid();
    if (uid == null || uid.isEmpty) return null;

    final appId = Platform.isIOS
        ? GateConfig.iosStoreNumericId
        : GateConfig.applicationPackage;
    final url = TrackerKeys.resolveGcdUrl(appId: appId, deviceId: uid);
    if (url.isEmpty) return null;

    try {
      final reply = await olympusCourier
          .get(
            Uri.parse(url),
            headers: {'authorization': 'Bearer ${GateConfig.appsFlyerDevKey}'},
          )
          .timeout(const Duration(seconds: 10));
      if (reply.statusCode != 200) return null;
      final decoded = jsonDecode(reply.body);
      if (decoded is Map<String, dynamic>) {
        if (kDebugMode) {
          debugPrint('[AttributionBridge] GCD refresh data: $decoded');
        }
        return decoded;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[AttributionBridge] GCD failed: $e');
    }
    return null;
  }

  /// Block until the conversion callback fires or the given budget
  /// elapses. Returns an empty map on timeout so the caller can
  /// continue without attribution data.
  Future<Map<String, dynamic>> awaitConversion({int? timeoutSeconds}) {
    final seconds =
        timeoutSeconds ?? GateConfig.firstLaunchAttributionTimeoutSeconds;
    return _conversionReady.future.timeout(
      Duration(seconds: seconds),
      onTimeout: () => <String, dynamic>{},
    );
  }

  /// Wait up to 5s for the deep-link callback. Resolves on timeout
  /// — deep links are optional and most users never get one.
  Future<void> awaitDeepLink() => _deepLinkReady.future
      .timeout(const Duration(seconds: 5), onTimeout: () {});

  /// AppsFlyer unique install ID. Returns null when the SDK is not
  /// initialised yet or the platform call throws.
  Future<String?> fetchUid() async {
    if (_sdk == null) return null;
    try {
      return await _sdk!.getAppsFlyerUID();
    } catch (_) {
      return null;
    }
  }

  /// Build the full POST body for the bridge endpoint. See the
  /// header comment for the merge order.
  Future<Map<String, dynamic>> composeBridgeBody({
    required String locale,
    String? pushToken,
  }) async {
    final body = <String, dynamic>{};

    if (_conversion != null) body.addAll(_conversion!);
    _deepLink?.forEach((k, v) => body.putIfAbsent(k, () => v));
    _appOpen?.forEach((k, v) => body.putIfAbsent(k, () => v));

    body['af_id'] = await fetchUid() ?? '';
    body['bundle_id'] = GateConfig.applicationPackage;
    body['os'] = Platform.isAndroid ? 'Android' : 'iOS';
    body['store_id'] = GateConfig.storeListingId;
    body['locale'] = locale;

    if (pushToken != null && pushToken.isNotEmpty) {
      body['push_token'] = pushToken;
    }

    final sender = GateConfig.firebaseSenderId;
    if (sender.isNotEmpty) {
      body['firebase_project_id'] = sender;
    }

    if (kDebugMode) {
      debugPrint('[AttributionBridge] composed body: ${jsonEncode(body)}');
    }
    return body;
  }
}
