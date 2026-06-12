import 'package:flutter/material.dart';
import '../../data/models/agent.dart';

class AgentCard extends StatefulWidget {
  final Agent agent;
  final Future<void> Function(BuildContext context, String agentId) onTest;
  final void Function(BuildContext context, Agent agent) onEdit;
  final void Function(BuildContext context, String agentId) onDelete;

  const AgentCard({
    super.key,
    required this.agent,
    required this.onTest,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<AgentCard> createState() => _AgentCardState();
}

class _AgentCardState extends State<AgentCard> {
  bool _isTesting = false;

  IconData _getAgentIcon(String type) {
    switch (type.toLowerCase()) {
      case 'openai':
        return Icons.auto_awesome;
      case 'webhook':
        return Icons.webhook;
      case 'echo':
        return Icons.record_voice_over;
      default:
        return Icons.smart_toy;
    }
  }

  Color _getStatusColor(BuildContext context, String status) {
    final theme = Theme.of(context).colorScheme;
    switch (status.toLowerCase()) {
      case 'online':
        return Colors.green;
      case 'offline':
        return theme.outline;
      case 'error':
        return theme.error;
      default:
        return theme.outline;
    }
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  Future<void> _handleTest(BuildContext context) async {
    setState(() {
      _isTesting = true;
    });
    try {
      await widget.onTest(context, widget.agent.id);
    } finally {
      if (mounted) {
        setState(() {
          _isTesting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: colorScheme.surfaceContainerHighest,
              child: Icon(
                _getAgentIcon(widget.agent.connectorType),
                color: colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.agent.name,
                          style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(
                          widget.agent.connectorType,
                          style: textTheme.labelSmall?.copyWith(color: colorScheme.primary),
                        ),
                        backgroundColor: colorScheme.primaryContainer,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        visualDensity: VisualDensity.compact,
                        side: BorderSide.none,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.agent.description?.isNotEmpty == true
                        ? widget.agent.description!
                        : 'No description',
                    style: textTheme.bodySmall?.copyWith(color: colorScheme.secondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _getStatusColor(context, widget.agent.status),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _capitalize(widget.agent.status),
                        style: textTheme.labelSmall?.copyWith(color: colorScheme.secondary),
                      ),
                      const Spacer(),
                      if (_isTesting)
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        TextButton(
                          onPressed: () => _handleTest(context),
                          style: TextButton.styleFrom(
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Test',
                            style: TextStyle(color: colorScheme.primary, fontSize: 12),
                          ),
                        ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => widget.onEdit(context, widget.agent),
                        style: TextButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Edit',
                          style: TextStyle(color: colorScheme.secondary, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => widget.onDelete(context, widget.agent.id),
                        style: TextButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Delete',
                          style: TextStyle(color: colorScheme.error, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
