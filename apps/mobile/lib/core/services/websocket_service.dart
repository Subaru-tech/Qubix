import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../utils/api_client.dart';
import '../constants/app_constants.dart';

final webSocketServiceProvider = Provider.family<WebSocketService, String>((ref, threadId) {
  final baseUrl = ref.watch(serverUrlProvider);
  final token = ref.watch(authTokenProvider);
  
  // Convert http:// to ws:// and https:// to wss://
  final wsUrl = baseUrl.replaceFirst('http://', 'ws://').replaceFirst('https://', 'wss://');
  
  return WebSocketService(
    wsUrl: '$wsUrl${AppConstants.pathWs}?token=$token',
    threadId: threadId,
  );
});

class WebSocketService {
  final String wsUrl;
  final String threadId;
  WebSocketChannel? _channel;

  WebSocketService({required this.wsUrl, required this.threadId});

  void connect(void Function(Map<String, dynamic> event) onMessage) {
    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    
    // Subscribe to thread
    _channel?.sink.add(jsonEncode({
      'type': 'subscribe',
      'threadId': threadId,
    }));

    _channel?.stream.listen(
      (message) {
        try {
          final data = jsonDecode(message);
          onMessage(data as Map<String, dynamic>);
        } catch (e) {
          // Ignore invalid JSON
        }
      },
      onError: (error) {
        // Handle error
      },
      onDone: () {
        // Handle disconnect
      },
    );
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }
}
