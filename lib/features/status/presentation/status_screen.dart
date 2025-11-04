import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  late final WebViewController _controller;
  bool _isReloading = false;

  static const _statusUrl =
      'http://crewning-mpa.s3-website.ap-northeast-2.amazonaws.com/';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..loadRequest(Uri.parse(_statusUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        Positioned(
          left: 16,
          bottom: 16,
          child: SafeArea(
            child: FloatingActionButton(
              heroTag: 'statusRefreshFab',
              onPressed: _isReloading
                  ? null
                  : () async {
                      setState(() => _isReloading = true);
                      try {
                        await _controller.reload();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('크루닝 지도를 새로고침했습니다.')),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('새로고침 실패: $e')),
                        );
                      } finally {
                        if (mounted) {
                          setState(() => _isReloading = false);
                        }
                      }
                    },
              child: _isReloading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.refresh),
            ),
          ),
        ),
      ],
    );
  }
}
