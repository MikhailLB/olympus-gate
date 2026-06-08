import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/app_theme.dart';

/// Lightweight in-app WebView used by the native game's menu to
/// show legal pages (privacy / terms / support) without leaving
/// the app. Unlike OracleView this screen has an AppBar and is
/// portrait-only — it is invoked from the game, not the gray flow.
class ParchmentPage extends StatefulWidget {
  const ParchmentPage({
    super.key,
    required this.heading,
    required this.url,
  });

  final String heading;
  final String url;

  @override
  State<ParchmentPage> createState() => _ParchmentPageState();
}

class _ParchmentPageState extends State<ParchmentPage> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.nightBottom)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.nightBottom,
      appBar: AppBar(
        backgroundColor: AppColors.nightTop,
        iconTheme: const IconThemeData(color: AppColors.goldLight),
        title: Text(widget.heading, style: AppTheme.title(20)),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            ),
        ],
      ),
    );
  }
}
