import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magent_app/core/api/api_client.dart';
import 'package:magent_app/core/api/git_api.dart';
import 'package:magent_app/core/api/session_api.dart';
import 'package:magent_app/core/api/file_api.dart';
import 'package:magent_app/core/repositories/bootstrap_repository.dart';
import 'package:magent_app/core/repositories/session_repository.dart';
import 'package:magent_app/core/sync/realtime_service.dart';
import 'package:magent_app/core/sync/sync_engine.dart';
import 'package:magent_app/core/storage/secure_storage.dart';
import 'package:magent_app/core/storage/app_database.dart';

final secureStorageProvider = Provider<AgentStorage>((ref) => AgentStorage());

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

class AppApiClient {
  final String agentId;
  final ApiClient _client;
  late final GitApi git;
  late final SessionApi session;
  late final FileApi file;

  AppApiClient({required this.agentId, required ApiClient client})
    : _client = client {
    git = GitApi(_client.dio);
    session = SessionApi(_client.dio);
    file = FileApi(_client.dio);
  }

  ApiClient get client => _client;
}

/// Creates an AppApiClient from agent URL and token.
AppApiClient createApiClient(String url, String token, {String? agentId}) {
  return AppApiClient(
    agentId: agentId ?? url,
    client: ApiClient(baseUrl: url, token: token),
  );
}

/// Loads the active agent's API client from secure storage.
/// Returns null if no agent is configured.
Future<AppApiClient?> loadActiveApi(WidgetRef ref) async {
  return ref.read(activeApiProvider.future);
}

final activeApiProvider = FutureProvider<AppApiClient?>((ref) async {
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

  return createApiClient(
    agent['url'] ?? '',
    agent['token'] ?? '',
    agentId: agent['id'],
  );
});

BootstrapRepository createBootstrapRepository(WidgetRef ref, AppApiClient api) {
  return BootstrapRepository(
    agentId: api.agentId,
    dio: api.client.dio,
    db: ref.read(appDatabaseProvider),
  );
}

final realtimeServiceProvider = Provider<RealtimeService?>((ref) {
  final api = ref
      .watch(activeApiProvider)
      .when(data: (api) => api, error: (_, _) => null, loading: () => null);
  if (api == null) return null;
  final service = RealtimeService(
    url: api.client.baseUrl,
    token: api.client.token,
  );
  service.start();
  ref.onDispose(service.dispose);
  return service;
});

final syncEngineProvider = Provider<SyncEngine?>((ref) {
  final api = ref
      .watch(activeApiProvider)
      .when(data: (api) => api, error: (_, _) => null, loading: () => null);
  final realtime = ref.watch(realtimeServiceProvider);
  if (api == null || realtime == null) return null;
  final db = ref.read(appDatabaseProvider);
  final engine = SyncEngine(
    realtime: realtime,
    bootstrap: BootstrapRepository(
      agentId: api.agentId,
      dio: api.client.dio,
      db: db,
    ),
    sessions: SessionRepository(agentId: api.agentId, api: api.session, db: db),
  );
  engine.start();
  ref.onDispose(engine.dispose);
  return engine;
});
