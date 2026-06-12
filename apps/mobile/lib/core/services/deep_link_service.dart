import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DeepLinkEvent {
  final String path;
  final Map<String, String> params;

  DeepLinkEvent({required this.path, this.params = const {}});
}

final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  return DeepLinkService(ref);
});

class DeepLinkService {
  final Ref _ref;
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  DeepLinkService(this._ref);

  Future<void> initialize() async {
    // Check initial link if app was in cold state (terminated)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint('Failed to get initial app link: $e');
    }

    // Attach a listener to the stream
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    }, onError: (err) {
      debugPrint('Failed to handle incoming app link: $err');
    });
  }

  void dispose() {
    _linkSubscription?.cancel();
  }

  void _handleDeepLink(Uri uri) {
    if (uri.scheme != 'qubix') {
      debugPrint('Unsupported scheme: ${uri.scheme}');
      return;
    }

    // pathSegments are split by '/'
    // Example: qubix://auth?token=abc -> pathSegments = ['auth']
    // Example: qubix://thread/123 -> pathSegments = ['thread', '123']

    if (uri.host == 'auth' || uri.pathSegments.firstOrNull == 'auth') {
      _emitEvent('/auth', uri.queryParameters);
    } else if (uri.host == 'thread' || uri.pathSegments.firstOrNull == 'thread') {
      // In qubix://thread/123:
      // uri.host might be 'thread', and uri.path might be '/123'
      // OR uri.host might be empty and path is 'thread/123' depending on parsing
      String? threadId;
      if (uri.host == 'thread' && uri.pathSegments.isNotEmpty) {
        threadId = uri.pathSegments.first;
      } else if (uri.pathSegments.length > 1 && uri.pathSegments.first == 'thread') {
        threadId = uri.pathSegments[1];
      }

      if (threadId != null) {
        _emitEvent('/thread', {'id': threadId});
      }
    } else if (uri.host == 'settings' || uri.pathSegments.firstOrNull == 'settings') {
      _emitEvent('/settings', uri.queryParameters);
    } else if (uri.host == 'chats' || uri.pathSegments.firstOrNull == 'chats') {
      _emitEvent('/chats', uri.queryParameters);
    } else {
      debugPrint('Unknown deep link path: $uri');
      _emitEvent('/chats', {}); // fallback
    }
  }

  void emit(DeepLinkEvent event) {
    _ref.read(deepLinkProvider.notifier).update(event);
  }

  void _emitEvent(String path, Map<String, String> params) {
    emit(DeepLinkEvent(path: path, params: params));
  }
}

class DeepLinkNotifier extends Notifier<DeepLinkEvent?> {
  @override
  DeepLinkEvent? build() => null;
  void update(DeepLinkEvent? event) => state = event;
}

final deepLinkProvider = NotifierProvider<DeepLinkNotifier, DeepLinkEvent?>(DeepLinkNotifier.new);
