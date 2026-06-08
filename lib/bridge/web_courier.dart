import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

import '../cipher/oracle_cipher.dart';

// ============================================================
// WEB COURIER — outbound HTTP client with a realistic UA
// ============================================================
// Every outbound request gets a User-Agent string that looks
// like a real mobile browser. Without this, the backend (and
// every reasonable attribution network) sees a Dart UA and
// quietly rejects the install.
//
// The Chrome / WebKit version fragments are XOR-masked so the
// binary does not advertise the exact UA string in a strings
// dump. Re-encode them via tool/encode_keys.dart after rotating
// the cipher mantra.
// ============================================================

// encoded "131.0.0.0"
const List<int> _chromeFragment = <int>[
  0x2C, 0xFE, 0xC4, 0x12, 0x29, 0xDF, 0x50, 0x3A, 0x51,
];

// encoded "605.1.15"
const List<int> _webkitFragment = <int>[
  0x2B, 0xFD, 0xC0, 0x12, 0x28, 0xDF, 0x51, 0x21,
];

class WebCourier extends http.BaseClient {
  WebCourier({http.Client? inner}) : _inner = inner ?? http.Client();

  final http.Client _inner;
  String? _ua;

  String get userAgent => _ua ?? 'Mozilla/5.0';

  /// Probe device data once at startup, build a UA, and cache it.
  /// Call this from main() before runApp() so every later request
  /// already gets the right header.
  Future<void> warmUp() async {
    final chrome = _chromeFragment.isNotEmpty
        ? OracleCipher.reveal(_chromeFragment)
        : '131.0.0.0';
    final webkit = _webkitFragment.isNotEmpty
        ? OracleCipher.reveal(_webkitFragment)
        : '605.1.15';

    try {
      final plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        final build = info.display.isNotEmpty ? info.display : info.id;
        _ua = 'Mozilla/5.0 (Linux; Android ${info.version.sdkInt}; '
            '${info.brand} ${info.model} Build/$build) '
            'AppleWebKit/537.36 (KHTML, like Gecko) '
            'Chrome/$chrome Mobile Safari/537.36';
      } else if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        final ver = info.systemVersion.replaceAll('.', '_');
        _ua = 'Mozilla/5.0 (iPhone; CPU iPhone OS $ver like Mac OS X) '
            'AppleWebKit/$webkit (KHTML, like Gecko) '
            'Version/${info.systemVersion} Mobile/15E148 Safari/$webkit';
      }
    } catch (_) {
      // Stay silent — the fallback below covers it.
    }

    _ua ??= Platform.isAndroid
        ? 'Mozilla/5.0 (Linux; Android 14; Pixel 8) '
            'AppleWebKit/537.36 (KHTML, like Gecko) '
            'Chrome/$chrome Mobile Safari/537.36'
        : 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
            'AppleWebKit/$webkit (KHTML, like Gecko) '
            'Version/17.0 Mobile/15E148 Safari/$webkit';
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.putIfAbsent('User-Agent', () => userAgent);
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

/// Process-wide singleton used by the messenger, the attribution
/// bridge GCD retry and the push image downloader.
final WebCourier olympusCourier = WebCourier();
