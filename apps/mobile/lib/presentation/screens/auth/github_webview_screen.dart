import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/utils/api_client.dart';
import '../../../core/services/deep_link_service.dart';

class GithubWebViewScreen extends ConsumerStatefulWidget {
  const GithubWebViewScreen({super.key});

  @override
  ConsumerState<GithubWebViewScreen> createState() => _GithubWebViewScreenState();
}

class _GithubWebViewScreenState extends ConsumerState<GithubWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final baseUrl = ref.read(serverUrlProvider);
    final githubAuthUrl = '$baseUrl/auth/github';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.startsWith('qubix://')) {
              // Intercept deep link
              final uri = Uri.parse(request.url);
              // Send it to deep link service
              ref.read(deepLinkServiceProvider).emit(
                DeepLinkEvent(path: uri.path, params: uri.queryParameters),
              );
              // Close the webview
              Navigator.of(context).pop();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(githubAuthUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign in with GitHub'),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
