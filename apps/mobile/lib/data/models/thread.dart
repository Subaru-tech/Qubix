import 'agent.dart';

/// Thread model matching the backend's /threads response shape.
class Thread {
  final String id;
  final String? title;
  final String? agentId;
  final Agent? agent;
  final bool isPinned;
  final DateTime lastMessageAt;
  final DateTime createdAt;
  final ThreadLastMessage? lastMessage;

  const Thread({
    required this.id,
    this.title,
    this.agentId,
    this.agent,
    required this.isPinned,
    required this.lastMessageAt,
    required this.createdAt,
    this.lastMessage,
  });

  factory Thread.fromJson(Map<String, dynamic> json) {
    return Thread(
      id: json['id'] as String,
      title: json['title'] as String?,
      agentId: json['agentId'] as String?,
      agent: json['agent'] != null
          ? Agent.fromJson(json['agent'] as Map<String, dynamic>)
          : null,
      isPinned: json['isPinned'] as bool? ?? false,
      lastMessageAt: DateTime.parse(json['lastMessageAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastMessage: json['lastMessage'] != null
          ? ThreadLastMessage.fromJson(
              json['lastMessage'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Preview of the last message in a thread (truncated to 100 chars by server).
class ThreadLastMessage {
  final String content;
  final String role;
  final DateTime createdAt;

  const ThreadLastMessage({
    required this.content,
    required this.role,
    required this.createdAt,
  });

  factory ThreadLastMessage.fromJson(Map<String, dynamic> json) {
    return ThreadLastMessage(
      content: json['content'] as String,
      role: json['role'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
