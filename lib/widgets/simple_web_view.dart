// lib/widgets/simple_web_view.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// WebView (webview_flutter v4+)
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

class SimpleWebView extends StatefulWidget {
  const SimpleWebView({
    super.key,
    required this.initialUrl,
    this.title,
    this.userAgent,
    this.headers = const <String, String>{},
    this.backgroundColor = Colors.white,
  });

  final String initialUrl;
  final String? title;
  final String? userAgent;
  final Map<String, String> headers;
  final Color backgroundColor;

  @override
  State<SimpleWebView> createState() => _SimpleWebViewState();
}

class _SimpleWebViewState extends State<SimpleWebView> {
  late final WebViewController _controller;
  double _progress = 0;

  void _setProgress(double value) {
    if (!mounted) return;
    setState(() => _progress = value);
  }

  @override
  void initState() {
    super.initState();

    // ===== Platform-specific creation params =====
    final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      // iOS
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      // Android
      params = const PlatformWebViewControllerCreationParams();
    }

    final controller = WebViewController.fromPlatformCreationParams(params);

    // ===== Android tuning (4.10.1 safe) =====
    if (controller.platform is AndroidWebViewController) {
      final androidCtrl = controller.platform as AndroidWebViewController;
      // Mulai 4.10.1: tetap ada, aman dipakai
      androidCtrl.setMediaPlaybackRequiresUserGesture(false);
      // JANGAN panggil setOverScrollMode di versi ini (enum-nya tidak diekspos).
    }

    // ===== iOS tuning =====
    if (controller.platform is WebKitWebViewController) {
      final iosCtrl = controller.platform as WebKitWebViewController;
      iosCtrl.setInspectable(false);
    }

    // ===== Common settings =====
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(widget.backgroundColor)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) => _setProgress(p / 100),
          onPageStarted: (_) => _setProgress(0.05),
          onPageFinished: (_) => _setProgress(0),
          onNavigationRequest: (req) {
            final uri = Uri.tryParse(req.url);
            // Biarkan http/https di dalam webview
            if (uri != null &&
                (uri.scheme == 'http' || uri.scheme == 'https')) {
              return NavigationDecision.navigate;
            }
            // Selain itu buka eksternal (mailto, tel, app link)
            _launchExternal(req.url);
            return NavigationDecision.prevent;
          },
          onWebResourceError: (err) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Failed to load: ${err.description}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          },
        ),
      );

    if (widget.userAgent != null && widget.userAgent!.isNotEmpty) {
      controller.setUserAgent(widget.userAgent!);
    }

    controller.loadRequest(
      Uri.parse(widget.initialUrl),
      headers: widget.headers,
    );

    _controller = controller;
  }

  Future<void> _launchExternal(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot open external link.')),
      );
    }
  }

  Future<void> _reload() async {
    try {
      await _controller.reload();
    } catch (_) {}
  }

  Future<void> _openInBrowser() async {
    final current = await _controller.currentUrl();
    if (current == null) return;
    _launchExternal(current);
  }

  Future<void> _goBackOrPop() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
    } else if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Untuk tampilan penuh: WebView diletakkan di Expanded dalam Column.
    return WillPopScope(
      onWillPop: () async {
        if (await _controller.canGoBack()) {
          await _controller.goBack();
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: widget.backgroundColor,
        appBar: AppBar(
          elevation: 0,
          title: Text(widget.title ?? ''),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: _goBackOrPop,
          ),
          actions: [
            IconButton(
              tooltip: 'Reload',
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: 'Open in browser',
              onPressed: _openInBrowser,
              icon: const Icon(Icons.open_in_browser),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (_progress > 0 && _progress < 1)
                LinearProgressIndicator(value: _progress, minHeight: 2),
              Expanded(child: WebViewWidget(controller: _controller)),
            ],
          ),
        ),
        resizeToAvoidBottomInset: true,
      ),
    );
  }
}
