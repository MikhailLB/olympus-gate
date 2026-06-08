import 'dart:convert';

import '../env/gate_config.dart';
import '../types/bridge_payload.dart';
import 'vault_keeper.dart';
import 'web_courier.dart';

// ============================================================
// ORACLE MESSENGER — POST attribution body to the bridge endpoint
// ============================================================
// Behaviour mirrors the gray-flow spec:
//   * Plain HTTP POST, JSON body, 15s timeout
//   * 200 with ok=true and a non-empty url → store url+expiry in
//     VaultKeeper (the saved URL survives across launches and is
//     used as a fallback when the bridge later fails)
//   * 200 with ok=false                    → return as-is
//   * non-200 / network error              → wrap as failure;
//     caller decides whether to fall back to the saved URL
//
// The messenger never short-circuits to a hard-coded URL.
// ============================================================

class OracleMessenger {
  OracleMessenger(this._vault);

  final VaultKeeper _vault;

  Future<BridgePayload> dispatch(Map<String, dynamic> body) async {
    final endpoint = GateConfig.bridgeEndpoint;
    if (endpoint.isEmpty) {
      return BridgePayload.failure('endpoint_missing');
    }

    try {
      final reply = await olympusCourier
          .post(
            Uri.parse(endpoint),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(Duration(seconds: GateConfig.bridgeTimeoutSeconds));

      if (reply.statusCode != 200) {
        return BridgePayload.failure('http_${reply.statusCode}');
      }

      final decoded = jsonDecode(reply.body) as Map<String, dynamic>;
      final payload = BridgePayload.fromMap(decoded);

      if (payload.ok && payload.hasUrl) {
        await _vault.writeBridgeUrl(payload.url!);
        if (payload.expires != null) {
          await _vault.writeBridgeExpiry(payload.expires!);
        }
      }
      return payload;
    } catch (e) {
      return BridgePayload.failure(e.toString());
    }
  }

  /// Convenience helper for screens that just want the cached URL
  /// without dealing with expiry — expired URLs are still returned
  /// because they are preferable to a blank screen.
  Future<String?> cachedUrl() => _vault.readBridgeUrl();
}
