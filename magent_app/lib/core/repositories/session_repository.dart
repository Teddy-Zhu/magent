import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:magent_app/core/session/session_language.dart';
import 'package:magent_app/core/storage/app_database.dart';

abstract class SessionApiLike {
  Future<Map<String, dynamic>> createSession({
    required String providerId,
    required String projectId,
    String? model,
    String? effort,
    String? approvalPolicy,
    String? sandboxMode,
    String? prompt,
  });

  Future<Map<String, dynamic>> getSession(String id);

  Future<List<dynamic>> listSessions(String projectId, {bool archived = false});

  Future<void> sendInput(
    String sessionId,
    String input, {
    List<Map<String, dynamic>> items = const [],
    String? mode,
    String? model,
    String? effort,
    String? approvalPolicy,
    String? sandboxMode,
  });

  Future<void> resume(String sessionId);

  Future<void> interrupt(String sessionId);

  Future<void> stop(String sessionId);

  Future<void> archive(String sessionId);

  Future<Map<String, dynamic>> unarchive(String sessionId);

  Future<void> deleteSession(String sessionId);

  Future<Map<String, dynamic>> fork(String sessionId);

  Future<Map<String, dynamic>> getEventsPage(
    String sessionId, {
    String? cursor,
    int limit = 500,
  });

  Future<Map<String, dynamic>> getItemsPage(
    String sessionId, {
    String? cursor,
    int limit = 200,
  });

  Future<Map<String, dynamic>> getItemChanges(
    String sessionId, {
    required int afterRevision,
    int limit = 500,
  });

  Future<void> approve(String sessionId, String approvalId, String action);
}

abstract class SessionSyncStore {
  Future<bool> applyRealtimeEvent(Map<String, dynamic> event);

  Future<String?> getRealtimeCursor(String sessionId);

  Future<String?> getRealtimeEpoch(String sessionId);

  Future<int> getItemRevision(String sessionId);

  Future<List<Map<String, dynamic>>> refreshItems(String sessionId);

  Future<List<Map<String, dynamic>>> refreshSessions(
    String projectId, {
    bool archived = false,
  });
}

class _ItemSyncPage {
  final List<Map<String, dynamic>> items;
  final String? cursor;
  final bool hasMore;
  final int revision;

  const _ItemSyncPage({
    required this.items,
    required this.cursor,
    required this.hasMore,
    this.revision = 0,
  });
}

class SessionItemPageState {
  final List<Map<String, dynamic>> items;
  final String? olderCursor;
  final bool hasOlder;

  const SessionItemPageState({
    required this.items,
    required this.olderCursor,
    required this.hasOlder,
  });
}

class _WsCursor {
  final String? epoch;
  final int? seq;

  const _WsCursor({this.epoch, this.seq});
}

class SessionRepository implements SessionSyncStore {
  final String agentId;
  final SessionApiLike _api;
  final AppDatabase _db;

  SessionRepository({
    required this.agentId,
    required SessionApiLike api,
    required AppDatabase db,
  }) : _api = api,
       _db = db;

  // --- Sessions ---

  Stream<List<Map<String, dynamic>>> watchSessions(
    String projectId, {
    bool archived = false,
  }) {
    return _db
        .watchSessionsWithLastTextByProjectArchived(
          agentId,
          projectId,
          archived: archived,
        )
        .map((rows) => rows.map(_sessionWithLastTextToMap).toList());
  }

  Stream<List<Map<String, dynamic>>> watchItems(
    String sessionId, {
    int? limit,
  }) {
    final stream = limit == null
        ? _db.watchItemsBySession(agentId, sessionId)
        : _db.watchRecentItemsBySession(agentId, sessionId, limit);
    return stream.map((rows) => rows.map(_itemToMap).toList());
  }

  Stream<int> watchItemCount(String sessionId) {
    return _db.watchItemCountBySession(agentId, sessionId);
  }

