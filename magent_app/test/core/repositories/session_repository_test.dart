import 'dart:async';

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
    await repo.loadLatestItemsPage('s1');

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
    await repo.loadLatestItemsPage('s1');

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

    await repo.loadLatestItemsPage('s1');
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

  test('window refresh replaces cached provider item content', () async {
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

    await repo.loadLatestItemsPage('s1');
    final item = await db.getItem('agent-a', 's1', 'cmd-1');

    expect(item, isNotNull);
    expect(item!.content, isNot(contains('"command":"stale"')));
    expect(item.content, contains('"status":"completed"'));
  });

  test('latest window ignores older-page cursor state', () async {
    await db.setSyncCursor('agent-a', 'session_items_older', 's1', 'newer:old');
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

    await repo.loadLatestItemsPage('s1');

    expect(fakeApi.itemRequestCursors, [isNull]);
    final item = await db.getItem('agent-a', 's1', 'cmd-1');
    expect(item, isNotNull);
    expect(item!.content, contains('"command":"go test ./..."'));
    expect(item.content, contains('"output":"ok"'));
  });

  test('latest window requires a cursor before exposing older items', () async {
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
    fakeApi.pageHasMore[null] = true;

    final page = await repo.loadLatestItemsPage('s1');

    expect(page.hasOlder, isFalse);
    expect(page.olderCursor, isNull);
    expect(await db.getSyncCursor('agent-a', 'session_items_older', 's1'), '');
  });

  test('has older items reflects stored older-page cursor', () async {
    expect(await repo.hasOlderItems('s1'), isFalse);

    await db.setSyncCursor('agent-a', 'session_items_older', 's1', 'older-1');

    expect(await repo.hasOlderItems('s1'), isTrue);
  });

  test(
    'latest page replaces older cursor with current window cursor',
    () async {
      fakeApi.items = [
        for (var i = 0; i < 3; i++)
          {
            'item_id': 'cached-$i',
            'turn_id': 'turn-$i',
            'index': i,
            'type': 'agent_message',
            'status': 'completed',
            'content': {
              'id': 'cached-$i',
              'type': 'agentMessage',
              'text': 'cached $i',
            },
            'created_at': DateTime(2026, 5, 1, 0, 0, i).toIso8601String(),
            'updated_at': DateTime(2026, 5, 1, 0, 0, i).toIso8601String(),
          },
      ];
      fakeApi.pageCursors[null] = 'older:after-latest';
      fakeApi.pageHasMore[null] = true;

      await repo.loadLatestItemsPage('s1', limit: 3);
      expect(
        await db.getSyncCursor('agent-a', 'session_items_older', 's1'),
        'older:after-latest',
      );

      fakeApi.items = [
        {
          'item_id': 'cached-2',
          'turn_id': 'turn-2',
          'index': 2,
          'type': 'agent_message',
          'status': 'completed',
          'content': {
            'id': 'cached-2',
            'type': 'agentMessage',
            'text': 'cached 2',
          },
          'created_at': DateTime(2026, 5, 1, 0, 0, 2).toIso8601String(),
          'updated_at': DateTime(2026, 5, 1, 0, 0, 2).toIso8601String(),
        },
      ];
      fakeApi.pageCursors[null] = 'older:after-one';

      await repo.loadLatestItemsPage('s1', limit: 1);

      expect(
        await db.getSyncCursor('agent-a', 'session_items_older', 's1'),
        'older:after-one',
      );
    },
  );

  test('reload latest item window keeps a continuous tail window', () async {
    await db.insertOrUpdateItems([
      SessionItemEntriesCompanion.insert(
        agentId: 'agent-a',
        sessionId: 's1',
        itemId: 'old-1',
        turnId: const Value('turn-old'),
        type: 'agent_message',
        status: const Value('completed'),
        content: const Value('{"text":"old"}'),
        itemIndex: const Value(1),
        createdAt: DateTime(2026, 5, 1),
        updatedAt: DateTime(2026, 5, 1),
      ),
      SessionItemEntriesCompanion.insert(
        agentId: 'agent-a',
        sessionId: 's1',
        itemId: 'old-2',
        turnId: const Value('turn-older'),
        type: 'agent_message',
        status: const Value('completed'),
        content: const Value('{"text":"older"}'),
        itemIndex: const Value(2),
        createdAt: DateTime(2026, 5, 1, 0, 0, 1),
        updatedAt: DateTime(2026, 5, 1, 0, 0, 1),
      ),
    ]);
    await repo.addPendingUserMessage('s1', 'pending input');
    await db.setSyncCursor(
      'agent-a',
      'session_items_older',
      's1',
      'older:stale',
    );
    await db.setSyncState('agent-a', 'session_items', 's1', revision: 42);

    fakeApi.items = [
      {
        'item_id': 'latest-1',
        'turn_id': 'turn-latest',
        'index': 100,
        'type': 'agent_message',
        'status': 'completed',
        'content': {'id': 'latest-1', 'type': 'agentMessage', 'text': 'latest'},
        'created_at': DateTime(2026, 5, 1, 0, 2).toIso8601String(),
        'updated_at': DateTime(2026, 5, 1, 0, 2).toIso8601String(),
      },
    ];
    fakeApi.pageCursors[null] = 'older:after-latest';
    fakeApi.pageHasMore[null] = true;

    final page = await repo.reloadLatestItemsPage('s1', limit: 1);
    final items = await db.getItemsBySession('agent-a', 's1');

    expect(page.hasOlder, isTrue);
    expect(page.olderCursor, 'older:after-latest');
    expect(items.map((item) => item.itemId), contains('latest-1'));
    expect(items.any((item) => item.itemId.startsWith('local-')), isTrue);
    expect(items.map((item) => item.itemId), isNot(contains('old-1')));
    expect(items.map((item) => item.itemId), isNot(contains('old-2')));
    expect(
      await db.getSyncCursor('agent-a', 'session_items_older', 's1'),
      'older:after-latest',
    );
    expect(await repo.getItemRevision('s1'), 0);
  });

  test('older page continues from reloaded latest window cursor', () async {
    fakeApi.itemsByCursor[null] = [
      {
        'item_id': 'latest-1',
        'turn_id': 'turn-latest',
        'index': 100,
        'type': 'agent_message',
        'status': 'completed',
        'content': {'id': 'latest-1', 'type': 'agentMessage', 'text': 'latest'},
        'created_at': DateTime(2026, 5, 1, 0, 2).toIso8601String(),
        'updated_at': DateTime(2026, 5, 1, 0, 2).toIso8601String(),
      },
    ];
    fakeApi.itemsByCursor['older:after-latest'] = [
      {
        'item_id': 'older-1',
        'turn_id': 'turn-older',
        'index': 99,
        'type': 'agent_message',
        'status': 'completed',
        'content': {'id': 'older-1', 'type': 'agentMessage', 'text': 'older'},
        'created_at': DateTime(2026, 5, 1, 0, 1).toIso8601String(),
        'updated_at': DateTime(2026, 5, 1, 0, 1).toIso8601String(),
      },
    ];
    fakeApi.pageCursors[null] = 'older:after-latest';
    fakeApi.pageHasMore[null] = true;

    await repo.reloadLatestItemsPage('s1', limit: 1);
    final olderPage = await repo.loadOlderItemsPage('s1', limit: 1);
    final items = await db.getItemsBySession('agent-a', 's1');

    expect(fakeApi.itemRequestCursors, [isNull, 'older:after-latest']);
    expect(olderPage.items.map((item) => item['item_id']), ['older-1']);
    expect(items.map((item) => item.itemId), ['older-1', 'latest-1']);
  });

  test('turn watch window includes all items from a cached turn', () async {
    fakeApi.items = List.generate(73, (index) {
      return {
        'item_id': 'msg-$index',
        'turn_id': 'turn-1',
        'index': index,
        'type': 'agent_message',
        'status': 'completed',
        'content': {
          'id': 'msg-$index',
          'type': 'agentMessage',
          'text': 'message $index',
        },
        'created_at': DateTime(2026, 5, 1, 0, 0, index).toIso8601String(),
        'updated_at': DateTime(2026, 5, 1, 0, 0, index).toIso8601String(),
      };
    });

    await repo.loadLatestItemsPage('s1', limit: 1);

    final recent = await repo.watchItems('s1', turnLimit: 1).first;
    final turnCount = await repo.watchTurnCount('s1').first;

    expect(fakeApi.itemRequestLimits, [1]);
    expect(recent, hasLength(73));
    expect(turnCount, 1);
  });

  test('turn watch window includes complete recent turns only', () async {
    fakeApi.items = [
      for (final spec in const [
        ('turn-1', 0, 2),
        ('turn-2', 2, 3),
        ('turn-3', 5, 1),
      ])
        for (var offset = 0; offset < spec.$3; offset++)
          {
            'item_id': 'msg-${spec.$2 + offset}',
            'turn_id': spec.$1,
            'index': spec.$2 + offset,
            'type': 'agent_message',
            'status': 'completed',
            'content': {
              'id': 'msg-${spec.$2 + offset}',
              'type': 'agentMessage',
              'text': 'message ${spec.$2 + offset}',
            },
            'created_at': DateTime(
              2026,
              5,
              1,
              0,
              0,
              spec.$2 + offset,
            ).toIso8601String(),
            'updated_at': DateTime(
              2026,
              5,
              1,
              0,
              0,
              spec.$2 + offset,
            ).toIso8601String(),
          },
    ];

    await repo.loadLatestItemsPage('s1', limit: 3);

    final recent = await repo.watchItems('s1', turnLimit: 2).first;

    expect(recent.map((item) => item['item_id']), [
      'msg-2',
      'msg-3',
      'msg-4',
      'msg-5',
    ]);
  });

  test(
    'cached turn lookup returns current and adjacent turns locally',
    () async {
      fakeApi.items = [
        for (final turn in const ['turn-1', 'turn-2', 'turn-3'])
          {
            'item_id': 'msg-$turn',
            'turn_id': turn,
            'index': const {'turn-1': 1, 'turn-2': 2, 'turn-3': 3}[turn],
            'type': 'agent_message',
            'status': 'completed',
            'content': {
              'id': 'msg-$turn',
              'type': 'agentMessage',
              'text': turn,
            },
            'created_at': DateTime(
              2026,
              5,
              1,
              0,
              0,
              const {'turn-1': 1, 'turn-2': 2, 'turn-3': 3}[turn]!,
            ).toIso8601String(),
            'updated_at': DateTime(
              2026,
              5,
              1,
              0,
              0,
              const {'turn-1': 1, 'turn-2': 2, 'turn-3': 3}[turn]!,
            ).toIso8601String(),
          },
      ];

      await repo.loadLatestItemsPage('s1', limit: 3);

      expect(await repo.hasCachedTurn('s1', 'turn-2'), isTrue);
      expect(await repo.hasCachedTurn('s1', 'missing'), isFalse);

      final current = await repo.getCachedTurnItems('s1', 'turn-2');
      final older = await repo.getAdjacentCachedTurnItems(
        's1',
        'turn-2',
        newer: false,
      );
      final newer = await repo.getAdjacentCachedTurnItems(
        's1',
        'turn-2',
        newer: true,
      );

      expect(current.map((item) => item['turn_id']), ['turn-2']);
      expect(older.map((item) => item['turn_id']), ['turn-1']);
      expect(newer.map((item) => item['turn_id']), ['turn-3']);
      expect(fakeApi.itemRequestCursors, [isNull]);
    },
  );

  test('active tail turn reflects latest cached turn item status', () async {
    await db.insertOrUpdateItems([
      SessionItemEntriesCompanion.insert(
        agentId: 'agent-a',
        sessionId: 's1',
        itemId: 'completed-1',
        turnId: const Value('turn-1'),
        type: 'agent_message',
        status: const Value('completed'),
        content: const Value('{"text":"done"}'),
        itemIndex: const Value(1),
        createdAt: DateTime(2026, 5, 1),
        updatedAt: DateTime(2026, 5, 1),
      ),
    ]);

    expect(await repo.hasActiveTailTurn('s1'), isFalse);

    await db.insertOrUpdateItems([
      SessionItemEntriesCompanion.insert(
        agentId: 'agent-a',
        sessionId: 's1',
        itemId: 'running-1',
        turnId: const Value('turn-2'),
        type: 'agent_message',
        status: const Value('in_progress'),
        content: const Value('{"text":"running"}'),
        itemIndex: const Value(2),
        createdAt: DateTime(2026, 5, 1, 0, 0, 1),
        updatedAt: DateTime(2026, 5, 1, 0, 0, 1),
      ),
    ]);

    expect(await repo.hasActiveTailTurn('s1'), isTrue);
  });

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

    await repo.loadLatestItemsPage('s1');
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
    final items = await db.getItemsBySession('agent-a', 's1');
    expect(items.map((item) => item.itemId), ['msg-next']);
    expect(await repo.getItemRevision('s1'), 2);
  });

  test(
    'refresh items with no runtime revision does not fetch history window',
    () async {
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

      expect(fakeApi.itemChangeRequestRevisions, [0]);
      expect(fakeApi.itemRequestCursors, isEmpty);
      expect(await db.getItemsBySession('agent-a', 's1'), isEmpty);
    },
  );

  test('refresh items is deduplicated for same session revision', () async {
    fakeApi.changes = [
      {
        'revision': 47,
        'op': 'upsert',
        'item_id': 'msg-1',
        'item': {
          'item_id': 'msg-1',
          'type': 'agent_message',
          'status': 'completed',
          'content': {'id': 'msg-1', 'type': 'agentMessage', 'text': 'hello'},
          'created_at': DateTime(2026, 5, 1).toIso8601String(),
          'updated_at': DateTime(2026, 5, 1).toIso8601String(),
        },
      },
    ];
    fakeApi.revision = 47;
    fakeApi.itemChangeCompleter = Completer<Map<String, dynamic>>();

    final first = repo.refreshItems('s1');
    final second = repo.refreshItems('s1');

    await Future<void>.delayed(Duration.zero);
    expect(fakeApi.itemChangeRequestRevisions, [0]);

    fakeApi.completeItemChanges();

    expect((await first).map((item) => item['item_id']), ['msg-1']);
    expect((await second).map((item) => item['item_id']), ['msg-1']);
    expect(fakeApi.itemChangeRequestRevisions, [0]);
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

    await repo.loadLatestItemsPage('s1');

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
    'reset item window removes stale items and keeps pending input',
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

      await repo.resetItemWindow('s1');
      await repo.loadLatestItemsPage('s1');

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

    await repo.loadLatestItemsPage('s1');
    final first = await db.getItem('agent-a', 's1', 'msg-1');
    await repo.loadLatestItemsPage('s1');
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
    await repo.loadLatestItemsPage('s1');
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
    await repo.loadLatestItemsPage('s1');
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

  test('refresh sessions preserves source metadata for session list', () async {
    fakeApi.sessions = [
      {
        'id': 's1',
        'provider_id': 'codex',
        'project_id': 'p1',
        'source': 'cli',
        'runner_type': 'app-server',
        'model': 'gpt-5.5',
        'effort': 'xhigh',
        'status': {'type': 'notLoaded'},
        'created_at': DateTime(2026, 5, 1).toIso8601String(),
        'updated_at': DateTime(2026, 5, 1).toIso8601String(),
      },
    ];

    await repo.refreshSessions('p1');

    final session = await repo.getCachedSession('s1');
    expect(session?['source'], 'cli');
    expect(session?['runner_type'], 'app-server');
    expect(session?['provider_id'], 'codex');
    expect(session?['model'], 'gpt-5.5');
    expect(session?['effort'], 'xhigh');
  });

  test('refresh sessions normalizes object sandbox metadata', () async {
    fakeApi.sessions = [
      {
        'id': 's1',
        'provider_id': 'codex',
        'project_id': 'p1',
        'sandbox_mode': {
          'type': 'workspace-write',
          'writableRoots': ['/repo'],
        },
        'status': {'type': 'notLoaded'},
        'created_at': DateTime(2026, 5, 1).toIso8601String(),
        'updated_at': DateTime(2026, 5, 1).toIso8601String(),
      },
    ];

    await repo.refreshSessions('p1');

    final session = await repo.getCachedSession('s1');
    expect(session?['sandbox_mode'], 'workspace-write');
  });

  test('active and archived session refreshes sync separately', () async {
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

  test(
    'session list sync is deduplicated for same project and archive state',
    () async {
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
      fakeApi.sessionListCompleter = Completer<List<dynamic>>();

      final cached = repo.getSessions('p1');
      final refreshed = repo.refreshSessions('p1');

      await Future<void>.delayed(Duration.zero);
      expect(fakeApi.sessionListRequests, 1);

      fakeApi.completeSessionList();

      expect(await cached, isEmpty);
      expect((await refreshed).map((s) => s['id']), ['s1']);
    },
  );
}

class _FakeSessionApi implements SessionApiLike {
  List<dynamic> sessions = [];
  List<dynamic> items = [];
  List<dynamic> changes = [];
  int revision = 1;
  int sessionListRequests = 0;
  Completer<List<dynamic>>? sessionListCompleter;
  Completer<Map<String, dynamic>>? itemChangeCompleter;
  final Map<String?, List<dynamic>> itemsByCursor = {};
  final Map<String?, String?> pageCursors = {};
  final Map<String?, bool> pageHasMore = {};
  final List<String?> itemRequestCursors = [];
  final List<int> itemRequestLimits = [];
  final List<int> itemChangeRequestRevisions = [];

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
    int limit = 1,
  }) async {
    itemRequestCursors.add(cursor);
    itemRequestLimits.add(limit);
    return {
      'items': itemsByCursor[cursor] ?? items,
      'cursor': pageCursors.containsKey(cursor) ? pageCursors[cursor] : cursor,
      'has_more': pageHasMore[cursor] ?? false,
    };
  }

  @override
  Future<Map<String, dynamic>> getItemChanges(
    String sessionId, {
    required int afterRevision,
    int limit = 500,
  }) async {
    itemChangeRequestRevisions.add(afterRevision);
    final completer = itemChangeCompleter;
    if (completer != null) return completer.future;
    return {
      'changes': changes,
      'to_revision': revision,
      'has_more': false,
      'reset_required': false,
    };
  }

  void completeItemChanges() {
    final completer = itemChangeCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete({
        'changes': changes,
        'to_revision': revision,
        'has_more': false,
        'reset_required': false,
      });
    }
  }

  @override
  Future<Map<String, dynamic>> getSession(String id) async => {'id': id};

  @override
  Future<void> interrupt(String sessionId) async {}

  @override
  Future<List<dynamic>> listSessions(
    String projectId, {
    bool archived = false,
  }) async {
    sessionListRequests++;
    final completer = sessionListCompleter;
    if (completer != null) return completer.future;
    return sessions;
  }

  void completeSessionList() {
    final completer = sessionListCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(sessions);
    }
  }

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
