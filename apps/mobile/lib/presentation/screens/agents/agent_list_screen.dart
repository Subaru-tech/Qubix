import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/agent.dart';
import '../../viewmodels/agent_management_notifier.dart';
import '../../widgets/agent_card.dart';
import '../../widgets/agent_form_sheet.dart';

class AgentListScreen extends ConsumerStatefulWidget {
  const AgentListScreen({super.key});

  @override
  ConsumerState<AgentListScreen> createState() => _AgentListScreenState();
}

class _AgentListScreenState extends ConsumerState<AgentListScreen> {
  @override
  void initState() {
    super.initState();
    // Load agents immediately if not already loaded, though AsyncNotifier handles this on build
  }

  void _showAddAgentSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AgentFormSheet(
        onSave: ({
          required name,
          required connectorType,
          required config,
          description,
          systemPrompt,
          required isEnabled,
        }) async {
          await ref.read(agentManagementProvider.notifier).createAgent(
                name: name,
                connectorType: connectorType,
                config: config,
                description: description,
                systemPrompt: systemPrompt,
                isEnabled: isEnabled,
              );
        },
      ),
    );
  }

  void _showEditAgentSheet(BuildContext context, Agent agent) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AgentFormSheet(
        agent: agent,
        onSave: ({
          required name,
          required connectorType,
          required config,
          description,
          systemPrompt,
          required isEnabled,
        }) async {
          await ref.read(agentManagementProvider.notifier).updateAgent(
                agent.id,
                name: name,
                connectorType: connectorType,
                config: config,
                description: description,
                systemPrompt: systemPrompt,
                isEnabled: isEnabled,
              );
        },
      ),
    );
  }

  Future<void> _testAgent(BuildContext context, String agentId) async {
    final theme = Theme.of(context);
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 24),
            Expanded(child: Text('Testing connection...')),
          ],
        ),
      ),
    );

    final result = await ref.read(agentManagementProvider.notifier).testAgent(agentId);
    
    // Dismiss loading dialog
    if (context.mounted) {
      Navigator.of(context).pop();
    }

    if (!context.mounted) return;

    final bool success = result['success'] == true && result['status'] == 'online';
    
    if (success) {
      showDialog(
        context: context,
        builder: (context) {
          Future.delayed(const Duration(seconds: 3), () {
            if (context.mounted) Navigator.of(context).pop();
          });
          return AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 48),
                const SizedBox(height: 16),
                Text('Connected!', style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.primary)),
                const SizedBox(height: 8),
                const Text('Agent is online and ready.', textAlign: TextAlign.center),
              ],
            ),
          );
        },
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: theme.colorScheme.error, size: 48),
              const SizedBox(height: 16),
              Text('Connection failed', style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.error)),
              const SizedBox(height: 8),
              Text(result['error'] ?? 'Unknown error', textAlign: TextAlign.center),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _testAgent(context, agentId);
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
  }

  void _confirmDelete(BuildContext context, String agentId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Agent?'),
        content: const Text(
            'This agent and its configuration will be permanently removed. Existing messages will remain but show as "Deleted Agent".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              try {
                await ref.read(agentManagementProvider.notifier).deleteAgent(agentId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Agent deleted')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting agent: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final agentState = ref.watch(agentManagementProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Agents', style: theme.textTheme.headlineMedium),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddAgentSheet(context),
          ),
        ],
      ),
      body: agentState.when(
        data: (agents) {
          if (agents.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.smart_toy_outlined, size: 80, color: theme.colorScheme.outline),
                    const SizedBox(height: 16),
                    Text('No agents connected', style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text(
                      'Add your first AI agent to start chatting',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.secondary),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => _showAddAgentSheet(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Agent'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(agentManagementProvider.notifier).loadAgents(),
            child: ListView.builder(
              itemCount: agents.length,
              itemBuilder: (context, index) {
                final agent = agents[index];
                return AgentCard(
                  agent: agent,
                  onTest: _testAgent,
                  onEdit: _showEditAgentSheet,
                  onDelete: _confirmDelete,
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Failed to load agents', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.error)),
              const SizedBox(height: 8),
              Text(error.toString(), style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(agentManagementProvider.notifier).loadAgents(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAgentSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Agent'),
      ),
    );
  }
}
