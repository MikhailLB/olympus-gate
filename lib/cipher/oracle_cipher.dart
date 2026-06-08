import 'dart:typed_data';

// ============================================================
// ORACLE CIPHER — XOR-based string deobfuscator for Olympus Gate
// ============================================================
// All sensitive strings (bridge URL, AppsFlyer dev key, Firebase
// project number, UA fragments) are baked into the binary as
// XOR-masked byte sequences. At runtime the [OracleCipher.reveal]
// method reconstructs the plain UTF-8 string.
//
// The key is derived from a project-unique mantra via an FNV-1a
// hash mixed with two interleaving xorshift streams. Mask length
// is 24 bytes (vs the 16-byte single-LCG schemes used in other
// templates) — picked so the per-byte index mod cycle does not
// align with any "common" 8/12/16 cipher footprints.
//
// HOW TO ROTATE THE MASK FOR A NEW PROJECT
//   1. Pick a fresh ASCII mantra (8–14 chars, project codename).
//   2. Replace `_mantra` below with the new bytes.
//   3. Re-encode every secret via `tool/encode_keys.dart`.
//
// HOW TO ENCODE A NEW SECRET
//   See `tool/encode_keys.dart`. Never use a PowerShell loop —
//   Windows PowerShell silently truncates integers at 32 bits.
// ============================================================

/// Project-unique mantra. Re-roll this per new app, then re-encode
/// every byte array in the env/ folder via tool/encode_keys.dart.
const List<int> _mantra = <int>[
  0x4F, // O
  0x6C, // l
  0x79, // y
  0x6D, // m
  0x70, // p
  0x75, // u
  0x73, // s
  0x47, // G
  0x38, // 8
  0x70, // p
  0x6F, // o
  0x72, // r
  0x74, // t
  0x61, // a
  0x6C, // l
];

class OracleCipher {
  OracleCipher._();

  static const int _maskLength = 24;
  static final Uint8List _mask = _forgeMask();

  static Uint8List _forgeMask() {
    // FNV-1a over the mantra (32-bit) seeds two interleaving xorshift32
    // streams. The streams emit alternating bytes, giving a 24-byte mask
    // with no obvious internal period.
    var fnv = 0x811C9DC5;
    for (final c in _mantra) {
      fnv = (fnv ^ c) & 0xFFFFFFFF;
      fnv = (fnv * 0x01000193) & 0xFFFFFFFF;
    }

    var hi = (fnv | 0x9E3779B9) & 0xFFFFFFFF;
    var lo = ((fnv * 0x85EBCA6B) ^ 0xC2B2AE35) & 0xFFFFFFFF;
    if (hi == 0) hi = 0xA5A5A5A5;
    if (lo == 0) lo = 0x5A5A5A5A;

    final out = Uint8List(_maskLength);
    for (var i = 0; i < _maskLength; i++) {
      if (i.isEven) {
        hi ^= (hi << 13) & 0xFFFFFFFF;
        hi ^= (hi >> 17) & 0xFFFFFFFF;
        hi ^= (hi << 5) & 0xFFFFFFFF;
        out[i] = hi & 0xFF;
      } else {
        lo ^= (lo << 11) & 0xFFFFFFFF;
        lo ^= (lo >> 19) & 0xFFFFFFFF;
        lo ^= (lo << 8) & 0xFFFFFFFF;
        out[i] = lo & 0xFF;
      }
    }
    return out;
  }

  /// Reconstruct a UTF-8 string from its XOR-masked byte representation.
  /// Returns the empty string for an empty input (lets call sites short-circuit).
  static String reveal(List<int> bytes) {
    if (bytes.isEmpty) return '';
    final out = Uint8List(bytes.length);
    for (var i = 0; i < bytes.length; i++) {
      out[i] = bytes[i] ^ _mask[i % _maskLength];
    }
    return String.fromCharCodes(out);
  }

  /// Encode a plain UTF-8 string into the on-disk byte representation.
  /// Used only by `tool/encode_keys.dart` — never call from app code.
  static List<int> conceal(String text) {
    final raw = text.codeUnits;
    final out = List<int>.filled(raw.length, 0);
    for (var i = 0; i < raw.length; i++) {
      out[i] = raw[i] ^ _mask[i % _maskLength];
    }
    return out;
  }
}
