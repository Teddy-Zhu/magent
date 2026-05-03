import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:magent_app/core/repositories/bootstrap_repository.dart';
import 'package:magent_app/core/repositories/session_repository.dart';
import 'package:magent_app/core/sync/realtime_service.dart';

class SyncEngine {
  final RealtimeTransport realtime;
  final BootstrapSyncStore bootstrap;
  final SessionSyncStore sessions;
  StreamSubscription<Map<String, dynamic>>? _eventsSub;
  final _sessionEvents = StreamController<Map<String, dynamic>>.broadcast();
  final _sessionGates = <String, _SessionRealtimeGate>{};
  var _started = false;

  SyncEngine({
    required this.realtime,
    required this.bootstrap,
    required this.sessions,
  });

  Stream<Map<String, dynamic>> get sessionEvents => _sessionEvents.stream;

  void start() {
    if (_started) return;
    _started = true;
    realtime.start();
    _eventsSub ??= realtime.events.listen(_handleRealtimeEvent);
    bootstrap.refresh().catchError((error) {
      debugPrint('SyncEngine: bootstrap sync failed: $error');
      return BootstrapSnapshot.empty();
    });
    _resyncSubscribedSessions();
  }

  void _resyncSubscribedSessions() {
    for (final entry in _sessionGates.entries) {
      final gate = entry.value;
      if (!gate.subscribed) continue;
      gate.subscriptionSent = false;
      _beginSessionCatchUp(
        entry.key,
        beforeRefresh: () => _sendSessionSubscription(entry.key, gate),
      );
    }
  }

  Future<void> syncBootstrap({bool force = false}) {
    return bootstrap.refresh(force: force).then((_) {});
  }

  Future<void> syncSessionItems(String sessionId) {
    return _beginSessionCatchUp(sessionId).then((_) {});
  }

  Future<void> syncSessionList(String projectId) {
    return sessions.refreshSessions(projectId).then((_) {});
  }

  Future<void> handleForeground() async {
    start();
    _resyncSubscribedSessions();
    realtime.resume();
    await syncBootstrap();
  }

  void handleBackground() {
    for (final gate in _sessionGates.values) {
      gate.subscriptionSent = false;
    }
    realtime.pause();
  }

  Future<void> subscribeSession(String sessionId) async {
    start();
    final gate = _gateFor(sessionId);
    gate.subscribed = true;
    final sync = _beginSessionCatchUp(
      sessionId,
      beforeRefresh: () => _sendSessionSubscription(sessionId, gate),
    );
    await sync;
  }

  void unsubscribeSession(String sessionId) {
    final gate = _sessionGates[sessionId];
    if (gate != null) {
      gate.subscribed = false;
      gate.subscriptionSent = false;
      gate.buffer.clear();
    }
    realtime.unsubscribeSession(sessionId);
  }

  void _handleRealtimeEvent(Map<String, dynamic> event) {
    final type = event['type']?.toString() ?? '';
    if (type == 'server.hello') {
      _handleServerHello(event);
      return;
    }
    final sessionId = event['session_id']?.toString();
    if (type == 'session.sync_required') {
      if (sessionId != null && sessionId.isNotEmpty) {
        final gate = _sessionGates[sessionId];
        if (gate != null && (gate.subscribed || gate.syncing)) {
          _beginSessionCatchUp(sessionId);
          _sessionEvents.add(event);
        }
      }
      return;
    }
    if (sessionId == null || sessionId.isEmpty) return;
    final gate = _sessionGates[sessionId];
    if (gate == null || (!gate.subscribed && !gate.syncing)) return;
    if (gate.syncing) {
      gate.buffer.add(event);
      return;
    }
    if (type == 'session.items.changed') {
      _beginSessionCatchUp(sessionId, reconcile: false);
      _sessionEvents.add(event);
      return;
    }
    _enqueueSessionEvent(sessionId, event);
  }

  _SessionRealtimeGate _gateFor(String sessionId) {
    return _sessionGates.putIfAbsent(sessionId, _SessionRealtimeGate.new);
  }

  void _handleServerHello(Map<String, dynamic> event) {
    final sessionIds = _serverHelloSessionIds(event);
    for (final sessionId in sessionIds) {
      final gate = _sessionGates[sessionId];
      if (gate == null || !gate.subscribed) continue;
      _beginSessionCatchUp(sessionId);
    }
  }

