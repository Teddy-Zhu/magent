import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magent_app/core/api/api_client.dart';
import 'package:magent_app/core/api/git_api.dart';
import 'package:magent_app/core/api/session_api.dart';
import 'package:magent_app/core/api/file_api.dart';
import 'package:magent_app/core/storage/secure_storage.dart';

final secureStorageProvider = Provider<AgentStorage>((ref) => AgentStorage());

class AppApiClient {
  final ApiClient _client;
  late final GitApi git;
  late final SessionApi session;
  late final FileApi file;

  AppApiClient(this._client) {
    git = GitApi(_client.dio);
    session = SessionApi(_client.dio);
    file = FileApi(_client.dio);
  }

  ApiClient get client => _client;
}

/// Creates an AppApiClient from agent URL and token.
AppApiClient createApiClient(String url, String token) {
  return AppApiClient(ApiClient(baseUrl: url, token: token));
}

/// Loads the active agent's API client from secure storage.
/// Returns null if no agent is configured.
Future<AppApiClient?> loadActiveApi(WidgetRef ref) async {
  final storage = ref.read(secureStorageProvider);
  final agents = await storage.loadAgents();
  if (agents.isEmpty) return null;

  final activeId = await storage.getActiveAgentId();
  Map<String, String>? agent;
  if (activeId != null) {
    for (final a in agents) {
      if (a['id'] == activeId) {
        agent = a;
        break;
      }
    }
  }
  agent ??= agents.first;

  return createApiClient(agent['url'] ?? '', agent['token'] ?? '');
}
