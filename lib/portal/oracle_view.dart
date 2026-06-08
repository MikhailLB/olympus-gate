import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../bridge/herald_dispatcher.dart';
import '../bridge/network_sentinel.dart';
import '../bridge/vault_keeper.dart';
import '../bridge/web_courier.dart';
import 'offline_olympus.dart';

// ============================================================
// ORACLE VIEW — full-screen WebView shell (gray mode)
// ============================================================
// Hosts the URL the bridge handed us in an immersive, both-
// orientation WebView. The back button never exits the app —
// it walks back through the WebView history instead.
//
// Connectivity is observed live: as soon as Android reports
// "no transports", we jump straight to OfflineOlympus without
// waiting for a DNS round-trip (kept short to match the spec).
//
// Two JS injections run on every successful page load:
//   1. _injectSafeAreaWipe — strips iOS-style safe-area CSS
//      that some affiliate pages embed unconditionally
//   2. _injectKeyboardHelper — scrolls focused inputs into view
//      above the keyboard, using behavior:'auto' (NOT smooth)
// ============================================================

/// Pre-warms the WebView engine. Called via deferred-import in
/// PortalGateway so the engine binary is not paid by organic
/// users who never see this screen.
Future<void> primeOracleEngine() async {
  // Touching the static property is enough to load the platform
  // implementation eagerly.
  WebViewPlatform.instance;
}

class OracleView extends StatefulWidget {
  const OracleView({
    super.key,
    required this.url,
    required this.vault,
    required this.herald,
    required this.sentinel,
  });

  final String url;
  final VaultKeeper vault;
  final HeraldDispatcher herald;
  final NetworkSentinel sentinel;

  @override
  State<OracleView> createState() => _OracleViewState();
}

