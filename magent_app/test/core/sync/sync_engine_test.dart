import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:magent_app/core/repositories/bootstrap_repository.dart';
import 'package:magent_app/core/repositories/session_repository.dart';
import 'package:magent_app/core/sync/realtime_service.dart';
import 'package:magent_app/core/sync/sync_engine.dart';

void main() {
  late _FakeRealtime realtime;
  late _FakeBootstrap bootstrap;
  late _FakeSessions sessions;
  late SyncEngine engine;

  setUp(() {
    realtime = _FakeRealtime();
    bootstrap = _FakeBootstrap();
    sessions = _FakeSessions();
    engine = SyncEngine(
      realtime: realtime,
      bootstrap: bootstrap,
      sessions: sessions,
    );
  });

  tearDown(() {
    engine.dispose();
    realtime.dispose();
  });

  test('start opens realtime and syncs bootstrap', () async {
    engine.start();
    await Future<void>.delayed(Duration.zero);

    expect(realtime.started, isTrue);
    expect(bootstrap.refreshCount, 1);
  });

  test('foreground resume does not resync bootstrap or sessions', () async {
    engine.start();
    await engine.subscribeSession('s1');
    await Future<void>.delayed(Duration.zero);
    bootstrap.refreshCount = 0;
    sessions.refreshedItems.clear();

    await engine.handleForeground();

    expect(realtime.started, isTrue);
    expect(bootstrap.refreshCount, 0);
    expect(sessions.refreshedItems, isEmpty);
  });

  test('server hello does not resync subscribed sessions', () async {
    engine.start();
    await engine.subscribeSession('s1');
    sessions.refreshedItems.clear();

    realtime.emit({
      'type': 'server.hello',
      'subscriptions': ['s1'],
    });
    await Future<void>.delayed(Duration.zero);

    expect(sessions.refreshedItems, isEmpty);
  });

  test(
    'session sync required with no revision only dispatches sync hint',
    () async {
      final events = <Map<String, dynamic>>[];
      engine.start();
      final sub = engine.sessionEvents.listen(events.add);
      await engine.subscribeSession('s1');
      await engine.completeSessionInitialItemsSync('s1');
      sessions.refreshedItems.clear();

      realtime.emit({'type': 'session.sync_required', 'session_id': 's1'});
      await Future<void>.delayed(Duration.zero);

      expect(sessions.refreshedItems, isEmpty);
      expect(events.single['type'], 'session.sync_required');
      await sub.cancel();
    },
  );

  test(
    'session sync required with revision triggers item catch-up and event dispatch',
    () async {
      final events = <Map<String, dynamic>>[];
      sessions.revisions['s1'] = 1;
      engine.start();
      final sub = engine.sessionEvents.listen(events.add);
      await engine.subscribeSession('s1');
      await engine.completeSessionInitialItemsSync('s1');
      sessions.refreshedItems.clear();

      realtime.emit({'type': 'session.sync_required', 'session_id': 's1'});
      await Future<void>.delayed(Duration.zero);

      expect(sessions.refreshedItems, ['s1']);
      expect(events.single['type'], 'session.sync_required');
      await sub.cancel();
    },
  );

  test('item projection delta is dispatched without item catch-up', () async {
    final events = <Map<String, dynamic>>[];
    engine.start();
    final sub = engine.sessionEvents.listen(events.add);
    await engine.subscribeSession('s1');
    await engine.completeSessionInitialItemsSync('s1');
    sessions.refreshedItems.clear();

    final event = {
      'type': 'session.message_delta',
      'session_id': 's1',
      'item_id': 'i1',
      'data': {'delta': 'hello'},
    };
    realtime.emit(event);
    await Future<void>.delayed(Duration.zero);

    expect(sessions.appliedEvents, isEmpty);
    expect(sessions.refreshedItems, isEmpty);
    expect(events.single['type'], 'session.message_delta');
    await sub.cancel();
  });

  test(
    'wrapped item projection delta is dispatched without catch-up',
    () async {
      final events = <Map<String, dynamic>>[];
      engine.start();
      final sub = engine.sessionEvents.listen(events.add);
      await engine.subscribeSession('s1');
      await engine.completeSessionInitialItemsSync('s1');
      sessions.refreshedItems.clear();

      final event = {
        'type': 'session.event',
        'event_type': 'session.message_delta',
        'session_id': 's1',
        'item_id': 'i1',
        'data': {'delta': 'hello'},
      };
      realtime.emit(event);
      await Future<void>.delayed(Duration.zero);

      expect(sessions.appliedEvents, isEmpty);
      expect(sessions.refreshedItems, isEmpty);
      expect(events.single['type'], 'session.message_delta');
      expect(events.single['_envelope_type'], 'session.event');
      await sub.cancel();
    },
  );

  test('subscribe uses stored item revision cursor', () async {
    sessions.revisions['s1'] = 10;
    await engine.subscribeSession('s1');

    expect(realtime.subscriptions, {'s1': 'items:10'});
    expect(sessions.refreshedItems, isEmpty);
  });

  test('subscribe does not refresh even when tail turn is active', () async {
    sessions.revisions['s1'] = 10;
    sessions.activeTailTurns.add('s1');
    await engine.subscribeSession('s1');

    expect(realtime.subscriptions, {'s1': 'items:10'});
    expect(sessions.refreshedItems, isEmpty);
  });

  test('subscribe without item revision does not fetch history', () async {
    await engine.subscribeSession('s1');

    expect(realtime.subscriptions, {'s1': null});
    expect(sessions.refreshedItems, isEmpty);
  });

  test('subscribe buffers websocket events until catch-up completes', () async {
    final events = <Map<String, dynamic>>[];
    sessions.revisions['s1'] = 1;
    sessions.activeTailTurns.add('s1');
    final sub = engine.sessionEvents.listen(events.add);

    final subscribe = engine.subscribeSession('s1');
    await Future<void>.delayed(Duration.zero);
    final event = {
      'type': 'session.message_delta',
      'session_id': 's1',
      'item_id': 'i1',
      'ws_cursor': '11',
      'data': {'delta': 'hello'},
    };
    realtime.emit(event);
    await Future<void>.delayed(Duration.zero);

    expect(sessions.appliedEvents, isEmpty);
    expect(events, isEmpty);

    await subscribe;
    await engine.completeSessionInitialItemsSync('s1');
    await Future<void>.delayed(Duration.zero);

    expect(sessions.appliedEvents, isEmpty);
    expect(sessions.refreshedItems, isEmpty);
    expect(events.single['type'], 'session.message_delta');
    await sub.cancel();
  });

  test(
    'buffered item changes are applied after initial http sync without catch-up',
    () async {
      final events = <Map<String, dynamic>>[];
      sessions.revisions['s1'] = 1;
      final sub = engine.sessionEvents.listen(events.add);

      final subscribe = engine.subscribeSession('s1');
      await Future<void>.delayed(Duration.zero);
      final event = {
        'type': 'session.items.changed',
        'session_id': 's1',
        'from_revision': 1,
        'to_revision': 2,
        'changes': [
          {'revision': 2, 'op': 'upsert', 'item_id': 'i1'},
        ],
      };
      realtime.emit(event);
      await Future<void>.delayed(Duration.zero);

      expect(sessions.appliedItemChangeEvents, isEmpty);
      expect(sessions.refreshedItems, isEmpty);

      await subscribe;
      await engine.completeSessionInitialItemsSync('s1');
      await Future<void>.delayed(Duration.zero);

      expect(sessions.appliedItemChangeEvents.single, event);
      expect(sessions.refreshedItems, isEmpty);
      expect(events.single['type'], 'session.items.changed');
      await sub.cancel();
    },
  );

  test(
    'buffered projection event is dropped when catch-up advances revision',
    () async {
      final events = <Map<String, dynamic>>[];
      sessions.revisions['s1'] = 1;
      sessions.activeTailTurns.add('s1');
      final sub = engine.sessionEvents.listen(events.add);

      final subscribe = engine.subscribeSession('s1');
      await Future<void>.delayed(Duration.zero);
      realtime.emit({
        'type': 'session.message_delta',
        'session_id': 's1',
        'item_id': 'i1',
        'ws_cursor': '11',
        'data': {'delta': 'hello'},
      });
      await Future<void>.delayed(Duration.zero);
      sessions.revisions['s1'] = 11;
      await subscribe;
      await engine.completeSessionInitialItemsSync('s1');
      await Future<void>.delayed(Duration.zero);

      expect(sessions.appliedEvents, isEmpty);
      expect(sessions.refreshedItems, isEmpty);
      expect(events, isEmpty);
      await sub.cancel();
    },
  );

  test(
    'sync required buffers following session events during catch-up',
    () async {
      final events = <Map<String, dynamic>>[];
      sessions.revisions['s1'] = 1;
      engine.start();
      await Future<void>.delayed(Duration.zero);
      await engine.subscribeSession('s1');
      await engine.completeSessionInitialItemsSync('s1');
      final refresh = Completer<List<Map<String, dynamic>>>();
      sessions.refreshCompleters.add(refresh);
      sessions.refreshedItems.clear();
      final sub = engine.sessionEvents.listen(events.add);

      realtime.emit({'type': 'session.sync_required', 'session_id': 's1'});
      await Future<void>.delayed(Duration.zero);
      final event = {
        'type': 'session.message_delta',
        'session_id': 's1',
        'item_id': 'i1',
        'data': {'delta': 'hello'},
      };
      realtime.emit(event);
      await Future<void>.delayed(Duration.zero);

      expect(events.map((event) => event['type']), ['session.sync_required']);
      expect(sessions.appliedEvents, isEmpty);

      refresh.complete([]);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(sessions.appliedEvents, isEmpty);
      expect(sessions.refreshedItems, ['s1']);
      expect(events.map((event) => event['type']), [
        'session.sync_required',
        'session.message_delta',
      ]);
      await sub.cancel();
    },
  );

  test('session items changed triggers catch-up once', () async {
    final events = <Map<String, dynamic>>[];
    sessions.revisions['s1'] = 1;
    engine.start();
    final sub = engine.sessionEvents.listen(events.add);
    await engine.subscribeSession('s1');
    await engine.completeSessionInitialItemsSync('s1');
    sessions.refreshedItems.clear();

    final event = {
      'type': 'session.items.changed',
      'session_id': 's1',
      'from_revision': 1,
      'to_revision': 2,
    };
    realtime.emit(event);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(sessions.refreshedItems, ['s1']);
    expect(events.single['type'], 'session.items.changed');
    await sub.cancel();
  });

  test(
    'session items changed applies ws changes without http catch-up',
    () async {
      final events = <Map<String, dynamic>>[];
      sessions.revisions['s1'] = 1;
      engine.start();
      final sub = engine.sessionEvents.listen(events.add);
      await engine.subscribeSession('s1');
      await engine.completeSessionInitialItemsSync('s1');
      sessions.refreshedItems.clear();

      final event = {
        'type': 'session.items.changed',
        'session_id': 's1',
        'from_revision': 1,
        'to_revision': 2,
        'ws_cursor': 'same:11',
        'changes': [
          {'revision': 2, 'op': 'upsert', 'item_id': 'i1'},
        ],
      };
      realtime.emit(event);
      await Future<void>.delayed(Duration.zero);

      expect(sessions.appliedItemChangeEvents.single, event);
      expect(sessions.refreshedItems, isEmpty);
      expect(events.single['type'], 'session.items.changed');
      await sub.cancel();
    },
  );

  test(
    'session items changed falls back to http when ws changes cannot apply',
    () async {
      final events = <Map<String, dynamic>>[];
      sessions.revisions['s1'] = 1;
      sessions.applyItemChangeResults.add(false);
      engine.start();
      final sub = engine.sessionEvents.listen(events.add);
      await engine.subscribeSession('s1');
      await engine.completeSessionInitialItemsSync('s1');
      sessions.refreshedItems.clear();

      realtime.emit({
        'type': 'session.items.changed',
        'session_id': 's1',
        'from_revision': 1,
        'to_revision': 2,
        'changes': const [],
      });
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(sessions.refreshedItems, ['s1']);
      expect(events.single['type'], 'session.items.changed');
      await sub.cancel();
    },
  );

  test('covered session items changed does not trigger catch-up', () async {
    final events = <Map<String, dynamic>>[];
    sessions.revisions['s1'] = 46;
    engine.start();
    final sub = engine.sessionEvents.listen(events.add);
    await engine.subscribeSession('s1');
    await engine.completeSessionInitialItemsSync('s1');
    sessions.refreshedItems.clear();

    realtime.emit({
      'type': 'session.items.changed',
      'session_id': 's1',
      'from_revision': 45,
      'to_revision': 46,
      'ws_cursor': 'same:10',
    });
    await Future<void>.delayed(Duration.zero);

    expect(sessions.refreshedItems, isEmpty);
    expect(events, isEmpty);
    expect(realtime.subscriptions['s1'], 'items:46');
    await sub.cancel();
  });

  test(
    'ignored projection hint does not move subscription cursor backward',
    () async {
      final events = <Map<String, dynamic>>[];
      sessions.revisions['s1'] = 24;
      engine.start();
      final sub = engine.sessionEvents.listen(events.add);
      await engine.subscribeSession('s1');
      await engine.completeSessionInitialItemsSync('s1');
      sessions.refreshedItems.clear();

      final event = {
        'type': 'session.message_delta',
        'session_id': 's1',
        'item_id': 'i1',
        'ws_cursor': 'same:1',
        'data': {'delta': 'old'},
      };
      realtime.emit(event);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(sessions.appliedEvents, isEmpty);
      expect(events.single['type'], 'session.message_delta');
      expect(realtime.subscriptions['s1'], 'items:24');
      await sub.cancel();
    },
  );

  test('events for unsubscribed sessions are ignored', () async {
    final events = <Map<String, dynamic>>[];
    engine.start();
    final sub = engine.sessionEvents.listen(events.add);

    final event = {
      'type': 'session.message_delta',
      'session_id': 's2',
      'item_id': 'i1',
      'data': {'delta': 'hello'},
    };
    realtime.emit(event);
    await Future<void>.delayed(Duration.zero);

    expect(sessions.appliedEvents, isEmpty);
    expect(events, isEmpty);
    await sub.cancel();
  });

  test('sync required for unknown session is ignored', () async {
    final events = <Map<String, dynamic>>[];
    engine.start();
    final sub = engine.sessionEvents.listen(events.add);

    realtime.emit({'type': 'session.sync_required', 'session_id': 's2'});
    await Future<void>.delayed(Duration.zero);

    expect(sessions.refreshedItems, isEmpty);
    expect(events, isEmpty);
    await sub.cancel();
  });
}

