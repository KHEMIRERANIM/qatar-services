import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

class VeriffVerificationScreen extends StatefulWidget {
  final String verificationUrl;

  const VeriffVerificationScreen({
    super.key,
    required this.verificationUrl,
  });

  @override
  State<VeriffVerificationScreen> createState() => _VeriffVerificationScreenState();
}

class _VeriffVerificationScreenState extends State<VeriffVerificationScreen> {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _pageLoadFailed = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  Future<void> _requestMediaPermissions() async {
    final statuses = await [
      Permission.camera,
      Permission.microphone,
    ].request();

    debugPrint('Veriff permissions — camera: ${statuses[Permission.camera]}, mic: ${statuses[Permission.microphone]}');
  }

  Future<void> _initWebView() async {
    try {
      await _requestMediaPermissions();

      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFF0D1F3C))
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (_) {
              if (mounted) setState(() => _isLoading = true);
            },
            onPageFinished: (url) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  if (_pageLoadFailed) _pageLoadFailed = false;
                });
              }
            },
            onWebResourceError: (error) {
              debugPrint(
                'Veriff WebView error: ${error.errorCode} ${error.description} ${error.url}',
              );
              if (mounted) {
                setState(() {
                  _pageLoadFailed = true;
                  _isLoading = false;
                  _errorMessage =
                      'La vérification est temporairement indisponible. Veuillez réessayer dans quelques instants.';
                });
              }
            },
            onHttpError: (error) {
              debugPrint('Veriff HTTP error: ${error.response?.statusCode}');
              if (mounted) {
                setState(() {
                  _pageLoadFailed = true;
                  _isLoading = false;
                  _errorMessage =
                      'La vérification est temporairement indisponible. Veuillez réessayer dans quelques instants.';
                });
              }
            },
          ),
        )
        ..loadRequest(Uri.parse(widget.verificationUrl));

      if (controller.platform is AndroidWebViewController) {
        final androidController = controller.platform as AndroidWebViewController;
        androidController.setMediaPlaybackRequiresUserGesture(false);
        await androidController.setOnPlatformPermissionRequest(
          (request) async {
            await _requestMediaPermissions();
            request.grant();
          },
        );
      }

      if (mounted) {
        setState(() {
          _controller = controller;
          _errorMessage = null;
        });
      }
    } catch (e) {
      debugPrint('VeriffVerificationScreen init error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Impossible d\'ouvrir la vérification. Veuillez réessayer.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1F3C),
      appBar: AppBar(
        title: const Text(
          'Vérification d\'identité',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: const Color(0xFF0D1F3C),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _errorMessage != null
          ? _buildErrorState()
          : _controller == null
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC9A84C)),
                  ),
                )
              : Stack(
                  children: [
                    if (!_pageLoadFailed) WebViewWidget(controller: _controller!),
                    if (_isLoading)
                      const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC9A84C)),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Chargement de Veriff...',
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off, color: Color(0xFFC9A84C), size: 48),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                  _pageLoadFailed = false;
                  _isLoading = true;
                  _controller = null;
                });
                _initWebView();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC9A84C),
              ),
              child: const Text('Réessayer', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
