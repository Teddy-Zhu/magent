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
  final _gitInvalidations = StreamController<Map<String, dynamic>>.broadcast();
  final _sessionEvents = StreamController<Map<String, dynamic>>.broadcast();
  var _started = false;

  SyncEngine({
    required this.realtime,
    required this.bootstrap,
    required this.sessions,
  });

  Stream<Map<String, dynamic>> get gitInvalidations => _gitInvalidations.stream;
  Stream<Map<String, dynamic>> get sessionEvents => _sessionEvents.stream;

  void start() {
    if (_started) return;
    _started = true;
    realtime.start();
    bootstrap.refresh().catchError((error) {
      debugPrint('SyncEngine: bootstrap sync failed: $error');
      return BootstrapSnapshot.empty();
    });
    _eventsSub = realtime.events.listen(_handleRealtimeEvent);
  }

  Future<void> syncBootstrap({bool force = false}) {
    return bootstrap.refresh(force: force).then((_) {});
  }

  Future<void> syncSessionItems(String sessionId) {
    return sessions.refreshItems(sessionId).then((_) {});
  }

  Future<void> syncSessionList(String projectId) {
    return sessions.refreshSessions(projectId).then((_) {});
  }

  Future<void> handleForeground() async {
    start();
    realtime.resume();
    await syncBootstrap();
  }

  void handleBackground() {
    realtime.pause();
  }

  Future<void> subscribeSession(String sessionId) async {
    start();
    final cursor = await sessions.getRealtimeCursor(sessionId);
    realtime.subscribeSession(sessionId, cursor: cursor);
  }

  void unsubscribeSession(String sessionId) {
    realtime.unsubscribeSession(sessionId);
  }

  Future<void> _handleRealtimeEvent(Map<String, dynamic> event) async {
    final type = event['type']?.toString() ?? '';
    final sessionId = event['session_id']?.toString();
    if (type == 'session.sync_required') {
      if (sessionId != null && sessionId.isNotEmpty) {
        try {
          await syncSessionItems(sessionId);
        } catch (error) {
          debugPrint('SyncEngine: session catch-up failed: $error');
        }
      }
      _sessionEvents.add(event);
      return;
    }
    if (type == 'git.invalidated') {
      _gitInvalidations.add(event);
      return;
    }
    if (sessionId == null || sessionId.isEmpty) return;
    try {
      await sessions.applyRealtimeEvent(event);
    } catch (error) {
      debugPrint('SyncEngine: apply realtime event failed: $error');
    }
    _sessionEvents.add(event);
  }

  void dispose() {
    _eventsSub?.cancel();
    _gitInvalidations.close();
    _sessionEvents.close();
  }
}