  Future<void> addPendingUserMessage(String sessionId, String content) {
    final now = DateTime.now();
    return _db.insertOrUpdateItem(
      SessionItemEntriesCompanion(
        agentId: Value(agentId),
        sessionId: Value(sessionId),
        itemId: Value('local-${now.microsecondsSinceEpoch}'),
        type: const Value('user_message'),
        status: const Value('pending'),
        role: const Value('user'),
        summary: Value(_truncate(content, 160)),
        content: Value(_encodeJson({'content': content, 'text': content})),
        itemIndex: Value(now.microsecondsSinceEpoch),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  Future<Map<String, dynamic>?> getCachedSession(String sessionId) async {
    final row = await _db.getSession(agentId, sessionId);
    return row == null ? null : _sessionToMap(row);
  }

  Future<void> upsertSession(
    Map<String, dynamic> session, {
    String? projectId,
  }) async {
    final existing = await _db.getSession(
      agentId,
      session['id']?.toString() ?? '',
    );
    final companion = _sessionCompanion(
      session,
      fallbackProjectId: projectId,
      existing: existing,
    );
    if (companion == null) return;
    await _db.insertOrUpdateSession(companion);
  }

  Future<void> deleteCachedSession(String sessionId) {
    return _db.deleteSessionCache(agentId, sessionId);
  }

  /// Returns sessions for a project. Loads from local DB first, then syncs from API.
  Future<List<Map<String, dynamic>>> getSessions(
    String projectId, {
    bool archived = false,
  }) async {
    // 1. Load from local DB
    final localWithLastText = await _db
        .getSessionsWithLastTextByProjectArchived(
          agentId,
          projectId,
          archived: archived,
        );
    final localList = localWithLastText.map(_sessionWithLastTextToMap).toList();

    // 2. Try syncing from API in background
    _syncSessionsFromApi(projectId, archived: archived).catchError((e) {
      debugPrint('SessionRepository: sync sessions error: $e');
      return <Map<String, dynamic>>[];
    });

    return localList;
  }

  /// Fetches sessions from API and updates local DB. Returns the fresh list.
  Future<List<Map<String, dynamic>>> _syncSessionsFromApi(
    String projectId, {
    bool archived = false,
  }) async {
    final apiSessions = await _api.listSessions(projectId, archived: archived);
    final localSessions = await _db.getSessionsByProjectArchived(
      agentId,
      projectId,
      archived: archived,
    );
    final remoteIds = <String>{};

    final companions = <SessionEntriesCompanion>[];
    for (final s in apiSessions) {
      final map = Map<String, dynamic>.from(s as Map);
      if (archived && map['archived_at'] == null) {
        map['archived_at'] =
            map['updated_at'] ??
            map['updatedAt'] ??
            DateTime.now().toIso8601String();
      } else if (!archived) {
        map['archived_at'] = null;
      }
      final id = map['id']?.toString();
      if (id != null && id.isNotEmpty) remoteIds.add(id);
      final companion = _sessionCompanion(map, fallbackProjectId: projectId);
      if (companion != null) companions.add(companion);
    }

    if (companions.isNotEmpty) {
      await _db.insertOrUpdateSessions(companions);
    }
    for (final local in localSessions) {
      if (!remoteIds.contains(local.id)) {
        await _db.deleteSessionCache(agentId, local.id);
      }
    }

    return apiSessions.map((s) => Map<String, dynamic>.from(s as Map)).toList();
  }

  /// Force refresh sessions from API and update local DB.
  @override
  Future<List<Map<String, dynamic>>> refreshSessions(
    String projectId, {
    bool archived = false,
  }) async {
    return _syncSessionsFromApi(projectId, archived: archived);
  }

  Future<void> archiveSession(String sessionId) async {
    await _api.archive(sessionId);
    await _db.deleteSessionCache(agentId, sessionId);
  }

  Future<void> unarchiveSession(String sessionId, {String? projectId}) async {
    final session = await _api.unarchive(sessionId);
    session['archived_at'] = null;
    await upsertSession(session, projectId: projectId);
  }

  Future<void> deleteSession(String sessionId) async {
    await _api.deleteSession(sessionId);
    await _db.deleteSessionCache(agentId, sessionId);
  }

  // --- Events ---

  /// Returns events for a session. Loads from local DB first, then fetches incremental from API.
  Future<List<Map<String, dynamic>>> getEvents(String sessionId) async {
    // 1. Load from local DB
    final localEvents = await _db.getEventsBySession(agentId, sessionId);
    final localList = localEvents.map(_eventToMap).toList();

    // 2. Try fetching incremental from API
    _syncEventsFromApi(sessionId).catchError((e) {
      debugPrint('SessionRepository: sync events error: $e');
      return <Map<String, dynamic>>[];
    });

    return localList;
  }

  /// Fetches incremental events from API and appends to local DB.
  Future<List<Map<String, dynamic>>> _syncEventsFromApi(
    String sessionId,
  ) async {
    final cursor = await _db.getSyncCursor(
      agentId,
      'session_events',
      sessionId,
    );
    final page = await _api.getEventsPage(sessionId, cursor: cursor);
    final newEvents = page['events'] as List<dynamic>? ?? [];
    final companions = <SessionEventEntriesCompanion>[];
    for (var i = 0; i < newEvents.length; i++) {
      final e = newEvents[i];
      final map = Map<String, dynamic>.from(e as Map);
      final nextCursor = _eventCursor(map, page, i);
      companions.add(
        SessionEventEntriesCompanion(
          sessionId: Value(sessionId),
          agentId: Value(agentId),
          providerCursor: Value(nextCursor),
          type: Value(
            SessionEventTypes.normalize(map['type']?.toString() ?? ''),
          ),
          itemId: Value(map['item_id']?.toString()),
          turnId: Value(map['turn_id']?.toString()),
          data: Value(_encodeJson(map['data'])),
          createdAt: Value(_parseDateTime(map['created_at'])),
        ),
      );
    }

    if (companions.isNotEmpty) {
      await _db.insertEvents(companions);
    }
    final nextCursor = page['cursor']?.toString();
    if (nextCursor != null && nextCursor.isNotEmpty) {
      await _db.setSyncCursor(agentId, 'session_events', sessionId, nextCursor);
    }

    // Return ALL events (local + new)
    final allEvents = await _db.getEventsBySession(agentId, sessionId);
    return allEvents.map(_eventToMap).toList();
  }

  /// Force refresh events from API. Fetches all from provider.
  Future<List<Map<String, dynamic>>> refreshEvents(String sessionId) async {
    return _syncEventsFromApi(sessionId);
  }

  @override
  Future<bool> applyRealtimeEvent(Map<String, dynamic> event) async {
    final sessionId = event['session_id']?.toString();
    if (sessionId == null || sessionId.isEmpty) return false;
    if (await _isStaleRealtimeEvent(sessionId, event)) return false;

    final eventType = SessionEventTypes.normalize(
      event['event_type']?.toString() ?? event['type']?.toString() ?? '',
    );
    final data = _eventData(event);
    if (eventType == 'session.created') {
      await _upsertRealtimeSession(sessionId, data);
      await _advanceRealtimeCursor(sessionId, event);
      return true;
    }
    final statusChanged = await _applyRealtimeSessionStatus(
      sessionId,
      eventType,
      event,
    );
    if (eventType == SessionEventTypes.approvalRequest) {
      await saveApprovalRequest(event);
      await _advanceRealtimeCursor(sessionId, event);
      return true;
    }
    if (_isRealtimeItemProjectionEvent(eventType)) {
      await _advanceRealtimeCursor(sessionId, event);
      return false;
    }
    if (!_shouldPersistRealtimeEvent(eventType)) {
      await _advanceRealtimeCursor(sessionId, event);
      return statusChanged;
    }

    final cursor =
        event['cursor']?.toString() ??
        event['provider_cursor']?.toString() ??
        DateTime.now().microsecondsSinceEpoch.toString();
    await _db.insertEvents([
      SessionEventEntriesCompanion(
        agentId: Value(agentId),
        sessionId: Value(sessionId),
        providerCursor: Value(cursor),
        type: Value(eventType),
        itemId: Value(event['item_id']?.toString()),
        turnId: Value(event['turn_id']?.toString()),
        data: Value(_encodeJson(event['data'])),
        createdAt: Value(_parseDateTime(event['created_at'])),
      ),
    ]);
    await _advanceRealtimeCursor(sessionId, event);
    return true;
  }

  Future<bool> _isStaleRealtimeEvent(
    String sessionId,
    Map<String, dynamic> event,
  ) async {
    final incoming = _wsCursor(event);
    if (incoming == null || incoming.isEmpty) return false;
    final incomingEpoch = _wsEpoch(event);
    final currentEpoch = await getRealtimeEpoch(sessionId);
    if (incomingEpoch != null &&
        incomingEpoch.isNotEmpty &&
        currentEpoch != null &&
        currentEpoch.isNotEmpty &&
        incomingEpoch != currentEpoch) {
      return false;
    }

    final current = await getRealtimeCursor(sessionId);
    if (current == null || current.isEmpty) return false;
    final incomingCursor = _parseWsCursor(incoming);
    final currentCursor = _parseWsCursor(current);
    if (incomingCursor.epoch != null &&
        incomingCursor.epoch!.isNotEmpty &&
        currentCursor.epoch != null &&
        currentCursor.epoch!.isNotEmpty &&
        incomingCursor.epoch != currentCursor.epoch) {
      return false;
    }
    final incomingSeq = incomingCursor.seq;
    final currentSeq = currentCursor.seq;
    if (incomingSeq != null && currentSeq != null) {
      if ((incomingEpoch != null &&
              incomingEpoch.isNotEmpty &&
              currentEpoch != null &&
              currentEpoch.isNotEmpty) ||
          (incomingCursor.epoch != null && currentCursor.epoch != null)) {
        return incomingSeq <= currentSeq;
      }
      return incomingSeq == currentSeq;
    }
    return incoming == current;
  }

  Future<void> _advanceRealtimeCursor(
    String sessionId,
    Map<String, dynamic> event,
  ) async {
    final wsCursor = _wsCursor(event);
    if (wsCursor != null && wsCursor.isNotEmpty) {
      await _db.setSyncCursor(agentId, 'session_ws', sessionId, wsCursor);
    }
    final wsEpoch = _wsEpoch(event);
    if (wsEpoch != null && wsEpoch.isNotEmpty) {
      await _db.setSyncCursor(agentId, 'session_ws_epoch', sessionId, wsEpoch);
    }
  }

  String? _wsCursor(Map<String, dynamic> event) {
    return event['ws_cursor']?.toString() ?? event['ws_seq']?.toString();
  }

  String? _wsEpoch(Map<String, dynamic> event) {
    return event['ws_epoch']?.toString();
  }

  _WsCursor _parseWsCursor(String cursor) {
    final separator = cursor.lastIndexOf(':');
    if (separator > 0 && separator < cursor.length - 1) {
      return _WsCursor(
        epoch: cursor.substring(0, separator),
        seq: int.tryParse(cursor.substring(separator + 1)),
      );
    }
    return _WsCursor(seq: int.tryParse(cursor));
  }

  bool _shouldPersistRealtimeEvent(String eventType) {
    switch (eventType) {
      case SessionEventTypes.started:
      case SessionEventTypes.statusChanged:
        return false;
      default:
        return true;
    }
  }

  bool _isRealtimeItemProjectionEvent(String eventType) {
    switch (eventType) {
      case SessionEventTypes.userMessage:
      case SessionEventTypes.message:
      case SessionEventTypes.messageDelta:
      case SessionEventTypes.output:
      case SessionEventTypes.plan:
      case SessionEventTypes.planDelta:
      case SessionEventTypes.planUpdated:
      case SessionEventTypes.reasoning:
      case SessionEventTypes.reasoningSummaryDelta:
      case SessionEventTypes.reasoningTextDelta:
      case SessionEventTypes.reasoningSummaryPart:
      case SessionEventTypes.diffUpdated:
      case SessionEventTypes.commandCompleted:
      case SessionEventTypes.commandOutputDelta:
      case SessionEventTypes.fileWrite:
      case SessionEventTypes.fileRead:
      case SessionEventTypes.fileChangeOutputDelta:
      case SessionEventTypes.mcpToolCompleted:
      case SessionEventTypes.itemStarted:
      case SessionEventTypes.itemCompleted:
        return true;
      default:
        return false;
    }
  }

  Future<bool> _upsertRealtimeSession(
    String fallbackSessionId,
    Map<String, dynamic> rawData,
  ) async {
    final data = _canonicalSessionMap(rawData);
    final id = data['id']?.toString() ?? fallbackSessionId;
    final projectId = data['project_id']?.toString();
    if (id.isEmpty || projectId == null || projectId.isEmpty) return false;

    final existing = await _db.getSession(agentId, id);
    final now = DateTime.now();
    await _db.insertOrUpdateSession(
      SessionEntriesCompanion(
        id: Value(id),
        agentId: Value(agentId),
        providerId: Value(
          data['provider_id']?.toString() ?? existing?.providerId ?? '',
        ),
        threadId: Value(
          data['thread_id']?.toString() ??
              data['threadId']?.toString() ??
              existing?.threadId,
        ),
        projectId: Value(projectId),
        purpose: Value(data['purpose']?.toString() ?? existing?.purpose),
        workdir: Value(data['workdir']?.toString() ?? existing?.workdir),
        title: Value(
          data['title']?.toString() ??
              data['preview']?.toString() ??
              existing?.title,
        ),
        status: Value(
          SessionStatuses.normalize(data['status']) ??
              existing?.status ??
              SessionStatuses.stopped,
        ),
        source: Value(data['source']?.toString() ?? existing?.source),
        runnerType: Value(
          data['runner_type']?.toString() ??
              data['runnerType']?.toString() ??
              existing?.runnerType,
        ),
        model: Value(data['model']?.toString() ?? existing?.model),
        effort: Value(data['effort']?.toString() ?? existing?.effort),
        approvalPolicy: Value(
          SessionApprovalPolicies.normalize(data['approval_policy']) ??
              existing?.approvalPolicy,
        ),
        sandboxMode: Value(
          SessionSandboxModes.normalize(
                data['sandbox_mode'] ??
                    data['sandboxMode'] ??
                    data['sandbox_policy'] ??
                    data['sandboxPolicy'],
              ) ??
              existing?.sandboxMode,
        ),
        providerCursor: Value(
          data['provider_cursor']?.toString() ?? existing?.providerCursor,
        ),
        listRevision: Value(
          _parseInt(data['list_revision']) ?? existing?.listRevision,
        ),
        createdAt: Value(
          data.containsKey('created_at')
              ? _parseDateTime(data['created_at'])
              : existing?.createdAt ?? now,
        ),
        updatedAt: Value(
          data.containsKey('updated_at')
              ? _parseDateTime(data['updated_at'])
              : now,
        ),
        archivedAt: Value(
          data.containsKey('archived_at')
              ? _parseNullableDateTime(data['archived_at'])
              : existing?.archivedAt,
        ),
        deletedAt: Value(existing?.deletedAt),
      ),
    );
    return true;
  }

  Future<bool> _applyRealtimeSessionStatus(
    String sessionId,
    String eventType,
    Map<String, dynamic> event,
  ) async {
    final nextStatus = _sessionStatusFromEvent(eventType, _eventData(event));
    if (nextStatus == null) return false;

    final existing = await _db.getSession(agentId, sessionId);
    if (existing == null) return false;
    if (existing.status == nextStatus) return false;

    await _db.insertOrUpdateSession(
      SessionEntriesCompanion(
        id: Value(existing.id),
        agentId: Value(existing.agentId),
        providerId: Value(existing.providerId),
        threadId: Value(existing.threadId),
        projectId: Value(existing.projectId),
        purpose: Value(existing.purpose),
        workdir: Value(existing.workdir),
        title: Value(existing.title),
        status: Value(nextStatus),
        source: Value(existing.source),
        runnerType: Value(existing.runnerType),
        model: Value(existing.model),
        effort: Value(existing.effort),
        approvalPolicy: Value(existing.approvalPolicy),
        sandboxMode: Value(existing.sandboxMode),
        providerCursor: Value(existing.providerCursor),
        listRevision: Value(existing.listRevision),
        createdAt: Value(existing.createdAt),
        updatedAt: Value(DateTime.now()),
        archivedAt: Value(existing.archivedAt),
        deletedAt: Value(existing.deletedAt),
      ),
    );
    return true;
  }

  @override
  Future<String?> getRealtimeCursor(String sessionId) {
    return _db.getSyncCursor(agentId, 'session_ws', sessionId);
  }

  @override
  Future<String?> getRealtimeEpoch(String sessionId) {
    return _db.getSyncCursor(agentId, 'session_ws_epoch', sessionId);
  }

  // --- Items ---

  Future<List<Map<String, dynamic>>> getItems(
    String sessionId, {
    int? limit,
  }) async {
    final localItems = limit == null
        ? await _db.getItemsBySession(agentId, sessionId)
        : await _db.getRecentItemsBySession(agentId, sessionId, limit);
    final localList = localItems.map(_itemToMap).toList();

    loadLatestItemsPage(sessionId, limit: limit ?? 80).catchError((e) {
      debugPrint('SessionRepository: sync items error: $e');
      return const SessionItemPageState(
        items: [],
        olderCursor: null,
        hasOlder: false,
      );
    });

    return localList;
  }

  @override
  Future<List<Map<String, dynamic>>> refreshItems(String sessionId) async {
    final revision = await getItemRevision(sessionId);
    if (revision <= 0) {
      final page = await loadLatestItemsPage(sessionId);
      return page.items;
    }
    return _syncItemChanges(sessionId, revision);
  }

  @override
  Future<int> getItemRevision(String sessionId) async {
    return await _db.getSyncRevision(agentId, 'session_items', sessionId) ?? 0;
  }

  Future<SessionItemPageState> loadLatestItemsPage(
    String sessionId, {
    int limit = 80,
  }) async {
    return _loadItemsPage(sessionId, cursor: null, limit: limit);
  }

  Future<SessionItemPageState> loadOlderItemsPage(
    String sessionId, {
    int limit = 80,
  }) async {
    final cursor = await _db.getSyncCursor(
      agentId,
      'session_items_older',
      sessionId,
    );
    if (cursor == null || cursor.isEmpty) {
      return const SessionItemPageState(
        items: [],
        olderCursor: null,
        hasOlder: false,
      );
    }
    return _loadItemsPage(sessionId, cursor: cursor, limit: limit);
  }

  Future<SessionItemPageState> _loadItemsPage(
    String sessionId, {
    required String? cursor,
    required int limit,
  }) async {
    final page = await _api.getItemsPage(
      sessionId,
      cursor: cursor,
      limit: limit,
    );
    final newItems = page['items'] as List<dynamic>? ?? [];
    final realUserMessageContents = <dynamic>[];
    final entries = <SessionItemEntriesCompanion>[];
    for (final item in newItems) {
      final map = Map<String, dynamic>.from(item as Map);
      final itemId = map['item_id']?.toString() ?? map['id']?.toString() ?? '';
      if (itemId.isEmpty) continue;
      final type = SessionItemTypes.normalize(map['type']?.toString() ?? '');
      final existing = await _db.getItem(agentId, sessionId, itemId);
      final incomingContent = _apiItemContent(map, type);
      final content = incomingContent;
      if (type == SessionItemTypes.reasoning &&
          !_hasVisibleReasoningContent(content)) {
        if (existing != null) {
          await _db.deleteItem(agentId, sessionId, itemId);
        }
        continue;
      }
      if (type == SessionItemTypes.userMessage &&
          !itemId.startsWith('local-')) {
        realUserMessageContents.add(content);
      }
      final next = _sessionItemCompanion(
        sessionId: sessionId,
        itemId: itemId,
        type: type,
        map: map,
        content: content,
        existing: existing,
      );
      if (!_sessionItemMatchesExisting(existing, next)) {
        entries.add(next);
      }
    }
    await _db.transaction(() async {
      if (entries.isNotEmpty) {
        await _db.insertOrUpdateItems(entries);
      }
      await _db.setSyncCursor(
        agentId,
        'session_items_older',
        sessionId,
        _stringValue(page['cursor']) ?? '',
      );
    });
    for (final content in realUserMessageContents) {
      await _removeMatchingPendingUserMessage(sessionId, content);
    }
    return SessionItemPageState(
      items: entries.map(_itemCompanionToMap).toList(growable: false),
      olderCursor: _stringValue(page['cursor']),
      hasOlder: page['has_more'] == true || page['hasMore'] == true,
    );
  }

  Future<List<Map<String, dynamic>>> _syncItemChanges(
    String sessionId,
    int initialRevision,
  ) async {
    final synced = <Map<String, dynamic>>[];
    var afterRevision = initialRevision;
    while (true) {
      final page = await _api.getItemChanges(
        sessionId,
        afterRevision: afterRevision,
      );
      if (page['reset_required'] == true || page['resetRequired'] == true) {
        await resetItemWindow(sessionId);
        final loaded = await loadLatestItemsPage(sessionId);
        return loaded.items;
      }
      final result = await _applyItemChangesPage(sessionId, page);
      synced.addAll(result.items);
      if (!result.hasMore) break;
      if (result.revision <= afterRevision) break;
      afterRevision = result.revision;
    }
    return synced;
  }

  Future<_ItemSyncPage> _applyItemChangesPage(
    String sessionId,
    Map<String, dynamic> page,
  ) async {
    final changes = page['changes'] as List<dynamic>? ?? [];
    final changed = <Map<String, dynamic>>[];
    var revision = _parseInt(page['to_revision'] ?? page['toRevision']) ?? 0;
    await _db.transaction(() async {
      for (final rawChange in changes) {
        final change = Map<String, dynamic>.from(rawChange as Map);
        revision = _parseInt(change['revision']) ?? revision;
        final op = change['op']?.toString() ?? '';
        final itemId = change['item_id']?.toString() ?? '';
        if (itemId.isEmpty) continue;
        if (op == 'delete') {
          await _db.deleteItem(agentId, sessionId, itemId);
          continue;
        }
        final rawItem = change['item'];
        if (rawItem is! Map) continue;
        final applied = await _upsertApiItem(
          sessionId,
          Map<String, dynamic>.from(rawItem),
        );
        if (applied != null) changed.add(applied);
      }
      await _db.setSyncState(
        agentId,
        'session_items',
        sessionId,
        revision: revision,
      );
    });
    return _ItemSyncPage(
      items: changed,
      cursor: null,
      hasMore: page['has_more'] == true || page['hasMore'] == true,
      revision: revision,
    );
  }

  Future<Map<String, dynamic>?> _upsertApiItem(
    String sessionId,
    Map<String, dynamic> map,
  ) async {
    final itemId = map['item_id']?.toString() ?? map['id']?.toString() ?? '';
    if (itemId.isEmpty) return null;
    final type = SessionItemTypes.normalize(map['type']?.toString() ?? '');
    final existing = await _db.getItem(agentId, sessionId, itemId);
    final incomingContent = _apiItemContent(map, type);
    if (type == SessionItemTypes.reasoning &&
        !_hasVisibleReasoningContent(incomingContent)) {
      if (existing != null) {
        await _db.deleteItem(agentId, sessionId, itemId);
      }
      return null;
    }
    final next = _sessionItemCompanion(
      sessionId: sessionId,
      itemId: itemId,
      type: type,
      map: map,
      content: incomingContent,
      existing: existing,
    );
    if (!_sessionItemMatchesExisting(existing, next)) {
      await _db.insertOrUpdateItem(next);
    }
    if (type == SessionItemTypes.userMessage && !itemId.startsWith('local-')) {
      await _removeMatchingPendingUserMessage(sessionId, incomingContent);
    }
    return _itemCompanionToMap(next);
  }

  Future<void> resetItemWindow(String sessionId) async {
    final cachedItems = await _db.getItemsBySession(agentId, sessionId);
    for (final item in cachedItems) {
      if (item.itemId.startsWith('local-') &&
          item.type == SessionItemTypes.userMessage &&
          item.status == 'pending') {
        continue;
      }
      await _db.deleteItem(agentId, sessionId, item.itemId);
    }
    await _db.setSyncState(agentId, 'session_items', sessionId, revision: 0);
    await _db.setSyncCursor(agentId, 'session_items_older', sessionId, '');
  }

  SessionItemEntriesCompanion _sessionItemCompanion({
    required String sessionId,
    required String itemId,
    required String type,
    required Map<String, dynamic> map,
    required Map<String, dynamic> content,
    required SessionItemEntry? existing,
  }) {
    return SessionItemEntriesCompanion(
      agentId: Value(agentId),
      sessionId: Value(sessionId),
      itemId: Value(itemId),
      turnId: Value(map['turn_id']?.toString() ?? existing?.turnId),
      type: Value(type),
      status: Value(map['status']?.toString() ?? existing?.status),
      role: Value(map['role']?.toString() ?? existing?.role),
      summary: Value(
        _nonEmptyString(map['summary']) ??
            existing?.summary ??
            _contentSummary(type, content),
      ),
      content: Value(_encodeJson(content)),
      providerCursor: Value(
        map['cursor']?.toString() ??
            map['provider_cursor']?.toString() ??
            existing?.providerCursor,
      ),
      revision: Value(_parseInt(map['revision']) ?? existing?.revision),
      itemIndex: Value(_parseInt(map['index']) ?? existing?.itemIndex ?? 0),
      createdAt: Value(
        map['created_at'] == null
            ? existing?.createdAt ?? DateTime.now()
            : _parseDateTime(map['created_at']),
      ),
      updatedAt: Value(
        map['updated_at'] == null
            ? existing?.updatedAt ?? DateTime.now()
            : _parseDateTime(map['updated_at']),
      ),
    );
  }

  bool _sessionItemMatchesExisting(
    SessionItemEntry? existing,
    SessionItemEntriesCompanion next,
  ) {
    if (existing == null) return false;
    return existing.turnId == next.turnId.value &&
        existing.type == next.type.value &&
        existing.status == next.status.value &&
        existing.role == next.role.value &&
        existing.summary == next.summary.value &&
        existing.content == next.content.value &&
        existing.providerCursor == next.providerCursor.value &&
        existing.revision == next.revision.value &&
        existing.itemIndex == next.itemIndex.value &&
        existing.createdAt == next.createdAt.value;
  }

  Map<String, dynamic> _itemCompanionToMap(SessionItemEntriesCompanion item) {
    return {
      'item_id': item.itemId.value,
      'turn_id': item.turnId.value,
      'type': item.type.value,
      'status': item.status.value,
      'role': item.role.value,
      'summary': item.summary.value,
      'content': _decodeJson(item.content.value),
      'cursor': item.providerCursor.value,
      'index': item.itemIndex.value,
      'created_at': item.createdAt.value.toIso8601String(),
      'updated_at': item.updatedAt.value.toIso8601String(),
    };
  }

  Future<void> _removeMatchingPendingUserMessage(
    String sessionId,
    dynamic realContent,
  ) async {
    final text = _messageContentText(realContent).trim();
    if (text.isEmpty) return;
    final items = await _db.getItemsBySession(agentId, sessionId);
    for (final item in items) {
      if (!item.itemId.startsWith('local-') ||
          item.type != SessionItemTypes.userMessage ||
          item.status != 'pending') {
        continue;
      }
      final pendingText = _messageContentText(_decodeJson(item.content)).trim();
      if (pendingText == text) {
        await _db.deleteItem(agentId, sessionId, item.itemId);
        return;
      }
    }
  }

  Future<void> saveApprovalRequest(Map<String, dynamic> request) async {
    final data = Map<String, dynamic>.from(
      (request['data'] as Map?) ?? request,
    );
    final approvalId =
        data['approval_id']?.toString() ??
        data['id']?.toString() ??
        data['item_id']?.toString() ??
        '';
    final sessionId =
        data['session_id']?.toString() ??
        request['session_id']?.toString() ??
        '';
    if (approvalId.isEmpty || sessionId.isEmpty) return;
    await _db.upsertPendingApproval(
      PendingApprovalEntriesCompanion(
        agentId: Value(agentId),
        approvalId: Value(approvalId),
        sessionId: Value(sessionId),
        itemId: Value(data['item_id']?.toString()),
        type: Value(data['type']?.toString() ?? 'approval'),
        requestJson: Value(_encodeJson(data)),
        status: const Value('pending'),
        createdAt: Value(_parseDateTime(data['created_at'])),
      ),
    );
  }

  Future<void> markApprovalResolved(String approvalId, String status) {
    return _db.resolvePendingApproval(agentId, approvalId, status);
  }

  // --- Helpers ---

  Map<String, dynamic> _sessionToMap(SessionEntry s) {
    return {
      'id': s.id,
      'provider_id': s.providerId,
      'thread_id': s.threadId,
      'project_id': s.projectId,
      'purpose': s.purpose,
      'workdir': s.workdir,
      'title': s.title,
      'status': s.status,
      'source': s.source,
      'runner_type': s.runnerType,
      'model': s.model,
      'effort': s.effort,
      'approval_policy': s.approvalPolicy,
      'sandbox_mode': s.sandboxMode,
      'provider_cursor': s.providerCursor,
      'created_at': s.createdAt.toIso8601String(),
      'updated_at': s.updatedAt.toIso8601String(),
      'archived_at': s.archivedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> _sessionWithLastTextToMap(SessionWithLastText row) {
    final map = _sessionToMap(row.session);
    final lastText = row.lastText?.trim();
    if (lastText != null && lastText.isNotEmpty) {
      map['last_text'] = lastText;
    }
    return map;
  }

  Map<String, dynamic> _canonicalSessionMap(Map<String, dynamic> input) {
    final map = Map<String, dynamic>.from(input);
    final providerId = canonicalProviderId(map);
    if (providerId != null && providerId.isNotEmpty) {
      map['provider_id'] = providerId;
    }
    return map;
  }

  SessionEntriesCompanion? _sessionCompanion(
    Map<String, dynamic> input, {
    String? fallbackProjectId,
    SessionEntry? existing,
  }) {
    final map = _canonicalSessionMap(input);
    final id = map['id']?.toString() ?? '';
    final mappedProjectId = map['project_id']?.toString();
    final projectId = mappedProjectId != null && mappedProjectId.isNotEmpty
        ? mappedProjectId
        : fallbackProjectId;
    if (id.isEmpty || projectId == null || projectId.isEmpty) return null;

    return SessionEntriesCompanion(
      id: Value(id),
      agentId: Value(agentId),
      providerId: Value(map['provider_id']?.toString() ?? ''),
      threadId: Value(map['thread_id']?.toString()),
      projectId: Value(projectId),
      purpose: Value(map['purpose']?.toString()),
      workdir: Value(map['workdir']?.toString()),
      title: Value(map['title']?.toString() ?? map['preview']?.toString()),
      status: Value(_extractStatus(map)),
      source: Value(map['source']?.toString() ?? existing?.source),
      runnerType: Value(
        map['runner_type']?.toString() ??
            map['runnerType']?.toString() ??
            existing?.runnerType,
      ),
      model: Value(map['model']?.toString()),
      effort: Value(map['effort']?.toString()),
      approvalPolicy: Value(
        SessionApprovalPolicies.normalize(
          map['approval_policy'] ?? map['approvalPolicy'],
        ),
      ),
      sandboxMode: Value(
        SessionSandboxModes.normalize(
          map['sandbox_mode'] ??
              map['sandboxMode'] ??
              map['sandbox_policy'] ??
              map['sandboxPolicy'],
        ),
      ),
      providerCursor: Value(map['provider_cursor']?.toString()),
      listRevision: Value(_parseInt(map['list_revision'])),
      createdAt: Value(_parseDateTime(map['created_at'])),
      updatedAt: Value(_parseDateTime(map['updated_at'])),
      archivedAt: Value(_parseNullableDateTime(map['archived_at'])),
    );
  }

  Map<String, dynamic> _eventToMap(SessionEventEntry e) {
    return {
      'type': e.type,
      'data': _decodeJson(e.data),
      'item_id': e.itemId,
      'turn_id': e.turnId,
      'cursor': e.providerCursor,
      'time': e.createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> _itemToMap(SessionItemEntry item) {
    return {
      'item_id': item.itemId,
      'turn_id': item.turnId,
      'type': item.type,
      'status': item.status,
      'role': item.role,
      'summary': item.summary,
      'content': _decodeJson(item.content),
      'cursor': item.providerCursor,
      'index': item.itemIndex,
      'created_at': item.createdAt.toIso8601String(),
      'updated_at': item.updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> _eventData(Map<String, dynamic> event) {
    final data = event['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  String _contentSummary(String type, Map<String, dynamic> content) {
    if (type == SessionItemTypes.reasoning) {
      final reasoning = _reasoningContentText(content);
      if (reasoning.isNotEmpty) return _truncate(reasoning, 160);
      return '';
    }
    final text = _firstContentText(content, ['text', 'content']);
    if (text.isNotEmpty) return _truncate(text, 160);
    final output = _firstContentText(content, [
      'output',
      'aggregatedOutput',
      'stdout',
      'stderr',
      'result',
      'error',
    ]);
    if (output.isNotEmpty) return _truncate(output, 160);
    final command = _commandContentText(content);
    if (command.isNotEmpty) return _truncate(command, 160);
    final path = _firstContentText(content, ['path']);
    if (path.isNotEmpty) return path;
    final changes = content['changes'];
    if (changes is List && changes.isNotEmpty && changes.first is Map) {
      final first = Map<String, dynamic>.from(changes.first as Map);
      final changePath = first['path']?.toString();
      if (changePath != null && changePath.isNotEmpty) return changePath;
    }
    return type;
  }

  Map<String, dynamic> _apiItemContent(Map<String, dynamic> item, String type) {
    final rawContent = item['content'];
    final content = rawContent is Map
        ? Map<String, dynamic>.from(rawContent)
        : rawContent == null
        ? <String, dynamic>{}
        : <String, dynamic>{'value': rawContent};
    for (final entry in item.entries) {
      if (_isApiItemEnvelopeKey(entry.key)) continue;
      if (entry.value != null && content[entry.key] == null) {
        content[entry.key] = entry.value;
      }
    }
    content['id'] ??= item['item_id'] ?? item['id'];
    content['type'] ??= type;
    content['status'] ??= item['status'];
    _normalizeContentAliases(content);
    return content;
  }

  bool _isApiItemEnvelopeKey(String key) {
    switch (key) {
      case 'content':
      case 'cursor':
      case 'provider_cursor':
      case 'revision':
      case 'index':
      case 'created_at':
      case 'updated_at':
      case 'role':
      case 'summary':
      case 'turn_id':
      case 'turnId':
        return true;
      default:
        return false;
    }
  }

  void _normalizeContentAliases(Map<String, dynamic> content) {
    if (content['output'] == null && content['aggregatedOutput'] != null) {
      content['output'] = content['aggregatedOutput'];
    }
    if (content['output'] == null && content['stdout'] != null) {
      content['output'] = content['stdout'];
    }
    if (content['output'] == null && content['stderr'] != null) {
      content['output'] = content['stderr'];
    }
    if (content['exit_code'] == null && content['exitCode'] != null) {
      content['exit_code'] = content['exitCode'];
    }
    if (content['command'] == null) {
      for (final key in [
        'cmd',
        'cmdline',
        'argv',
        'args',
        'program',
        'script',
      ]) {
        if (_hasMeaningfulValue(content[key])) {
          content['command'] = content[key];
          break;
        }
      }
    }
  }

  bool _hasMeaningfulValue(dynamic value) {
    if (value == null) return false;
    if (value is String) return value.trim().isNotEmpty;
    if (value is Iterable) return value.isNotEmpty;
    if (value is Map) return value.isNotEmpty;
    return true;
  }

  String? _nonEmptyString(dynamic value) {
    final text = value?.toString();
    if (text == null || text.trim().isEmpty) return null;
    return text;
  }

  String? _stringValue(dynamic value) {
    final text = value?.toString();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  bool _hasVisibleReasoningContent(Map<String, dynamic> content) {
    return _reasoningContentText(content).trim().isNotEmpty;
  }

  String _reasoningContentText(Map<String, dynamic> content) {
    for (final key in ['summary', 'content', 'delta', 'text']) {
      final text = _messageContentText(content[key]).trim();
      if (text.isNotEmpty) return text;
    }
    final parts = content['summary_parts'];
    if (parts is List && parts.isNotEmpty) {
      return parts
          .map(_messageContentText)
          .where((text) => text.trim().isNotEmpty)
          .join('\n');
    }
    return '';
  }

  String _messageContentText(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is List) {
      return value.map(_messageContentText).join();
    }
    if (value is Map) {
      for (final key in ['text', 'content', 'message', 'value', 'delta']) {
        final text = _messageContentText(value[key]);
        if (text.isNotEmpty) return text;
      }
      return '';
    }
    return value.toString();
  }

  String _firstContentText(Map<String, dynamic> content, List<String> keys) {
    for (final key in keys) {
      final text = _messageContentText(content[key]).trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  String _commandContentText(dynamic value) {
    if (value == null) return '';
    if (value is String) return value.trim();
    if (value is List) {
      return value
          .map(_commandContentText)
          .where((part) => part.isNotEmpty)
          .join(' ');
    }
    if (value is Map) {
      for (final key in [
        'command',
        'cmd',
        'cmdline',
        'argv',
        'args',
        'program',
        'script',
      ]) {
        final text = _commandContentText(value[key]);
        if (text.isNotEmpty) return text;
      }
    }
    return value.toString().trim();
  }

  String _truncate(String value, int max) {
    if (value.length <= max) return value;
    return value.substring(0, max);
  }

  String _eventCursor(
    Map<String, dynamic> event,
    Map<String, dynamic> page,
    int index,
  ) {
    final cursor = event['cursor'] ?? event['provider_cursor'];
    if (cursor != null && cursor.toString().isNotEmpty) {
      return cursor.toString();
    }
    final pageCursor = page['cursor'];
    if (pageCursor != null && pageCursor.toString().isNotEmpty) {
      final base = int.tryParse(pageCursor.toString());
      final total = (page['events'] as List?)?.length ?? 0;
      if (base != null && total > 0) {
        return (base - total + index + 1).toString();
      }
    }
    return DateTime.now().microsecondsSinceEpoch.toString();
  }

  String _extractStatus(Map<String, dynamic> map) {
    return SessionStatuses.normalizeOrStopped(map['status']);
  }

  String? _sessionStatusFromEvent(String eventType, Map<String, dynamic> data) {
    switch (eventType) {
      case SessionEventTypes.started:
        return SessionStatuses.running;
      case 'session.created':
        return SessionStatuses.normalize(data['status']) ??
            SessionStatuses.running;
      case SessionEventTypes.exited:
        return SessionStatuses.completed;
      case SessionEventTypes.statusChanged:
        return SessionStatuses.normalize(data['status']);
      default:
        return null;
    }
  }

  DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) {
      return value.year <= 1 ? DateTime.now() : value;
    }
    if (value is int) {
      if (value <= 0) return DateTime.now();
      return DateTime.fromMillisecondsSinceEpoch(value * 1000);
    }
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed == null || parsed.year <= 1) return DateTime.now();
      return parsed;
    }
    return DateTime.now();
  }

  DateTime? _parseNullableDateTime(dynamic value) {
    if (value == null) return null;
    if (value is String && value.trim().isEmpty) return null;
    if (value is DateTime && value.year <= 1) return null;
    if (value is int && value <= 0) return null;
    return _parseDateTime(value);
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  String _encodeJson(dynamic data) {
    if (data == null) return '{}';
    try {
      return jsonEncode(data);
    } catch (_) {
      return '{}';
    }
  }

  dynamic _decodeJson(String json) {
    try {
      return jsonDecode(json);
    } catch (_) {
      return {};
    }
  }
}
