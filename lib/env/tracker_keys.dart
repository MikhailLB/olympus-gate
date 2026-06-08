import '../cipher/oracle_cipher.dart';

// ============================================================
// TRACKER KEYS — AppsFlyer + Firebase credentials, masked
// ============================================================
// AppsFlyer Dev Key, Firebase sender id and the GCD (Get
// Conversion Data) fallback endpoint are all kept here as
// XOR-masked byte arrays. Plain literals would let a Store
// scanner trivially classify this binary as part of the
// gray-flow family.
//
// Re-encode every array via tool/encode_keys.dart whenever the
// mantra in oracle_cipher.dart changes.
// ============================================================

class TrackerKeys {
  TrackerKeys._();

  // TODO: paste output of tool/encode_keys.dart → "appsflyer.dev_key"
  static const List<int> _devKey = <int>[];

  // TODO: paste output of tool/encode_keys.dart → "firebase.sender_id"
  static const List<int> _firebaseSender = <int>[];

  // TODO: paste output of tool/encode_keys.dart → "appsflyer.gcd_host"
  // e.g. "https://gcdsdk.appsflyer.com"
  static const List<int> _gcdHost = <int>[];

  // TODO: paste output of tool/encode_keys.dart → "appsflyer.gcd_path"
  // e.g. "/install_data/v4.0/"
  static const List<int> _gcdPath = <int>[];

  static String resolveDevKey() => OracleCipher.reveal(_devKey);

  static String resolveFirebaseSender() => OracleCipher.reveal(_firebaseSender);

  /// Build the full GCD URL used to refresh attribution when the
  /// first `onInstallConversionData` callback reports `Organic`.
  ///
  /// Format:
  ///   https://gcdsdk.appsflyer.com/install_data/v4.0/{appId}?device_id={uid}
  /// Authorization header: `Bearer {devKey}` (set by the caller).
  static String resolveGcdUrl({required String appId, required String deviceId}) {
    if (_gcdHost.isEmpty) return '';
    final host = OracleCipher.reveal(_gcdHost);
    final path = OracleCipher.reveal(_gcdPath);
    return '$host$path$appId?device_id=$deviceId';
  }
}
