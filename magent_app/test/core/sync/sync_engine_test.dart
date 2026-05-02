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

      realtime.emit({'type': 'session.sync_required', 'session_id': 's1'});
      await Future<void>.delayed(Duration.zero);

      expect(sessions.refreshedItems, ['s1']);
      expect(events.single['type'], 'session.sync_required');
      await sub.cancel();
    },
  );

  test('session event is applied and emitted', () async {
    final events = <Map<String, dynamic>>[];
    engine.start();
    final sub = engine.sessionEvents.listen(events.add);

    final event = {
      'type': 'session.message_delta',
      'session_id': 's1',
      'item_id': 'i1',
      'data': {'delta': 'hello'},
    };
    realtime.emit(event);
    await Future<void>.delayed(Duration.zero);

    expect(sessions.appliedEvents, [event]);
    expect(events, [event]);
    await sub.cancel();
  });

  test('git invalidation is routed separately', () async {
    final events = <Map<String, dynamic>>[];
    engine.start();
    final sub = engine.gitInvalidations.listen(events.add);

    final event = {'type': 'git.invalidated', 'project_id': 'p1'};
    realtime.emit(event);
    await Future<void>.delayed(Duration.zero);

    expect(events, [event]);
    expect(sessions.appliedEvents, isEmpty);
    await sub.cancel();
  });

  test('subscribe uses stored realtime cursor', () async {
    sessions.cursors['s1'] = 'ws:10';
    await engine.subscribeSession('s1');

    expect(realtime.subscriptions, {'s1': 'ws:10'});
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
  final refreshedItems = <String>[];
  final refreshedSessions = <String>[];
  final appliedEvents = <Map<String, dynamic>>[];

  @override
  Future<void> applyRealtimeEvent(Map<String, dynamic> event) async {
    appliedEvents.add(event);
  }

  @override
  Future<String?> getRealtimeCursor(String sessionId) async {
    return cursors[sessionId];
  }

  @override
  Future<List<Map<String, dynamic>>> refreshItems(
    String sessionId, {
    bool forceFull = false,
  }) async {
    refreshedItems.add(sessionId);
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
