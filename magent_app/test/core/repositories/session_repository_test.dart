import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magent_app/core/repositories/session_repository.dart';
import 'package:magent_app/core/storage/app_database.dart';

void main() {
  late AppDatabase db;
  late SessionRepository repo;
  late _FakeSessionApi fakeApi;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    fakeApi = _FakeSessionApi();
    repo = SessionRepository(agentId: 'agent-a', api: fakeApi, db: db);
  });

  tearDown(() async {
    await db.close();
  });

  test('pending user message is stored as local session item', () async {
    await repo.addPendingUserMessage('s1', 'hello');

    final items = await db.getItemsBySession('agent-a', 's1');

    expect(items, hasLength(1));
    expect(items.single.type, 'user_message');
    expect(items.single.status, 'pending');
    expect(items.single.role, 'user');
    expect(items.single.content, contains('hello'));
  });

  test('real user message removes matching local pending item', () async {
    await repo.addPendingUserMessage('s1', 'hello');

    await repo.applyRealtimeEvent({
      'type': 'session.user_message',
      'session_id': 's1',
      'item_id': 'real-user-1',
      'created_at': DateTime(2026, 5, 1).toIso8601String(),
      'data': {'id': 'real-user-1', 'type': 'userMessage', 'content': 'hello'},
    });

    final items = await db.getItemsBySession('agent-a', 's1');

    expect(items, hasLength(1));
    expect(items.single.itemId, 'real-user-1');
    expect(items.single.type, 'user_message');
    expect(items.single.status, 'completed');
  });

  test(
    'session items are ordered by provider item index before timestamp',
    () async {
      await db.insertOrUpdateItems([
        SessionItemEntriesCompanion.insert(
          agentId: 'agent-a',
          sessionId: 's1',
          itemId: 'assistant',
          type: 'agent_message',
          content: const Value('{"text":"reply"}'),
          itemIndex: const Value(2),
          createdAt: DateTime(2026, 5, 1),
          updatedAt: DateTime(2026, 5, 1),
        ),
        SessionItemEntriesCompanion.insert(
          agentId: 'agent-a',
          sessionId: 's1',
          itemId: 'user',
          type: 'user_message',
          content: const Value('{"text":"hello"}'),
          itemIndex: const Value(1),
          createdAt: DateTime(2026, 5, 1, 0, 0, 5),
          updatedAt: DateTime(2026, 5, 1, 0, 0, 5),
        ),
      ]);

      final items = await db.getItemsBySession('agent-a', 's1');

      expect(items.map((item) => item.itemId), ['user', 'assistant']);
    },
  );

  test('realtime deltas update item projection and ws cursor', () async {
    await repo.applyRealtimeEvent({
      'type': 'session.message_delta',
      'session_id': 's1',
      'item_id': 'i1',
      'turn_id': 't1',
      'ws_cursor': 'ws:1',
      'cursor': 'provider:1',
      'created_at': DateTime(2026, 5, 1).toIso8601String(),
      'data': {'delta': 'hel'},
    });
    await repo.applyRealtimeEvent({
      'type': 'session.message_delta',
      'session_id': 's1',
      'item_id': 'i1',
      'turn_id': 't1',
      'ws_cursor': 'ws:2',
      'cursor': 'provider:2',
      'created_at': DateTime(2026, 5, 1, 0, 0, 1).toIso8601String(),
      'data': {'delta': 'lo'},
    });

    final item = await db.getItem('agent-a', 's1', 'i1');
    final cursor = await repo.getRealtimeCursor('s1');

    expect(item, isNotNull);
    expect(item!.type, 'agent_message');
    expect(item.role, 'assistant');
    expect(item.content, contains('hello'));
    expect(cursor, 'ws:2');
  });

  test('realtime session status changes update local session row', () async {
    fakeApi.sessions = [
      {
        'id': 's1',
        'provider_id': 'codex',
        'project_id': 'p1',
        'status': {'type': 'notLoaded'},
        'created_at': DateTime(2026, 5, 1).toIso8601String(),
        'updated_at': DateTime(2026, 5, 1).toIso8601String(),
      },
    ];

    await repo.refreshSessions('p1');
    var session = await db.getSession('agent-a', 's1');
    expect(session?.status, 'stopped');

    await repo.applyRealtimeEvent({
      'type': 'session.status_changed',
      'session_id': 's1',
      'data': {
        'threadId': 's1',
        'status': {'type': 'active'},
      },
    });

    session = await db.getSession('agent-a', 's1');
    expect(session?.status, 'running');
  });
}

class _FakeSessionApi implements SessionApiLike {
  List<dynamic> sessions = [];

  @override
  Future<void> approve(
    String sessionId,
    String approvalId,
    String action,
  ) async {}

  @override
  Future<Map<String, dynamic>> createSession({
    required String providerId,
    required String projectId,
    String? model,
    String? effort,
    String? approvalPolicy,
    String? sandboxMode,
    String? prompt,
  }) async => {};

  @override
  Future<Map<String, dynamic>> fork(String sessionId) async => {};

  @override
  Future<Map<String, dynamic>> getEventsPage(
    String sessionId, {
    String? cursor,
    int limit = 500,
  }) async => {'events': <dynamic>[], 'cursor': cursor};

  @override
  Future<Map<String, dynamic>> getItemsPage(
    String sessionId, {
    String? cursor,
    int limit = 200,
  }) async => {'items': <dynamic>[], 'cursor': cursor};

  @override
  Future<Map<String, dynamic>> getSession(String id) async => {'id': id};

  @override
  Future<void> interrupt(String sessionId) async {}

  @override
  Future<List<dynamic>> listSessions(String projectId) async => sessions;

  @override
  Future<void> resume(String sessionId) async {}

  @override
  Future<void> sendInput(
    String sessionId,
    String input, {
    List<Map<String, dynamic>> items = const [],
    String? mode,
  }) async {}

  @override
  Future<void> stop(String sessionId) async {}
}
