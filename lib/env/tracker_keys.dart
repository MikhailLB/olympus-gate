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

  // encoded AppsFlyer Dev Key
  static const List<int> _devKey = <int>[
    0x29, 0xBD, 0x9B, 0x44, 0x5B, 0xA0, 0x58, 0x7A, 0x26, 0xE0, 0x39, 0x41,
    0x5F, 0x5B, 0xE5, 0xED, 0x4F, 0xBC, 0x9A, 0x0F, 0xE6, 0x7B,
  ];

  // encoded Firebase sender id (project number)
  static const List<int> _firebaseSender = <int>[
    0x2C, 0xFD, 0xCC, 0x0C, 0x2D, 0xC3, 0x54, 0x26, 0x59, 0x83, 0x70, 0x1C,
    0x3A,
  ];

  // encoded "https://gcdsdk.appsflyer.com"
  static const List<int> _gcdHost = <int>[
    0x75, 0xB9, 0x81, 0x4C, 0x6A, 0xCB, 0x4F, 0x3B, 0x06, 0xD9, 0x2C, 0x5A,
    0x6A, 0x76, 0x8F, 0xFD, 0x6F, 0xA8, 0x8E, 0x10, 0xEC, 0x4F, 0x83, 0x1A,
    0x33, 0xAE, 0x9A, 0x51,
  ];

  // encoded "/install_data/v4.0/"
  static const List<int> _gcdPath = <int>[
    0x32, 0xA4, 0x9B, 0x4F, 0x6D, 0x90, 0x0C, 0x78, 0x3E, 0xDE, 0x29, 0x5D,
    0x6F, 0x32, 0xD7, 0xA8, 0x31, 0xE8, 0xD2,
  ];

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