  Iterable<String> _serverHelloSessionIds(Map<String, dynamic> event) {
    final subscriptions = event['subscriptions'];
    if (subscriptions is! Iterable) return const [];
    return subscriptions
        .map((subscription) {
          if (subscription is String) return subscription;
          if (subscription is Map) {
            return subscription['session_id']?.toString() ??
                subscription['sessionId']?.toString();
          }
          return null;
        })
        .whereType<String>()
        .where((sessionId) => sessionId.isNotEmpty);
  }

  Future<void> _sendSessionSubscription(
    String sessionId,
    _SessionRealtimeGate gate,
  ) async {
    if (gate.subscriptionSent) return;
    final revision = await sessions.getItemRevision(sessionId);
    final cursor = revision > 0 ? 'items:$revision' : null;
    if (!gate.subscribed) return;
    realtime.subscribeSession(sessionId, cursor: cursor);
    gate.subscriptionSent = true;
  }

  Future<void> _beginSessionCatchUp(
    String sessionId, {
    Future<void> Function()? beforeRefresh,
    bool reconcile = true,
  }) {
    final gate = _gateFor(sessionId);
    if (gate.syncing) {
      if (reconcile) {
        gate.pendingReconcile = true;
      }
      if (beforeRefresh != null && !gate.subscriptionSent) {
        beforeRefresh().catchError((error) {
          debugPrint('SyncEngine: session subscribe failed: $error');
        });
      }
      return gate.syncFuture ?? Future<void>.value();
    }

    gate.syncing = true;
    final sync = _runSessionCatchUp(
      sessionId,
      gate,
      beforeRefresh: beforeRefresh,
      reconcile: reconcile,
    );
    gate.syncFuture = sync;
    return sync;
  }

  Future<void> _runSessionCatchUp(
    String sessionId,
    _SessionRealtimeGate gate, {
    Future<void> Function()? beforeRefresh,
    bool reconcile = true,
  }) async {
    var refreshed = false;
    var startRevision = 0;
    var endRevision = 0;
    try {
      if (beforeRefresh != null) {
        await beforeRefresh();
      }
      startRevision = await sessions.getItemRevision(sessionId);
      await gate.applyTail;
      await sessions.refreshItems(sessionId, reconcile: reconcile);
      endRevision = await sessions.getItemRevision(sessionId);
      refreshed = true;
    } catch (error) {
      debugPrint('SyncEngine: session catch-up failed: $error');
    }

    if (!refreshed) {
      _retrySessionCatchUp(sessionId, gate, reconcile: reconcile);
      return;
    }

    var runPendingReconcile = false;
    try {
      await _drainBufferedSessionEvents(
        sessionId,
        gate,
        startRevision: startRevision,
        endRevision: endRevision,
      );
    } finally {
      if (gate.pendingReconcile && !reconcile) {
        gate.pendingReconcile = false;
        runPendingReconcile = true;
      } else {
        gate.syncing = false;
        gate.syncFuture = null;
      }
    }
    if (runPendingReconcile) {
      final sync = _runSessionCatchUp(sessionId, gate, reconcile: true);
      gate.syncFuture = sync;
      await sync;
    }
  }

  void _retrySessionCatchUp(
    String sessionId,
    _SessionRealtimeGate gate, {
    required bool reconcile,
  }) {
    if (!gate.subscribed && gate.buffer.isEmpty) {
      gate.syncing = false;
      gate.syncFuture = null;
      return;
    }
    gate.syncFuture = Future<void>.delayed(const Duration(seconds: 2)).then((
      _,
    ) {
      if (!gate.subscribed && gate.buffer.isEmpty) {
        gate.syncing = false;
        gate.syncFuture = null;
        return Future<void>.value();
      }
      final nextReconcile = reconcile || gate.pendingReconcile;
      gate.pendingReconcile = false;
      return _runSessionCatchUp(sessionId, gate, reconcile: nextReconcile);
    });
  }

  Future<void> _drainBufferedSessionEvents(
    String sessionId,
    _SessionRealtimeGate gate, {
    required int startRevision,
    required int endRevision,
  }) async {
    var currentRevision = endRevision;
    while (gate.buffer.isNotEmpty) {
      final buffered = List<Map<String, dynamic>>.of(gate.buffer);
      gate.buffer.clear();
      for (final event in buffered) {
        final itemRevisionAdvanced = currentRevision > startRevision;
        await _applySessionEvent(
          sessionId,
          event,
          currentRevision: currentRevision,
          dropCoveredItemHints: itemRevisionAdvanced,
        );
        currentRevision = await sessions.getItemRevision(sessionId);
      }
    }
  }

