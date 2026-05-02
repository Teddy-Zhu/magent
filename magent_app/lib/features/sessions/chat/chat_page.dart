import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:magent_app/core/api/error_messages.dart';
import 'package:magent_app/core/providers/api_provider.dart';
import 'package:magent_app/core/repositories/bootstrap_repository.dart';
import 'package:magent_app/core/repositories/file_repository.dart';
import 'package:magent_app/core/repositories/git_repository.dart';
import 'package:magent_app/core/repositories/session_repository.dart';
import 'package:magent_app/core/session/session_language.dart';
import 'package:magent_app/core/services/app_settings_service.dart';
import 'package:magent_app/core/services/message_template_service.dart';
import 'package:magent_app/features/git/widgets/diff_sheet.dart';
import 'package:magent_app/features/sessions/widgets/message_template_sheet.dart';
import 'package:magent_app/l10n/app_localizations.dart';

class ChatPage extends ConsumerStatefulWidget {
  final String sessionId;

  const ChatPage({super.key, required this.sessionId});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _LinkedFileTarget {
  final String projectId;
  final String relativePath;

  const _LinkedFileTarget({
    required this.projectId,
    required this.relativePath,
  });
}

class _VisibleEventState {
  final List<Map<String, dynamic>> events;
  final int hiddenCount;

  const _VisibleEventState({required this.events, required this.hiddenCount});
}

class _ChatPageState extends ConsumerState<ChatPage> {
  static const _initialVisibleEventCount = 80;
  static const _eventPageSize = 80;
  static const _sendModeQueue = 'queue';
  static const _sendModeInterruptThenSend = 'interrupt_then_send';

  final List<Map<String, dynamic>> _events = [];
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _settings = AppSettingsService();
  final _templateService = MessageTemplateService();
  final List<Map<String, dynamic>> _inputItems = [];
  final List<Map<String, dynamic>> _selectedSkills = [];
  final List<Map<String, dynamic>> _skills = [];
  List<Map<String, dynamic>> _visibleEventsCache = const [];
  int _hiddenEventCountCache = 0;
  var _disposed = false;
  bool _loading = true;
  bool _resuming = false;
  bool _openAtBottom = true;
  bool _didInitialBottomScroll = false;
  bool _pendingScrollToBottom = false;
  bool _pendingJumpToBottom = false;
  bool _turnActive = false;
  bool _itemsRefreshInFlight = false;
  int _queuedInputCount = 0;
  AppApiClient? _api;
  SessionRepository? _repo;
  BootstrapRepository? _bootstrap;
  FileRepository? _files;
  GitRepository? _git;
  StreamSubscription<Map<String, dynamic>>? _sessionEventsSub;
  StreamSubscription<List<Map<String, dynamic>>>? _itemsSub;
  StreamSubscription<int>? _itemCountSub;
  Map<String, dynamic>? _session;
  int _visibleEventCount = _initialVisibleEventCount;
  int _totalEventCount = 0;

  bool get _isRunning {
    return SessionStatuses.isRunning(_session?['status']);
  }

  bool get _isExited {
    return SessionStatuses.isEnded(_session?['status']);
  }

