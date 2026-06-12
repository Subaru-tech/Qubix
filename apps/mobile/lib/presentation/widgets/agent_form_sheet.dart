import 'dart:convert';
import 'package:flutter/material.dart';
import '../../data/models/agent.dart';

class AgentFormSheet extends StatefulWidget {
  final Agent? agent;
  final Future<void> Function({
    required String name,
    required String connectorType,
    required Map<String, dynamic> config,
    String? description,
    String? systemPrompt,
    required bool isEnabled,
  }) onSave;

  const AgentFormSheet({super.key, this.agent, required this.onSave});

  @override
  State<AgentFormSheet> createState() => _AgentFormSheetState();
}

class _AgentFormSheetState extends State<AgentFormSheet> {
  final _formKey = GlobalKey<FormState>();
  
  late String _name;
  late String? _description;
  late String _connectorType;
  late String? _systemPrompt;
  late bool _isEnabled;

  // OpenAI fields
  late String _openAiApiKey;
  late String _openAiModel;
  late String _openAiBaseUrl;

  // Webhook fields
  late String _webhookUrl;
  late String _webhookHeaders;

  bool _obscureApiKey = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final agent = widget.agent;
    _name = agent?.name ?? '';
    _description = agent?.description;
    _connectorType = agent?.connectorType ?? 'openai';
    _systemPrompt = agent?.systemPrompt;
    _isEnabled = agent?.isEnabled ?? true;

    // Config extraction
    final config = agent?.config ?? {};
    _openAiApiKey = config['apiKey'] ?? '';
    _openAiModel = config['model'] ?? '';
    _openAiBaseUrl = config['baseUrl'] ?? '';
    _webhookUrl = config['url'] ?? '';
    
    // Convert headers map to string if possible, else empty
    final headersMap = config['headers'] as Map<String, dynamic>?;
    if (headersMap != null && headersMap.isNotEmpty) {
      _webhookHeaders = headersMap.toString(); // Not perfect JSON, but ok for MVP
    } else {
      _webhookHeaders = '';
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() {
      _isSaving = true;
    });

    Map<String, dynamic> config = {};
    if (_connectorType == 'openai') {
      config = {
        'apiKey': _openAiApiKey,
        if (_openAiModel.isNotEmpty) 'model': _openAiModel,
        if (_openAiBaseUrl.isNotEmpty) 'baseUrl': _openAiBaseUrl,
      };
    } else if (_connectorType == 'webhook') {
      config = {
        'url': _webhookUrl,
        if (_webhookHeaders.isNotEmpty) 'headers': _webhookHeaders, // Note: real app would parse this string to Map
      };
    }

    try {
      await widget.onSave(
        name: _name,
        connectorType: _connectorType,
        config: config,
        description: _description?.isEmpty == true ? null : _description,
        systemPrompt: _systemPrompt?.isEmpty == true ? null : _systemPrompt,
        isEnabled: _isEnabled,
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Agent saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving agent: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.agent != null;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.85,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Form(
            key: _formKey,
            child: ListView(
              controller: scrollController,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  isEditing ? 'Edit Agent' : 'Add Agent',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),

                TextFormField(
                  initialValue: _name,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 100,
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  onSaved: (v) => _name = v!.trim(),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  initialValue: _description,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 200,
                  onSaved: (v) => _description = v?.trim(),
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  initialValue: _connectorType,
                  decoration: const InputDecoration(
                    labelText: 'Connector Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'openai', child: Text('OpenAI')),
                    DropdownMenuItem(value: 'webhook', child: Text('Webhook')),
                    DropdownMenuItem(value: 'echo', child: Text('Echo')),
                  ],
                  onChanged: isEditing ? null : (v) {
                    if (v != null) {
                      setState(() {
                        _connectorType = v;
                      });
                    }
                  },
                ),
                const SizedBox(height: 24),

                if (_connectorType == 'openai') ...[
                  TextFormField(
                    initialValue: isEditing ? '••••••••' : _openAiApiKey,
                    obscureText: _obscureApiKey,
                    style: const TextStyle(fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      labelText: 'API Key',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureApiKey ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscureApiKey = !_obscureApiKey),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      return null;
                    },
                    onSaved: (v) {
                      if (v != null && v != '••••••••') {
                        _openAiApiKey = v.trim();
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: _openAiModel,
                    decoration: const InputDecoration(
                      labelText: 'Model (optional)',
                      hintText: 'gpt-4-turbo',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v != null && v.isNotEmpty) {
                        final validModels = ['gpt-4', 'gpt-4-turbo', 'gpt-3.5-turbo', 'gpt-4o'];
                        if (!validModels.contains(v.trim())) {
                          return 'Unknown model (e.g., gpt-4-turbo)';
                        }
                      }
                      return null;
                    },
                    onSaved: (v) => _openAiModel = v?.trim() ?? '',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: _openAiBaseUrl,
                    decoration: const InputDecoration(
                      labelText: 'Base URL (optional)',
                      hintText: 'https://api.openai.com/v1',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v != null && v.isNotEmpty && !Uri.parse(v).isAbsolute) {
                        return 'Must be a valid URL';
                      }
                      return null;
                    },
                    onSaved: (v) => _openAiBaseUrl = v?.trim() ?? '',
                  ),
                ] else if (_connectorType == 'webhook') ...[
                  TextFormField(
                    initialValue: _webhookUrl,
                    decoration: const InputDecoration(
                      labelText: 'Webhook URL',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (!v.startsWith('http://') && !v.startsWith('https://')) {
                        return 'Must start with http:// or https://';
                      }
                      if (!Uri.parse(v).isAbsolute) return 'Must be a valid URL';
                      return null;
                    },
                    onSaved: (v) => _webhookUrl = v!.trim(),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: _webhookHeaders,
                    decoration: const InputDecoration(
                      labelText: 'Headers (JSON string, optional)',
                      hintText: '{"Authorization": "Bearer xyz"}',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v != null && v.isNotEmpty) {
                        try {
                          final decoded = jsonDecode(v);
                          if (decoded is! Map<String, dynamic>) {
                            return 'Headers must be a JSON object';
                          }
                        } catch (_) {
                          return 'Invalid JSON string';
                        }
                      }
                      return null;
                    },
                    onSaved: (v) => _webhookHeaders = v?.trim() ?? '',
                  ),
                ] else if (_connectorType == 'echo') ...[
                  Text(
                    'Echo agent repeats your messages back for testing.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],

                const SizedBox(height: 24),

                if (_connectorType != 'echo') ...[
                  TextFormField(
                    initialValue: _systemPrompt,
                    decoration: const InputDecoration(
                      labelText: 'System Prompt (optional)',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 3,
                    maxLength: 2000,
                    onSaved: (v) => _systemPrompt = v?.trim(),
                  ),
                  const SizedBox(height: 16),
                ],

                SwitchListTile(
                  title: const Text('Enabled'),
                  value: _isEnabled,
                  onChanged: (v) => setState(() => _isEnabled = v),
                  contentPadding: EdgeInsets.zero,
                ),

                const SizedBox(height: 32),

                ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Agent'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
