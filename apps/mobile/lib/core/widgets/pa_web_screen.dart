import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme.dart';
import 'pa_widgets.dart';

/// Full-screen in-app WebView with the standard PulangAman AppBar.
///
/// Used for Privasi / Syarat & Ketentuan pages so users stay inside the
/// app instead of being sent to a Chrome Custom Tab.
class PaWebScreen extends StatefulWidget {
  const PaWebScreen({super.key, required this.title, required this.url});

  final String title;
  final String url;

  @override
  State<PaWebScreen> createState() => _PaWebScreenState();
}

class _PaWebScreenState extends State<PaWebScreen> {
  InAppWebViewController? _controller;
  double _progress = 0;
  bool _failed = false;

  @override
  Widget build(BuildContext context) {
    final refresh = visualRefreshOf(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final controller = _controller;
        if (controller != null && await controller.canGoBack()) {
          await controller.goBack();
          return;
        }
        if (mounted) navigator.pop();
      },
      child: Scaffold(
        backgroundColor:
            refresh ? VisualRefreshColors.background : Colors.white,
        appBar: AppBar(
          title: Text(
            widget.title,
            style: refresh
                ? GoogleFonts.fraunces(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.4,
                    color: VisualRefreshColors.textPrimary,
                  )
                : null,
          ),
          backgroundColor:
              refresh ? VisualRefreshColors.background : null,
          leadingWidth: PaScreenHeader.appBarLeadingWidth,
          titleSpacing: PaScreenHeader.appBarTitleSpacing,
          leading: paAppBarLeading(
            context,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        body: Column(
          children: [
            if (_progress < 1)
              LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                minHeight: 2,
                color: refresh
                    ? VisualRefreshColors.accent
                    : AppColors.teal,
                backgroundColor: Colors.transparent,
              ),
            Expanded(
              child: _failed ? _buildError() : _buildWebView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebView() {
    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(widget.url)),
      initialSettings: InAppWebViewSettings(
        transparentBackground: true,
        allowsBackForwardNavigationGestures: true,
      ),
      onWebViewCreated: (controller) => _controller = controller,
      onProgressChanged: (controller, progress) {
        if (!mounted) return;
        setState(() => _progress = progress / 100);
      },
      onReceivedError: (controller, request, error) {
        // Only treat failures of the main page as fatal.
        if (request.isForMainFrame != true || !mounted) return;
        setState(() => _failed = true);
      },
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.inkSoft),
            const SizedBox(height: 12),
            const Text(
              'Tidak bisa memuat halaman.',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 4),
            const Text(
              'Periksa koneksi internet lalu coba lagi.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.inkSoft,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                // Rebuilding the webview reloads initialUrlRequest.
                setState(() {
                  _controller = null;
                  _failed = false;
                  _progress = 0;
                });
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text(
                'Coba lagi',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
