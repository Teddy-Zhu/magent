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

  test('empty reasoning items are ignored', () async {
    await repo.applyRealtimeEvent({
      'type': 'session.item_started',
      'session_id': 's1',
      'item_id': 'r1',
      'turn_id': 't1',
      'created_at': DateTime(2026, 5, 1).toIso8601String(),
      'data': {
        'item': {
          'id': 'r1',
          'type': 'reasoning',
          'summary': <dynamic>[],
          'content': <dynamic>[],
        },
      },
    });
    await repo.applyRealtimeEvent({
      'type': 'session.item_completed',
      'session_id': 's1',
      'item_id': 'r1',
      'turn_id': 't1',
      'created_at': DateTime(2026, 5, 1, 0, 0, 1).toIso8601String(),
      'data': {
        'item': {
          'id': 'r1',
          'type': 'reasoning',
          'summary': <dynamic>[],
          'content': <dynamic>[],
        },
      },
    });

    final items = await db.getItemsBySession('agent-a', 's1');

    expect(items, isEmpty);
  });

  test('reasoning deltas with text are stored', () async {
    await repo.applyRealtimeEvent({
      'type': 'session.reasoning_summary_delta',
      'session_id': 's1',
      'item_id': 'r1',
      'turn_id': 't1',
      'created_at': DateTime(2026, 5, 1).toIso8601String(),
      'data': {'delta': 'thinking'},
    });

    final item = await db.getItem('agent-a', 's1', 'r1');

    expect(item, isNotNull);
    expect(item!.type, 'reasoning');
    expect(item.content, contains('thinking'));
  });

  test('historical command execution keeps provider fields', () async {
    fakeApi.items = [
      {
        'item_id': 'cmd-1',
        'turn_id': 'turn-1',
        'index': 1,
        'type': 'command_execution',
        'status': 'failed',
        'content': {
          'id': 'cmd-1',
          'type': 'commandExecution',
          'command': ['go', 'test', './...'],
          'cwd': '/repo',
          'status': 'failed',
          'aggregatedOutput': 'FAIL',
          'exitCode': 1,
          'commandActions': [
            {'type': 'rerun'},
          ],
        },
        'created_at': DateTime(2026, 5, 1).toIso8601String(),
        'updated_at': DateTime(2026, 5, 1, 0, 0, 1).toIso8601String(),
      },
    ];

    await repo.refreshItems('s1');
    final item = await db.getItem('agent-a', 's1', 'cmd-1');

    expect(item, isNotNull);
    expect(item!.type, 'command_execution');
    expect(item.content, contains('"cwd":"/repo"'));
    expect(item.content, contains('"aggregatedOutput":"FAIL"'));
    expect(item.content, contains('"output":"FAIL"'));
    expect(item.content, contains('"exitCode":1'));
    expect(item.content, contains('"exit_code":1'));
    expect(item.content, contains('commandActions'));
  });

  test(
    'historical sync does not overwrite richer realtime command item',
    () async {
      await repo.applyRealtimeEvent({
        'type': 'session.item_completed',
        'session_id': 's1',
        'item_id': 'cmd-1',
        'turn_id': 'turn-1',
        'created_at': DateTime(2026, 5, 1).toIso8601String(),
        'data': {
          'item': {
            'id': 'cmd-1',
            'type': 'commandExecution',
            'command': 'go test ./...',
            'cwd': '/repo',
            'status': 'completed',
            'aggregatedOutput': 'ok',
            'exitCode': 0,
          },
        },
      });
      fakeApi.items = [
        {
          'item_id': 'cmd-1',
          'turn_id': 'turn-1',
          'index': 1,
          'type': 'command_execution',
          'status': 'completed',
          'content': {
            'id': 'cmd-1',
            'type': 'commandExecution',
            'status': 'completed',
          },
          'created_at': DateTime(2026, 5, 1).toIso8601String(),
          'updated_at': DateTime(2026, 5, 1, 0, 0, 1).toIso8601String(),
        },
      ];

      await repo.refreshItems('s1');
      final item = await db.getItem('agent-a', 's1', 'cmd-1');

      expect(item, isNotNull);
      expect(item!.content, contains('"command":"go test ./..."'));
      expect(item.content, contains('"cwd":"/repo"'));
      expect(item.content, contains('"aggregatedOutput":"ok"'));
      expect(item.content, contains('"output":"ok"'));
    },
  );

  test(
    'refresh items reconciles history even when a cursor was stored',
    () async {
      await db.setSyncCursor('agent-a', 'session_items', 's1', 'newer:old');
      fakeApi.items = [
        {
          'item_id': 'cmd-1',
          'turn_id': 'turn-1',
          'index': 1,
          'type': 'command_execution',
          'status': 'completed',
          'content': {
            'id': 'cmd-1',
            'type': 'commandExecution',
            'command': 'go test ./...',
            'aggregatedOutput': 'ok',
            'exitCode': 0,
          },
          'created_at': DateTime(2026, 5, 1).toIso8601String(),
          'updated_at': DateTime(2026, 5, 1, 0, 0, 1).toIso8601String(),
        },
      ];

      await repo.refreshItems('s1', forceFull: true);

      expect(fakeApi.itemRequestCursors, [isNull]);
      final item = await db.getItem('agent-a', 's1', 'cmd-1');
      expect(item, isNotNull);
      expect(item!.content, contains('"command":"go test ./..."'));
      expect(item.content, contains('"output":"ok"'));
    },
  );

  test('refresh items uses stored cursor by default', () async {
    await db.setSyncCursor('agent-a', 'session_items', 's1', 'newer:old');

    await repo.refreshItems('s1');

    expect(fakeApi.itemRequestCursors, ['newer:old']);
  });

  test('refresh items skips unchanged cached rows', () async {
    final createdAt = DateTime(2026, 5, 1);
    final updatedAt = DateTime(2026, 5, 1, 0, 0, 1);
    fakeApi.items = [
      {
        'item_id': 'msg-1',
        'turn_id': 'turn-1',
        'index': 1,
        'type': 'agent_message',
        'status': 'completed',
        'content': {'id': 'msg-1', 'type': 'agentMessage', 'text': 'hello'},
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      },
    ];

    await repo.refreshItems('s1', forceFull: true);
    final first = await db.getItem('agent-a', 's1', 'msg-1');
    await repo.refreshItems('s1', forceFull: true);
    final second = await db.getItem('agent-a', 's1', 'msg-1');

    expect(second, isNotNull);
    expect(second!.updatedAt, first!.updatedAt);
    expect(second.content, first.content);
  });

  test('refresh items ignores timestamp-only provider changes', () async {
    final createdAt = DateTime(2026, 5, 1);
    fakeApi.items = [
      {
        'item_id': 'msg-1',
        'turn_id': 'turn-1',
        'index': 1,
        'type': 'agent_message',
        'status': 'completed',
        'content': {'id': 'msg-1', 'type': 'agentMessage', 'text': 'hello'},
        'created_at': createdAt.toIso8601String(),
        'updated_at': DateTime(2026, 5, 1, 0, 0, 1).toIso8601String(),
      },
    ];
    await repo.refreshItems('s1', forceFull: true);
    final first = await db.getItem('agent-a', 's1', 'msg-1');

    fakeApi.items = [
      {
        'item_id': 'msg-1',
        'turn_id': 'turn-1',
        'index': 1,
        'type': 'agent_message',
        'status': 'completed',
        'content': {'id': 'msg-1', 'type': 'agentMessage', 'text': 'hello'},
        'created_at': createdAt.toIso8601String(),
        'updated_at': DateTime(2026, 5, 1, 0, 0, 2).toIso8601String(),
      },
    ];
    await repo.refreshItems('s1', forceFull: true);
    final second = await db.getItem('agent-a', 's1', 'msg-1');

    expect(second, isNotNull);
    expect(second!.updatedAt, first!.updatedAt);
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
    final events = await db.getEventsBySession('agent-a', 's1');
    expect(events, isEmpty);
  });

  test('active and archived session refreshes reconcile separately', () async {
    fakeApi.sessions = [
      {
        'id': 'active-1',
        'provider_id': 'codex',
        'project_id': 'p1',
        'status': {'type': 'notLoaded'},
        'created_at': DateTime(2026, 5, 1).toIso8601String(),
        'updated_at': DateTime(2026, 5, 1).toIso8601String(),
      },
    ];
    await repo.refreshSessions('p1');

    fakeApi.sessions = [
      {
        'id': 'archived-1',
        'provider_id': 'codex',
        'project_id': 'p1',
        'status': {'type': 'notLoaded'},
        'created_at': DateTime(2026, 4, 30).toIso8601String(),
        'updated_at': DateTime(2026, 4, 30).toIso8601String(),
      },
    ];
    await repo.refreshSessions('p1', archived: true);

    final active = await db.getSessionsByProjectArchived(
      'agent-a',
      'p1',
      archived: false,
    );
    final archived = await db.getSessionsByProjectArchived(
      'agent-a',
      'p1',
      archived: true,
    );

    expect(active.map((s) => s.id), ['active-1']);
    expect(archived.map((s) => s.id), ['archived-1']);
    expect(archived.single.archivedAt, isNotNull);
  });
}

class _FakeSessionApi implements SessionApiLike {
  List<dynamic> sessions = [];
  List<dynamic> items = [];
  final List<String?> itemRequestCursors = [];

  @override
  Future<void> approve(
    String sessionId,
    String approvalId,
    String action,
  ) async {}

  @override
  Future<void> archive(String sessionId) async {}

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
  }) async {
    itemRequestCursors.add(cursor);
    return {'items': items, 'cursor': cursor};
  }

  @override
  Future<Map<String, dynamic>> getSession(String id) async => {'id': id};

  @override
  Future<void> interrupt(String sessionId) async {}

  @override
  Future<List<dynamic>> listSessions(
    String projectId, {
    bool archived = false,
  }) async => sessions;

  @override
  Future<void> deleteSession(String sessionId) async {}

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

  @override
  Future<Map<String, dynamic>> unarchive(String sessionId) async => {
    'id': sessionId,
  };
}
