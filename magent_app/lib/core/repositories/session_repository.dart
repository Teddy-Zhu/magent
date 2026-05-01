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

  Future<List<dynamic>> listSessions(String projectId);

  Future<void> sendInput(
    String sessionId,
    String input, {
    List<Map<String, dynamic>> items = const [],
  });

  Future<void> resume(String sessionId);

  Future<void> interrupt(String sessionId);

  Future<void> stop(String sessionId);

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

  Future<void> approve(String sessionId, String approvalId, String action);
}

abstract class SessionSyncStore {
  Future<void> applyRealtimeEvent(Map<String, dynamic> event);

  Future<String?> getRealtimeCursor(String sessionId);

  Future<List<Map<String, dynamic>>> refreshItems(String sessionId);

  Future<List<Map<String, dynamic>>> refreshSessions(String projectId);
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

  Stream<List<Map<String, dynamic>>> watchSessions(String projectId) {
    return _db
        .watchSessionsByProject(agentId, projectId)
        .map((rows) => rows.map(_sessionToMap).toList());
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

  /// Returns sessions for a project. Loads from local DB first, then syncs from API.
  Future<List<Map<String, dynamic>>> getSessions(String projectId) async {
    // 1. Load from local DB
    final localSessions = await _db.getSessionsByProject(agentId, projectId);
    final localList = localSessions.map(_sessionToMap).toList();

    // 2. Try syncing from API in background
    _syncSessionsFromApi(projectId).catchError((e) {
      debugPrint('SessionRepository: sync sessions error: $e');
      return <Map<String, dynamic>>[];
    });

    return localList;
  }

  /// Fetches sessions from API and updates local DB. Returns the fresh list.
  Future<List<Map<String, dynamic>>> _syncSessionsFromApi(
    String projectId,
  ) async {
    final apiSessions = await _api.listSessions(projectId);

    final companions = <SessionEntriesCompanion>[];
    for (final s in apiSessions) {
      final map = _canonicalSessionMap(Map<String, dynamic>.from(s as Map));
      companions.add(
        SessionEntriesCompanion(
          id: Value(map['id']?.toString() ?? ''),
          agentId: Value(agentId),
          providerId: Value(map['provider_id']?.toString() ?? ''),
          threadId: Value(map['thread_id']?.toString()),
          projectId: Value(projectId),
          workdir: Value(map['workdir']?.toString()),
          title: Value(map['title']?.toString() ?? map['preview']?.toString()),
          status: Value(_extractStatus(map)),
          model: Value(map['model']?.toString()),
          effort: Value(map['effort']?.toString()),
          approvalPolicy: Value(
            SessionApprovalPolicies.normalize(map['approval_policy']),
          ),
          sandboxMode: Value(
            SessionSandboxModes.normalize(map['sandbox_mode']),
          ),
          providerCursor: Value(map['provider_cursor']?.toString()),
          listRevision: Value(_parseInt(map['list_revision'])),
          createdAt: Value(_parseDateTime(map['created_at'])),
          updatedAt: Value(_parseDateTime(map['updated_at'])),
        ),
      );
    }

    if (companions.isNotEmpty) {
      await _db.insertOrUpdateSessions(companions);
    }

    return apiSessions.map((s) => Map<String, dynamic>.from(s as Map)).toList();
  }

  /// Force refresh sessions from API and update local DB.
  @override
  Future<List<Map<String, dynamic>>> refreshSessions(String projectId) async {
    return _syncSessionsFromApi(projectId);
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
  Future<void> applyRealtimeEvent(Map<String, dynamic> event) async {
    final sessionId = event['session_id']?.toString();
    if (sessionId == null || sessionId.isEmpty) return;

    final eventType = SessionEventTypes.normalize(
      event['event_type']?.toString() ?? event['type']?.toString() ?? '',
    );
    final data = _eventData(event);
    if (eventType == 'session.created') {
      await _upsertRealtimeSession(sessionId, data);
    }
    await _applyRealtimeSessionStatus(sessionId, eventType, event);
    if (eventType == SessionEventTypes.approvalRequest) {
      await saveApprovalRequest(event);
    }
    await _applyRealtimeItemProjection(sessionId, eventType, event);

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
    final wsCursor =
        event['ws_cursor']?.toString() ?? event['ws_seq']?.toString();
    if (wsCursor != null && wsCursor.isNotEmpty) {
      await _db.setSyncCursor(agentId, 'session_ws', sessionId, wsCursor);
    }
  }

  Future<void> _upsertRealtimeSession(
    String fallbackSessionId,
    Map<String, dynamic> rawData,
  ) async {
    final data = _canonicalSessionMap(rawData);
    final id = data['id']?.toString() ?? fallbackSessionId;
    final projectId = data['project_id']?.toString();
    if (id.isEmpty || projectId == null || projectId.isEmpty) return;

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
        model: Value(data['model']?.toString() ?? existing?.model),
        effort: Value(data['effort']?.toString() ?? existing?.effort),
        approvalPolicy: Value(
          SessionApprovalPolicies.normalize(data['approval_policy']) ??
              existing?.approvalPolicy,
        ),
        sandboxMode: Value(
          SessionSandboxModes.normalize(data['sandbox_mode']) ??
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
        archivedAt: Value(existing?.archivedAt),
        deletedAt: Value(existing?.deletedAt),
      ),
    );
  }

  Future<void> _applyRealtimeSessionStatus(
    String sessionId,
    String eventType,
    Map<String, dynamic> event,
  ) async {
    final nextStatus = _sessionStatusFromEvent(eventType, _eventData(event));
    if (nextStatus == null) return;

    final existing = await _db.getSession(agentId, sessionId);
    if (existing == null) return;

    await _db.insertOrUpdateSession(
      SessionEntriesCompanion(
        id: Value(existing.id),
        agentId: Value(existing.agentId),
        providerId: Value(existing.providerId),
        threadId: Value(existing.threadId),
        projectId: Value(existing.projectId),
        workdir: Value(existing.workdir),
        title: Value(existing.title),
        status: Value(nextStatus),
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
  }

  @override
  Future<String?> getRealtimeCursor(String sessionId) {
    return _db.getSyncCursor(agentId, 'session_ws', sessionId);
  }

  Future<void> _applyRealtimeItemProjection(
    String sessionId,
    String eventType,
    Map<String, dynamic> event,
  ) async {
    final data = _eventData(event);
    final itemId =
        event['item_id']?.toString() ??
        data['item_id']?.toString() ??
        data['itemId']?.toString() ??
        data['id']?.toString();
    if (itemId == null || itemId.isEmpty) return;

    final existing = await _db.getItem(agentId, sessionId, itemId);
    final currentContent = existing == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(_decodeJson(existing.content) as Map);
    final nextContent = Map<String, dynamic>.from(currentContent);
    final now = _parseDateTime(event['created_at']);
    final cursor =
        event['cursor']?.toString() ?? event['provider_cursor']?.toString();
    var type = existing?.type ?? _itemTypeFromEvent(eventType, data);
    var status = existing?.status ?? 'in_progress';
    var role = existing?.role ?? _roleForType(type);
    var summary = existing?.summary;
    var createdAt = existing?.createdAt ?? now;
    var itemIndex =
        _parseInt(event['index']) ??
        _parseInt(data['index']) ??
        existing?.itemIndex ??
        now.microsecondsSinceEpoch;

    switch (eventType) {
      case SessionEventTypes.messageDelta:
        type = 'agent_message';
        role = 'assistant';
        status = 'in_progress';
        nextContent['text'] = '${nextContent['text'] ?? ''}${_deltaText(data)}';
        summary = _truncate(nextContent['text']?.toString() ?? '', 160);
      case SessionEventTypes.planDelta:
        type = 'plan';
        status = 'in_progress';
        nextContent['text'] = '${nextContent['text'] ?? ''}${_deltaText(data)}';
        summary = _truncate(nextContent['text']?.toString() ?? '', 160);
      case SessionEventTypes.reasoningSummaryDelta:
        type = 'reasoning';
        status = 'in_progress';
        nextContent['summary'] =
            '${nextContent['summary'] ?? ''}${_deltaText(data)}';
        summary = _truncate(nextContent['summary']?.toString() ?? '', 160);
      case SessionEventTypes.reasoningTextDelta:
        type = 'reasoning';
        status = 'in_progress';
        nextContent['content'] =
            '${nextContent['content'] ?? ''}${_deltaText(data)}';
        summary ??= 'Reasoning';
      case SessionEventTypes.reasoningSummaryPart:
        type = 'reasoning';
        status = 'in_progress';
        final parts = List<dynamic>.from(
          nextContent['summary_parts'] as List? ?? [],
        );
        parts.add(data);
        nextContent['summary_parts'] = parts;
        summary ??= 'Reasoning';
      case SessionEventTypes.commandOutputDelta:
        type = 'command_execution';
        status = 'in_progress';
        nextContent['output'] =
            '${nextContent['output'] ?? ''}${_deltaText(data)}';
        summary = _commandSummary(data, nextContent);
      case SessionEventTypes.fileChangeOutputDelta:
        type = 'file_change';
        status = 'in_progress';
        nextContent['output'] =
            '${nextContent['output'] ?? ''}${_deltaText(data)}';
        summary = _contentSummary(type, nextContent);
      case SessionEventTypes.planUpdated:
        type = 'plan';
        status = 'in_progress';
        nextContent.addAll(data);
        summary = _planSummary(data);
      case SessionEventTypes.diffUpdated:
        type = 'diff';
        status = 'in_progress';
        nextContent.addAll(data);
        summary = 'Diff updated';
      case SessionEventTypes.itemStarted:
        type = _itemTypeFromEvent(eventType, data);
        status = data['status']?.toString() ?? 'in_progress';
        nextContent.addAll(data);
        summary = _contentSummary(type, nextContent);
      default:
        final completed = _completedItemFromEvent(eventType, data);
        if (completed == null) return;
        type = _normalizeItemType(completed['type']?.toString() ?? type);
        status = completed['status']?.toString() ?? 'completed';
        role = _roleForType(type);
        nextContent
          ..clear()
          ..addAll(completed);
        summary = _contentSummary(type, nextContent);
        createdAt = existing?.createdAt ?? now;
        itemIndex =
            _parseInt(completed['index']) ??
            _parseInt(data['index']) ??
            itemIndex;
    }

    await _db.insertOrUpdateItem(
      SessionItemEntriesCompanion(
        agentId: Value(agentId),
        sessionId: Value(sessionId),
        itemId: Value(itemId),
        turnId: Value(
          event['turn_id']?.toString() ?? data['turnId']?.toString(),
        ),
        type: Value(type),
        status: Value(status),
        role: Value(role),
        summary: Value(summary),
        content: Value(_encodeJson(nextContent)),
        providerCursor: Value(cursor),
        itemIndex: Value(itemIndex),
        createdAt: Value(createdAt),
        updatedAt: Value(now),
      ),
    );
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

    _syncItemsFromApi(sessionId).catchError((e) {
      debugPrint('SessionRepository: sync items error: $e');
      return <Map<String, dynamic>>[];
    });

    return localList;
  }

  @override
  Future<List<Map<String, dynamic>>> refreshItems(String sessionId) {
    return _syncItemsFromApi(sessionId);
  }

  Future<List<Map<String, dynamic>>> _syncItemsFromApi(String sessionId) async {
    final cursor = await _db.getSyncCursor(agentId, 'session_items', sessionId);
    final page = await _api.getItemsPage(sessionId, cursor: cursor);
    final newItems = page['items'] as List<dynamic>? ?? [];
    final companions = <SessionItemEntriesCompanion>[];
    for (final item in newItems) {
      final map = Map<String, dynamic>.from(item as Map);
      final itemId = map['item_id']?.toString() ?? map['id']?.toString() ?? '';
      if (itemId.isEmpty) continue;
      companions.add(
        SessionItemEntriesCompanion(
          agentId: Value(agentId),
          sessionId: Value(sessionId),
          itemId: Value(itemId),
          turnId: Value(map['turn_id']?.toString()),
          type: Value(
            SessionItemTypes.normalize(map['type']?.toString() ?? ''),
          ),
          status: Value(map['status']?.toString()),
          role: Value(map['role']?.toString()),
          summary: Value(map['summary']?.toString()),
          content: Value(_encodeJson(map['content'])),
          providerCursor: Value(
            map['cursor']?.toString() ?? map['provider_cursor']?.toString(),
          ),
          revision: Value(_parseInt(map['revision'])),
          itemIndex: Value(_parseInt(map['index']) ?? 0),
          createdAt: Value(_parseDateTime(map['created_at'])),
          updatedAt: Value(_parseDateTime(map['updated_at'])),
        ),
      );
    }

    if (companions.isNotEmpty) {
      await _db.insertOrUpdateItems(companions);
    }
    final nextCursor = page['cursor']?.toString();
    if (nextCursor != null && nextCursor.isNotEmpty) {
      await _db.setSyncCursor(agentId, 'session_items', sessionId, nextCursor);
    }

    final allItems = await _db.getItemsBySession(agentId, sessionId);
    return allItems.map(_itemToMap).toList();
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
      'workdir': s.workdir,
      'title': s.title,
      'status': s.status,
      'model': s.model,
      'effort': s.effort,
      'approval_policy': s.approvalPolicy,
      'sandbox_mode': s.sandboxMode,
      'provider_cursor': s.providerCursor,
      'created_at': s.createdAt.toIso8601String(),
      'updated_at': s.updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> _canonicalSessionMap(Map<String, dynamic> input) {
    final map = Map<String, dynamic>.from(input);
    final providerId = canonicalProviderId(map);
    if (providerId != null && providerId.isNotEmpty) {
      map['provider_id'] = providerId;
    }
    return map;
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

  Map<String, dynamic>? _completedItemFromEvent(
    String eventType,
    Map<String, dynamic> data,
  ) {
    switch (eventType) {
      case SessionEventTypes.message:
      case SessionEventTypes.commandCompleted:
      case SessionEventTypes.fileWrite:
      case SessionEventTypes.fileRead:
      case SessionEventTypes.mcpToolCompleted:
      case SessionEventTypes.itemCompleted:
      case SessionEventTypes.userMessage:
        return data;
      default:
        return null;
    }
  }

  String _itemTypeFromEvent(String eventType, Map<String, dynamic> data) {
    final rawType = data['type']?.toString() ?? data['item_type']?.toString();
    if (rawType != null && rawType.isNotEmpty) {
      return _normalizeItemType(rawType);
    }
    switch (eventType) {
      case SessionEventTypes.message:
      case SessionEventTypes.messageDelta:
        return 'agent_message';
      case SessionEventTypes.userMessage:
        return 'user_message';
      case SessionEventTypes.commandCompleted:
      case SessionEventTypes.commandOutputDelta:
        return 'command_execution';
      case SessionEventTypes.fileWrite:
      case SessionEventTypes.fileChangeOutputDelta:
        return 'file_change';
      case SessionEventTypes.fileRead:
        return 'file_read';
      case SessionEventTypes.mcpToolCompleted:
        return 'mcp_tool_call';
      case SessionEventTypes.planUpdated:
        return 'plan';
      case SessionEventTypes.diffUpdated:
        return 'diff';
      default:
        return 'event';
    }
  }

  String _normalizeItemType(String itemType) {
    return SessionItemTypes.normalize(itemType);
  }

  String? _roleForType(String type) {
    switch (type) {
      case 'user_message':
        return 'user';
      case 'agent_message':
        return 'assistant';
      default:
        return null;
    }
  }

  String _deltaText(Map<String, dynamic> data) {
    for (final key in ['delta', 'text', 'content', 'output']) {
      final value = data[key];
      if (value != null) return value.toString();
    }
    return '';
  }

  String _contentSummary(String type, Map<String, dynamic> content) {
    final text = content['text']?.toString();
    if (text != null && text.isNotEmpty) return _truncate(text, 160);
    final output = content['output']?.toString();
    if (output != null && output.isNotEmpty) return _truncate(output, 160);
    final command = content['command']?.toString();
    if (command != null && command.isNotEmpty) return _truncate(command, 160);
    final path = content['path']?.toString();
    if (path != null && path.isNotEmpty) return path;
    final changes = content['changes'];
    if (changes is List && changes.isNotEmpty && changes.first is Map) {
      final first = Map<String, dynamic>.from(changes.first as Map);
      final changePath = first['path']?.toString();
      if (changePath != null && changePath.isNotEmpty) return changePath;
    }
    return type;
  }

  String _commandSummary(
    Map<String, dynamic> data,
    Map<String, dynamic> content,
  ) {
    final command =
        data['command']?.toString() ?? content['command']?.toString();
    if (command != null && command.isNotEmpty) return _truncate(command, 160);
    return 'Command output';
  }

  String _planSummary(Map<String, dynamic> data) {
    final explanation = data['explanation']?.toString();
    if (explanation != null && explanation.isNotEmpty) {
      return _truncate(explanation, 160);
    }
    final plan = data['plan'];
    if (plan is List && plan.isNotEmpty) return 'Plan updated';
    return 'Plan';
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
      case SessionEventTypes.turnStarted:
        return SessionStatuses.running;
      case 'session.created':
        return SessionStatuses.normalize(data['status']) ??
            SessionStatuses.running;
      case SessionEventTypes.turnFailed:
        return SessionStatuses.failed;
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
