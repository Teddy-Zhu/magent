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

    fakeApi.items = [
      {
        'item_id': 'real-user-1',
        'turn_id': 'turn-1',
        'index': 1,
        'type': 'user_message',
        'status': 'completed',
        'content': {
          'id': 'real-user-1',
          'type': 'userMessage',
          'content': 'hello',
        },
        'created_at': DateTime(2026, 5, 1).toIso8601String(),
        'updated_at': DateTime(2026, 5, 1).toIso8601String(),
      },
    ];
    await repo.refreshItems('s1', forceFull: true);

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

  test('realtime item deltas are hints and only advance ws cursor', () async {
    final firstApplied = await repo.applyRealtimeEvent({
      'type': 'session.message_delta',
      'session_id': 's1',
      'item_id': 'i1',
      'turn_id': 't1',
      'ws_cursor': 'ws:1',
      'cursor': 'provider:1',
      'created_at': DateTime(2026, 5, 1).toIso8601String(),
      'data': {'delta': 'hel'},
    });
    final secondApplied = await repo.applyRealtimeEvent({
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

    expect(firstApplied, isFalse);
    expect(secondApplied, isFalse);
    expect(item, isNull);
    expect(cursor, 'ws:2');
  });

  test('realtime duplicate events at stored ws cursor are ignored', () async {
    final event = {
      'type': 'session.message_delta',
      'session_id': 's1',
      'item_id': 'i1',
      'turn_id': 't1',
      'ws_cursor': '1',
      'created_at': DateTime(2026, 5, 1).toIso8601String(),
      'data': {'delta': 'hel'},
    };

    final firstApplied = await repo.applyRealtimeEvent(event);
    final duplicateApplied = await repo.applyRealtimeEvent(event);

    final item = await db.getItem('agent-a', 's1', 'i1');
    expect(firstApplied, isFalse);
    expect(duplicateApplied, isFalse);
    expect(item, isNull);
  });

  test('lower ws cursor after agent restart is still applied', () async {
    await db.setSyncCursor('agent-a', 'session_ws', 's1', '24');
    await db.setSyncCursor('agent-a', 'session_ws_epoch', 's1', 'old');

    final applied = await repo.applyRealtimeEvent({
      'type': 'session.message_delta',
      'session_id': 's1',
      'item_id': 'i1',
      'turn_id': 't1',
      'ws_cursor': '1',
      'ws_epoch': 'new',
      'created_at': DateTime(2026, 5, 1).toIso8601String(),
      'data': {'delta': 'new'},
    });

    final item = await db.getItem('agent-a', 's1', 'i1');
    final cursor = await repo.getRealtimeCursor('s1');
    final epoch = await repo.getRealtimeEpoch('s1');

    expect(applied, isFalse);
    expect(item, isNull);
    expect(cursor, '1');
    expect(epoch, 'new');
  });

  test('lower ws cursor in same epoch is ignored', () async {
    await db.setSyncCursor('agent-a', 'session_ws', 's1', '24');
    await db.setSyncCursor('agent-a', 'session_ws_epoch', 's1', 'same');

    final applied = await repo.applyRealtimeEvent({
      'type': 'session.message_delta',
      'session_id': 's1',
      'item_id': 'i1',
      'turn_id': 't1',
      'ws_cursor': '1',
      'ws_epoch': 'same',
      'created_at': DateTime(2026, 5, 1).toIso8601String(),
      'data': {'delta': 'old'},
    });

    final item = await db.getItem('agent-a', 's1', 'i1');

    expect(applied, isFalse);
    expect(item, isNull);
  });

  test('epoch-prefixed ws cursor is deduplicated within same epoch', () async {
    await db.setSyncCursor('agent-a', 'session_ws', 's1', 'same:24');

    final applied = await repo.applyRealtimeEvent({
      'type': 'session.message_delta',
      'session_id': 's1',
      'item_id': 'i1',
      'turn_id': 't1',
      'ws_cursor': 'same:1',
      'created_at': DateTime(2026, 5, 1).toIso8601String(),
      'data': {'delta': 'old'},
    });

    final item = await db.getItem('agent-a', 's1', 'i1');

    expect(applied, isFalse);
    expect(item, isNull);
  });

  test('epoch-prefixed ws cursor with new epoch is applied', () async {
    await db.setSyncCursor('agent-a', 'session_ws', 's1', 'old:24');

    final applied = await repo.applyRealtimeEvent({
      'type': 'session.message_delta',
      'session_id': 's1',
      'item_id': 'i1',
      'turn_id': 't1',
      'ws_cursor': 'new:1',
      'created_at': DateTime(2026, 5, 1).toIso8601String(),
      'data': {'delta': 'new'},
    });

    final item = await db.getItem('agent-a', 's1', 'i1');

    expect(applied, isFalse);
    expect(item, isNull);
  });

  test('delta after completed item from catch-up is dropped', () async {
    fakeApi.items = [
      {
        'item_id': 'msg-1',
        'turn_id': 'turn-1',
        'index': 1,
        'type': 'agent_message',
        'status': 'completed',
        'content': {'id': 'msg-1', 'type': 'agentMessage', 'text': 'hello'},
        'created_at': DateTime(2026, 5, 1).toIso8601String(),
        'updated_at': DateTime(2026, 5, 1).toIso8601String(),
      },
    ];
    await repo.refreshItems('s1');

    final applied = await repo.applyRealtimeEvent({
      'type': 'session.message_delta',
      'session_id': 's1',
      'item_id': 'msg-1',
      'turn_id': 'turn-1',
      'ws_cursor': '2',
      'created_at': DateTime(2026, 5, 1, 0, 0, 1).toIso8601String(),
      'data': {'delta': 'hello'},
    });

    final item = await db.getItem('agent-a', 's1', 'msg-1');
    final cursor = await repo.getRealtimeCursor('s1');

    expect(applied, isFalse);
    expect(item?.content, contains('"text":"hello"'));
    expect(item?.content, isNot(contains('hellohello')));
    expect(cursor, '2');
  });

  test('plan and diff realtime updates are projection hints', () async {
    final planApplied = await repo.applyRealtimeEvent({
      'type': 'session.plan_updated',
      'session_id': 's1',
      'turn_id': 'turn-1',
      'created_at': DateTime(2026, 5, 1).toIso8601String(),
      'data': {
        'explanation': 'plan',
        'plan': [
          {'step': 'one', 'status': 'inProgress'},
        ],
      },
    });
    final diffApplied = await repo.applyRealtimeEvent({
      'type': 'session.diff_updated',
      'session_id': 's1',
      'turn_id': 'turn-1',
      'created_at': DateTime(2026, 5, 1, 0, 0, 1).toIso8601String(),
      'data': {'summary': 'diff'},
    });

    final items = await db.getItemsBySession('agent-a', 's1');

    expect(planApplied, isFalse);
    expect(diffApplied, isFalse);
    expect(items, isEmpty);
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

  test('reasoning deltas are projection hints', () async {
    await repo.applyRealtimeEvent({
      'type': 'session.reasoning_summary_delta',
      'session_id': 's1',
      'item_id': 'r1',
      'turn_id': 't1',
      'created_at': DateTime(2026, 5, 1).toIso8601String(),
      'data': {'delta': 'thinking'},
    });

    final item = await db.getItem('agent-a', 's1', 'r1');

    expect(item, isNull);
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

  test('snapshot replaces cached provider item content', () async {
    await db.insertOrUpdateItem(
      SessionItemEntriesCompanion.insert(
        agentId: 'agent-a',
        sessionId: 's1',
        itemId: 'cmd-1',
        type: 'command_execution',
        status: const Value('completed'),
        content: const Value(
          '{"id":"cmd-1","type":"commandExecution","command":"stale"}',
        ),
        itemIndex: const Value(1),
        createdAt: DateTime(2026, 5, 1),
        updatedAt: DateTime(2026, 5, 1),
      ),
    );
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
    expect(item!.content, isNot(contains('"command":"stale"')));
    expect(item.content, contains('"status":"completed"'));
  });

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

  test('delete session cache clears websocket epoch cursor', () async {
    await db.setSyncCursor('agent-a', 'session_ws', 's1', 'old:24');
    await db.setSyncCursor('agent-a', 'session_ws_epoch', 's1', 'old');
    fakeApi.revision = 1;
    fakeApi.items = [
      {
        'item_id': 'msg-1',
        'turn_id': 'turn-1',
        'index': 1,
        'revision': 1,
        'type': 'agent_message',
        'status': 'completed',
        'content': {'id': 'msg-1', 'type': 'agentMessage', 'text': 'hello'},
        'created_at': DateTime(2026, 5, 1).toIso8601String(),
        'updated_at': DateTime(2026, 5, 1).toIso8601String(),
      },
    ];

    await repo.refreshItems('s1', forceFull: true);
    await db.deleteSessionCache('agent-a', 's1');

    expect(await repo.getRealtimeCursor('s1'), isNull);
    expect(await repo.getRealtimeEpoch('s1'), isNull);
  });

  test('refresh items applies revision changes by default', () async {
    await db.setSyncState('agent-a', 'session_items', 's1', revision: 1);
    fakeApi.revision = 2;
    fakeApi.changes = [
      {
        'revision': 2,
        'op': 'upsert',
        'item_id': 'msg-next',
        'item': {
          'item_id': 'msg-next',
          'turn_id': 'turn-2',
          'index': 2,
          'revision': 2,
          'type': 'agent_message',
          'status': 'completed',
          'content': {'id': 'msg-next', 'type': 'agentMessage', 'text': 'next'},
          'created_at': DateTime(2026, 5, 1, 0, 0, 1).toIso8601String(),
          'updated_at': DateTime(2026, 5, 1, 0, 0, 1).toIso8601String(),
        },
      },
    ];

    await repo.refreshItems('s1');

    expect(fakeApi.itemChangeRequestRevisions, [1]);
    expect(fakeApi.itemChangeRequestReconciles, [true]);
    final items = await db.getItemsBySession('agent-a', 's1');
    expect(items.map((item) => item.itemId), ['msg-next']);
    expect(await repo.getItemRevision('s1'), 2);
  });

  test('refresh items stores codex app-server tool call projections', () async {
    fakeApi.items = [
      {
        'item_id': 'call_9aeFf1ciI8rUGMFPARv8L5PM',
        'turn_id': '019de8f9-e',
        'index': 177773014500022,
        'type': 'command_execution',
        'status': 'completed',
        'summary': 'nl -ba docs/dev/prepare/enginev4综合优化实施计划.md',
        'content': {
          'id': 'call_9aeFf1ciI8rUGMFPARv8L5PM',
          'type': 'commandExecution',
          'command':
              '/usr/bin/zsh -lc "nl -ba docs/dev/prepare/enginev4综合优化实施计划.md | sed -n \'990,1040p\'"',
          'cwd': '/home/teddyhp/code/python_web_template',
          'aggregatedOutput': '   990\tDivergenceIndex int\n',
          'exitCode': 0,
        },
        'created_at': DateTime(2026, 5, 2, 14, 4, 45).toIso8601String(),
        'updated_at': DateTime(2026, 5, 2, 14, 5, 7).toIso8601String(),
      },
      {
        'item_id': 'call_FcpXP8t6AwbUOO6obYCuhMbB',
        'turn_id': '019de8f9-e',
        'index': 177773014500023,
        'type': 'command_execution',
        'status': 'completed',
        'content': {
          'id': 'call_FcpXP8t6AwbUOO6obYCuhMbB',
          'type': 'commandExecution',
          'command':
              '/usr/bin/zsh -lc "nl -ba docs/dev/prepare/enginev4综合优化实施计划.md | sed -n \'1065,1118p\'"',
          'cwd': '/home/teddyhp/code/python_web_template',
          'aggregatedOutput': '  1065\tmetrics.go\n',
          'exitCode': 0,
        },
        'created_at': DateTime(2026, 5, 2, 14, 4, 45).toIso8601String(),
        'updated_at': DateTime(2026, 5, 2, 14, 5, 7).toIso8601String(),
      },
      {
        'item_id': 'call_50BanriSB8wfP52Zwql6mnbN',
        'turn_id': '019de8f9-e',
        'index': 177773014500021,
        'type': 'file_change',
        'status': 'completed',
        'content': {
          'id': 'call_50BanriSB8wfP52Zwql6mnbN',
          'type': 'fileChange',
          'changes': [
            {
              'path':
                  '/home/teddyhp/code/python_web_template/docs/dev/prepare/enginev4综合优化实施计划.md',
              'kind': {'type': 'update', 'move_path': null},
              'diff': '@@ -271,2 +271,3 @@\n+类型落位：\n',
            },
          ],
        },
        'created_at': DateTime(2026, 5, 2, 14, 4, 45).toIso8601String(),
        'updated_at': DateTime(2026, 5, 2, 14, 5, 7).toIso8601String(),
      },
    ];

    await repo.refreshItems('s1', forceFull: true);

    final commandA = await db.getItem(
      'agent-a',
      's1',
      'call_9aeFf1ciI8rUGMFPARv8L5PM',
    );
    final commandB = await db.getItem(
      'agent-a',
      's1',
      'call_FcpXP8t6AwbUOO6obYCuhMbB',
    );
    final fileChange = await db.getItem(
      'agent-a',
      's1',
      'call_50BanriSB8wfP52Zwql6mnbN',
    );

    expect(commandA, isNotNull);
    expect(commandA!.type, 'command_execution');
    expect(commandA.content, contains('"output":"   990'));
    expect(commandA.content, contains('"exit_code":0'));
    expect(commandB, isNotNull);
    expect(commandB!.content, contains('1065'));
    expect(fileChange, isNotNull);
    expect(fileChange!.type, 'file_change');
    expect(fileChange.content, contains('"diff":"@@ -271'));
  });

  test(
    'force refresh replaces stale realtime items with provider snapshot',
    () async {
      await db.insertOrUpdateItem(
        SessionItemEntriesCompanion.insert(
          agentId: 'agent-a',
          sessionId: 's1',
          itemId: 'stale-realtime',
          type: 'command_execution',
          status: const Value('in_progress'),
          content: const Value('{"output":"old"}'),
          itemIndex: const Value(999999999),
          createdAt: DateTime(2026, 5, 2, 14, 0),
          updatedAt: DateTime(2026, 5, 2, 14, 0),
        ),
      );
      await repo.addPendingUserMessage('s1', 'pending input');
      fakeApi.items = [
        {
          'item_id': 'call_FcpXP8t6AwbUOO6obYCuhMbB',
          'turn_id': '019de8f9-e',
          'index': 177773014500036,
          'type': 'command_execution',
          'status': 'completed',
          'content': {
            'id': 'call_FcpXP8t6AwbUOO6obYCuhMbB',
            'type': 'commandExecution',
            'command': 'nl -ba docs/dev/prepare/enginev4综合优化实施计划.md',
            'aggregatedOutput': '  1065\tmetrics.go\n',
            'exitCode': 0,
          },
          'created_at': DateTime(2026, 5, 2, 14, 4, 45).toIso8601String(),
          'updated_at': DateTime(2026, 5, 2, 14, 5, 7).toIso8601String(),
        },
      ];

      await repo.refreshItems('s1', forceFull: true);

      expect(await db.getItem('agent-a', 's1', 'stale-realtime'), isNull);
      expect(
        await db.getItem('agent-a', 's1', 'call_FcpXP8t6AwbUOO6obYCuhMbB'),
        isNotNull,
      );
      final items = await db.getItemsBySession('agent-a', 's1');
      expect(items.any((item) => item.itemId.startsWith('local-')), isTrue);
    },
  );

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
  List<dynamic> changes = [];
  int revision = 1;
  final Map<String?, List<dynamic>> itemsByCursor = {};
  final Map<String?, String?> pageCursors = {};
  final Map<String?, bool> pageHasMore = {};
  final List<String?> itemRequestCursors = [];
  final List<int> itemChangeRequestRevisions = [];
  final List<bool> itemChangeRequestReconciles = [];

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
    return {
      'items': itemsByCursor[cursor] ?? items,
      'cursor': pageCursors.containsKey(cursor) ? pageCursors[cursor] : cursor,
      'has_more': pageHasMore[cursor] ?? false,
    };
  }

  @override
  Future<Map<String, dynamic>> getItemsSnapshot(String sessionId) async {
    itemRequestCursors.add(null);
    return {'items': itemsByCursor[null] ?? items, 'revision': revision};
  }

  @override
  Future<Map<String, dynamic>> getItemChanges(
    String sessionId, {
    required int afterRevision,
    int limit = 500,
    bool reconcile = false,
  }) async {
    itemChangeRequestRevisions.add(afterRevision);
    itemChangeRequestReconciles.add(reconcile);
    return {
      'changes': changes,
      'to_revision': revision,
      'has_more': false,
      'reset_required': false,
    };
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
    String? model,
    String? effort,
    String? approvalPolicy,
    String? sandboxMode,
  }) async {}

  @override
  Future<void> stop(String sessionId) async {}

  @override
  Future<Map<String, dynamic>> unarchive(String sessionId) async => {
    'id': sessionId,
  };
}
