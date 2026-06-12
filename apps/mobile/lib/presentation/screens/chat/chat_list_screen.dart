import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/api_client.dart';
import '../../../core/router.dart';
import '../../../data/models/thread.dart';

/// Provider for the thread list.
final threadListProvider = FutureProvider<List<Thread>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(AppConstants.pathThreads);
  final list = response.data as List;
  return list.map((json) => Thread.fromJson(json as Map<String, dynamic>)).toList();
});

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threadsAsync = ref.watch(threadListProvider);

    return Scaffold(
      backgroundColor: QubixColors.background,
      appBar: AppBar(
        title: const Text('QUBIX'),
        actions: [
          IconButton(
            icon: const Icon(Icons.smart_toy_outlined),
            tooltip: 'Agents',
            onPressed: () => context.push(Routes.agents),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push(Routes.settings),
          ),
        ],
      ),
      body: threadsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: QubixColors.primary),
        ),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 48, color: QubixColors.textTertiary),
              const SizedBox(height: 16),
              Text('Cannot load threads', style: QubixTypography.bodyMedium),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(threadListProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (threads) {
          if (threads.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 64, color: QubixColors.textTertiary),
                  const SizedBox(height: 16),
                  Text('No conversations yet', style: QubixTypography.displaySmall),
                  const SizedBox(height: 8),
                  Text(
                    'Create an agent and start chatting',
                    style: QubixTypography.bodyMedium.copyWith(color: QubixColors.textSecondary),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: QubixColors.primary,
            onRefresh: () async => ref.invalidate(threadListProvider),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: threads.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final thread = threads[index];
                return _ThreadTile(thread: thread);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNewThreadDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showNewThreadDialog(BuildContext context, WidgetRef ref) {
    // Placeholder — Step 16 will add agent picker
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('New Chat', style: QubixTypography.displaySmall),
            const SizedBox(height: 8),
            Text(
              'Select an agent to start a conversation',
              style: QubixTypography.bodyMedium.copyWith(color: QubixColors.textSecondary),
            ),
            const SizedBox(height: 24),
            Text(
              'Set up agents first from the Agents screen.',
              style: QubixTypography.bodySmall.copyWith(color: QubixColors.textTertiary),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _ThreadTile extends StatelessWidget {
  final Thread thread;
  const _ThreadTile({required this.thread});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/chats/${thread.id}'),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(
          children: [
            // Agent avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: QubixColors.connectorColor(thread.agent?.connectorType ?? 'echo')
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.smart_toy_outlined,
                color: QubixColors.connectorColor(thread.agent?.connectorType ?? 'echo'),
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          thread.title ?? 'Untitled',
                          style: QubixTypography.labelLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatTime(thread.lastMessageAt),
                        style: QubixTypography.labelSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (thread.lastMessage != null)
                    Text(
                      thread.lastMessage!.content,
                      style: QubixTypography.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (thread.agent != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: thread.agent!.status == 'online'
                                  ? QubixColors.success
                                  : QubixColors.textTertiary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            thread.agent!.name,
                            style: QubixTypography.labelSmall.copyWith(
                              color: QubixColors.connectorColor(thread.agent!.connectorType),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.month}/${dt.day}';
  }
}
