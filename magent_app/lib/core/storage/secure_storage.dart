import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AgentStorage {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> saveAgent(String id, String url, String token, String name) async {
    await _storage.write(key: 'agent_${id}_url', value: url);
    await _storage.write(key: 'agent_${id}_token', value: token);
    await _storage.write(key: 'agent_${id}_name', value: name);
  }

  Future<List<Map<String, String>>> loadAgents() async {
    final all = await _storage.readAll();
    final agentIds = <String>{};

    for (final key in all.keys) {
      if (key.startsWith('agent_') && key.endsWith('_url')) {
        final id = key.substring(6, key.length - 4);
        agentIds.add(id);
      }
    }

    final agents = <Map<String, String>>[];
    for (final id in agentIds) {
      agents.add({
        'id': id,
        'url': all['agent_${id}_url'] ?? '',
        'token': all['agent_${id}_token'] ?? '',
        'name': all['agent_${id}_name'] ?? '',
      });
    }

    return agents;
  }

  Future<void> deleteAgent(String id) async {
    await _storage.delete(key: 'agent_${id}_url');
    await _storage.delete(key: 'agent_${id}_token');
    await _storage.delete(key: 'agent_${id}_name');
    // If this was the active agent, clear it
    final active = await getActiveAgentId();
    if (active == id) {
      await _storage.delete(key: 'active_agent_id');
    }
  }

  Future<void> setActiveAgent(String id) async {
    await _storage.write(key: 'active_agent_id', value: id);
  }

  Future<String?> getActiveAgentId() async {
    return await _storage.read(key: 'active_agent_id');
  }

  Future<Map<String, String>?> getActiveAgent() async {
    final id = await getActiveAgentId();
    if (id == null) return null;
    final agents = await loadAgents();
    for (final agent in agents) {
      if (agent['id'] == id) return agent;
    }
    return null;
  }

  Future<void> setDefaultProvider(String provider) async {
    await _storage.write(key: 'default_provider', value: provider);
  }

  Future<String?> getDefaultProvider() async {
    return await _storage.read(key: 'default_provider');
  }

  Future<void> setDefaultModel(String provider, String model) async {
    await _storage.write(key: 'default_model_$provider', value: model);
  }

  Future<String?> getDefaultModel(String provider) async {
    return await _storage.read(key: 'default_model_$provider');
  }

  Future<void> setDefaultEffort(String provider, String effort) async {
    await _storage.write(key: 'default_effort_$provider', value: effort);
  }

  Future<String?> getDefaultEffort(String provider) async {
    return await _storage.read(key: 'default_effort_$provider');
  }
}
