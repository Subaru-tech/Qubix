import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/agent.dart';
import '../../data/repositories/agent_repository.dart';

final agentManagementProvider = AsyncNotifierProvider<AgentManagementNotifier, List<Agent>>(() {
  return AgentManagementNotifier();
});

class AgentManagementNotifier extends AsyncNotifier<List<Agent>> {
  late AgentRepository _repository;

  @override
  FutureOr<List<Agent>> build() async {
    _repository = ref.read(agentRepositoryProvider);
    return await _repository.getAgents();
  }

  Future<void> loadAgents() async {
    state = const AsyncValue.loading();
    try {
      final agents = await _repository.getAgents();
      state = AsyncValue.data(agents);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createAgent({
    required String name,
    required String connectorType,
    required Map<String, dynamic> config,
    String? description,
    String? systemPrompt,
    bool isEnabled = true,
  }) async {
    await _repository.createAgent(
      name: name,
      connectorType: connectorType,
      config: config,
      description: description,
      systemPrompt: systemPrompt,
      isEnabled: isEnabled,
    );
    await loadAgents();
  }

  Future<void> updateAgent(
    String id, {
    String? name,
    String? connectorType,
    Map<String, dynamic>? config,
    String? description,
    String? systemPrompt,
    bool? isEnabled,
  }) async {
    await _repository.updateAgent(
      id,
      name: name,
      connectorType: connectorType,
      config: config,
      description: description,
      systemPrompt: systemPrompt,
      isEnabled: isEnabled,
    );
    await loadAgents();
  }

  Future<void> deleteAgent(String id) async {
    await _repository.deleteAgent(id);
    await loadAgents();
  }

  Future<Map<String, dynamic>> testAgent(String id) async {
    final result = await _repository.testAgent(id);
    
    // Update local state for immediate feedback
    state.whenData((agents) {
      final index = agents.indexWhere((a) => a.id == id);
      if (index != -1) {
        final newAgents = List<Agent>.from(agents);
        newAgents[index] = newAgents[index].copyWith(status: result['status'] as String);
        state = AsyncValue.data(newAgents);
      }
    });

    return result;
  }
}
