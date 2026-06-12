import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/api_client.dart';
import '../models/message.dart';
import '../models/thread.dart';
import '../local/db_service.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(
    ref.read(dioProvider),
    ref.read(dbServiceProvider),
  );
});

class ChatRepository {
  final Dio _dio;
  final DbService _dbService;

  ChatRepository(this._dio, this._dbService);

  Future<List<Thread>> getThreads() async {
    final response = await _dio.get('/api/threads');
    final data = response.data['data'] as List;
    return data.map((json) => Thread.fromJson(json)).toList();
  }

  Future<Thread> createThread(String agentId, String title) async {
    final response = await _dio.post('/api/threads', data: {
      'agentId': agentId,
      'title': title,
    });
    return Thread.fromJson(response.data['data']);
  }

  Future<List<Message>> getMessages(String threadId) async {
    final response = await _dio.get('/api/threads/$threadId/messages');
    final data = response.data['data'] as List;
    final messages = data.map((json) => Message.fromJson(json)).toList();

    // Append any local pending messages for this thread
    final pending = await _dbService.getPendingMessages(threadId);
    messages.addAll(pending);
    messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    
    return messages;
  }

  Future<Message> sendMessage(String threadId, String content, String tempId) async {
    try {
      final response = await _dio.post('/api/threads/$threadId/messages', data: {
        'content': content,
        'role': 'user',
      });
      return Message.fromJson(response.data['data']);
    } on DioException catch (e) {
      if (_isNetworkError(e)) {
        // Buffer to SQLite
        final pendingMsg = Message(
          id: tempId,
          threadId: threadId,
          role: 'user',
          content: content,
          status: MessageStatus.pending,
          createdAt: DateTime.now().toUtc(),
          isLocalPending: true,
        );
        await _dbService.savePendingMessage(pendingMsg);
        return pendingMsg;
      }
      rethrow;
    }
  }

  Future<void> flushPendingMessages(String threadId) async {
    final pending = await _dbService.getPendingMessages(threadId);
    for (final msg in pending) {
      try {
        await _dio.post('/api/threads/$threadId/messages', data: {
          'content': msg.content,
          'role': 'user',
        });
        await _dbService.deletePendingMessage(msg.id);
      } catch (e) {
        // If it fails again, stop flushing to preserve order
        break;
      }
    }
  }

  bool _isNetworkError(DioException e) {
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.unknown;
  }
}
