/// Message status enum.
enum MessageStatus { pending, sent, delivered, failed }

/// Message model matching the backend's /threads/:id/messages response shape.
class Message {
  final String id;
  final String threadId;
  final String? agentId;
  final String role;
  final String content;
  final MessageStatus status;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  /// Local-only flag: true if this message hasn't been confirmed by the server.
  final bool isLocalPending;

  const Message({
    required this.id,
    required this.threadId,
    this.agentId,
    required this.role,
    required this.content,
    required this.status,
    this.metadata,
    required this.createdAt,
    this.isLocalPending = false,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      threadId: json['threadId'] as String,
      agentId: json['agentId'] as String?,
      role: json['role'] as String,
      content: json['content'] as String,
      status: _parseStatus(json['status'] as String? ?? 'sent'),
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'threadId': threadId,
        'agentId': agentId,
        'role': role,
        'content': content,
        'status': status.name,
        'metadata': metadata,
        'createdAt': createdAt.toIso8601String(),
      };

  Message copyWith({
    String? content,
    MessageStatus? status,
    Map<String, dynamic>? metadata,
    bool? isLocalPending,
  }) {
    return Message(
      id: id,
      threadId: threadId,
      agentId: agentId,
      role: role,
      content: content ?? this.content,
      status: status ?? this.status,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt,
      isLocalPending: isLocalPending ?? this.isLocalPending,
    );
  }

  bool get isUser => role == 'user';
  bool get isAgent => role == 'agent';
  bool get isSystem => role == 'system';

  static MessageStatus _parseStatus(String s) {
    switch (s) {
      case 'pending':
        return MessageStatus.pending;
      case 'sent':
        return MessageStatus.sent;
      case 'delivered':
        return MessageStatus.delivered;
      case 'failed':
        return MessageStatus.failed;
      default:
        return MessageStatus.sent;
    }
  }
}
