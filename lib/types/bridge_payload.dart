/// Response envelope returned by the bridge endpoint.
///
/// The backend answers in one of two shapes:
///   { "ok": true,  "url": "...", "expires": 169... }   → show WebView
///   { "ok": false, "message": "organic" }              → show game
class BridgePayload {
  const BridgePayload({
    required this.ok,
    this.url,
    this.message,
    this.expires,
  });

  final bool ok;
  final String? url;
  final String? message;
  final int? expires;

  bool get hasUrl => url != null && url!.isNotEmpty;

  factory BridgePayload.fromMap(Map<String, dynamic> map) {
    return BridgePayload(
      ok: map['ok'] as bool? ?? false,
      url: map['url'] as String?,
      message: map['message'] as String?,
      expires: map['expires'] is int
          ? map['expires'] as int
          : (map['expires'] is num
              ? (map['expires'] as num).toInt()
              : null),
    );
  }

  factory BridgePayload.failure(String reason) =>
      BridgePayload(ok: false, message: reason);
}
