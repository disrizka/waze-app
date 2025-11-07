import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class SimpleWebView extends StatefulWidget {
  final String title;
  final String initialUrl;

  const SimpleWebView({
    super.key,
    required this.title,
    required this.initialUrl,
  });

  @override
  State<SimpleWebView> createState() => _SimpleWebViewState();
}

class _SimpleWebViewState extends State<SimpleWebView> {
  late final WebViewController _controller;
  double _progress = 0;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) => setState(() => _progress = p / 100.0),
          onWebResourceError: (err) {
            // opsional: tampilkan snackbar ketika gagal
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to load: ${err.errorCode}'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl));
  }

  Future<void> _reload() async {
    try {
      await _controller.reload();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: canPop
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () async {
                  if (await _controller.canGoBack()) {
                    _controller.goBack();
                  } else {
                    Navigator.of(context).maybePop();
                  }
                },
              )
            : null,
        actions: [
          IconButton(
            tooltip: 'Reload',
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Pull-to-refresh sederhana
          RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height:
                      MediaQuery.of(context).size.height -
                      (kToolbarHeight + MediaQuery.of(context).padding.top),
                  child: WebViewWidget(controller: _controller),
                ),
              ],
            ),
          ),

          // Progress bar tipis di atas
          if (_progress < 1.0)
            Align(
              alignment: Alignment.topCenter,
              child: LinearProgressIndicator(value: _progress),
            ),
        ],
      ),
    );
  }
}