class _FakeRealtime implements RealtimeTransport {
  final controller = StreamController<Map<String, dynamic>>.broadcast();
  final subscriptions = <String, String?>{};
  var started = false;
  var paused = false;

  @override
  Stream<Map<String, dynamic>> get events => controller.stream;

  void emit(Map<String, dynamic> event) {
    controller.add(event);
  }

  @override
  void start() {
    started = true;
    paused = false;
  }

  @override
  void subscribeSession(String sessionId, {String? cursor}) {
    start();
    subscriptions[sessionId] = cursor;
  }

  @override
  void unsubscribeSession(String sessionId) {
    subscriptions.remove(sessionId);
  }

  @override
  void updateSessionCursor(String sessionId, String cursor) {
    if (!subscriptions.containsKey(sessionId)) return;
    subscriptions[sessionId] = cursor;
  }

  @override
  void pause() {
    paused = true;
  }

  @override
  void resume() {
    start();
  }

  @override
  void dispose() {
    controller.close();
  }
}

class _FakeBootstrap implements BootstrapSyncStore {
  var refreshCount = 0;

  @override
  Future<BootstrapSnapshot> refresh({bool force = false}) async {
    refreshCount++;
    return BootstrapSnapshot.empty();
  }
}

class _FakeSessions implements SessionSyncStore {
  final cursors = <String, String?>{};
  final revisions = <String, int>{};
  final activeTailTurns = <String>{};
  final refreshedItems = <String>[];
  final refreshedSessions = <String>[];
  final appliedEvents = <Map<String, dynamic>>[];
  final appliedItemChangeEvents = <Map<String, dynamic>>[];
  final refreshCompleters = <Completer<List<Map<String, dynamic>>>>[];
  final applyResults = <bool>[];
  final applyItemChangeResults = <bool>[];

