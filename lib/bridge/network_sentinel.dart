import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Watches connectivity transitions and answers the simple
/// "do we have real internet right now?" question used by every
/// gray-flow screen.
///
/// The DNS probe matters because Android happily reports
/// `ConnectivityResult.mobile` while a captive portal is blocking
/// every actual outbound request.
class NetworkSentinel {
  NetworkSentinel({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  Stream<List<ConnectivityResult>> get onChange =>
      _connectivity.onConnectivityChanged;

  Future<bool> reachable() async {
    final transports = await _connectivity.checkConnectivity();
    final anyLink = transports.any((t) => t != ConnectivityResult.none);
    if (!anyLink) return false;

    try {
      final lookup = await InternetAddress.lookup('cloudflare.com')
          .timeout(const Duration(seconds: 3));
      return lookup.isNotEmpty && lookup.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