class _OracleViewState extends State<OracleView>
    with WidgetsBindingObserver {
  late final WebViewController _controller;
  bool _busy = true;
  bool _bailingOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _connSub;

  String? _lastMainFrame;
  int _redirectRetries = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _applyImmersive();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(olympusCourier.userAgent)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _busy = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _busy = false);
          _redirectRetries = 0;
          _injectSafeAreaWipe();
          _injectKeyboardHelper();
        },
        onWebResourceError: (error) {
          if (error.isForMainFrame != true) return;
          final desc = error.description.toLowerCase();
          final loopy = desc.contains('too_many_redirects') ||
              desc.contains('too many redirects') ||
              error.errorCode == -1007 ||
              error.errorCode == -9;
          if (loopy &&
              _lastMainFrame != null &&
              _redirectRetries < 3) {
            _redirectRetries++;
            _controller.loadRequest(Uri.parse(_lastMainFrame!));
            return;
          }
          _maybeShowOffline();
        },
        onHttpError: (_) {},
        onNavigationRequest: (request) {
          final uri = Uri.tryParse(request.url);
          if (uri == null) return NavigationDecision.prevent;
          const allowed = {'http', 'https', 'about', 'data', 'blob'};
          if (allowed.contains(uri.scheme)) {
            if (request.isMainFrame) _lastMainFrame = request.url;
            return NavigationDecision.navigate;
          }
          unawaited(_launchOutside(uri));
          return NavigationDecision.prevent;
        },
      ))
      ..enableZoom(false);

    _wireUpAndroidSpecifics();
    _controller.loadRequest(Uri.parse(widget.url));

    widget.herald.onDeepLink = (url) {
      if (!mounted) return;
      _controller.loadRequest(Uri.parse(url));
    };

    _connSub = widget.sentinel.onChange.listen((transports) {
      if (transports.every((t) => t == ConnectivityResult.none)) {
        _maybeShowOffline(skipProbe: true);
      }
    });
  }

  void _applyImmersive() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _applyImmersive();
  }

  void _wireUpAndroidSpecifics() {
    if (!Platform.isAndroid) return;
    final platform = _controller.platform;
    if (platform is! AndroidWebViewController) return;

    platform.setMediaPlaybackRequiresUserGesture(false);
    platform.setOnShowFileSelector(_handleFilePick);

    final cookies = AndroidWebViewCookieManager(
      AndroidWebViewCookieManagerCreationParams
          .fromPlatformWebViewCookieManagerCreationParams(
        const PlatformWebViewCookieManagerCreationParams(),
      ),
    );
    cookies.setAcceptThirdPartyCookies(platform, true);
  }

  Future<List<String>> _handleFilePick(FileSelectorParams params) async {
    try {
      final res = await FilePicker.platform.pickFiles(
        allowMultiple: params.mode == FileSelectorMode.openMultiple,
        type: FileType.any,
      );
      if (res != null && res.files.isNotEmpty) {
        return res.files
            .where((f) => f.path != null)
            .map((f) => Uri.file(f.path!).toString())
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  Future<void> _launchOutside(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _maybeShowOffline({bool skipProbe = false}) async {
    if (_bailingOffline) return;
    if (!skipProbe) {
      final online = await widget.sentinel.reachable();
      if (online || !mounted) return;
    }
    if (!mounted) return;
    _bailingOffline = true;
    final last = await _controller.currentUrl() ?? widget.url;
    if (!mounted) return;
    final navigator = Navigator.of(context);

    navigator.pushReplacement(
      MaterialPageRoute(
        builder: (_) => OfflineOlympus(
          rebuildOnRetry: (_) => OracleView(
            url: last,
            vault: widget.vault,
            herald: widget.herald,
            sentinel: widget.sentinel,
          ),
        ),
      ),
    );
  }

  void _injectKeyboardHelper() {
    _controller.runJavaScript('''
(function() {
  if (window.__olKbHelper) return;
  window.__olKbHelper = true;

  function isEditable(el) {
    if (!el) return false;
    return el.tagName === 'INPUT' || el.tagName === 'TEXTAREA' || el.isContentEditable;
  }

  function liftFocus() {
    var el = document.activeElement;
    if (!isEditable(el)) return;
    var vp = window.visualViewport;
    if (vp) {
      var rect = el.getBoundingClientRect();
      var bottom = vp.offsetTop + vp.height;
      if (rect.bottom > bottom - 20 || rect.top < vp.offsetTop) {
        el.scrollIntoView({ behavior: 'auto', block: 'nearest' });
      }
    } else {
      el.scrollIntoView({ behavior: 'auto', block: 'nearest' });
    }
  }

  document.addEventListener('focusin', function(e) {
    if (isEditable(e.target)) setTimeout(liftFocus, 350);
  });

  if (window.visualViewport) {
    var prev = window.visualViewport.height;
    window.visualViewport.addEventListener('resize', function() {
      var h = window.visualViewport.height;
      if (h < prev) setTimeout(liftFocus, 120);
      prev = h;
    });
  }
})();
''');
  }

  void _injectSafeAreaWipe() {
    _controller.runJavaScript(r'''
(function() {
  if (window.__olSaWipe) return;
  window.__olSaWipe = true;

  var TAG = '__olympus_safe_area';
  var RULES =
    ':root{' +
      '--safe-area-inset-top:0px!important;' +
      '--safe-area-inset-right:0px!important;' +
      '--safe-area-inset-bottom:0px!important;' +
      '--safe-area-inset-left:0px!important;' +
      '--sat:0px!important;--sar:0px!important;' +
      '--sab:0px!important;--sal:0px!important;' +
      '--safe-top:0px!important;--safe-right:0px!important;' +
      '--safe-bottom:0px!important;--safe-left:0px!important;' +
    '}' +
    'html,body,#__nuxt,#__layout,#app,#root,' +
    '.gameview-mobile-header{' +
      'padding-top:0!important;' +
      'padding-left:0!important;' +
      'padding-right:0!important;' +
      'margin-top:0!important;' +
    '}';

  function keyboardOpen() {
    if (!window.visualViewport) return false;
    return window.visualViewport.height < window.innerHeight * 0.75;
  }

  function bake() {
    if (keyboardOpen()) return;
    var head = document.head || document.documentElement;
    if (!head) return;
    var meta = document.querySelector('meta[name="viewport"]');
    if (meta && !/viewport-fit\s*=\s*contain/i.test(meta.getAttribute('content') || '')) {
      var c = (meta.getAttribute('content') || '')
        .replace(/,?\s*viewport-fit\s*=\s*\w+/ig, '').trim();
      meta.setAttribute('content', c + (c ? ', ' : '') + 'viewport-fit=contain');
    }
    var style = document.getElementById(TAG);
    if (!style) {
      style = document.createElement('style');
      style.id = TAG;
      head.appendChild(style);
    }
    if (style.textContent !== RULES) style.textContent = RULES;
    if (head.lastElementChild !== style) head.appendChild(style);
  }

  bake();
  ['pushState', 'replaceState'].forEach(function(fn) {
    var orig = history[fn];
    history[fn] = function() {
      var r = orig.apply(this, arguments);
      setTimeout(bake, 80);
      setTimeout(bake, 400);
      return r;
    };
  });
  window.addEventListener('popstate', function() { setTimeout(bake, 80); });
  setInterval(bake, 2500);
})();
''');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connSub?.cancel();
    widget.herald.onDeepLink = null;
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  Future<bool> _backToPrevious() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _backToPrevious();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).orientation ==
                        Orientation.landscape
                    ? 0
                    : MediaQuery.of(context).viewPadding.top,
                left: MediaQuery.of(context).orientation ==
                        Orientation.landscape
                    ? MediaQuery.of(context).viewPadding.left
                    : 0,
                right: MediaQuery.of(context).orientation ==
                        Orientation.landscape
                    ? MediaQuery.of(context).viewPadding.right
                    : 0,
              ),
              child: WebViewWidget(controller: _controller),
            ),
            if (_busy)
              Container(
                color: Colors.black.withValues(alpha: 0.45),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFFE9B949),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
