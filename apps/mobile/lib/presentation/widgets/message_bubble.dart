import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../data/models/message.dart';
import '../viewmodels/chat_thread_notifier.dart';

class MessageBubble extends ConsumerWidget {
  final Message message;

  const MessageBubble({super.key, required this.message});

  void _showOptions(BuildContext context, WidgetRef ref) {
    if (!message.isLocalPending && message.status != MessageStatus.failed) return;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.refresh, color: QubixColors.primary),
                title: const Text('Retry Now'),
                onTap: () {
                  Navigator.pop(context);
                  ref.read(chatThreadProvider(message.threadId).notifier).retryMessage(message);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: QubixColors.error),
                title: const Text('Delete'),
                onTap: () {
                  Navigator.pop(context);
                  ref.read(chatThreadProvider(message.threadId).notifier).deleteLocalMessage(message);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUser = message.isUser;
    final align = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bgColor = isUser ? QubixColors.surface : Colors.transparent;
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isUser ? 16 : 0),
      bottomRight: Radius.circular(isUser ? 0 : 16),
    );

    Widget statusIcon = const SizedBox.shrink();
    Color finalBgColor = bgColor;
    Border? border;

    if (message.status == MessageStatus.pending) {
      statusIcon = const Icon(Icons.schedule, size: 12, color: QubixColors.textSecondary);
      finalBgColor = bgColor.withValues(alpha: 0.7);
      if (!isUser) {
        border = const Border(left: BorderSide(color: QubixColors.warning, width: 2));
      }
    } else if (message.status == MessageStatus.failed) {
      statusIcon = const Icon(Icons.error_outline, size: 14, color: QubixColors.error);
    } else if (message.status == MessageStatus.sent) {
      statusIcon = const Icon(Icons.check, size: 12, color: QubixColors.textSecondary);
    } else if (message.status == MessageStatus.delivered) {
      statusIcon = const Icon(Icons.done_all, size: 12, color: QubixColors.primary);
    }

    return GestureDetector(
      onLongPress: () => _showOptions(context, ref),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: finalBgColor,
              borderRadius: borderRadius,
              border: border ?? (isUser ? null : Border.all(color: QubixColors.surface)),
            ),
            child: Column(
              crossAxisAlignment: align,
              children: [
                MarkdownBody(
                  data: message.content,
                  styleSheet: MarkdownStyleSheet(
                    p: QubixTypography.bodyLarge,
                    code: QubixTypography.bodySmall.copyWith(
                      fontFamily: 'monospace',
                      backgroundColor: QubixColors.background,
                    ),
                    codeblockDecoration: BoxDecoration(
                      color: QubixColors.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(message.createdAt),
                      style: QubixTypography.bodySmall.copyWith(
                        color: QubixColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                    if (isUser) ...[
                      const SizedBox(width: 4),
                      statusIcon,
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (message.status == MessageStatus.failed)
            Padding(
              padding: const EdgeInsets.only(right: 16, bottom: 4),
              child: TextButton.icon(
                onPressed: () {
                  ref.read(chatThreadProvider(message.threadId).notifier).retryMessage(message);
                },
                icon: const Icon(Icons.refresh, size: 14, color: QubixColors.error),
                label: Text(
                  'Retry',
                  style: QubixTypography.bodySmall.copyWith(color: QubixColors.error),
                ),
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