  @override
  Future<bool> applyRealtimeEvent(Map<String, dynamic> event) async {
    appliedEvents.add(event);
    if (applyResults.isNotEmpty) return applyResults.removeAt(0);
    return true;
  }

  @override
  Future<bool> applyRealtimeItemChanges(
    String sessionId,
    Map<String, dynamic> event,
  ) async {
    appliedItemChangeEvents.add(event);
    if (applyItemChangeResults.isNotEmpty) {
      return applyItemChangeResults.removeAt(0);
    }
    final changes = event['changes'];
    if (changes is! List || changes.isEmpty) return false;
    return true;
  }

  @override
  Future<String?> getRealtimeCursor(String sessionId) async {
    return cursors[sessionId];
  }

  @override
  Future<String?> getRealtimeEpoch(String sessionId) async {
    return null;
  }

  @override
  Future<int> getItemRevision(String sessionId) async {
    return revisions[sessionId] ?? 0;
  }

  @override
  Future<bool> hasActiveTailTurn(String sessionId) async {
    return activeTailTurns.contains(sessionId);
  }

  @override
  Future<List<Map<String, dynamic>>> refreshItems(String sessionId) async {
    refreshedItems.add(sessionId);
    if (refreshCompleters.isNotEmpty) {
      return refreshCompleters.removeAt(0).future;
    }
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> refreshItemsIfChanged(
    String sessionId,
  ) async {
    if ((revisions[sessionId] ?? 0) <= 0) return [];
    return refreshItems(sessionId);
  }

  @override
  Future<List<Map<String, dynamic>>> refreshSessions(
    String projectId, {
    bool archived = false,
  }) async {
    refreshedSessions.add(projectId);
    return [];
  }
}
