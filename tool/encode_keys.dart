// ignore_for_file: avoid_print, avoid_relative_lib_imports

// ============================================================
// encode_keys.dart — generate XOR-masked byte arrays for the
// gray-flow secret bag (bridge URL, AppsFlyer key, GCD path,
// Firebase sender id, UA fragments).
//
// HOW TO USE
//   1. Edit the `secrets` map below — replace every TODO with
//      the real plaintext value you want to bake into the APK.
//   2. Run from the project root:
//
//        dart run tool/encode_keys.dart
//
//   3. Paste each printed array into the corresponding `const`
//      slot in lib/env/* and lib/bridge/web_courier.dart.
//
// ⚠️ NEVER encode these values with a PowerShell `foreach` loop:
//    Windows PowerShell silently overflows past 32-bit integers
//    and the resulting bytes will be wrong (you will see
//    "FormatException: Invalid HTTP header field value" or 401s
//    from the bridge). Always use this Dart helper.
// ============================================================

import '../lib/cipher/oracle_cipher.dart';

void main() {
  final secrets = <String, String>{
    // Bridge endpoint — split host vs path so neither piece alone
    // looks like a URL inside the binary.
    'bridge.scheme_host': 'https://example.com', // TODO
    'bridge.path': '/v1/decide',                  // TODO

    // AppsFlyer Dev Key from the AppsFlyer dashboard.
    'appsflyer.dev_key': 'YOUR_APPSFLYER_DEV_KEY', // TODO

    // GCD (Get Conversion Data) endpoint — host + path slices.
    'appsflyer.gcd_host': 'https://gcdsdk.appsflyer.com',
    'appsflyer.gcd_path': '/install_data/v4.0/',

    // Firebase project number (NOT project id) from Firebase
    // Console → Project Settings → General.
    'firebase.sender_id': '000000000000', // TODO

    // User-Agent version fragments — match a recent stable
    // Chrome / WebKit release.
    'ua.chrome_full': '131.0.0.0',
    'ua.webkit_full': '605.1.15',
  };

  for (final entry in secrets.entries) {
    final encoded = OracleCipher.conceal(entry.value);
    final formatted = encoded
        .map((b) => '0x${b.toRadixString(16).padLeft(2, '0').toUpperCase()}')
        .toList();
    final pretty = _wrap(formatted);
    print('// ${entry.key}  (plaintext length ${entry.value.length})');
    print('const List<int> _${_camel(entry.key)} = <int>[');
    print(pretty);
    print('];');
    print('');
  }
}

String _camel(String key) =>
    key.split('.').map((part) => part.replaceAll('_', '')).join('_');

String _wrap(List<String> tokens) {
  final buf = StringBuffer();
  const indent = '  ';
  var lineLength = indent.length;
  buf.write(indent);
  for (var i = 0; i < tokens.length; i++) {
    final token = '${tokens[i]},';
    if (lineLength + token.length + 1 > 78 && i != 0) {
      buf.writeln();
      buf.write(indent);
      lineLength = indent.length;
    }
    buf.write(token);
    buf.write(' ');
    lineLength += token.length + 1;
  }
  return buf.toString().trimRight();
}
