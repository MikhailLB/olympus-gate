/// High-level routing state remembered between launches.
///
/// `awaiting`  — first launch, no decision yet
/// `webPortal` — backend granted a content URL, show the WebView shell
/// `arcade`    — backend denied (or first launch had no network), keep
///               showing the native game from now on, forever
enum GateState {
  webPortal,
  arcade,
  awaiting;

  static GateState parse(String? raw) {
    switch (raw) {
      case 'web_portal':
        return GateState.webPortal;
      case 'arcade':
        return GateState.arcade;
      default:
        return GateState.awaiting;
    }
  }

  String get token {
    switch (this) {
      case GateState.webPortal:
        return 'web_portal';
      case GateState.arcade:
        return 'arcade';
      case GateState.awaiting:
        return 'awaiting';
    }
  }
}
