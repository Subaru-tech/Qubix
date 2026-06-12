import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/message.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/local/db_service.dart';
import '../../core/services/websocket_service.dart';
import 'connectivity_notifier.dart';

final chatThreadProvider = AsyncNotifierProvider.family<ChatThreadNotifier, List<Message>, String>(
  (arg) => ChatThreadNotifier(arg)
);

class ChatThreadNotifier extends AsyncNotifier<List<Message>> {
  final String threadId;
  late ChatRepository repository;
  late WebSocketService wsService;
  final _uuid = const Uuid();

  ChatThreadNotifier(this.threadId);

  @override
  FutureOr<List<Message>> build() async {
    repository = ref.read(chatRepositoryProvider);
    wsService = ref.read(webSocketServiceProvider(threadId));
    
    _connectWebSocket();

    // Listen for reconnection to auto-flush
    ref.listen<AppConnectionState>(connectivityProvider, (previous, next) {
      if (previous is AppConnectionOffline && next is AppConnectionOnline) {
        _flushPending();
      }
    });
    
    // Cleanup on dispose
    ref.onDispose(() {
      wsService.disconnect();
    });

    return await repository.getMessages(threadId);
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await repository.getMessages(threadId);
      state = AsyncData(messages);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  void _connectWebSocket() {
    wsService.connect((event) {
      if (event['type'] == 'message.chunk' || event['type'] == 'message.done') {
        final messageId = event['messageId'] as String;
        final chunk = event['chunk'] as String? ?? '';
        final status = event['type'] == 'message.done' ? MessageStatus.sent : MessageStatus.pending;
        
        state.whenData((messages) {
          final existingIndex = messages.indexWhere((m) => m.id == messageId);
          if (existingIndex >= 0) {
            final existing = messages[existingIndex];
            final updated = existing.copyWith(
              content: existing.content + chunk,
              status: status,
            );
            final newMessages = List<Message>.from(messages);
            newMessages[existingIndex] = updated;
            state = AsyncData(newMessages);
          } else {
            // New agent message started
            final newMsg = Message(
              id: messageId,
              threadId: threadId,
              role: 'agent',
              content: chunk,
              status: status,
              createdAt: DateTime.now().toUtc(),
            );
            state = AsyncData([...messages, newMsg]);
          }
        });
      }
    });
  }

  Future<void> sendMessage(String content) async {
    final tempId = _uuid.v4();
    final tempMsg = Message(
      id: tempId,
      threadId: threadId,
      role: 'user',
      content: content,
      status: MessageStatus.pending,
      createdAt: DateTime.now().toUtc(),
      isLocalPending: true,
    );

    // Optimistic UI update
    state.whenData((messages) {
      state = AsyncData([...messages, tempMsg]);
    });

    final connectivity = ref.read(connectivityProvider);
    if (connectivity is AppConnectionOffline) {
      // Save to SQLite
      await repository.sendMessage(threadId, content, tempId); // Repository handles offline buffering
      return;
    }

    try {
      final serverMsg = await repository.sendMessage(threadId, content, tempId);
      
      // Update UI with confirmed message
      state.whenData((messages) {
        final index = messages.indexWhere((m) => m.id == tempId || m.id == serverMsg.id);
        if (index >= 0) {
          final newMessages = List<Message>.from(messages);
          newMessages[index] = serverMsg;
          state = AsyncData(newMessages);
        }
      });
    } catch (e) {
      // Mark as failed
      state.whenData((messages) {
        final index = messages.indexWhere((m) => m.id == tempId);
        if (index >= 0) {
          final newMessages = List<Message>.from(messages);
          newMessages[index] = newMessages[index].copyWith(status: MessageStatus.failed);
          state = AsyncData(newMessages);
        }
      });
    }
  }

  Future<int> _flushPending() async {
    try {
      final pendingCount = (await repository.getMessages(threadId))
          .where((m) => m.isLocalPending)
          .length;
      if (pendingCount > 0) {
        await repository.flushPendingMessages(threadId);
        await _loadMessages(); // Reload from server to get accurate state
        return pendingCount;
      }
    } catch (e) {
      // Ignore flush errors
    }
    return 0;
  }

  Future<void> retryMessage(Message message) async {
    if (message.status != MessageStatus.failed && !message.isLocalPending) return;
    
    // Optimistic retry state
    state.whenData((messages) {
      final index = messages.indexWhere((m) => m.id == message.id);
      if (index >= 0) {
        final newMessages = List<Message>.from(messages);
        newMessages[index] = newMessages[index].copyWith(status: MessageStatus.pending);
        state = AsyncData(newMessages);
      }
    });

    try {
      final serverMsg = await repository.sendMessage(threadId, message.content, message.id);
      state.whenData((messages) {
        final index = messages.indexWhere((m) => m.id == message.id || m.id == serverMsg.id);
        if (index >= 0) {
          final newMessages = List<Message>.from(messages);
          newMessages[index] = serverMsg;
          state = AsyncData(newMessages);
        }
      });
    } catch (e) {
      state.whenData((messages) {
        final index = messages.indexWhere((m) => m.id == message.id);
        if (index >= 0) {
          final newMessages = List<Message>.from(messages);
          newMessages[index] = newMessages[index].copyWith(status: MessageStatus.failed);
          state = AsyncData(newMessages);
        }
      });
    }
  }

  Future<void> deleteLocalMessage(Message message) async {
    if (message.isLocalPending || message.status == MessageStatus.failed) {
      final dbService = ref.read(dbServiceProvider);
      await dbService.deletePendingMessage(message.id);
      state.whenData((messages) {
        state = AsyncData(messages.where((m) => m.id != message.id).toList());
      });
    }
  }
}
