import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/agent.dart';
import '../../core/utils/api_client.dart';

final agentRepositoryProvider = Provider<AgentRepository>((ref) {
  return AgentRepository(ref.watch(dioProvider));
});

class AgentRepository {
  final Dio _dio;

  AgentRepository(this._dio);

  Future<List<Agent>> getAgents() async {
    final response = await _dio.get('/agents');
    final data = response.data['data'] as List;
    return data.map((json) => Agent.fromJson(json)).toList();
  }

  Future<Agent> createAgent({
    required String name,
    required String connectorType,
    required Map<String, dynamic> config,
    String? description,
    String? systemPrompt,
    bool isEnabled = true,
  }) async {
    final response = await _dio.post('/agents', data: {
      'name': name,
      'connectorType': connectorType,
      'config': config,
      'description': ?description,
      'systemPrompt': ?systemPrompt,
      'isEnabled': isEnabled,
    });
    return Agent.fromJson(response.data['data']);
  }

  Future<Agent> updateAgent(
    String id, {
    String? name,
    String? connectorType,
    Map<String, dynamic>? config,
    String? description,
    String? systemPrompt,
    bool? isEnabled,
  }) async {
    final response = await _dio.patch('/agents/$id', data: {
      'name': ?name,
      'connectorType': ?connectorType,
      'config': ?config,
      'description': ?description,
      'systemPrompt': ?systemPrompt,
      'isEnabled': ?isEnabled,
    });
    return Agent.fromJson(response.data['data']);
  }

  Future<void> deleteAgent(String id) async {
    await _dio.delete('/agents/$id');
  }

  Future<Map<String, dynamic>> testAgent(String id) async {
    try {
      final response = await _dio.post('/agents/$id/test');
      return {
        'success': response.data['data']['success'] ?? false,
        'status': response.data['data']['status'] ?? 'error',
        'error': response.data['data']['error'],
      };
    } catch (e) {
      return {
        'success': false,
        'status': 'error',
        'error': e.toString(),
      };
    }
  }
}
