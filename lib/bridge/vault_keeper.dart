import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../types/gate_state.dart';

// ============================================================
// VAULT KEEPER — persistence layer for gray-flow state
// ============================================================
// Two backing stores:
//   * SharedPreferences for non-sensitive flags / counters
//   * FlutterSecureStorage (Keystore-backed) for URLs that
//     reveal the partner network — must not show up in a
//     plain xml dump of the app's data folder.
//
// Keys use opaque short identifiers (`vk_*`) so a casual data
// dump does not advertise their purpose at a glance.
// ============================================================

class VaultKeeper {
  VaultKeeper._(this._prefs, this._secure);

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  static const _kGateState = 'vk_gate_state';
  static const _kBridgeUrl = 'vk_bridge_url';
  static const _kBridgeExpiry = 'vk_bridge_expiry';
  static const _kHeraldGranted = 'vk_herald_granted';
  static const _kHeraldOsBlocked = 'vk_herald_os_blocked';
  static const _kHeraldRetryAt = 'vk_herald_retry_at';
  static const _kHeraldDeepUrl = 'vk_herald_deep_url';

  static Future<VaultKeeper> open() async {
    final prefs = await SharedPreferences.getInstance();
    const secure = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );
    return VaultKeeper._(prefs, secure);
  }

  // ── gate state ──────────────────────────────────────────────

  GateState readGateState() => GateState.parse(_prefs.getString(_kGateState));

  Future<void> writeGateState(GateState state) =>
      _prefs.setString(_kGateState, state.token);

  // ── bridge url (secure) ─────────────────────────────────────

  Future<String?> readBridgeUrl() => _secure.read(key: _kBridgeUrl);

  Future<void> writeBridgeUrl(String url) =>
      _secure.write(key: _kBridgeUrl, value: url);

  int? readBridgeExpiry() => _prefs.getInt(_kBridgeExpiry);

  Future<void> writeBridgeExpiry(int unixSeconds) =>
      _prefs.setInt(_kBridgeExpiry, unixSeconds);

  bool isBridgeUrlExpired() {
    final exp = readBridgeExpiry();
    if (exp == null) return true;
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return nowSec >= exp;
  }

  // ── push permission state ───────────────────────────────────

  bool isHeraldGranted() => _prefs.getBool(_kHeraldGranted) ?? false;

  Future<void> setHeraldGranted(bool value) =>
      _prefs.setBool(_kHeraldGranted, value);

  /// True if the system permission dialog has already been denied —
  /// Android never re-shows the prompt in that case, so we must not
  /// keep reopening the in-app promo screen either.
  bool isHeraldOsBlocked() => _prefs.getBool(_kHeraldOsBlocked) ?? false;

  Future<void> markHeraldOsBlocked() =>
      _prefs.setBool(_kHeraldOsBlocked, true);

  int? readHeraldRetryAt() => _prefs.getInt(_kHeraldRetryAt);

  Future<void> writeHeraldRetryAt(int unixSeconds) =>
      _prefs.setInt(_kHeraldRetryAt, unixSeconds);

  bool shouldOpenHeraldConsentPage() {
    if (isHeraldGranted()) return false;
    if (isHeraldOsBlocked()) return false;
    final retryAt = readHeraldRetryAt();
    if (retryAt == null) return true;
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return nowSec >= retryAt;
  }

  // ── one-shot push URL captured during a cold-start tap ──────

  Future<String?> readPendingHeraldUrl() =>
      _secure.read(key: _kHeraldDeepUrl);

  Future<void> writePendingHeraldUrl(String? url) async {
    if (url == null) {
      await _secure.delete(key: _kHeraldDeepUrl);
    } else {
      await _secure.write(key: _kHeraldDeepUrl, value: url);
    }
  }

  /// Atomically read-and-clear the pending push URL. Use this on
  /// splash to ensure we never re-open the same push URL twice.
  Future<String?> drainPendingHeraldUrl() async {
    final url = await readPendingHeraldUrl();
    if (url != null) {
      await _secure.delete(key: _kHeraldDeepUrl);
    }
    return url;
  }
}
