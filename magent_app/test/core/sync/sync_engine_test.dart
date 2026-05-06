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

  test(
    'session sync required triggers item catch-up and event dispatch',
    () async {
      final events = <Map<String, dynamic>>[];
      engine.start();
      final sub = engine.sessionEvents.listen(events.add);
      await engine.subscribeSession('s1');
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
    expect(sessions.refreshedItems, ['s1']);
  });

  test('subscribe buffers websocket events until catch-up completes', () async {
    final events = <Map<String, dynamic>>[];
    final refresh = Completer<List<Map<String, dynamic>>>();
    sessions.refreshCompleters.add(refresh);
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

    refresh.complete([]);
    await subscribe;
    await Future<void>.delayed(Duration.zero);

    expect(sessions.appliedEvents, isEmpty);
    expect(sessions.refreshedItems, ['s1']);
    expect(events.single['type'], 'session.message_delta');
    await sub.cancel();
  });

  test(
    'buffered projection event is dropped when catch-up advances revision',
    () async {
      final events = <Map<String, dynamic>>[];
      final refresh = Completer<List<Map<String, dynamic>>>();
      sessions.refreshCompleters.add(refresh);
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
      refresh.complete([]);
      await subscribe;
      await Future<void>.delayed(Duration.zero);

      expect(sessions.appliedEvents, isEmpty);
      expect(sessions.refreshedItems, ['s1']);
      expect(events, isEmpty);
      await sub.cancel();
    },
  );

  test(
    'sync required buffers following session events during catch-up',
    () async {
      final events = <Map<String, dynamic>>[];
      engine.start();
      await Future<void>.delayed(Duration.zero);
      await engine.subscribeSession('s1');
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
    engine.start();
    final sub = engine.sessionEvents.listen(events.add);
    await engine.subscribeSession('s1');
    sessions.refreshedItems.clear();

    final event = {
      'type': 'session.items.changed',
      'session_id': 's1',
      'from_revision': 1,
      'to_revision': 2,
    };
    realtime.emit(event);
    await Future<void>.delayed(Duration.zero);

    expect(sessions.refreshedItems, ['s1']);
    expect(events.single['type'], 'session.items.changed');
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
  final refreshedItems = <String>[];
  final refreshedSessions = <String>[];
  final appliedEvents = <Map<String, dynamic>>[];
  final refreshCompleters = <Completer<List<Map<String, dynamic>>>>[];
  final applyResults = <bool>[];

  @override
  Future<bool> applyRealtimeEvent(Map<String, dynamic> event) async {
    appliedEvents.add(event);
    if (applyResults.isNotEmpty) return applyResults.removeAt(0);
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
  Future<List<Map<String, dynamic>>> refreshItems(
    String sessionId,
  ) async {
    refreshedItems.add(sessionId);
    if (refreshCompleters.isNotEmpty) {
      return refreshCompleters.removeAt(0).future;
    }
    return [];
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