  void _enqueueSessionEvent(String sessionId, Map<String, dynamic> event) {
    final gate = _gateFor(sessionId);
    final next = gate.applyTail.then(
      (_) => _applySessionEvent(sessionId, event),
    );
    gate.applyTail = next.catchError((error) {
      debugPrint('SyncEngine: apply realtime event failed: $error');
    });
  }

  Future<void> _applySessionEvent(
    String sessionId,
    Map<String, dynamic> event, {
    int? currentRevision,
    bool dropCoveredItemHints = false,
  }) async {
    if (_isSessionTransportEvent(event)) {
      _sessionEvents.add(event);
      return;
    }
    if (event['type'] == 'session.items.changed') {
      final toRevision = _eventInt(event['to_revision'] ?? event['toRevision']);
      if (currentRevision != null &&
          toRevision != null &&
          currentRevision >= toRevision) {
        return;
      }
      await sessions.refreshItems(sessionId, reconcile: false);
      _sessionEvents.add(event);
      return;
    }
    if (_isItemProjectionHintEvent(event)) {
      if (dropCoveredItemHints) return;
      _sessionEvents.add(_uiSessionEvent(event));
      return;
    }

    var applied = false;
    var handled = false;
    try {
      applied = await sessions.applyRealtimeEvent(event);
      handled = true;
    } catch (error) {
      debugPrint('SyncEngine: apply realtime event failed: $error');
    }
    if (handled) {
      await _trackAppliedRealtimeCursor(sessionId, event);
    }
    if (applied) {
      _sessionEvents.add(_uiSessionEvent(event));
    } else if (handled) {
      debugPrint(
        'SyncEngine: realtime event ignored session=$sessionId '
        'type=${event['event_type'] ?? event['type']} '
        'ws=${event['ws_epoch'] ?? '-'}:${event['ws_cursor'] ?? event['ws_seq'] ?? '-'}',
      );
    }
  }

  Map<String, dynamic> _uiSessionEvent(Map<String, dynamic> event) {
    final eventType = event['event_type']?.toString();
    if (eventType == null || eventType.isEmpty) return event;
    return {...event, 'type': eventType, '_envelope_type': event['type']};
  }

  Future<void> _trackAppliedRealtimeCursor(
    String sessionId,
    Map<String, dynamic> event,
  ) async {
    final revision = await sessions.getItemRevision(sessionId);
    if (revision <= 0) return;
    final cursor = 'items:$revision';
    realtime.updateSessionCursor(sessionId, cursor);
  }

  bool _isSessionTransportEvent(Map<String, dynamic> event) {
    switch (event['type']?.toString()) {
      case 'server.hello':
      case 'session.subscribed':
      case 'session.unsubscribed':
      case 'session.replay_complete':
        return true;
      default:
        return false;
    }
  }

  bool _isItemProjectionHintEvent(Map<String, dynamic> event) {
    switch (event['event_type']?.toString() ?? event['type']?.toString()) {
      case 'session.user_message':
      case 'session.message':
      case 'session.message_delta':
      case 'session.output':
      case 'session.plan':
      case 'session.plan_delta':
      case 'session.plan_updated':
      case 'session.reasoning':
      case 'session.reasoning_summary_delta':
      case 'session.reasoning_text_delta':
      case 'session.reasoning_summary_part':
      case 'session.diff_updated':
      case 'session.command_completed':
      case 'session.command_output_delta':
      case 'session.file_write':
      case 'session.file_read':
      case 'session.file_change_output_delta':
      case 'session.mcp_tool_completed':
      case 'session.item_started':
      case 'session.item_completed':
        return true;
      default:
        return false;
    }
  }

  int? _eventInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '');
  }

  void dispose() {
    _eventsSub?.cancel();
    _sessionGates.clear();
    _sessionEvents.close();
  }
}

class _SessionRealtimeGate {
  final buffer = <Map<String, dynamic>>[];
  Future<void> applyTail = Future<void>.value();
  Future<void>? syncFuture;
  bool subscribed = false;
  bool subscriptionSent = false;
  bool syncing = false;
  bool pendingReconcile = false;
}