  /// Session exists but is not loaded in provider — needs resume
  bool get _isIdle {
    if (_session == null && !_loading) return true;
    final status = SessionStatuses.normalize(_session?['status']);
    return status == null || SessionStatuses.canResume(status);
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _openAtBottom = await _settings.getSessionOpenAtBottom();
    _api = await loadActiveApi(ref);
    if (_api == null || !_isActive) {
      if (_isActive) setState(() => _loading = false);
      return;
    }
    final db = ref.read(appDatabaseProvider);
    _repo = SessionRepository(
      agentId: _api!.agentId,
      api: _api!.session,
      db: db,
    );
    _bootstrap = createBootstrapRepository(ref, _api!);
    _files = FileRepository(agentId: _api!.agentId, api: _api!.file, db: db);
    _git = GitRepository(agentId: _api!.agentId, api: _api!.git, db: db);
    _subscribeItems();
    _itemCountSub = _repo!.watchItemCount(widget.sessionId).listen((count) {
      if (!_isActive) return;
      if (_totalEventCount == count) return;
      setState(() => _totalEventCount = count);
    });
    final engine = ref.read(syncEngineProvider);
    engine?.start();
    unawaited(
      _loadSession().then((_) {
        if (_isActive) unawaited(_refreshSkills());
      }),
    );
    unawaited(_connectSessionEvents());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isActive) unawaited(_loadItems());
    });
  }

  void _subscribeItems() {
    _itemsSub?.cancel();
    _itemsSub = _repo!
        .watchItems(widget.sessionId, limit: _visibleEventCount)
        .listen((items) {
          if (!_isActive) return;
          final nextEvents = items.map(_itemToEvent).toList(growable: false);
          final nextVisibleState = _computeVisibleEventState(nextEvents);
          final eventsChanged = !_eventListsEqualShallow(_events, nextEvents);
          final visibleEventsChanged = !_eventListsEqualShallow(
            _visibleEventsCache,
            nextVisibleState.events,
          );
          final nextTurnActive = _itemsContainActiveTurn(items);
          final turnActiveChanged = _turnActive != nextTurnActive;
          final loadingChanged = _loading;
          final shouldInitialBottomScroll =
              !_didInitialBottomScroll && nextVisibleState.events.isNotEmpty;
          final shouldAutoScroll = visibleEventsChanged && _isNearBottom();
          if (!_isActive) return;
          if (eventsChanged ||
              visibleEventsChanged ||
              turnActiveChanged ||
              loadingChanged) {
            setState(() {
              if (eventsChanged) {
                _events
                  ..clear()
                  ..addAll(nextEvents);
              }
              if (eventsChanged || visibleEventsChanged) {
                _applyVisibleEventState(nextVisibleState);
              }
              if (turnActiveChanged) {
                _turnActive = nextTurnActive;
              }
              if (loadingChanged) {
                _loading = false;
              }
            });
          }
          if (shouldInitialBottomScroll) {
            _didInitialBottomScroll = true;
            if (_openAtBottom) {
              _jumpToBottom();
            }
          } else if (visibleEventsChanged &&
              (shouldAutoScroll || nextVisibleState.events.length <= 1)) {
            _scrollToBottom();
          }
        });
  }

  Future<void> _connectSessionEvents() async {
    final engine = ref.read(syncEngineProvider);
    if (engine == null) return;
    _sessionEventsSub = engine.sessionEvents.listen((event) {
      if (!_isActive) return;
      final sessionId = event['session_id']?.toString();
      if (sessionId != null && sessionId != widget.sessionId) return;
      final type = event['type']?.toString() ?? '';
      if (type == 'session.sync_required') {
        _loadItems();
        return;
      }
      if (type == 'server.hello' ||
          type == 'session.subscribed' ||
          type == 'session.replay_complete') {
        return;
      }
      final eventType =
          event['event_type']?.toString() ?? event['type']?.toString() ?? '';
      if (eventType == 'session.event') return;
      final normalized = <String, dynamic>{
        'type': SessionEventTypes.normalize(eventType),
        'data': event['data'],
      };
      final normalizedType = normalized['type'] as String;
      _applyTurnRuntimeState(normalizedType, normalized['data']);
      if (!_isRenderableRealtimeEvent(normalizedType)) return;
      if (_isItemProjectionEvent(normalizedType)) {
        _upsertRealtimeItemEvent(normalizedType, event);
        return;
      }
      final shouldAutoScroll = _isNearBottom();
      if (!_isActive) return;
      if (_events.isNotEmpty && _eventEquals(_events.last, normalized)) {
        return;
      }
      setState(() {
        _events.add(normalized);
        _recomputeVisibleEventCache();
      });
      if (shouldAutoScroll) _scrollToBottom();
    });
    await engine.subscribeSession(widget.sessionId);
  }

  bool _isRenderableRealtimeEvent(String type) {
    switch (type) {
      case SessionEventTypes.started:
      case SessionEventTypes.statusChanged:
        return false;
      default:
        return true;
    }
  }

  bool _isItemProjectionEvent(String type) {
    switch (type) {
      case SessionEventTypes.userMessage:
      case SessionEventTypes.message:
      case SessionEventTypes.messageDelta:
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

  void _upsertRealtimeItemEvent(String type, Map<String, dynamic> event) {
    final rawData = event['data'];
    final data = rawData is Map
        ? Map<String, dynamic>.from(rawData)
        : <String, dynamic>{};
    final itemKey = _eventItemKey(event, data);
    if (itemKey.isEmpty) return;

    final existingIndex = _events.indexWhere(
      (item) => item['_item_key'] == itemKey,
    );
    final existing = existingIndex >= 0 ? _events[existingIndex] : null;
    final existingData = existing?['data'] is Map
        ? Map<String, dynamic>.from(existing!['data'] as Map)
        : <String, dynamic>{};
    final next = _mergedRealtimeItemEvent(
      type: type,
      itemKey: itemKey,
      data: data,
      existingData: existingData,
    );
    if (next == null) return;

    final hasSameExisting =
        existingIndex >= 0 && _eventEquals(_events[existingIndex], next);
    if (hasSameExisting && !_hasMatchingPendingUserEvent(next)) {
      return;
    }
    final shouldAutoScroll = _isNearBottom();
    if (!_isActive) return;
    setState(() {
      _removeMatchingPendingUserEvent(next);
      final updatedIndex = _events.indexWhere(
        (item) => item['_item_key'] == itemKey,
      );
      if (updatedIndex >= 0) {
        _events[updatedIndex] = next;
      } else {
        _events.add(next);
      }
      _recomputeVisibleEventCache();
    });
    if (shouldAutoScroll) _scrollToBottom();
  }

  bool _hasMatchingPendingUserEvent(Map<String, dynamic> next) {
    final text = _pendingUserMessageText(next);
    if (text.isEmpty) return false;
    return _events.any((event) => _isMatchingPendingUserEvent(event, text));
  }

  void _removeMatchingPendingUserEvent(Map<String, dynamic> next) {
    final text = _pendingUserMessageText(next);
    if (text.isEmpty) return;
    _events.removeWhere((event) => _isMatchingPendingUserEvent(event, text));
  }

  String _pendingUserMessageText(Map<String, dynamic> next) {
    if (next['type'] != SessionEventTypes.userMessage) return '';
    final itemKey = next['_item_key']?.toString() ?? '';
    if (itemKey.isEmpty || itemKey.startsWith('local-')) return '';
    final text = _messageText(next['data'], ['content', 'text']).trim();
    return text;
  }

  bool _isMatchingPendingUserEvent(Map<String, dynamic> event, String text) {
    if (event['type'] != SessionEventTypes.userMessage) return false;
    final pendingKey = event['_item_key']?.toString() ?? '';
    if (!pendingKey.startsWith('local-')) return false;
    if (event['status']?.toString() != 'pending') return false;
    final pendingText = _messageText(event['data'], ['content', 'text']).trim();
    return pendingText == text;
  }

  Map<String, dynamic>? _mergedRealtimeItemEvent({
    required String type,
    required String itemKey,
    required Map<String, dynamic> data,
    required Map<String, dynamic> existingData,
  }) {
    final nextData = Map<String, dynamic>.from(existingData);
    var renderType = type;
    var status = 'in_progress';

    switch (type) {
      case SessionEventTypes.messageDelta:
        renderType = SessionEventTypes.message;
        nextData['text'] = '${nextData['text'] ?? ''}${_deltaText(data)}';
      case SessionEventTypes.planDelta:
        renderType = SessionEventTypes.plan;
        nextData['text'] = '${nextData['text'] ?? ''}${_deltaText(data)}';
      case SessionEventTypes.reasoningSummaryDelta:
        renderType = SessionEventTypes.reasoning;
        nextData['summary'] = '${nextData['summary'] ?? ''}${_deltaText(data)}';
      case SessionEventTypes.reasoningTextDelta:
        renderType = SessionEventTypes.reasoning;
        nextData['content'] = '${nextData['content'] ?? ''}${_deltaText(data)}';
      case SessionEventTypes.commandOutputDelta:
        renderType = SessionEventTypes.commandOutputDelta;
        nextData.addAll(_withoutDelta(data));
        nextData['output'] = '${nextData['output'] ?? ''}${_deltaText(data)}';
      case SessionEventTypes.fileChangeOutputDelta:
        renderType = SessionEventTypes.fileChangeOutputDelta;
        nextData.addAll(_withoutDelta(data));
        nextData['output'] = '${nextData['output'] ?? ''}${_deltaText(data)}';
      case SessionEventTypes.reasoningSummaryPart:
        renderType = SessionEventTypes.reasoning;
        final parts = List<dynamic>.from(
          nextData['summary_parts'] as List? ?? [],
        );
        parts.add(data);
        nextData['summary_parts'] = parts;
      case SessionEventTypes.planUpdated:
      case SessionEventTypes.diffUpdated:
        nextData.addAll(data);
      case SessionEventTypes.itemStarted:
        final item = _eventItemPayload(data);
        renderType = _eventTypeForItem(item, fallback: type);
        if (renderType.isEmpty) return null;
        nextData.addAll(item);
        _normalizeEventDataAliases(nextData);
        status = item['status']?.toString() ?? status;
        if (!_hasVisibleItemContent(renderType, nextData)) return null;
      case SessionEventTypes.itemCompleted:
        final item = _eventItemPayload(data);
        renderType = _eventTypeForItem(item, fallback: type);
        if (renderType.isEmpty) return null;
        nextData
          ..clear()
          ..addAll(item);
        _normalizeEventDataAliases(nextData);
        status = item['status']?.toString() ?? 'completed';
        if (!_hasVisibleItemContent(renderType, nextData)) return null;
      case SessionEventTypes.message:
      case SessionEventTypes.userMessage:
      case SessionEventTypes.commandCompleted:
      case SessionEventTypes.fileWrite:
      case SessionEventTypes.fileRead:
      case SessionEventTypes.mcpToolCompleted:
        nextData
          ..clear()
          ..addAll(data);
        _normalizeEventDataAliases(nextData);
        status = data['status']?.toString() ?? 'completed';
      default:
        return null;
    }

    return {
      '_item_key': itemKey,
      'type': renderType,
      'status': status,
      'data': nextData,
    };
  }

  String _eventItemKey(Map<String, dynamic> event, Map<String, dynamic> data) {
    for (final source in [event, data, _eventItemPayload(data)]) {
      for (final key in ['item_id', 'itemId', 'id']) {
        final value = source[key]?.toString();
        if (value != null && value.isNotEmpty) return value;
      }
    }
    return '';
  }

  Map<String, dynamic> _eventItemPayload(Map<String, dynamic> data) {
    final item = data['item'];
    if (item is Map) {
      final map = Map<String, dynamic>.from(item);
      for (final key in ['threadId', 'thread_id', 'turnId', 'turn_id']) {
        map.putIfAbsent(key, () => data[key]);
      }
      return map;
    }
    return data;
  }

  String _eventTypeForItem(
    Map<String, dynamic> item, {
    required String fallback,
  }) {
    switch (SessionItemTypes.normalize(item['type']?.toString() ?? '')) {
      case 'context_compaction':
        return '';
      case SessionItemTypes.userMessage:
        return SessionEventTypes.userMessage;
      case SessionItemTypes.agentMessage:
        return SessionEventTypes.message;
      case SessionItemTypes.commandExecution:
        return SessionEventTypes.commandCompleted;
      case SessionItemTypes.fileChange:
        return SessionEventTypes.fileWrite;
      case SessionItemTypes.fileRead:
        return SessionEventTypes.fileRead;
      case SessionItemTypes.mcpToolCall:
        return SessionEventTypes.mcpToolCompleted;
      case SessionItemTypes.plan:
        return SessionEventTypes.plan;
      case SessionItemTypes.reasoning:
        return SessionEventTypes.reasoning;
      case SessionItemTypes.diff:
        return SessionEventTypes.diffUpdated;
      default:
        return fallback;
    }
  }

  Map<String, dynamic> _withoutDelta(Map<String, dynamic> data) {
    final copy = Map<String, dynamic>.from(data);
    copy.remove('delta');
    return copy;
  }

  String _deltaText(Map<String, dynamic> data) {
    for (final key in ['delta', 'text', 'content', 'output']) {
      final value = data[key];
      if (value != null) return value.toString();
    }
    return '';
  }

  bool _hasVisibleItemContent(String type, Map<String, dynamic> data) {
    if (_isHiddenSessionItemType(data['type']?.toString()) ||
        _isHiddenSessionItemType(data['item_type']?.toString())) {
      return false;
    }
    switch (type) {
      case SessionEventTypes.message:
      case SessionEventTypes.userMessage:
        return _messageText(data, ['text', 'content']).trim().isNotEmpty;
      case SessionEventTypes.reasoning:
      case SessionEventTypes.reasoningSummaryDelta:
      case SessionEventTypes.reasoningTextDelta:
      case SessionEventTypes.reasoningSummaryPart:
        return _reasoningText(data, fallback: '').trim().isNotEmpty;
      case SessionEventTypes.commandCompleted:
      case SessionEventTypes.commandOutputDelta:
        return _commandText(_commandValue(data)).isNotEmpty ||
            _toolText(_commandOutputValue(data)).isNotEmpty ||
            _hasMeaningfulData(data, [
              'cwd',
              'status',
              'commandActions',
              'exit_code',
              'exitCode',
              'durationMs',
            ]);
      case SessionEventTypes.fileWrite:
      case SessionEventTypes.fileChangeOutputDelta:
      case SessionEventTypes.fileRead:
        return _hasMeaningfulData(data, [
          'path',
          'changes',
          'output',
          'diff',
          'kind',
          'status',
          'additions',
          'deletions',
          'change_count',
        ]);
      case SessionEventTypes.mcpToolCompleted:
        return _hasMeaningfulData(data, [
          'server',
          'tool',
          'name',
          'arguments',
          'result',
          'error',
          'output',
          'status',
        ]);
      default:
        return data.entries.any((entry) {
          if (entry.key.startsWith('_')) return false;
          return _isMeaningfulValue(entry.value);
        });
    }
  }

  void _normalizeEventDataAliases(Map<String, dynamic> data) {
    if (data['output'] == null && data['aggregatedOutput'] != null) {
      data['output'] = data['aggregatedOutput'];
    }
    if (data['output'] == null && data['stdout'] != null) {
      data['output'] = data['stdout'];
    }
    if (data['output'] == null && data['stderr'] != null) {
      data['output'] = data['stderr'];
    }
    if (data['exit_code'] == null && data['exitCode'] != null) {
      data['exit_code'] = data['exitCode'];
    }
    if (data['command'] == null) {
      for (final key in [
        'cmd',
        'cmdline',
        'argv',
        'args',
        'program',
        'script',
      ]) {
        if (_isMeaningfulValue(data[key])) {
          data['command'] = data[key];
          break;
        }
      }
    }
  }

  bool _hasMeaningfulData(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      if (_isMeaningfulValue(data[key])) return true;
    }
    return false;
  }

  bool _isMeaningfulValue(dynamic value) {
    if (value == null) return false;
    if (value is String) return value.trim().isNotEmpty;
    if (value is Iterable) return value.isNotEmpty;
    if (value is Map) return value.isNotEmpty;
    return true;
  }

  Future<void> _loadSession() async {
    if (_api == null) return;
    try {
      final cached = await _repo?.getCachedSession(widget.sessionId);
      if (cached != null && mounted) {
        _replaceSession(cached);
      }
      final session = await _api!.session.getSession(widget.sessionId);
      await _repo?.upsertSession(
        session,
        projectId:
            session['project_id']?.toString() ??
            cached?['project_id']?.toString(),
      );
      if (mounted) {
        _replaceSession(_mergeSession(cached, session));
        debugPrint('ChatPage: loaded session status=${_session?['status']}');
      }
    } on DioException catch (e) {
      debugPrint(
        'ChatPage: loadSession DioException: ${e.response?.statusCode} ${e.response?.data}',
      );
      // If 404, session might only exist in provider — set as idle
      if (e.response?.statusCode == 404 && mounted) {
        final cached = await _repo?.getCachedSession(widget.sessionId);
        if (cached != null) {
          _replaceSession({
            ...cached,
            'id': widget.sessionId,
            'status': SessionStatuses.stopped,
            'provider_id': cached['provider_id'] ?? 'codex',
          });
        } else {
          _replaceSession({
            'id': widget.sessionId,
            'status': SessionStatuses.lost,
            'provider_id': 'codex',
          });
        }
      }
    } catch (e) {
      debugPrint('ChatPage: loadSession error: $e');
    }
  }

  Map<String, dynamic> _mergeSession(
    Map<String, dynamic>? cached,
    Map<String, dynamic> remote,
  ) {
    final merged = <String, dynamic>{...?cached, ...remote};
    for (final key in ['project_id', 'provider_id', 'thread_id', 'workdir']) {
      final value = merged[key]?.toString();
      if ((value == null || value.isEmpty) && cached?[key] != null) {
        merged[key] = cached![key];
      }
    }
    return merged;
  }

  void _replaceSession(Map<String, dynamic> next) {
    if (!_isActive) return;
    if (_sessionUiEquals(_session, next)) {
      _session = next;
      return;
    }
    setState(() => _session = next);
  }

  bool _sessionUiEquals(
    Map<String, dynamic>? current,
    Map<String, dynamic> next,
  ) {
    if (current == null) return false;
    return _deepValueEquals(
      _sessionUiSnapshot(current),
      _sessionUiSnapshot(next),
    );
  }

  Map<String, dynamic> _sessionUiSnapshot(Map<String, dynamic> session) {
    return {
      for (final key in [
        'id',
        'provider_id',
        'thread_id',
        'project_id',
        'purpose',
        'workdir',
        'title',
        'status',
        'model',
        'effort',
        'approval_policy',
        'sandbox_mode',
      ])
        key: session[key],
    };
  }

  void _applyTurnRuntimeState(String type, Object? data) {
    if (!_isActive) return;
    switch (type) {
      case SessionEventTypes.started:
        _applySessionRuntimeStatus(SessionStatuses.running);
        break;
      case SessionEventTypes.turnStarted:
        final nextQueuedInputCount = _queuedInputCount > 0
            ? _queuedInputCount - 1
            : _queuedInputCount;
        if (_turnActive && _queuedInputCount == nextQueuedInputCount) return;
        setState(() {
          _turnActive = true;
          _queuedInputCount = nextQueuedInputCount;
        });
        break;
      case SessionEventTypes.turnCompleted:
        if (!_turnActive) return;
        setState(() => _turnActive = false);
        break;
      case SessionEventTypes.turnFailed:
      case SessionEventTypes.error:
        if (!_turnActive && _queuedInputCount == 0) return;
        setState(() {
          _turnActive = false;
          _queuedInputCount = 0;
        });
        break;
      case SessionEventTypes.exited:
        final currentStatus = SessionStatuses.normalize(_session?['status']);
        if (!_turnActive &&
            _queuedInputCount == 0 &&
            currentStatus == SessionStatuses.completed) {
          return;
        }
        setState(() {
          _turnActive = false;
          _queuedInputCount = 0;
          _session = {
            ...?_session,
            'id': widget.sessionId,
            'status': SessionStatuses.completed,
          };
        });
        break;
      case SessionEventTypes.statusChanged:
        _applySessionRuntimeStatus(_sessionRuntimeStatus(data));
        break;
    }
  }

  String? _sessionRuntimeStatus(Object? data) {
    if (data is! Map) return SessionStatuses.normalize(data);
    final status = data['status'];
    if (status is Map) {
      return SessionStatuses.normalize(
        status['type']?.toString() ?? status['status']?.toString(),
      );
    }
    return SessionStatuses.normalize(
      status?.toString() ?? data['type']?.toString(),
    );
  }

  void _applySessionRuntimeStatus(String? status) {
    if (status == null || !_isActive) return;
    final currentStatus = SessionStatuses.normalize(_session?['status']);
    final nextTurnActive = status == SessionStatuses.running
        ? _turnActive
        : false;
    final nextQueuedInputCount = status == SessionStatuses.running
        ? _queuedInputCount
        : 0;
    if (currentStatus == status &&
        _turnActive == nextTurnActive &&
        _queuedInputCount == nextQueuedInputCount) {
      return;
    }
    setState(() {
      _session = {...?_session, 'id': widget.sessionId, 'status': status};
      if (status != SessionStatuses.running) {
        _turnActive = false;
        _queuedInputCount = 0;
      }
    });
  }

  Future<void> _loadItems() async {
    if (_repo == null || _itemsRefreshInFlight) return;
    _itemsRefreshInFlight = true;
    try {
      await _repo!.refreshItems(widget.sessionId);
      if (mounted && _loading) setState(() => _loading = false);
    } catch (e) {
      debugPrint('ChatPage: loadEvents error: $e');
      if (mounted && _loading) setState(() => _loading = false);
    } finally {
      _itemsRefreshInFlight = false;
    }
  }

  Future<void> _refreshItemsFull() async {
    if (_repo == null || _itemsRefreshInFlight) return;
    _itemsRefreshInFlight = true;
    try {
      await _repo!.refreshItems(widget.sessionId, forceFull: true);
      if (mounted && _loading) setState(() => _loading = false);
    } catch (e) {
      debugPrint('ChatPage: refreshEvents error: $e');
      if (mounted && _loading) setState(() => _loading = false);
    } finally {
      _itemsRefreshInFlight = false;
    }
  }

  bool _itemsContainActiveTurn(List<Map<String, dynamic>> items) {
    for (final item in items) {
      final status = item['status']?.toString();
      if (status == 'in_progress' || status == 'inProgress') {
        return true;
      }
    }
    return false;
  }

  Future<void> _sendInput() async {
    final input = _inputController.text.trim();
    if (input.isEmpty || _api == null) return;
    final wasTurnActive = _turnActive;
    final mode = wasTurnActive
        ? await _chooseRunningSendMode()
        : _queuedInputCount > 0
        ? _sendModeQueue
        : null;
    if (mode == null && wasTurnActive) return;
    await _sendInputWithMode(mode);
  }

  Future<void> _sendInputWithMode(String? mode) async {
    final input = _inputController.text.trim();
    if (input.isEmpty || _api == null) return;
    final previousInput = _inputController.text;
    final previousItems = List<Map<String, dynamic>>.from(_inputItems);
    final previousSkills = List<Map<String, dynamic>>.from(_selectedSkills);
    final items = List<Map<String, dynamic>>.from(_inputItems);
    setState(() {
      _inputController.clear();
      _inputItems.clear();
      _selectedSkills.clear();
    });
    await _repo?.addPendingUserMessage(widget.sessionId, input);
    _visibleEventCount = _initialVisibleEventCount;
    _scrollToBottom();

    // Save to recent messages
    _templateService.addRecent(input);

    try {
      await _api!.session.sendInput(
        widget.sessionId,
        input,
        items: items,
        mode: mode,
      );
      if (!mounted) return;
      setState(() {
        if (mode == _sendModeQueue ||
            mode == _sendModeInterruptThenSend ||
            _queuedInputCount > 0) {
          _queuedInputCount++;
        }
        if (mode == _sendModeInterruptThenSend) {
          _turnActive = false;
        } else if (mode == null) {
          _turnActive = true;
        }
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final errCode = e.response?.data?['error']?['code'] as String?;
      if (errCode == 'SESSION_NOT_FOUND') {
        _restoreInputDraft(previousInput, previousItems, previousSkills);
        await _repo?.deleteCachedSession(widget.sessionId);
        _showSessionLostDialog();
      } else {
        _restoreInputDraft(previousInput, previousItems, previousSkills);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizedErrorMessage(
                AppLocalizations.of(context)!,
                e,
                action: AppLocalizations.of(context)!.chatSendFailed,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _restoreInputDraft(previousInput, previousItems, previousSkills);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizedErrorMessage(
                AppLocalizations.of(context)!,
                e,
                action: AppLocalizations.of(context)!.chatSendFailed,
              ),
            ),
          ),
        );
      }
    }
  }

  void _restoreInputDraft(
    String text,
    List<Map<String, dynamic>> items,
    List<Map<String, dynamic>> skills,
  ) {
    if (!mounted) return;
    setState(() {
      _inputController.text = text;
      _inputItems
        ..clear()
        ..addAll(items);
      _selectedSkills
        ..clear()
        ..addAll(skills);
    });
  }

  Future<String?> _chooseRunningSendMode() {
    final l10n = AppLocalizations.of(context)!;
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.bolt_outlined),
              title: Text(l10n.chatRunningTitle),
              subtitle: Text(l10n.chatRunningSubtitle),
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: Text(l10n.chatQueueMessage),
              subtitle: Text(l10n.chatQueueMessageSub),
              onTap: () => Navigator.pop(ctx, _sendModeQueue),
            ),
            ListTile(
              leading: const Icon(Icons.stop_circle_outlined),
              title: Text(l10n.chatInterruptAndSend),
              subtitle: Text(l10n.chatInterruptAndSendSub),
              onTap: () => Navigator.pop(ctx, _sendModeInterruptThenSend),
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: Text(l10n.cancel),
              onTap: () => Navigator.pop(ctx),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showSessionLostDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.chatSessionLostTitle),
        content: Text(l10n.chatSessionLostContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.pop();
            },
            child: Text(l10n.back),
          ),
        ],
      ),
    );
  }

  Future<void> _resume() async {
    if (_api == null) return;
    setState(() => _resuming = true);
    try {
      await _api!.session.resume(widget.sessionId);
      await _loadSession();
      await _loadItems();
    } on DioException catch (e) {
      if (!mounted) return;
      final errCode = e.response?.data?['error']?['code'] as String?;
      if (errCode == 'SESSION_NOT_FOUND') {
        await _repo?.deleteCachedSession(widget.sessionId);
        _showSessionLostDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizedErrorMessage(
                AppLocalizations.of(context)!,
                e,
                action: AppLocalizations.of(context)!.chatStartFailed,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizedErrorMessage(
                AppLocalizations.of(context)!,
                e,
                action: AppLocalizations.of(context)!.chatStartFailed,
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _resuming = false);
    }
  }

  Future<void> _interrupt() async {
    if (_api == null) return;
    try {
      await _api!.session.interrupt(widget.sessionId);
      if (mounted) {
        if (_turnActive) setState(() => _turnActive = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.chatInterruptSent),
          ),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        final msg = localizedErrorMessage(
          l10n,
          e,
          action: l10n.chatInterruptFailed,
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizedErrorMessage(
                AppLocalizations.of(context)!,
                e,
                action: AppLocalizations.of(context)!.chatInterruptFailed,
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _stop() async {
    if (_api == null) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.chatStopSession),
        content: Text(l10n.chatStopConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l10n.chatStop,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _api!.session.stop(widget.sessionId);
      if (mounted) {
        _applySessionRuntimeStatus(SessionStatuses.stopped);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.chatSessionStopped)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizedErrorMessage(
                AppLocalizations.of(context)!,
                e,
                action: AppLocalizations.of(context)!.chatStopFailed,
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _respondApproval(String approvalId, String action) async {
    if (_api == null) return;
    try {
      await _api!.session.approve(widget.sessionId, approvalId, action);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizedErrorMessage(
                AppLocalizations.of(context)!,
                e,
                action: AppLocalizations.of(context)!.chatApprovalFailed,
              ),
            ),
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    if (_pendingScrollToBottom || _pendingJumpToBottom) return;
    _pendingScrollToBottom = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_pendingScrollToBottom || !_isActive) return;
      _pendingScrollToBottom = false;
      if (_scrollController.hasClients) {
        final position = _scrollController.position;
        final target = position.maxScrollExtent;
        if ((position.pixels - target).abs() < 1) return;
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _jumpToBottom() {
    if (_pendingJumpToBottom) return;
    _pendingScrollToBottom = false;
    _pendingJumpToBottom = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_pendingJumpToBottom || !_isActive) return;
      _pendingJumpToBottom = false;
      if (_scrollController.hasClients) {
        final position = _scrollController.position;
        final target = position.maxScrollExtent;
        if ((position.pixels - target).abs() < 1) return;
        _scrollController.jumpTo(target);
      }
    });
  }

  bool _isNearBottom() {
    if (!_isActive) return false;
    if (!_scrollController.hasClients) return true;
    final position = _scrollController.position;
    return position.maxScrollExtent - position.pixels < 180;
  }

  List<Map<String, dynamic>> get _visibleEvents {
    return _visibleEventsCache;
  }

  _VisibleEventState _computeVisibleEventState(
    List<Map<String, dynamic>> events,
  ) {
    final visible = <Map<String, dynamic>>[];
    var renderableCount = 0;
    for (final event in events) {
      if (!_isVisibleEvent(event)) continue;
      renderableCount++;
      visible.add(event);
      if (visible.length > _visibleEventCount) {
        visible.removeAt(0);
      }
    }
    final hidden = renderableCount - visible.length;
    return _VisibleEventState(
      events: visible,
      hiddenCount: hidden > 0 ? hidden : 0,
    );
  }

  void _applyVisibleEventState(_VisibleEventState state) {
    _visibleEventsCache = state.events;
    _hiddenEventCountCache = state.hiddenCount;
  }

  void _recomputeVisibleEventCache() {
    _applyVisibleEventState(_computeVisibleEventState(_events));
  }

  bool _eventListsEqualShallow(
    List<Map<String, dynamic>> left,
    List<Map<String, dynamic>> right,
  ) {
    if (identical(left, right)) return true;
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (!_eventShallowEquals(left[i], right[i])) return false;
    }
    return true;
  }

  bool _eventListsEqual(
    List<Map<String, dynamic>> left,
    List<Map<String, dynamic>> right,
  ) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (!_eventEquals(left[i], right[i])) return false;
    }
    return true;
  }

  bool _eventEquals(Map<String, dynamic> left, Map<String, dynamic> right) {
    return _deepValueEquals(left, right);
  }

  bool _eventShallowEquals(
    Map<String, dynamic> left,
    Map<String, dynamic> right,
  ) {
    if (identical(left, right)) return true;
    if (left['_item_key'] != right['_item_key']) return false;
    if (left['type'] != right['type']) return false;
    if (left['status'] != right['status']) return false;
    if (left['_item_key'] != null || right['_item_key'] != null) {
      for (final key in ['_index', '_summary', '_content_sig']) {
        if (left[key] != right[key]) return false;
      }
      return true;
    }
    return _deepValueEquals(left['data'], right['data']);
  }

  bool _deepValueEquals(Object? left, Object? right) {
    if (identical(left, right)) return true;
    if (left is Map && right is Map) {
      if (left.length != right.length) return false;
      for (final key in left.keys) {
        if (!right.containsKey(key)) return false;
        if (!_deepValueEquals(left[key], right[key])) return false;
      }
      return true;
    }
    if (left is List && right is List) {
      if (left.length != right.length) return false;
      for (var i = 0; i < left.length; i++) {
        if (!_deepValueEquals(left[i], right[i])) return false;
      }
      return true;
    }
    return left == right;
  }

  bool _isVisibleEvent(Map<String, dynamic> event) {
    final type = event['type']?.toString() ?? '';
    final data = event['data'];
    if (data is Map) {
      return _hasVisibleItemContent(type, Map<String, dynamic>.from(data));
    }
    return true;
  }

  int get _hiddenEventCount {
    if (_totalEventCount > _events.length) {
      return _totalEventCount - _events.length + _hiddenEventCountCache;
    }
    return _hiddenEventCountCache;
  }

  void _loadMoreEvents() {
    if (_hiddenEventCount == 0) return;
    if (!_isActive) return;
    setState(() => _visibleEventCount += _eventPageSize);
    _subscribeItems();
  }

  String _eventRenderKey(Map<String, dynamic> event, int index) {
    final itemKey = event['_item_key']?.toString();
    if (itemKey != null && itemKey.isNotEmpty) return 'item:$itemKey';
    final data = event['data'];
    final dataId = data is Map ? data['id']?.toString() : null;
    final suffix = dataId == null || dataId.isEmpty ? index.toString() : dataId;
    return '${event['type']}:$suffix';
  }

  void _openTemplates() {
    MessageTemplateSheet.show(
      context,
      onSelect: (text) {
        _inputController.text = text;
      },
    );
  }

  Future<void> _openSkillPicker() async {
    if (_bootstrap == null) return;
    if (_skills.isEmpty) {
      await _refreshSkills(showError: true);
    }
    if (!mounted) return;
    if (_skills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.chatNoSkills)),
      );
      return;
    }
    final selected = await _SkillPickerSheet.show(context, _skills);
    if (selected == null) return;
    _insertSkill(selected);
  }

  Future<void> _refreshSkills({bool showError = false}) async {
    if (_bootstrap == null) return;
    final providerId = _session == null
        ? 'codex'
        : canonicalProviderId(Map<String, dynamic>.from(_session!)) ?? 'codex';
    try {
      final config = await _bootstrap!.fetchProviderConfig(providerId);
      final skills = _skillsFromConfig(config);
      if (!mounted) return;
      if (_eventListsEqual(_skills, skills)) return;
      setState(() {
        _skills
          ..clear()
          ..addAll(skills);
      });
    } catch (e) {
      if (!mounted || !showError) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizedErrorMessage(
              AppLocalizations.of(context)!,
              e,
              action: AppLocalizations.of(context)!.chatLoadSkillsFailed,
            ),
          ),
        ),
      );
    }
  }

  Future<void> _openFilePicker() async {
    if (_files == null || _session == null) return;
    final projectId = await _resolveProjectId();
    if (!mounted) return;
    if (projectId == null || projectId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.chatMissingProject),
        ),
      );
      return;
    }
    final selected = await _WorkspaceFilePickerSheet.show(
      context,
      file: _files!,
      projectId: projectId,
    );
    if (selected == null || selected.path.isEmpty) return;
    _insertTextToken(_workspacePathToken(selected.path));
  }

  String _workspacePathToken(String path) {
    final providerId = _session == null
        ? null
        : canonicalProviderId(Map<String, dynamic>.from(_session!));
    switch (providerId?.toLowerCase()) {
      case 'codex':
        return path;
      case 'claude':
      default:
        return '@$path';
    }
  }

  Future<void> _openChanges() async {
    final projectId = await _resolveProjectId();
    if (!mounted) return;
    if (projectId == null || projectId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.chatMissingProject),
        ),
      );
      return;
    }
    context.push('/git/manage', extra: {'projectId': projectId});
  }

  Future<void> _openLinkedFileDiff(String? href) async {
    final targetPath = _pathFromMarkdownHref(href);
    if (targetPath == null || _git == null) return;
    final linkTarget = await _resolveLinkedFileTarget(targetPath);
    if (!mounted) return;
    if (linkTarget == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.chatMissingProject),
        ),
      );
      return;
    }

    try {
      final file = await _changedFileForPath(
        linkTarget.projectId,
        linkTarget.relativePath,
      );
      final staged =
          file?['staged'] == true ||
          (file == null &&
              await _shouldUseStagedDiff(
                linkTarget.projectId,
                linkTarget.relativePath,
              ));
      if (!mounted) return;
      DiffSheet.show(
        context: context,
        git: _git!,
        file: _files,
        projectId: linkTarget.projectId,
        path: linkTarget.relativePath,
        diffHash: file?['diff_hash']?.toString() ?? '',
        isBinary: file?['binary'] == true,
        staged: staged,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizedErrorMessage(
              AppLocalizations.of(context)!,
              e,
              action: AppLocalizations.of(context)!.gitLoadDiffFailed,
            ),
          ),
        ),
      );
    }
  }

  String? _pathFromMarkdownHref(String? href) {
    final raw = href?.trim();
    if (raw == null || raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    final value = uri == null || !uri.hasScheme
        ? raw
        : uri.scheme == 'file'
        ? uri.toFilePath()
        : null;
    if (value == null || value.isEmpty) return null;
    return _decodeUriText(value).replaceFirst(RegExp(r':\d+$'), '');
  }

  String _decodeUriText(String value) {
    try {
      return Uri.decodeFull(value);
    } catch (_) {
      try {
        return Uri.decodeComponent(value);
      } catch (_) {
        return value;
      }
    }
  }

  Future<_LinkedFileTarget?> _resolveLinkedFileTarget(String path) async {
    final projects = await _loadKnownProjects();
    final matched = _projectForPath(projects, path);
    if (matched != null) {
      final projectId = matched['id']?.toString();
      final root = matched['path']?.toString();
      final relativePath = _relativePathForProject(path, root);
      if (projectId != null &&
          projectId.isNotEmpty &&
          relativePath != null &&
          relativePath.isNotEmpty) {
        return _LinkedFileTarget(
          projectId: projectId,
          relativePath: relativePath,
        );
      }
    }

    final projectId = await _resolveProjectId();
    if (projectId == null || projectId.isEmpty) return null;
    final projectRoot = await _resolveProjectRoot(projectId);
    final relativePath = _relativePathForProject(path, projectRoot);
    if (relativePath == null || relativePath.isEmpty) return null;
    return _LinkedFileTarget(projectId: projectId, relativePath: relativePath);
  }

  Future<List<Map<String, dynamic>>> _loadKnownProjects() async {
    if (_bootstrap == null) return const [];
    var projects = await _bootstrap!.getProjects();
    if (projects.isEmpty) {
      projects = await _bootstrap!.refreshProjects();
    }
    return projects;
  }

  Map<String, dynamic>? _projectForPath(
    List<Map<String, dynamic>> projects,
    String path,
  ) {
    final normalizedPath = _normalizePath(path);
    if (!normalizedPath.startsWith('/')) return null;
    Map<String, dynamic>? best;
    var bestLength = -1;
    for (final project in projects) {
      final root = _normalizePath(project['path']?.toString());
      if (root.isEmpty) continue;
      final rootPrefix = root.endsWith('/') ? root : '$root/';
      final matches =
          normalizedPath == root || normalizedPath.startsWith(rootPrefix);
      if (matches && root.length > bestLength) {
        best = project;
        bestLength = root.length;
      }
    }
    return best;
  }

  Future<Map<String, dynamic>?> _changedFileForPath(
    String projectId,
    String relativePath,
  ) async {
    final snapshot = await _git!.refreshSnapshot(projectId);
    return _findChangedFile(snapshot.files, relativePath);
  }

  Future<bool> _shouldUseStagedDiff(
    String projectId,
    String relativePath,
  ) async {
    final unstaged = await _git!.getFileDiff(
      projectId,
      relativePath,
      '',
      offset: 0,
      limit: 1,
      staged: false,
    );
    if (_diffHasLines(unstaged)) return false;
    final staged = await _git!.getFileDiff(
      projectId,
      relativePath,
      '',
      offset: 0,
      limit: 1,
      staged: true,
    );
    return _diffHasLines(staged);
  }

  bool _diffHasLines(Map<String, dynamic> diff) {
    final total = diff['total_lines'];
    if (total is int && total > 0) return true;
    final lines = diff['lines'];
    return lines is List && lines.isNotEmpty;
  }

  Future<String?> _resolveProjectRoot(String projectId) async {
    final project = await _bootstrap?.getProject(projectId);
    final projectPath = project?['path']?.toString();
    if (projectPath != null && projectPath.isNotEmpty) {
      return projectPath;
    }
    final sessionWorkdir = _session?['workdir']?.toString();
    if (sessionWorkdir != null && sessionWorkdir.isNotEmpty) {
      return sessionWorkdir;
    }
    final cached = await _repo?.getCachedSession(widget.sessionId);
    final cachedWorkdir = cached?['workdir']?.toString();
    if (cachedWorkdir != null && cachedWorkdir.isNotEmpty) {
      return cachedWorkdir;
    }
    return null;
  }

  String? _relativePathForProject(String path, String? projectRoot) {
    final normalizedPath = _normalizePath(path);
    final normalizedRoot = _normalizePath(projectRoot);
    if (normalizedPath.isEmpty) return null;
    if (!normalizedPath.startsWith('/')) return normalizedPath;
    if (normalizedRoot.isEmpty) return null;
    if (normalizedPath == normalizedRoot) return null;
    final rootPrefix = normalizedRoot.endsWith('/')
        ? normalizedRoot
        : '$normalizedRoot/';
    if (!normalizedPath.startsWith(rootPrefix)) return null;
    return normalizedPath.substring(rootPrefix.length);
  }

  Map<String, dynamic>? _findChangedFile(List<dynamic> files, String path) {
    final normalizedPath = _normalizePath(path);
    Map<String, dynamic>? stagedMatch;
    for (final file in files) {
      if (file is! Map) continue;
      final map = Map<String, dynamic>.from(file);
      if (_normalizePath(_decodeUriText(map['path']?.toString() ?? '')) ==
          normalizedPath) {
        if (map['staged'] != true) return map;
        stagedMatch ??= map;
      }
    }
    return stagedMatch;
  }

  Future<String?> _resolveProjectId() async {
    final current = _session?['project_id']?.toString();
    if (current != null && current.isNotEmpty) return current;

    final cached = await _repo?.getCachedSession(widget.sessionId);
    final cachedProjectId = cached?['project_id']?.toString();
    if (cachedProjectId != null && cachedProjectId.isNotEmpty) {
      if (mounted) {
        _replaceSession(_mergeSession(_session, cached!));
      }
      return cachedProjectId;
    }

    if (_bootstrap == null) return null;
    final workdir =
        _session?['workdir']?.toString() ?? cached?['workdir']?.toString();
    var projects = await _bootstrap!.getProjects();
    if (projects.isEmpty) {
      projects = await _bootstrap!.refreshProjects();
    }
    final matched = _projectForWorkdir(projects, workdir);
    final id = matched?['id']?.toString();
    if (id != null && id.isNotEmpty && mounted) {
      _replaceSession({
        ...?_session,
        ...?cached,
        'project_id': id,
        if (matched?['path'] != null) 'workdir': matched!['path'],
      });
    }
    return id;
  }

  Map<String, dynamic>? _projectForWorkdir(
    List<Map<String, dynamic>> projects,
    String? workdir,
  ) {
    if (projects.length == 1) return projects.first;
    final normalizedWorkdir = _normalizePath(workdir);
    if (normalizedWorkdir.isEmpty) return null;
    for (final project in projects) {
      if (_normalizePath(project['path']?.toString()) == normalizedWorkdir) {
        return project;
      }
    }
    return null;
  }

  String _normalizePath(String? path) {
    if (path == null) return '';
    var value = path.trim();
    while (value.length > 1 && value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  List<Map<String, dynamic>> _skillsFromConfig(Map<String, dynamic> config) {
    final rawSkills = config['skills'];
    final result = <Map<String, dynamic>>[];

    void collect(dynamic value) {
      if (value is Map) {
        final map = Map<String, dynamic>.from(value);
        if (map['name'] != null && map['path'] != null) {
          result.add(map);
        }
        final nestedSkills = map['skills'];
        if (nestedSkills is List) {
          for (final skill in nestedSkills) {
            collect(skill);
          }
        }
        final data = map['data'];
        if (data is List) {
          for (final item in data) {
            collect(item);
          }
        }
      } else if (value is List) {
        for (final item in value) {
          collect(item);
        }
      }
    }

    collect(rawSkills);
    final seen = <String>{};
    return result
        .where((skill) {
          final key = '${skill['name']}|${skill['path']}';
          if (seen.contains(key)) return false;
          seen.add(key);
          return true;
        })
        .toList(growable: false);
  }

  void _insertSkill(Map<String, dynamic> skill) {
    final name = skill['name']?.toString() ?? '';
    final path = skill['path']?.toString() ?? '';
    if (name.isEmpty || path.isEmpty) return;
    _inputItems.removeWhere(
      (item) => item['type'] == 'skill' && item['name'] == name,
    );
    _inputItems.add({'type': 'skill', 'name': name, 'path': path});
    _selectedSkills.removeWhere((item) => item['name'] == name);
    _selectedSkills.add(skill);
    _insertTextToken('\$$name');
  }

  void _insertTextToken(String token) {
    final current = _inputController.text;
    final selection = _inputController.selection;
    final insert = current.isEmpty || current.endsWith(' ') ? token : ' $token';
    final start = selection.isValid ? selection.start : current.length;
    final end = selection.isValid ? selection.end : current.length;
    final next = current.replaceRange(start, end, insert);
    _inputController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + insert.length),
    );
  }

  Map<String, dynamic> _itemToEvent(Map<String, dynamic> item) {
    final type = SessionItemTypes.normalize(item['type']?.toString() ?? '');
    if (_isHiddenSessionItemType(type)) {
      return {'type': '', 'data': const <String, dynamic>{}};
    }
    final content = item['content'];
    final data = content is Map<String, dynamic>
        ? content
        : <String, dynamic>{'value': content};
    Map<String, dynamic> buildEvent(String eventType) {
      final event = <String, dynamic>{'type': eventType, 'data': data};
      final itemKey = item['item_id']?.toString();
      if (itemKey != null && itemKey.isNotEmpty) event['_item_key'] = itemKey;
      final status = item['status']?.toString();
      if (status != null && status.isNotEmpty) event['status'] = status;
      for (final entry in {
        '_index': item['index'],
        '_summary': item['summary'],
        '_content_sig': item['content']?.toString(),
      }.entries) {
        if (entry.value != null) event[entry.key] = entry.value;
      }
      return event;
    }

    switch (type) {
      case SessionItemTypes.userMessage:
        return buildEvent(SessionEventTypes.userMessage);
      case SessionItemTypes.agentMessage:
        return buildEvent(SessionEventTypes.message);
      case SessionItemTypes.commandExecution:
        return buildEvent(SessionEventTypes.commandCompleted);
      case SessionItemTypes.fileChange:
        return buildEvent(SessionEventTypes.fileWrite);
      case SessionItemTypes.fileRead:
        return buildEvent(SessionEventTypes.fileRead);
      case SessionItemTypes.mcpToolCall:
        return buildEvent(SessionEventTypes.mcpToolCompleted);
      case SessionItemTypes.plan:
        return buildEvent(SessionEventTypes.plan);
      case SessionItemTypes.reasoning:
        return buildEvent(SessionEventTypes.reasoning);
      case SessionItemTypes.diff:
        return buildEvent(SessionEventTypes.diffUpdated);
      default:
        return buildEvent(SessionEventTypes.itemCompleted)
          ..['data'] = {...data, 'item_type': type};
    }
  }

  bool _isHiddenSessionItemType(String? type) {
    if (type == null || type.isEmpty) return false;
    return SessionItemTypes.normalize(type) == 'context_compaction';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final status = SessionStatuses.normalizeOrStopped(_session?['status']);
    final title = _session?['title'] as String? ?? l10n.chatTitle;
    final provider = _session == null
        ? null
        : canonicalProviderId(Map<String, dynamic>.from(_session!));
    final visibleEvents = _visibleEvents;
    final hiddenEventCount = _hiddenEventCount;
    final hasVisibleContent = visibleEvents.isNotEmpty || hiddenEventCount > 0;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16)),
            Row(
              children: [
                _StatusDot(status: status),
                const SizedBox(width: 4),
                Text(
                  _sessionStatusLabel(l10n, status),
                  style: TextStyle(fontSize: 12, color: _statusColor(status)),
                ),
                if (provider != null && provider.isNotEmpty) ...[
                  Text(
                    ' · ',
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                  Text(
                    provider,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.difference_outlined),
            onPressed: _openChanges,
            tooltip: l10n.gitChanges,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshItemsFull,
            tooltip: l10n.chatRefresh,
          ),
          if (_isRunning)
            IconButton(
              icon: const Icon(Icons.stop_circle_outlined),
              onPressed: _stop,
              tooltip: l10n.chatStopSession,
              color: Colors.red,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : !hasVisibleContent
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    cacheExtent: 360,
                    addAutomaticKeepAlives: false,
                    addRepaintBoundaries: true,
                    itemCount:
                        visibleEvents.length + (hiddenEventCount > 0 ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (hiddenEventCount > 0 && index == 0) {
                        return _LoadMoreEventsBanner(
                          hiddenCount: hiddenEventCount,
                          onTap: _loadMoreEvents,
                        );
                      }
                      final eventIndex = hiddenEventCount > 0
                          ? index - 1
                          : index;
                      final event = visibleEvents[eventIndex];
                      return KeyedSubtree(
                        key: ValueKey(_eventRenderKey(event, eventIndex)),
                        child: _buildEventWidget(event),
                      );
                    },
                  ),
          ),
          if (_isIdle) _buildIdleBar(),
          if (_isRunning) _buildInputBar(),
          if (_isExited) _buildExitedBar(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            _isExited ? l10n.chatSessionEnded : l10n.chatNoMessages,
            style: TextStyle(color: Colors.grey[500], fontSize: 15),
          ),
          if (_isExited) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () =>
                  context.push('/sessions/${widget.sessionId}/fork'),
              icon: const Icon(Icons.fork_right, size: 16),
              label: Text(l10n.chatCreateNewSession),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIdleBar() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.play_circle_outline,
            size: 40,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.chatSessionNotStarted,
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _resuming ? null : _resume,
            icon: _resuming
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow),
            label: Text(_resuming ? l10n.chatStarting : l10n.chatStartSession),
          ),
        ],
      ),
    );
  }

  Widget _buildExitedBar() {
    final l10n = AppLocalizations.of(context)!;
    final status = SessionStatuses.normalizeOrStopped(_session?['status']);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.grey[500]),
          const SizedBox(width: 8),
          Text(
            '${l10n.settingsSession}${_sessionStatusLabel(l10n, status)}',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () {
              // Navigate back to project to create a new session
              context.pop();
            },
            icon: const Icon(Icons.add, size: 16),
            label: Text(l10n.chatNewSession),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_turnActive) ...[
            _RunningTurnBar(
              queuedCount: _queuedInputCount,
              onInterrupt: _interrupt,
              l10n: l10n,
            ),
            const SizedBox(height: 8),
          ] else if (_queuedInputCount > 0) ...[
            _QueuedInputBar(count: _queuedInputCount, l10n: l10n),
            const SizedBox(height: 8),
          ],
          _InputToolbar(
            selectedSkills: _selectedSkills,
            l10n: l10n,
            onTemplates: _openTemplates,
            onSkill: _openSkillPicker,
            onFile: _openFilePicker,
            onRemoveSkill: (name) {
              setState(() {
                _selectedSkills.removeWhere((s) => s['name'] == name);
                _inputItems.removeWhere(
                  (item) => item['type'] == 'skill' && item['name'] == name,
                );
              });
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputController,
                  decoration: InputDecoration(
                    hintText: l10n.chatInputHint,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    isDense: true,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.send, size: 18),
                      onPressed: _sendInput,
                    ),
                  ),
                  onSubmitted: (_) => _sendInput(),
                  textInputAction: TextInputAction.send,
                  minLines: 1,
                  maxLines: 4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEventWidget(Map<String, dynamic> event) {
    final l10n = AppLocalizations.of(context)!;
    final type = event['type'] as String? ?? '';
    final data = event['data'];

    switch (type) {
      case 'user.input':
        return _UserBubble(content: _messageText(data, ['content', 'text']));
      case SessionEventTypes.userMessage:
        return _UserBubble(content: _messageText(data, ['text', 'content']));
      case SessionEventTypes.message:
        return _MessageBubble(
          content: _messageText(data, ['text', 'content']),
          onTapLink: (_, href, _) => _openLinkedFileDiff(href),
        );
      case SessionEventTypes.messageDelta:
        return _MessageBubble(
          content: _messageText(data, ['delta', 'text', 'content']),
          onTapLink: (_, href, _) => _openLinkedFileDiff(href),
        );
      case SessionEventTypes.output:
        return _MessageBubble(
          content: _messageText(data, ['content', 'text']),
          onTapLink: (_, href, _) => _openLinkedFileDiff(href),
        );
      case SessionEventTypes.plan:
      case SessionEventTypes.planDelta:
      case SessionEventTypes.planUpdated:
        return _StructuredInfoCard(
          icon: Icons.checklist,
          title: l10n.chatPlan,
          content: _planText(data),
        );
      case SessionEventTypes.reasoning:
      case SessionEventTypes.reasoningSummaryDelta:
      case SessionEventTypes.reasoningTextDelta:
      case SessionEventTypes.reasoningSummaryPart:
        return _StructuredInfoCard(
          icon: Icons.psychology_outlined,
          title: l10n.chatReasoningSummary,
          content: _reasoningText(data),
        );
      case SessionEventTypes.diffUpdated:
        return _StructuredInfoCard(
          icon: Icons.difference_outlined,
          title: l10n.chatDiffSummary,
          content: data?['diff']?.toString() ?? l10n.chatDiffSummary,
          monospace: true,
        );
      case SessionEventTypes.commandOutputDelta:
        return _ToolCallCard(
          icon: Icons.terminal,
          title: _commandTitle(
            _commandValue(data),
            fallback: l10n.chatCommandOutput,
          ),
          output: _toolText(data?['delta'] ?? _commandOutputValue(data)),
          success: true,
        );
      case SessionEventTypes.fileChangeOutputDelta:
        return _ToolCallCard(
          icon: Icons.edit_note,
          title: _toolText(data?['path'], fallback: l10n.chatFileChangeOutput),
          output: _toolText(data?['delta'] ?? data?['output']),
          success: true,
        );
      case SessionEventTypes.commandCompleted:
        return _ToolCallCard(
          icon: Icons.terminal,
          title: _commandTitle(_commandValue(data), fallback: l10n.chatCommand),
          output: _commandCompletedOutput(data),
          success: _commandSuccess(data),
        );
      case SessionEventTypes.fileWrite:
        return _ToolCallCard(
          icon: Icons.edit_note,
          title: _toolText(data?['path'], fallback: l10n.chatFileChange),
          output: _fileChangeSummary(data),
          success: true,
        );
      case SessionEventTypes.fileRead:
        return _ToolCallCard(
          icon: Icons.visibility_outlined,
          title: _toolText(data?['path'], fallback: l10n.chatReadFile),
          output: l10n.chatReadFile,
          success: true,
        );
      case SessionEventTypes.mcpToolCompleted:
        return _ToolCallCard(
          icon: Icons.extension_outlined,
          title: _toolText(
            data?['tool'] ?? data?['name'] ?? data?['server'],
            fallback: 'MCP Tool',
          ),
          output: _toolText(
            data?['output'] ?? data?['result'] ?? data?['error'],
          ),
          success: data?['error'] == null,
        );
      case SessionEventTypes.turnStarted:
        return _InfoChip(
          label: l10n.chatTurnStarted,
          icon: Icons.play_circle_outline,
        );
      case SessionEventTypes.turnCompleted:
        return _InfoChip(
          label: l10n.chatTurnCompleted,
          icon: Icons.check_circle_outline,
        );
      case SessionEventTypes.turnFailed:
        return _InfoChip(
          label: l10n.chatTurnFailed,
          icon: Icons.error_outline,
          isError: true,
        );
      case SessionEventTypes.approvalRequest:
        final approvalId =
            data?['approval_id']?.toString() ??
            data?['id']?.toString() ??
            data?['item_id']?.toString() ??
            '';
        return _ApprovalCard(
          request: data,
          onRespond: (action) => _respondApproval(approvalId, action),
        );
      case SessionEventTypes.approvalResolved:
        return _InfoChip(
          label: l10n.chatApprovalResolved,
          icon: Icons.check_circle_outline,
        );
      case SessionEventTypes.error:
        return _ErrorCard(
          message: _toolText(
            data?['error'] ?? data?['message'],
            fallback: l10n.error,
          ),
        );
      case SessionEventTypes.exited:
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              l10n.chatExited(data?['exit_code'] ?? 0),
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        );
      default:
        return _StructuredInfoCard(
          icon: Icons.data_object,
          title: _genericItemTitle(type, data),
          content: _genericItemContent(data),
          monospace: true,
        );
    }
  }

  String _planText(dynamic data) {
    if (data is! Map) return '';
    final text = data['text']?.toString();
    if (text != null && text.isNotEmpty) return text;
    final explanation = data['explanation']?.toString();
    final plan = data['plan'];
    if (plan is List && plan.isNotEmpty) {
      final lines = <String>[];
      if (explanation != null && explanation.isNotEmpty) {
        lines.add(explanation);
      }
      for (final item in plan) {
        if (item is Map) {
          final step = item['step']?.toString() ?? item['text']?.toString();
          final status = item['status']?.toString();
          if (step != null && step.isNotEmpty) {
            lines.add(
              status == null || status.isEmpty
                  ? '- $step'
                  : '- [$status] $step',
            );
          }
        } else {
          lines.add('- $item');
        }
      }
      return lines.join('\n');
    }
    return explanation ?? AppLocalizations.of(context)!.chatPlanUpdated;
  }

  String _messageText(dynamic data, List<String> preferredKeys) {
    if (data == null) return '';
    if (data is String) return data;
    if (data is List) {
      return data.map((item) => _messageText(item, preferredKeys)).join();
    }
    if (data is Map) {
      for (final key in preferredKeys) {
        final value = data[key];
        final text = _messageText(value, preferredKeys);
        if (text.isNotEmpty) return text;
      }
      for (final key in ['text', 'content', 'delta', 'message', 'value']) {
        if (preferredKeys.contains(key)) continue;
        final text = _messageText(data[key], preferredKeys);
        if (text.isNotEmpty) return text;
      }
      return '';
    }
    return data.toString();
  }

  String _reasoningText(dynamic data, {String? fallback}) {
    if (data is! Map) return fallback ?? '';
    final summary = _messageText(data['summary'], ['text', 'content']);
    if (summary.isNotEmpty) return summary;
    final content = _messageText(data['content'], ['text', 'content']);
    if (content.isNotEmpty) return content;
    final delta = _messageText(data['delta'] ?? data['text'], [
      'text',
      'content',
      'delta',
    ]);
    if (delta.isNotEmpty) return delta;
    final parts = data['summary_parts'];
    if (parts is List && parts.isNotEmpty) {
      final text = parts
          .map((e) => _messageText(e, ['text', 'content']))
          .where((text) => text.isNotEmpty)
          .join('\n');
      if (text.isNotEmpty) return text;
    }
    return fallback ?? AppLocalizations.of(context)!.chatReasoningUpdated;
  }

  String _commandTitle(dynamic command, {required String fallback}) {
    final text = _commandText(command);
    return text.isEmpty ? fallback : text;
  }

  dynamic _commandValue(dynamic data) {
    if (data is! Map) return null;
    for (final key in [
      'command',
      'cmd',
      'cmdline',
      'argv',
      'args',
      'program',
      'script',
    ]) {
      if (_isMeaningfulValue(data[key])) return data[key];
    }
    return null;
  }

  dynamic _commandOutputValue(dynamic data) {
    if (data is! Map) return null;
    for (final key in ['output', 'aggregatedOutput', 'stdout', 'stderr']) {
      if (_isMeaningfulValue(data[key])) return data[key];
    }
    return null;
  }

  String _commandCompletedOutput(dynamic data) {
    final output = _toolText(_commandOutputValue(data));
    if (output.isNotEmpty) return output;
    if (data is! Map) return '';
    final details = <String>[];
    final cwd = _toolText(data['cwd']);
    if (cwd.isNotEmpty) details.add('cwd: $cwd');
    final status = _toolText(data['status']);
    if (status.isNotEmpty) details.add('status: $status');
    final exitCode = data['exit_code'] ?? data['exitCode'];
    if (exitCode != null) details.add('exit: $exitCode');
    return details.join('\n');
  }

  bool _commandSuccess(dynamic data) {
    if (data is! Map) return true;
    final exitCode = data['exit_code'] ?? data['exitCode'];
    if (exitCode == null) {
      final status = data['status']?.toString();
      if (status == null || status.isEmpty) return true;
      return status != 'failed' && status != 'declined';
    }
    final parsed = _intValue(exitCode);
    return parsed == null || parsed == 0;
  }

  String _commandText(dynamic command) {
    if (command == null) return '';
    if (command is String) return command.trim();
    if (command is List) {
      return command.map((part) => part.toString()).join(' ').trim();
    }
    if (command is Map) {
      for (final key in [
        'command',
        'cmd',
        'cmdline',
        'argv',
        'args',
        'script',
      ]) {
        final text = _commandText(command[key]);
        if (text.isNotEmpty) return text;
      }
      final program = command['program']?.toString();
      if (program != null && program.isNotEmpty) {
        final args = _commandText(command['args']);
        return args.isEmpty ? program : '$program $args';
      }
    }
    return command.toString().trim();
  }

  String _toolText(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    if (value is String) {
      final text = value.trim();
      return text.isEmpty ? fallback : text;
    }
    if (value is List) {
      final text = value.map((item) => _toolText(item)).join('\n').trim();
      return text.isEmpty ? fallback : text;
    }
    if (value is Map) {
      for (final key in ['text', 'content', 'message', 'value', 'path']) {
        final text = _toolText(value[key]);
        if (text.isNotEmpty) return text;
      }
    }
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  String _genericItemTitle(String type, dynamic data) {
    if (data is Map) {
      final itemType = _toolText(data['item_type'] ?? data['type']);
      if (itemType.isNotEmpty) return itemType;
      final id = _toolText(data['id'] ?? data['item_id'] ?? data['itemId']);
      if (id.isNotEmpty) return id;
    }
    return type.isEmpty ? 'Item' : type;
  }

  String _genericItemContent(dynamic data) {
    if (data == null) return '';
    try {
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (_) {
      return data.toString();
    }
  }

  String _fileChangeSummary(dynamic data) {
    final l10n = AppLocalizations.of(context)!;
    if (data is! Map) return l10n.chatFileUpdated;
    final additions = _intValue(data['additions']);
    final deletions = _intValue(data['deletions']);
    final kind = _changeKindText(data['kind']);
    final parts = <String>[];
    if (kind.isNotEmpty) parts.add(kind);
    if ((additions ?? 0) > 0 || (deletions ?? 0) > 0) {
      parts.add('+${additions ?? 0} -${deletions ?? 0}');
    }
    final count = _intValue(data['change_count']);
    if (count != null && count > 1) parts.add(l10n.chatFileCount(count));
    if (parts.isNotEmpty) return parts.join(' · ');
    final diff = data['diff']?.toString().trim();
    if (diff != null && diff.isNotEmpty) return diff;
    return l10n.chatFileUpdated;
  }

  String _sessionStatusLabel(AppLocalizations l10n, dynamic status) {
    switch (SessionStatuses.normalize(status)) {
      case SessionStatuses.running:
        return l10n.statusRunning;
      case SessionStatuses.completed:
        return l10n.statusCompleted;
      case SessionStatuses.stopped:
        return l10n.statusStopped;
      case SessionStatuses.failed:
        return l10n.statusFailed;
      case SessionStatuses.lost:
        return l10n.statusLost;
      case null:
        return l10n.statusUnknown;
      default:
        return SessionStatuses.normalize(status)!;
    }
  }

  int? _intValue(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  String _changeKindText(dynamic value) {
    if (value == null) return '';
    if (value is String) return value.trim();
    if (value is Map) {
      final type = value['type']?.toString().trim() ?? '';
      final movePath = value['move_path']?.toString().trim() ?? '';
      if (type.isNotEmpty && movePath.isNotEmpty) return '$type -> $movePath';
      return type;
    }
    return value.toString().trim();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'running':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'stopped':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ref.read(syncEngineProvider)?.unsubscribeSession(widget.sessionId);
    _sessionEventsSub?.cancel();
    _itemsSub?.cancel();
    _itemCountSub?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool get _isActive => mounted && !_disposed;
}

// --- Sub-widgets ---

class _RunningTurnBar extends StatelessWidget {
  final int queuedCount;
  final VoidCallback onInterrupt;
  final AppLocalizations l10n;

  const _RunningTurnBar({
    required this.queuedCount,
    required this.onInterrupt,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 36,
      padding: const EdgeInsets.only(left: 12, right: 4),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              queuedCount > 0
                  ? l10n.chatRunningQueued(queuedCount)
                  : l10n.chatRunningHint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
          ),
          TextButton.icon(
            onPressed: onInterrupt,
            icon: const Icon(Icons.stop_circle_outlined, size: 16),
            label: Text(l10n.chatInterrupt),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ],
      ),
    );
  }
}

class _QueuedInputBar extends StatelessWidget {
  final int count;
  final AppLocalizations l10n;

  const _QueuedInputBar({required this.count, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.playlist_add_check, size: 16, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.chatQueuedInputs(count),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _InputToolbar extends StatelessWidget {
  final List<Map<String, dynamic>> selectedSkills;
  final AppLocalizations l10n;
  final VoidCallback onTemplates;
  final VoidCallback onSkill;
  final VoidCallback onFile;
  final ValueChanged<String> onRemoveSkill;

  const _InputToolbar({
    required this.selectedSkills,
    required this.l10n,
    required this.onTemplates,
    required this.onSkill,
    required this.onFile,
    required this.onRemoveSkill,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ToolbarIconButton(
          icon: Icons.history,
          tooltip: l10n.chatTemplatesTooltip,
          onPressed: onTemplates,
        ),
        _ToolbarIconButton(
          icon: Icons.auto_awesome,
          tooltip: l10n.chatSkillsTooltip,
          onPressed: onSkill,
        ),
        _ToolbarIconButton(
          icon: Icons.attach_file,
          tooltip: l10n.chatFilesTooltip,
          onPressed: onFile,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: selectedSkills.isEmpty
              ? const SizedBox(height: 28)
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: selectedSkills.map((skill) {
                      final name = skill['name']?.toString() ?? '';
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: InputChip(
                          label: Text('\$$name'),
                          avatar: const Icon(Icons.auto_awesome, size: 14),
                          onDeleted: () => onRemoveSkill(name),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      );
                    }).toList(),
                  ),
                ),
        ),
      ],
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _ToolbarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 19),
      onPressed: onPressed,
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _SkillPickerSheet extends StatelessWidget {
  final List<Map<String, dynamic>> skills;

  const _SkillPickerSheet({required this.skills});

  static Future<Map<String, dynamic>?> show(
    BuildContext context,
    List<Map<String, dynamic>> skills,
  ) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SkillPickerSheet(skills: skills),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.72,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHeader(
              title: AppLocalizations.of(context)!.chatChooseSkill,
              icon: Icons.auto_awesome,
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: skills.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final skill = skills[index];
                  final name = skill['name']?.toString() ?? '';
                  final iface = skill['interface'];
                  final displayName = iface is Map
                      ? iface['displayName']?.toString()
                      : null;
                  final desc =
                      (iface is Map
                          ? iface['shortDescription']?.toString()
                          : null) ??
                      skill['description']?.toString() ??
                      skill['path']?.toString() ??
                      '';
                  return ListTile(
                    leading: const Icon(Icons.auto_awesome),
                    title: Text(
                      displayName?.isNotEmpty == true ? displayName! : name,
                    ),
                    subtitle: desc.isEmpty
                        ? null
                        : Text(
                            desc,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                    onTap: () => Navigator.pop(context, skill),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspacePathSelection {
  final String path;
  final bool isDir;

  const _WorkspacePathSelection({required this.path, required this.isDir});
}

class _WorkspaceFilePickerSheet extends StatefulWidget {
  final FileRepository file;
  final String projectId;

  const _WorkspaceFilePickerSheet({
    required this.file,
    required this.projectId,
  });

  static Future<_WorkspacePathSelection?> show(
    BuildContext context, {
    required FileRepository file,
    required String projectId,
  }) {
    return showModalBottomSheet<_WorkspacePathSelection>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _WorkspaceFilePickerSheet(file: file, projectId: projectId),
    );
  }

  @override
  State<_WorkspaceFilePickerSheet> createState() =>
      _WorkspaceFilePickerSheetState();
}

class _WorkspaceFilePickerSheetState extends State<_WorkspaceFilePickerSheet> {
  final List<String> _stack = [''];
  final List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String _error = '';

  String get _path => _stack.last;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final data = await widget.file.listDir(widget.projectId, _path);
      final items = (data['items'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      items.sort((a, b) {
        final dirA = a['type'] == 'dir' || a['is_dir'] == true;
        final dirB = b['type'] == 'dir' || b['is_dir'] == true;
        if (dirA != dirB) return dirA ? -1 : 1;
        return (a['name']?.toString() ?? '').compareTo(
          b['name']?.toString() ?? '',
        );
      });
      if (mounted) {
        setState(() {
          _items
            ..clear()
            ..addAll(items);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = localizedErrorMessage(AppLocalizations.of(context)!, e);
        });
      }
    }
  }

  void _openDir(String name) {
    setState(() {
      _stack.add(_path.isEmpty ? name : '$_path/$name');
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.74,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHeader(
              title: _path.isEmpty
                  ? AppLocalizations.of(context)!.chatChooseWorkspaceFile
                  : _path,
              icon: Icons.attach_file,
              leading: _stack.length > 1
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        setState(() => _stack.removeLast());
                        _load();
                      },
                    )
                  : null,
            ),
            ListTile(
              leading: const Icon(Icons.folder_open_outlined),
              title: Text(AppLocalizations.of(context)!.select),
              subtitle: Text(
                _path.isEmpty ? '.' : _path,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => Navigator.pop(
                context,
                _WorkspacePathSelection(
                  path: _path.isEmpty ? '.' : _path,
                  isDir: true,
                ),
              ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              )
            else if (_error.isNotEmpty)
              Padding(padding: const EdgeInsets.all(24), child: Text(_error))
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final name = item['name']?.toString() ?? '';
                    final path =
                        item['path']?.toString() ??
                        (_path.isEmpty ? name : '$_path/$name');
                    final isDir =
                        item['type'] == 'dir' || item['is_dir'] == true;
                    return ListTile(
                      leading: Icon(
                        isDir
                            ? Icons.folder_outlined
                            : Icons.description_outlined,
                      ),
                      title: Text(name),
                      subtitle: Text(
                        path,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: isDir
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.check),
                                  tooltip: AppLocalizations.of(context)!.select,
                                  onPressed: () => Navigator.pop(
                                    context,
                                    _WorkspacePathSelection(
                                      path: path,
                                      isDir: true,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.chevron_right),
                              ],
                            )
                          : null,
                      onTap: isDir
                          ? () => _openDir(name)
                          : () => Navigator.pop(
                              context,
                              _WorkspacePathSelection(path: path, isDir: false),
                            ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? leading;

  const _SheetHeader({required this.title, required this.icon, this.leading});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          if (leading != null) leading! else Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadMoreEventsBanner extends StatelessWidget {
  final int hiddenCount;
  final VoidCallback onTap;

  const _LoadMoreEventsBanner({required this.hiddenCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Center(
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.history, size: 16),
          label: Text(
            AppLocalizations.of(context)!.chatCollapsedEvents(hiddenCount),
          ),
          style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final String status;
  const _StatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'running':
        color = Colors.green;
        break;
      case 'completed':
        color = Colors.blue;
        break;
      case 'stopped':
      case 'exited':
        color = Colors.orange;
        break;
      case 'failed':
      case 'lost':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isError;

  const _InfoChip({
    required this.label,
    required this.icon,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 14,
            color: isError ? Colors.red[400] : Colors.grey[500],
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isError ? Colors.red[400] : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  final String content;
  const _UserBubble({required this.content});

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.sizeOf(context).width * 0.72;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth.clamp(180.0, 720.0).toDouble(),
            ),
            child: _ExpandableBubble(
              content: content,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
              childBuilder: (context, text, collapsed, maxLines) =>
                  SelectableText(text, maxLines: collapsed ? maxLines : null),
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 14,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: const Icon(Icons.person, color: Colors.white, size: 16),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String content;
  final MarkdownTapLinkCallback? onTapLink;

  const _MessageBubble({required this.content, this.onTapLink});

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.sizeOf(context).width * 0.82;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            child: const Icon(Icons.smart_toy, size: 16),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth.clamp(200.0, 840.0).toDouble(),
              ),
              child: _ExpandableBubble(
                content: content,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                childBuilder: (context, text, collapsed, maxLines) =>
                    MarkdownBody(
                      data: text,
                      shrinkWrap: true,
                      onTapLink: onTapLink,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

typedef _ExpandableBubbleChildBuilder =
    Widget Function(
      BuildContext context,
      String text,
      bool collapsed,
      int maxLines,
    );

class _ExpandableBubble extends StatefulWidget {
  final String content;
  final Color backgroundColor;
  final BorderRadius borderRadius;
  final _ExpandableBubbleChildBuilder childBuilder;

  const _ExpandableBubble({
    required this.content,
    required this.backgroundColor,
    required this.borderRadius,
    required this.childBuilder,
  });

  @override
  State<_ExpandableBubble> createState() => _ExpandableBubbleState();
}

class _ExpandableBubbleState extends State<_ExpandableBubble> {
  static const _collapseLines = 8;
  static const _collapseChars = 700;
  var _expanded = false;

  bool get _shouldCollapse {
    final lineCount = '\n'.allMatches(widget.content).length + 1;
    return widget.content.length > _collapseChars || lineCount > _collapseLines;
  }

  @override
  void didUpdateWidget(covariant _ExpandableBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content && !_shouldCollapse) {
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final collapsed = _shouldCollapse && !_expanded;
    final displayText = collapsed
        ? _collapsedText(widget.content, _collapseChars)
        : widget.content;

    return InkWell(
      onTap: _shouldCollapse
          ? () => setState(() => _expanded = !_expanded)
          : null,
      borderRadius: widget.borderRadius,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: widget.backgroundColor,
          borderRadius: widget.borderRadius,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            widget.childBuilder(
              context,
              displayText,
              collapsed,
              _collapseLines,
            ),
            if (_shouldCollapse) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(
                    _expanded ? Icons.unfold_less : Icons.unfold_more,
                    size: 16,
                  ),
                  label: Text(
                    _expanded
                        ? AppLocalizations.of(context)!.collapse
                        : AppLocalizations.of(context)!.expand,
                  ),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _collapsedText(String text, int maxChars) {
    final lines = text.split('\n');
    var value = lines.length > _collapseLines
        ? lines.take(_collapseLines).join('\n')
        : text;
    if (value.length > maxChars) {
      value = value.substring(0, maxChars);
    }
    return '${value.trimRight()}...';
  }
}

class _ToolCallCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String output;
  final bool success;

  const _ToolCallCard({
    required this.icon,
    required this.title,
    required this.output,
    required this.success,
  });

  @override
  State<_ToolCallCard> createState() => _ToolCallCardState();
}

class _ToolCallCardState extends State<_ToolCallCard> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.success ? Colors.green : Colors.red;
    final title = widget.title.trim().isEmpty
        ? AppLocalizations.of(context)!.approvalUnknownAction
        : widget.title.trim();
    final output = widget.output.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: EdgeInsets.fromLTRB(10, 8, 8, _expanded ? 12 : 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(widget.icon, color: color, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 18,
                      color: Colors.grey[600],
                    ),
                  ],
                ),
                if (_expanded) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SelectableText(
                      [
                        title,
                        if (output.isNotEmpty) '',
                        if (output.isNotEmpty) output,
                      ].join('\n'),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StructuredInfoCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String content;
  final bool monospace;

  const _StructuredInfoCard({
    required this.icon,
    required this.title,
    required this.content,
    this.monospace = false,
  });

  @override
  State<_StructuredInfoCard> createState() => _StructuredInfoCardState();
}

class _StructuredInfoCardState extends State<_StructuredInfoCard> {
  static const _collapseChars = 220;
  var _expanded = false;

  bool get _shouldCollapse {
    final lineCount = '\n'.allMatches(widget.content).length + 1;
    return widget.content.length > _collapseChars || lineCount > 3;
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      fontFamily: widget.monospace ? 'monospace' : null,
      fontSize: 13,
    );
    final collapsed = _shouldCollapse && !_expanded;
    final content = collapsed ? _collapsedText(widget.content) : widget.content;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _shouldCollapse
              ? () => setState(() => _expanded = !_expanded)
              : null,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  widget.icon,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (_shouldCollapse)
                            Icon(
                              _expanded
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              size: 18,
                              color: Colors.grey[600],
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SelectableText(
                        content,
                        maxLines: collapsed ? 1 : null,
                        style: textStyle,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _collapsedText(String text) {
    final firstLine = text.split('\n').first.trim();
    if (firstLine.length <= _collapseChars) return firstLine;
    return '${firstLine.substring(0, _collapseChars).trimRight()}...';
  }
}

class _ApprovalCard extends StatelessWidget {
  final dynamic request;
  final void Function(String action) onRespond;

  const _ApprovalCard({this.request, required this.onRespond});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.warning,
                    color: Theme.of(context).colorScheme.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context)!.approvalRequired,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                request?['command'] ??
                    request?['file_path'] ??
                    AppLocalizations.of(context)!.approvalUnknownAction,
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => onRespond('decline'),
                    child: Text(AppLocalizations.of(context)!.chatDeny),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: () => onRespond('acceptForSession'),
                    child: Text(
                      AppLocalizations.of(context)!.approvalAllowSession,
                    ),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    onPressed: () => onRespond('accept'),
                    child: Text(AppLocalizations.of(context)!.chatApprove),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.error,
                color: Theme.of(context).colorScheme.error,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(message, style: const TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
