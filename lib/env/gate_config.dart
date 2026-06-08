import 'bridge_uri.dart';
import 'lore_links.dart';
import 'tracker_keys.dart';

// ============================================================
// GATE CONFIG — single source of truth for app-level constants
// ============================================================
// All other modules consume their config through this façade so
// the per-project knobs live in exactly one place. Numerics and
// public strings live here; secrets are pulled lazily through
// the masked accessors in tracker_keys.dart and bridge_uri.dart.
//
// SETUP CHECKLIST FOR A NEW APP
//   1. Update `applicationPackage` to match android/applicationId
//   2. Update `storeListingId` (same as applicationPackage on Android)
//   3. Update `displayName` so notification titles read right
//   4. Encode the bridge endpoint and AppsFlyer/Firebase keys
//      (see tool/encode_keys.dart) and paste the byte arrays into
//      bridge_uri.dart + tracker_keys.dart
// ============================================================

class GateConfig {
  GateConfig._();

  /// Android applicationId / iOS bundle identifier.
  static const String applicationPackage = 'com.olygames.olympusgates';

  /// Store listing identifier — equals applicationPackage on Android.
  static const String storeListingId = 'com.olygames.olympusgates';

  /// Display name shown in notification banners and the app drawer.
  static const String displayName = 'Olympus Gate';

  /// Numeric App Store ID (iOS only). Empty for Android-only builds.
  static const String iosStoreNumericId = '';

  /// Full bridge endpoint, decoded on first access.
  static String get bridgeEndpoint => BridgeUri.resolve();

  /// Decoded AppsFlyer Dev Key (or empty when not yet provisioned).
  static String get appsFlyerDevKey => TrackerKeys.resolveDevKey();

  /// Decoded Firebase sender id (also called "project number").
  static String get firebaseSenderId => TrackerKeys.resolveFirebaseSender();

  /// User-facing legal URLs.
  static String get privacyPolicyUrl => LoreLinks.privacy;
  static String get termsUrl => LoreLinks.terms;
  static String get supportUrl => LoreLinks.support;

  /// 3-day cooldown between successive notification permission prompts.
  /// Required by the gray-flow spec — never reduce below 3×24×3600.
  static const int notificationCooldownSeconds = 3 * 24 * 3600;

  /// Time we wait before retrying attribution through the GCD endpoint
  /// when the first onInstallConversionData callback reports Organic.
  static const int gcdRetryDelaySeconds = 5;

  /// Bridge request timeout, in seconds.
  static const int bridgeTimeoutSeconds = 15;

  /// AppsFlyer attribution wait budget on first launch.
  static const int firstLaunchAttributionTimeoutSeconds = 30;

  /// AppsFlyer attribution wait budget for returning launches.
  static const int returningAttributionTimeoutSeconds = 10;

  /// Notification channel id — must match the value in AndroidManifest.xml.
  static const String pushChannelId = 'olympus_herald_channel';

  /// Notification icon — must match a drawable in res/drawable/.
  static const String pushIconResource = '@drawable/ic_olympus_herald';
}
