import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';
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
import 'package:magent_app/core/theme/theme.dart';
import 'package:magent_app/features/git/widgets/diff_sheet.dart';
import 'package:magent_app/features/sessions/widgets/message_template_sheet.dart';
import 'package:magent_app/l10n/app_localizations.dart';
import 'package:magent_app/shared/widgets/app_loading.dart';
import 'package:magent_app/shared/widgets/app_sheet_header.dart';
import 'package:magent_app/shared/widgets/app_status_dot.dart';

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

class ChatTokenUsageSnapshot {
  final int totalTokens;
  final int inputTokens;
  final int outputTokens;
  final int cachedInputTokens;
  final int lastTotalTokens;
  final int lastInputTokens;
  final int lastOutputTokens;
  final int lastCachedInputTokens;
  final int contextWindow;

  const ChatTokenUsageSnapshot({
    required this.totalTokens,
    required this.inputTokens,
    required this.outputTokens,
    required this.cachedInputTokens,
    required this.lastTotalTokens,
    required this.lastInputTokens,
    required this.lastOutputTokens,
    required this.lastCachedInputTokens,
    required this.contextWindow,
  });

  int get contextTokens => lastInputTokens;

  double get contextRatio {
    if (contextWindow <= 0) return 0;
    return contextTokens / contextWindow;
  }
}

class ChatDiffFileSummary {
  final String path;
  final int additions;
  final int deletions;

  const ChatDiffFileSummary({
    required this.path,
    required this.additions,
    required this.deletions,
  });
}

@visibleForTesting
String chatWebSearchTitle(Object? data) {
  final map = data is Map ? Map<String, dynamic>.from(data) : null;
  final query = _chatFirstText(map, const [
    'query',
    'search_query',
    'searchQuery',
    'q',
    'text',
    'content',
  ]);
  return query.isEmpty ? 'Web search' : 'Web search: $query';
}

@visibleForTesting
String chatWebSearchSummary(Object? data) {
  final map = data is Map ? Map<String, dynamic>.from(data) : null;
  if (map == null) return '';
  final summary = _chatFirstText(map, const ['summary', 'snippet', 'text']);
  if (summary.isNotEmpty && summary != _chatFirstText(map, const ['query'])) {
    return _chatSingleLine(summary);
  }
  final results = _chatSearchResults(map);
  if (results.isNotEmpty) {
    return '${results.length} result${results.length == 1 ? '' : 's'}';
  }
  final status = _chatFirstText(map, const ['status']);
  return status.isEmpty ? 'Search completed' : status;
}

@visibleForTesting
String chatWebSearchDetail(Object? data) {
  final map = data is Map ? Map<String, dynamic>.from(data) : null;
  if (map == null) return data?.toString() ?? '';
  final lines = <String>[];
  final query = _chatFirstText(map, const [
    'query',
    'search_query',
    'searchQuery',
    'q',
    'text',
    'content',
  ]);
  if (query.isNotEmpty) {
    lines.add('Query: $query');
  }
  final status = _chatFirstText(map, const ['status']);
  if (status.isNotEmpty) {
    lines.add('Status: $status');
  }
  final summary = _chatFirstText(map, const ['summary', 'snippet']);
  if (summary.isNotEmpty) {
    if (lines.isNotEmpty) lines.add('');
    lines.add(summary);
  }
  final results = _chatSearchResults(map);
  if (results.isNotEmpty) {
    if (lines.isNotEmpty) lines.add('');
    for (var i = 0; i < results.length; i++) {
      final result = results[i];
      final title = _chatFirstText(result, const [
        'title',
        'name',
        'source',
        'url',
      ]);
      final url = _chatFirstText(result, const ['url', 'link', 'href']);
      final snippet = _chatFirstText(result, const [
        'snippet',
        'text',
        'content',
        'summary',
      ]);
      lines.add('${i + 1}. ${title.isEmpty ? 'Result' : title}');
      if (url.isNotEmpty && url != title) lines.add(url);
      if (snippet.isNotEmpty) lines.add(snippet);
      if (i != results.length - 1) lines.add('');
    }
  }
  if (lines.isNotEmpty) return lines.join('\n');
  return const JsonEncoder.withIndent('  ').convert(map);
}

String _chatFirstText(Map<String, dynamic>? data, List<String> keys) {
  if (data == null) return '';
  for (final key in keys) {
    final text = _chatText(data[key]);
    if (text.isNotEmpty) return text;
  }
  return '';
}

String _chatText(Object? value) {
  if (value == null) return '';
  if (value is String) return value.trim();
  if (value is Iterable) {
    return value.map(_chatText).where((text) => text.isNotEmpty).join('\n');
  }
  if (value is Map) {
    return _chatFirstText(Map<String, dynamic>.from(value), const [
      'text',
      'content',
      'message',
      'value',
      'title',
      'url',
    ]);
  }
  return value.toString().trim();
}

List<Map<String, dynamic>> _chatSearchResults(Map<String, dynamic> data) {
  for (final key in const ['results', 'sources', 'items', 'citations']) {
    final value = data[key];
    if (value is Iterable) {
      return value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    }
  }
  return const [];
}

String _chatSingleLine(String text) {
  final normalized = text
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .join(' ');
  if (normalized.length <= 160) return normalized;
  return '${normalized.substring(0, 160).trimRight()}...';
}

@visibleForTesting
bool chatTurnActiveFromItemSnapshot({
  required bool currentTurnActive,
  required bool snapshotHasActiveItem,
  required Object? sessionStatus,
}) {
  if (snapshotHasActiveItem) return true;
  if (!currentTurnActive) return false;
  final status = SessionStatuses.normalize(sessionStatus);
  return status == null || status == SessionStatuses.running;
}

@visibleForTesting
ChatTokenUsageSnapshot? chatTokenUsageFromEventData(Object? data) {
  if (data is! Map) return null;
  final map = Map<String, dynamic>.from(data);
  final usage = map['tokenUsage'] ?? map['token_usage'];
  if (usage is! Map) return null;
  final usageMap = Map<String, dynamic>.from(usage);
  final total = _usageBucket(usageMap['total']);
  final last = _usageBucket(usageMap['last']);
  final contextWindow = _intValue(
    usageMap['modelContextWindow'] ??
        usageMap['model_context_window'] ??
        map['modelContextWindow'] ??
        map['model_context_window'],
  );
  return ChatTokenUsageSnapshot(
    totalTokens: _intValue(total['totalTokens'] ?? total['total_tokens']),
    inputTokens: _intValue(total['inputTokens'] ?? total['input_tokens']),
    outputTokens: _intValue(total['outputTokens'] ?? total['output_tokens']),
    cachedInputTokens: _intValue(
      total['cachedInputTokens'] ?? total['cached_input_tokens'],
    ),
    lastTotalTokens: _intValue(
      last['totalTokens'] ??
          last['total_tokens'] ??
          total['totalTokens'] ??
          total['total_tokens'],
    ),
    lastInputTokens: _intValue(
      last['inputTokens'] ??
          last['input_tokens'] ??
          last['totalTokens'] ??
          last['total_tokens'],
    ),
    lastOutputTokens: _intValue(last['outputTokens'] ?? last['output_tokens']),
    lastCachedInputTokens: _intValue(
      last['cachedInputTokens'] ?? last['cached_input_tokens'],
    ),
    contextWindow: contextWindow,
  );
}

@visibleForTesting
String chatCompactTokenNumber(int value) {
  final sign = value < 0 ? '-' : '';
  final absValue = value.abs();
  if (absValue >= 1000000) {
    return '$sign${_trimFixed(absValue / 1000000, 1)}M';
  }
  if (absValue >= 1000) {
    return '$sign${_trimFixed(absValue / 1000, 1)}K';
  }
  return value.toString();
}

Map<String, dynamic> _usageBucket(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

int _intValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _trimFixed(double value, int fractionDigits) {
  final text = value.toStringAsFixed(fractionDigits);
  return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
}

String _formatDuration(int ms) {
  if (ms < 1000) return '${ms}ms';
  final seconds = ms / 1000;
  if (seconds < 60) {
    return '${_trimFixed(seconds, seconds >= 10 ? 0 : 1)}s';
  }
  final totalSec = ms ~/ 1000;
  final minutes = totalSec ~/ 60;
  final remainSec = totalSec - minutes * 60;
  if (minutes < 60) {
    return remainSec == 0 ? '${minutes}m' : '${minutes}m${remainSec}s';
  }
  final hours = minutes ~/ 60;
  final remainMin = minutes - hours * 60;
  return remainMin == 0 ? '${hours}h' : '${hours}h${remainMin}m';
}

@visibleForTesting
List<ChatDiffFileSummary> chatDiffFileSummaries(String diff) {
  final files = <ChatDiffFileSummary>[];
  var path = '';
  var additions = 0;
  var deletions = 0;
  var hasFile = false;

  void finishFile() {
    if (!hasFile) return;
    files.add(
      ChatDiffFileSummary(
        path: path.isEmpty ? 'diff' : path,
        additions: additions,
        deletions: deletions,
      ),
    );
    path = '';
    additions = 0;
    deletions = 0;
    hasFile = false;
  }

  for (final line in diff.split('\n')) {
    if (line.startsWith('diff --git ')) {
      finishFile();
      hasFile = true;
      path = _pathFromDiffHeader(line);
      continue;
    }
    if (line.startsWith('+++ ')) {
      hasFile = true;
      if (path.isEmpty) path = _pathFromDiffMarker(line.substring(4));
      continue;
    }
    if (line.startsWith('--- ')) {
      hasFile = true;
      continue;
    }
    if (line.startsWith('+')) {
      additions++;
      hasFile = true;
    } else if (line.startsWith('-')) {
      deletions++;
      hasFile = true;
    }
  }
  finishFile();
  return files;
}

String _pathFromDiffHeader(String line) {
  final match = RegExp(r'^diff --git a/(.*?) b/(.*)$').firstMatch(line);
  if (match != null) return _cleanDiffPath(match.group(2) ?? '');
  return '';
}

String _pathFromDiffMarker(String marker) {
  final trimmed = marker.trim();
  if (trimmed == '/dev/null') return '';
  if (trimmed.startsWith('a/') || trimmed.startsWith('b/')) {
    return _cleanDiffPath(trimmed.substring(2));
  }
  return _cleanDiffPath(trimmed);
}

String _cleanDiffPath(String path) {
  return path.trim().replaceAll(RegExp(r'^"|"$'), '');
}

class _ChatPageState extends ConsumerState<ChatPage> {
  static const _initialVisibleEventCount = 80;
  static const _eventPageSize = 80;
  static const _initialBottomJumpFrames = 8;
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
  bool _pendingInitialBottomScroll = false;
  bool _pendingScrollToBottom = false;
  bool _pendingJumpToBottom = false;
  bool _turnActive = false;
  bool _itemsRefreshInFlight = false;
  bool _manualItemsRefreshInFlight = false;
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
  ChatTokenUsageSnapshot? _tokenUsage;
  bool _tokenUsageExpanded = false;
  int _visibleEventCount = _initialVisibleEventCount;
  int _totalEventCount = 0;

  // 用户在设置面板里改过、且**与会话基线（_session 字段）不同**的待发送值。
  // 发送成功一次后会被"提升"为新基线（写回 _session）并清空，避免每次都重复
  // 把同一组参数塞进请求里浪费流量；codex 那边只需要一次覆盖就会作为后续
  // 默认。失败时保留以便下一次发送重试。
  String? _pendingModel;
  String? _pendingEffort;
  String? _pendingApproval;
  String? _pendingSandbox;
  Map<String, dynamic>? _providerConfig;

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

  String _sessionField(String key) {
    final value = _session?[key]?.toString().trim();
    return (value == null || value.isEmpty) ? '' : value;
  }

  String _sessionTitleText(AppLocalizations l10n) {
    if (_session == null) return l10n.chatTitle;
    for (final key in const ['title', 'last_text', 'lastText', 'preview']) {
      final text = _readableOneLine(_session![key]);
      if (text.isNotEmpty) return text;
    }
    return l10n.chatTitle;
  }

  String get _activeModel => (_pendingModel?.isNotEmpty ?? false)
      ? _pendingModel!
      : _sessionField('model');
  String get _activeEffort => (_pendingEffort?.isNotEmpty ?? false)
      ? _pendingEffort!
      : _sessionField('effort');
  String get _activeApproval => (_pendingApproval?.isNotEmpty ?? false)
      ? _pendingApproval!
      : _sessionField('approval_policy');
  String get _activeSandbox => (_pendingSandbox?.isNotEmpty ?? false)
      ? _pendingSandbox!
      : _sessionField('sandbox_mode');

  /// 当 sheet 返回新值时调用：只把"和当前基线不同"的字段记为 pending，
  /// 相同的清空（不发送）。
  void _applySettingsResult(_SessionSettingsResult r) {
    String? diff(String? next, String baseline) {
      final value = next?.trim();
      if (value == null || value.isEmpty) return null;
      if (value == baseline) return null;
      return value;
    }

    setState(() {
      _pendingModel = diff(r.model, _sessionField('model'));
      _pendingEffort = diff(r.effort, _sessionField('effort'));
      _pendingApproval = diff(
        r.approvalPolicy,
        _sessionField('approval_policy'),
      );
      _pendingSandbox = diff(r.sandboxMode, _sessionField('sandbox_mode'));
    });
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
        if (_isActive) unawaited(_loadProviderConfig());
      }),
    );
    unawaited(_connectSessionEvents());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isActive) unawaited(_loadItems());
    });
  }

  Future<void> _loadProviderConfig() async {
    if (_api == null) return;
    final providerId = _session == null
        ? 'codex'
        : (canonicalProviderId(Map<String, dynamic>.from(_session!)) ??
              'codex');
    try {
      final resp = await _api!.client.dio.get(
        '/api/v1/providers/$providerId/config',
      );
      if (!_isActive) return;
      final data = resp.data is Map ? resp.data['data'] : null;
      if (data is Map) {
        setState(() => _providerConfig = Map<String, dynamic>.from(data));
      }
    } catch (e) {
      debugPrint('ChatPage: load provider config error: $e');
    }
  }

  Future<void> _openSettingsSheet() async {
    if (_providerConfig == null) {
      await _loadProviderConfig();
    }
    if (!mounted) return;
    final result = await showModalBottomSheet<_SessionSettingsResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
      builder: (ctx) => _SessionSettingsSheet(
        config: _providerConfig,
        currentModel: _activeModel,
        currentEffort: _activeEffort,
        currentApproval: _activeApproval,
        currentSandbox: _activeSandbox,
      ),
    );
    if (result == null || !mounted) return;
    _applySettingsResult(result);
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
          final nextTurnActive = chatTurnActiveFromItemSnapshot(
            currentTurnActive: _turnActive,
            snapshotHasActiveItem: _itemsContainActiveTurn(items),
            sessionStatus: _session?['status'],
          );
          final turnActiveChanged = _turnActive != nextTurnActive;
          final shouldInitialBottomScroll =
              !_didInitialBottomScroll && nextVisibleState.events.isNotEmpty;
          final shouldAutoScroll = visibleEventsChanged && _isNearBottom();
          if (!_isActive) return;
          if (eventsChanged || visibleEventsChanged || turnActiveChanged) {
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
            });
          }
          if (shouldInitialBottomScroll) {
            _requestInitialBottomScroll();
          } else if (visibleEventsChanged &&
              (shouldAutoScroll || nextVisibleState.events.length <= 1)) {
            _scrollToBottom();
          }
        });
  }

  Future<void> _connectSessionEvents() async {
    final engine = ref.read(syncEngineProvider);
    if (engine == null) {
      _markInitialItemsLoaded();
      return;
    }
    _sessionEventsSub = engine.sessionEvents.listen((event) {
      if (!_isActive) return;
      final sessionId = event['session_id']?.toString();
      if (sessionId != null && sessionId != widget.sessionId) return;
      final type = event['type']?.toString() ?? '';
      if (type == 'session.sync_required' || type == 'session.items.changed') {
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
      if (normalizedType == SessionEventTypes.tokenUsageUpdated) {
        _applyTokenUsage(normalized['data']);
        return;
      }
      _applyTurnRuntimeState(normalizedType, normalized['data']);
      if (!_isRenderableRealtimeEvent(normalizedType)) return;
      if (_isItemProjectionEvent(normalizedType)) {
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
    try {
      await engine.subscribeSession(widget.sessionId);
    } finally {
      _markInitialItemsLoaded();
    }
  }

  void _applyTokenUsage(Object? data) {
    final next = chatTokenUsageFromEventData(data);
    if (next == null || !_isActive) return;
    setState(() => _tokenUsage = next);
  }

  bool _isRenderableRealtimeEvent(String type) {
    switch (type) {
      case SessionEventTypes.started:
      case SessionEventTypes.statusChanged:
      case SessionEventTypes.tokenUsageUpdated:
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

  bool _hasVisibleItemContent(String type, Map<String, dynamic> data) {
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
    } catch (e) {
      debugPrint('ChatPage: loadEvents error: $e');
      _markInitialItemsLoaded();
    } finally {
      _itemsRefreshInFlight = false;
    }
  }

  void _markInitialItemsLoaded() {
    if (!_isActive) return;
    if (_loading) {
      setState(() => _loading = false);
    }
    _flushPendingInitialBottomScroll();
  }

  Future<void> _refreshItemsFull() async {
    if (_repo == null || _manualItemsRefreshInFlight) return;
    _manualItemsRefreshInFlight = true;
    try {
      await _repo!.refreshItems(widget.sessionId, forceFull: true);
      if (mounted && _loading) setState(() => _loading = false);
    } catch (e) {
      debugPrint('ChatPage: refreshEvents error: $e');
      if (mounted && _loading) setState(() => _loading = false);
    } finally {
      _manualItemsRefreshInFlight = false;
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
      // 仅在用户改了某项设置后才把它带过去；发送成功后这些 pending 值会被
      // 提升为新基线，下次发送（如果用户没再改）就不会再传，省流量。
      final sendModel = _pendingModel;
      final sendEffort = _pendingEffort;
      final sendApproval = _pendingApproval;
      final sendSandbox = _pendingSandbox;
      await _api!.session.sendInput(
        widget.sessionId,
        input,
        items: items,
        mode: mode,
        model: sendModel,
        effort: sendEffort,
        approvalPolicy: sendApproval,
        sandboxMode: sendSandbox,
      );
      if (!mounted) return;
      setState(() {
        // 把刚发送的 pending 值"沉淀"为新基线（写回 _session），并清空
        // pending — 下次发送除非用户再次改设置，否则就不再附带这些字段。
        if (sendModel != null ||
            sendEffort != null ||
            sendApproval != null ||
            sendSandbox != null) {
          final next = Map<String, dynamic>.from(_session ?? const {});
          if (sendModel != null) next['model'] = sendModel;
          if (sendEffort != null) next['effort'] = sendEffort;
          if (sendApproval != null) next['approval_policy'] = sendApproval;
          if (sendSandbox != null) next['sandbox_mode'] = sendSandbox;
          _session = next;
          _pendingModel = null;
          _pendingEffort = null;
          _pendingApproval = null;
          _pendingSandbox = null;
        }
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
              style: TextStyle(color: Theme.of(context).colorScheme.error),
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

  void _requestInitialBottomScroll() {
    if (_didInitialBottomScroll) return;
    _didInitialBottomScroll = true;
    if (!_openAtBottom) return;
    _pendingInitialBottomScroll = true;
    _flushPendingInitialBottomScroll();
  }

  void _flushPendingInitialBottomScroll() {
    if (!_pendingInitialBottomScroll || !_isActive || _loading) return;
    _pendingInitialBottomScroll = false;
    _jumpToBottom();
  }

  void _jumpToBottom() {
    if (_pendingJumpToBottom) return;
    _pendingScrollToBottom = false;
    _pendingJumpToBottom = true;
    _jumpToBottomOnNextFrame(_initialBottomJumpFrames);
  }

  void _jumpToBottomOnNextFrame(int remainingFrames) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_pendingJumpToBottom || !_isActive) return;
      if (!_scrollController.hasClients) {
        if (remainingFrames <= 0) {
          _pendingJumpToBottom = false;
          return;
        }
        _jumpToBottomOnNextFrame(remainingFrames - 1);
        return;
      }
      final position = _scrollController.position;
      final target = position.maxScrollExtent;
      if ((position.pixels - target).abs() >= 1) {
        _scrollController.jumpTo(target);
      }
      if (remainingFrames <= 0) {
        _pendingJumpToBottom = false;
        return;
      }
      _jumpToBottomOnNextFrame(remainingFrames - 1);
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
      case SessionItemTypes.webSearch:
        return buildEvent(SessionEventTypes.itemCompleted)
          ..['data'] = {...data, 'item_type': type};
      default:
        return buildEvent(SessionEventTypes.itemCompleted)
          ..['data'] = {...data, 'item_type': type};
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final status = SessionStatuses.normalizeOrStopped(_session?['status']);
    final title = _sessionTitleText(l10n);
    final provider = _session == null
        ? null
        : canonicalProviderId(Map<String, dynamic>.from(_session!));
    final visibleEvents = _visibleEvents;
    final hiddenEventCount = _hiddenEventCount;
    final hasVisibleContent = visibleEvents.isNotEmpty || hiddenEventCount > 0;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(width: 8),
            _StatusDot(status: status),
            const SizedBox(width: 4),
            Text(
              _sessionStatusLabel(l10n, status),
              maxLines: 1,
              style: TextStyle(fontSize: 12, color: _statusColor(status)),
            ),
            if (provider != null && provider.isNotEmpty) ...[
              Text(
                ' · ',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
              Flexible(
                child: Text(
                  provider,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: _openSettingsSheet,
            tooltip: l10n.chatSettings,
          ),
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
              color: Theme.of(context).colorScheme.error,
            ),
        ],
      ),
      body: Column(
        children: [
          _SessionStrategyBar(
            model: _activeModel,
            effort: _activeEffort,
            approvalPolicy: _activeApproval,
            sandboxMode: _activeSandbox,
            onTap: _openSettingsSheet,
          ),
          if (_tokenUsage != null)
            _TokenUsagePanel(
              usage: _tokenUsage!,
              expanded: _tokenUsageExpanded,
              onTap: () {
                setState(() => _tokenUsageExpanded = !_tokenUsageExpanded);
              },
            ),
          Expanded(
            child: _loading
                ? const _SessionLoadingState()
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
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const SizedBox(height: 12),
          Text(
            _isExited ? l10n.chatSessionEnded : l10n.chatNoMessages,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 15,
            ),
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
            color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.05),
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
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
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
            color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            '${l10n.settingsSession}${_sessionStatusLabel(l10n, status)}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
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
            color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.10),
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
          phase: _messagePhase(data),
          onTapLink: (_, href, _) => _openLinkedFileDiff(href),
        );
      case SessionEventTypes.messageDelta:
        return _MessageBubble(
          content: _messageText(data, ['delta', 'text', 'content']),
          phase: _messagePhase(data),
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
        final diff = data?['diff']?.toString() ?? '';
        return _StructuredInfoCard(
          icon: Icons.difference_outlined,
          title: l10n.chatDiffSummary,
          summary: _diffSummary(diff),
          detail: diff,
          monospace: true,
        );
      case SessionEventTypes.commandOutputDelta:
        final output = _toolText(data?['delta'] ?? _commandOutputValue(data));
        return _ToolCallCard(
          icon: _commandIcon(data),
          title:
              _commandActionTitle(data) ??
              _commandTitle(
                _commandValue(data),
                fallback: l10n.chatCommandOutput,
              ),
          output: output,
          summary: _singleLineSummary(output, fallback: l10n.chatCommandOutput),
          success: true,
        );
      case SessionEventTypes.fileChangeOutputDelta:
        final output = _toolText(data?['delta'] ?? data?['output']);
        return _ToolCallCard(
          icon: Icons.edit_note,
          title: _toolText(data?['path'], fallback: l10n.chatFileChangeOutput),
          output: output,
          summary: _singleLineSummary(
            output,
            fallback: l10n.chatFileChangeOutput,
          ),
          success: true,
        );
      case SessionEventTypes.commandCompleted:
        final output = _commandCompletedOutput(data);
        return _ToolCallCard(
          icon: _commandIcon(data),
          title:
              _commandActionTitle(data) ??
              _commandTitle(_commandValue(data), fallback: l10n.chatCommand),
          output: output,
          summary: _commandSummary(data, output),
          success: _commandSuccess(data),
        );
      case SessionEventTypes.fileWrite:
        final detail = _fileChangeDetail(data);
        return _ToolCallCard(
          icon: Icons.edit_note,
          title: _toolText(data?['path'], fallback: l10n.chatFileChange),
          output: detail,
          summary: _fileChangeSummary(data),
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
          summary: _singleLineSummary(
            _toolText(data?['output'] ?? data?['result'] ?? data?['error']),
            fallback: 'MCP Tool',
          ),
          success: data?['error'] == null,
        );
      case SessionEventTypes.itemCompleted:
        final itemType = _itemType(data);
        if (itemType == SessionItemTypes.contextCompaction) {
          return _InfoChip(
            label: l10n.chatContextCompacted,
            icon: Icons.compress,
          );
        }
        if (itemType == SessionItemTypes.webSearch) {
          final detail = chatWebSearchDetail(data);
          return _ToolCallCard(
            icon: Icons.travel_explore,
            title: chatWebSearchTitle(data),
            output: detail,
            summary: chatWebSearchSummary(data),
            success: true,
            monospace: false,
          );
        }
        return _StructuredInfoCard(
          icon: Icons.data_object,
          title: _genericItemTitle(type, data),
          summary: _genericItemSummary(data),
          detail: _genericItemContent(data),
          monospace: true,
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
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
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

  String? _messagePhase(dynamic data) {
    if (data is! Map) return null;
    final phase = data['phase']?.toString();
    if (phase == null || phase.isEmpty) return null;
    return phase;
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

  List<dynamic> _commandActions(dynamic data) {
    if (data is! Map) return const [];
    final actions = data['commandActions'] ?? data['command_actions'];
    if (actions is List) return actions;
    return const [];
  }

  String? _commandActionTitle(dynamic data) {
    final actions = _commandActions(data);
    if (actions.isEmpty) return null;
    final first = actions.first;
    if (first is! Map) return null;
    final command = first['command']?.toString().trim();
    if (command != null && command.isNotEmpty) return command;
    final path = first['path']?.toString().trim();
    final name = first['name']?.toString().trim();
    if (name != null && name.isNotEmpty) {
      return path != null && path.isNotEmpty ? '$name  ($path)' : name;
    }
    if (path != null && path.isNotEmpty) return path;
    return null;
  }

  IconData _commandIcon(dynamic data) {
    final actions = _commandActions(data);
    if (actions.isEmpty) return Icons.terminal;
    final first = actions.first;
    final type = first is Map ? first['type']?.toString() : null;
    switch (type) {
      case 'read':
      case 'cat':
      case 'view':
        return Icons.visibility_outlined;
      case 'write':
      case 'edit':
      case 'modify':
        return Icons.edit_note;
      case 'search':
      case 'grep':
      case 'find':
        return Icons.search;
      case 'list':
      case 'list_dir':
      case 'ls':
        return Icons.folder_open;
      case 'shell':
      case 'execute':
      case 'run':
      default:
        return Icons.terminal;
    }
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

  String _itemType(dynamic data) {
    if (data is! Map) return '';
    return SessionItemTypes.normalize(
      data['item_type']?.toString() ?? data['type']?.toString() ?? '',
    );
  }

  String _genericItemContent(dynamic data) {
    if (data == null) return '';
    try {
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (_) {
      return data.toString();
    }
  }

  String _genericItemSummary(dynamic data) {
    if (data is! Map) return _singleLineSummary(data?.toString() ?? '');
    for (final key in ['message', 'text', 'content', 'summary', 'status']) {
      final text = _toolText(data[key]);
      if (text.isNotEmpty) return _singleLineSummary(text);
    }
    return _singleLineSummary(_genericItemContent(data));
  }

  String _singleLineSummary(String text, {String fallback = ''}) {
    final normalized = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .join(' ');
    if (normalized.isEmpty) return fallback;
    if (normalized.length <= 160) return normalized;
    return '${normalized.substring(0, 160).trimRight()}...';
  }

  String _commandSummary(dynamic data, String output) {
    final details = <String>[];
    if (data is Map) {
      final status = _toolText(data['status']);
      if (status.isNotEmpty) details.add(status);
      final exitCode = data['exit_code'] ?? data['exitCode'];
      if (exitCode != null) details.add('exit $exitCode');
      final durationRaw = data['durationMs'] ?? data['duration_ms'];
      if (durationRaw != null) {
        final ms = _intValue(durationRaw) ?? 0;
        if (ms > 0) details.add(_formatDuration(ms));
      }
      final source = _toolText(data['source']);
      if (source.isNotEmpty) details.add(source);
      final pidRaw = data['processId'] ?? data['pid'] ?? data['process_id'];
      if (pidRaw != null) {
        final pid = _intValue(pidRaw) ?? 0;
        if (pid > 0) details.add('pid $pid');
      }
    }
    final outputSummary = _singleLineSummary(output);
    if (outputSummary.isNotEmpty) details.add(outputSummary);
    return details.isEmpty
        ? AppLocalizations.of(context)!.chatCommand
        : details.join(' · ');
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

  String _fileChangeDetail(dynamic data) {
    if (data is! Map) return '';
    final diff = data['diff']?.toString().trim();
    if (diff != null && diff.isNotEmpty) return diff;
    final changes = data['changes'];
    if (changes != null) return _genericItemContent(changes);
    return _fileChangeSummary(data);
  }

  String _diffSummary(String diff) {
    final l10n = AppLocalizations.of(context)!;
    final files = chatDiffFileSummaries(diff);
    if (files.isEmpty) return l10n.chatDiffSummary;
    final totalAdditions = files.fold<int>(
      0,
      (sum, file) => sum + file.additions,
    );
    final totalDeletions = files.fold<int>(
      0,
      (sum, file) => sum + file.deletions,
    );
    final visible = files
        .take(3)
        .map((file) {
          final stats = '+${file.additions} -${file.deletions}';
          return '${file.path} $stats';
        })
        .join(' · ');
    final more = files.length > 3 ? ' · +${files.length - 3}' : '';
    return '$visible$more · total +$totalAdditions -$totalDeletions';
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
    if (value is String) return _changeKindLabel(value.trim());
    if (value is Map) {
      final type = value['type']?.toString().trim() ?? '';
      final movePath = value['move_path']?.toString().trim() ?? '';
      final label = _changeKindLabel(type);
      if (label.isNotEmpty && movePath.isNotEmpty) return '$label → $movePath';
      return label;
    }
    return _changeKindLabel(value.toString().trim());
  }

  String _changeKindLabel(String type) {
    switch (type) {
      case '':
        return '';
      case 'add':
      case 'added':
      case 'create':
      case 'created':
      case 'new':
        return '新增';
      case 'update':
      case 'updated':
      case 'modify':
      case 'modified':
      case 'change':
      case 'changed':
        return '修改';
      case 'delete':
      case 'deleted':
      case 'remove':
      case 'removed':
        return '删除';
      case 'rename':
      case 'renamed':
      case 'move':
      case 'moved':
        return '重命名';
      default:
        return type;
    }
  }

  Color _statusColor(String status) {
    final statusColors = AppStatusColors.of(context);
    switch (status) {
      case 'running':
        return statusColors.running.foreground;
      case 'completed':
        return statusColors.info.foreground;
      case 'stopped':
        return statusColors.warning.foreground;
      case 'failed':
        return statusColors.error.foreground;
      default:
        return statusColors.neutral.foreground;
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
    final statusColors = AppStatusColors.of(context);
    return Container(
      height: 38,
      padding: const EdgeInsets.only(left: 14, right: 4),
      decoration: BoxDecoration(
        color: statusColors.info.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColors.info.border),
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
          const SizedBox(width: 10),
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
    final statusColors = AppStatusColors.of(context);
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: statusColors.neutral.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColors.neutral.border),
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
              const Padding(padding: EdgeInsets.all(24), child: AppLoading())
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
    if (leading != null) {
      // 保留 leading 自定义场景（极少用）。
      final scheme = Theme.of(context).colorScheme;
      return Container(
        padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
        child: Row(
          children: [
            leading!,
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    }
    return AppSheetHeader(title: title, icon: icon);
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
    final statusColors = AppStatusColors.of(context);
    Color color;
    bool pulse = false;
    switch (status) {
      case 'running':
        color = statusColors.running.foreground;
        pulse = true;
        break;
      case 'completed':
        color = statusColors.info.foreground;
        break;
      case 'stopped':
      case 'exited':
        color = statusColors.warning.foreground;
        break;
      case 'failed':
      case 'lost':
        color = statusColors.error.foreground;
        break;
      default:
        color = statusColors.neutral.foreground;
    }
    return AppStatusDot(color: color, size: 8, pulse: pulse);
  }
}

class _TokenUsagePanel extends StatelessWidget {
  final ChatTokenUsageSnapshot usage;
  final bool expanded;
  final VoidCallback onTap;

  const _TokenUsagePanel({
    required this.usage,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = (usage.contextRatio * 100).clamp(0, 999).round();
    final usageText =
        'Token ${chatCompactTokenNumber(usage.totalTokens)} · 上下文 ${chatCompactTokenNumber(usage.contextTokens)}/${chatCompactTokenNumber(usage.contextWindow)} $percent%';
    final detailText =
        '本次输入 ${chatCompactTokenNumber(usage.lastInputTokens)} · 本次输出 ${chatCompactTokenNumber(usage.lastOutputTokens)} · 缓存 ${chatCompactTokenNumber(usage.lastCachedInputTokens)} · 总窗口 ${chatCompactTokenNumber(usage.contextWindow)}';
    final borderColor = theme.dividerColor.withValues(alpha: 0.65);

    if (!expanded) {
      return Material(
        color: theme.colorScheme.surface,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            height: 22,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Material(
      color: theme.colorScheme.surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.data_usage,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      usageText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_up,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                detailText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
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
            color: isError
                ? AppStatusColors.of(context).error.foreground
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isError
                  ? AppStatusColors.of(context).error.foreground
                  : Theme.of(context).colorScheme.onSurfaceVariant,
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
    final scheme = Theme.of(context).colorScheme;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.74;
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
              backgroundColor: scheme.primary.withValues(alpha: 0.10),
              borderColor: scheme.primary.withValues(alpha: 0.28),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(4),
              ),
              childBuilder: (context, text, collapsed, maxLines) =>
                  SelectableText(
                    text,
                    maxLines: collapsed ? maxLines : null,
                    style: const TextStyle(height: 1.5),
                  ),
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 16,
            backgroundColor: scheme.primary,
            child: Icon(Icons.person, color: scheme.onPrimary, size: 16),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String content;
  final String? phase;
  final MarkdownTapLinkCallback? onTapLink;

  const _MessageBubble({required this.content, this.phase, this.onTapLink});

  bool get _isCommentary => phase == 'commentary';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_isCommentary && content.trim().isNotEmpty) {
      return _CommentaryLine(content: content);
    }
    final maxWidth = MediaQuery.sizeOf(context).width * 0.84;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: scheme.secondaryContainer,
            child: Icon(
              Icons.smart_toy,
              size: 16,
              color: scheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth.clamp(200.0, 840.0).toDouble(),
              ),
              child: _ExpandableBubble(
                content: content,
                backgroundColor: scheme.surfaceContainerLow,
                borderColor: scheme.outlineVariant.withValues(alpha: 0.45),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(16),
                ),
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

/// commentary 旁白（agentMessage.phase == "commentary"）。
/// 模型在工具调用之间的简短解说，渲染为左侧缩进的淡色斜体单段，
/// 默认折到 3 行，超过则点击展开。
class _CommentaryLine extends StatefulWidget {
  final String content;
  const _CommentaryLine({required this.content});

  @override
  State<_CommentaryLine> createState() => _CommentaryLineState();
}

class _CommentaryLineState extends State<_CommentaryLine> {
  static const _collapsedLines = 3;
  bool _expanded = false;

  bool get _shouldCollapse {
    final lineCount = '\n'.allMatches(widget.content).length + 1;
    return widget.content.length > 240 || lineCount > _collapsedLines;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shouldCollapse = _shouldCollapse;
    final collapsed = shouldCollapse && !_expanded;
    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 2, 16, 2),
      child: InkWell(
        onTap: shouldCollapse
            ? () => setState(() => _expanded = !_expanded)
            : null,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(Icons.short_text, size: 14, color: scheme.outline),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.content.trim(),
                  maxLines: collapsed ? _collapsedLines : null,
                  overflow: collapsed
                      ? TextOverflow.ellipsis
                      : TextOverflow.clip,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    fontStyle: FontStyle.italic,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (shouldCollapse)
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 1),
                  child: Icon(
                    _expanded ? Icons.unfold_less : Icons.unfold_more,
                    size: 14,
                    color: scheme.outline,
                  ),
                ),
            ],
          ),
        ),
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
  final Color? borderColor;
  final BorderRadius borderRadius;
  final _ExpandableBubbleChildBuilder childBuilder;

  const _ExpandableBubble({
    required this.content,
    required this.backgroundColor,
    required this.borderRadius,
    required this.childBuilder,
    this.borderColor,
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: widget.backgroundColor,
          borderRadius: widget.borderRadius,
          border: widget.borderColor != null
              ? Border.all(color: widget.borderColor!)
              : null,
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
  final String? summary;
  final bool success;
  final bool monospace;

  const _ToolCallCard({
    required this.icon,
    required this.title,
    required this.output,
    this.summary,
    required this.success,
    this.monospace = true,
  });

  @override
  State<_ToolCallCard> createState() => _ToolCallCardState();
}

class _ToolCallCardState extends State<_ToolCallCard> {
  @override
  Widget build(BuildContext context) {
    final color = widget.success
        ? AppStatusColors.of(context).running.foreground
        : Theme.of(context).colorScheme.error;
    final title = widget.title.trim().isEmpty
        ? AppLocalizations.of(context)!.approvalUnknownAction
        : widget.title.trim();
    final output = widget.output.trim();
    final summary = (widget.summary ?? output).trim();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _showTextDetailSheet(
            context,
            title: title,
            content: [
              title,
              if (output.isNotEmpty) '',
              if (output.isNotEmpty) output,
            ].join('\n'),
            language: widget.monospace
                ? _detailLanguage(title, output)
                : 'plaintext',
            monospace: widget.monospace,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
            child: Row(
              children: [
                Icon(widget.icon, color: color, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                      ),
                      if (summary.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.open_in_full,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void _showTextDetailSheet(
  BuildContext context, {
  required String title,
  required String content,
  String language = 'plaintext',
  bool monospace = false,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _SessionDetailSheet(
      title: title,
      content: content.trim().isEmpty ? title : content.trim(),
      language: language,
      monospace: monospace,
    ),
  );
}

String _detailLanguage(String title, String content) {
  final lowerTitle = title.toLowerCase();
  final trimmed = content.trimLeft();
  if (trimmed.startsWith('diff --git') || lowerTitle.contains('diff')) {
    return 'diff';
  }
  if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
    return 'json';
  }
  if (lowerTitle.contains('dart')) return 'dart';
  if (lowerTitle.contains('.go') || lowerTitle.contains(' go ')) return 'go';
  if (lowerTitle.contains('.md') || lowerTitle.contains('markdown')) {
    return 'markdown';
  }
  if (lowerTitle.contains('.yaml') || lowerTitle.contains('.yml')) {
    return 'yaml';
  }
  if (lowerTitle.contains('.json')) return 'json';
  if (lowerTitle.contains('.ts')) return 'typescript';
  if (lowerTitle.contains('.js')) return 'javascript';
  if (lowerTitle.contains('.py')) return 'python';
  if (lowerTitle.contains('command') || lowerTitle.contains('命令')) {
    return 'bash';
  }
  return 'plaintext';
}

class _SessionDetailSheet extends StatefulWidget {
  final String title;
  final String content;
  final String language;
  final bool monospace;

  const _SessionDetailSheet({
    required this.title,
    required this.content,
    required this.language,
    required this.monospace,
  });

  @override
  State<_SessionDetailSheet> createState() => _SessionDetailSheetState();
}

class _SessionDetailSheetState extends State<_SessionDetailSheet> {
  bool _wrap = false;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      maxChildSize: 0.95,
      minChildSize: 0.32,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            _buildHeader(context),
            Expanded(child: _buildBody(scrollController)),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            widget.language == 'diff' ? Icons.difference_outlined : Icons.code,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppStatusColors.of(context).info.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.language,
              style: TextStyle(
                fontSize: 10,
                color: AppStatusColors.of(context).info.foreground,
              ),
            ),
          ),
          Tooltip(
            message: _wrap ? l10n.noWrap : l10n.wrap,
            child: IconButton(
              icon: Icon(
                _wrap ? Icons.wrap_text : Icons.horizontal_rule,
                size: 18,
              ),
              onPressed: () => setState(() => _wrap = !_wrap),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.content));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.copied),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ScrollController scrollController) {
    if (widget.language == 'diff') {
      return _buildDiffBody(scrollController);
    }
    final highlightLanguage = _highlightLanguage(widget.language);
    final codeView = highlightLanguage == null
        ? Padding(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              widget.content,
              style: TextStyle(
                fontFamily: widget.monospace ? 'monospace' : null,
                fontSize: 12,
              ),
            ),
          )
        : HighlightView(
            widget.content,
            language: highlightLanguage,
            theme: githubTheme,
            padding: const EdgeInsets.all(16),
            textStyle: TextStyle(
              fontFamily: widget.monospace ? 'monospace' : null,
              fontSize: 12,
            ),
          );
    if (_wrap) {
      return SingleChildScrollView(
        controller: scrollController,
        child: codeView,
      );
    }
    return SingleChildScrollView(
      controller: scrollController,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: codeView,
      ),
    );
  }

  String? _highlightLanguage(String language) {
    switch (language) {
      case 'bash':
      case 'dart':
      case 'go':
      case 'javascript':
      case 'json':
      case 'markdown':
      case 'python':
      case 'typescript':
      case 'yaml':
        return language;
      default:
        return null;
    }
  }

  Widget _buildDiffBody(ScrollController scrollController) {
    final lines = _diffDetailLines(widget.content);
    final list = ListView.builder(
      controller: scrollController,
      itemCount: lines.length,
      itemBuilder: (context, index) =>
          _DiffDetailLineView(line: lines[index], wrap: _wrap),
    );
    if (_wrap) return list;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(width: 1200, child: list),
    );
  }
}

class _DiffDetailLine {
  final String type;
  final String content;

  const _DiffDetailLine({required this.type, required this.content});
}

List<_DiffDetailLine> _diffDetailLines(String diff) {
  return diff
      .split('\n')
      .map((line) {
        if (line.startsWith('+') && !line.startsWith('+++')) {
          return _DiffDetailLine(type: 'add', content: line);
        }
        if (line.startsWith('-') && !line.startsWith('---')) {
          return _DiffDetailLine(type: 'del', content: line);
        }
        if (line.startsWith('@@')) {
          return _DiffDetailLine(type: 'hunk', content: line);
        }
        if (line.startsWith('diff --git') ||
            line.startsWith('index ') ||
            line.startsWith('---') ||
            line.startsWith('+++')) {
          return _DiffDetailLine(type: 'meta', content: line);
        }
        return _DiffDetailLine(type: 'context', content: line);
      })
      .toList(growable: false);
}

class _DiffDetailLineView extends StatelessWidget {
  final _DiffDetailLine line;
  final bool wrap;

  const _DiffDetailLineView({required this.line, required this.wrap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusColors = AppStatusColors.of(context);
    Color bgColor;
    Color textColor;
    switch (line.type) {
      case 'add':
        bgColor = statusColors.running.background;
        textColor = statusColors.running.foreground;
        break;
      case 'del':
        bgColor = statusColors.error.background;
        textColor = statusColors.error.foreground;
        break;
      case 'hunk':
        bgColor = statusColors.info.background;
        textColor = statusColors.info.foreground;
        break;
      case 'meta':
        bgColor = scheme.surfaceContainerHigh;
        textColor = scheme.onSurfaceVariant;
        break;
      default:
        bgColor = Colors.transparent;
        textColor = scheme.onSurface;
    }
    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
      child: Text(
        line.content,
        softWrap: wrap,
        style: TextStyle(
          color: textColor,
          fontFamily: 'monospace',
          fontSize: 12,
        ),
      ),
    );
  }
}

class _StructuredInfoCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String? summary;
  final String detail;
  final bool monospace;

  const _StructuredInfoCard({
    required this.icon,
    required this.title,
    String? content,
    this.summary,
    String? detail,
    this.monospace = false,
  }) : detail = detail ?? content ?? '';

  @override
  State<_StructuredInfoCard> createState() => _StructuredInfoCardState();
}

class _StructuredInfoCardState extends State<_StructuredInfoCard> {
  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      fontFamily: widget.monospace ? 'monospace' : null,
      fontSize: 13,
    );
    final summary = (widget.summary ?? _collapsedText(widget.detail)).trim();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _showTextDetailSheet(
            context,
            title: widget.title,
            content: widget.detail,
            language: widget.monospace
                ? _detailLanguage(widget.title, widget.detail)
                : 'plaintext',
            monospace: widget.monospace,
          ),
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
                          Icon(
                            Icons.open_in_full,
                            size: 16,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                      if (summary.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textStyle.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
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
    if (firstLine.length <= 220) return firstLine;
    return '${firstLine.substring(0, 220).trimRight()}...';
  }
}

class _SessionLoadingState extends StatelessWidget {
  const _SessionLoadingState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.chatSyncingTitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.chatSyncingSubtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
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

/// 顶部常驻的策略信息条：会话当前生效的 model / effort / approval / sandbox。
/// 即使没有 token usage 也展示。点击触发设置面板。
class _SessionStrategyBar extends StatelessWidget {
  final String model;
  final String effort;
  final String approvalPolicy;
  final String sandboxMode;
  final VoidCallback onTap;

  const _SessionStrategyBar({
    required this.model,
    required this.effort,
    required this.approvalPolicy,
    required this.sandboxMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final displayModel = _readableOneLine(model);

    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            children: [
              Icon(Icons.tune, size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _StrategyChip(
                        label: displayModel.isEmpty ? '—' : displayModel,
                        tone: scheme.primary,
                      ),
                    ),
                    if (effort.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _StrategyChip(
                        label: _readableOneLine(effort),
                        tone: scheme.secondary,
                        maxWidth: 70,
                      ),
                    ],
                    if (approvalPolicy.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _StrategyChip(
                        label: _approvalLabel(l10n, approvalPolicy),
                        tone: scheme.tertiary,
                        maxWidth: 82,
                      ),
                    ],
                    if (sandboxMode.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _StrategyChip(
                        label: _sandboxLabel(l10n, sandboxMode),
                        tone: scheme.tertiary,
                        maxWidth: 82,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.edit_outlined,
                size: 14,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StrategyChip extends StatelessWidget {
  final String label;
  final Color tone;
  final double? maxWidth;

  const _StrategyChip({required this.label, required this.tone, this.maxWidth});

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: AppRadius.rxs,
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
        style: TextStyle(
          color: tone,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    if (maxWidth == null) return chip;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth!),
      child: chip,
    );
  }
}

String _approvalLabel(AppLocalizations l10n, String value) {
  switch (SessionApprovalPolicies.normalize(value)) {
    case SessionApprovalPolicies.onRequest:
      return l10n.approvalNormal;
    case SessionApprovalPolicies.onFailure:
      return l10n.approvalAuto;
    case SessionApprovalPolicies.untrusted:
      return l10n.approvalStrict;
    case SessionApprovalPolicies.never:
      return l10n.approvalAuto;
    default:
      return _readableOneLine(value);
  }
}

String _sandboxLabel(AppLocalizations l10n, String value) {
  switch (SessionSandboxModes.normalize(value)) {
    case SessionSandboxModes.readOnly:
      return l10n.sandboxReadOnly;
    case SessionSandboxModes.workspaceWrite:
      return l10n.sandboxWorkspace;
    case SessionSandboxModes.dangerFullAccess:
      return l10n.sandboxFull;
    default:
      return _readableOneLine(value);
  }
}

String _readableOneLine(Object? value) {
  if (value == null) return '';
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    final decoded = _tryDecodeJson(trimmed);
    if (decoded != null && decoded != value) {
      final text = _readableOneLine(decoded);
      if (text.isNotEmpty) return text;
    }
    return _collapseWhitespace(trimmed);
  }
  if (value is Map) {
    for (final key in const [
      'name',
      'id',
      'title',
      'summary',
      'text',
      'content',
      'message',
      'value',
      'path',
    ]) {
      final text = _readableOneLine(value[key]);
      if (text.isNotEmpty) return text;
    }
    final pairs = value.entries
        .where((entry) => entry.value != null)
        .take(3)
        .map((entry) {
          final text = _readableOneLine(entry.value);
          return text.isEmpty ? '' : '${entry.key}: $text';
        })
        .where((text) => text.isNotEmpty)
        .join(' · ');
    if (pairs.isNotEmpty) return pairs;
  }
  if (value is Iterable) {
    final text = value
        .map(_readableOneLine)
        .where((item) => item.isNotEmpty)
        .take(3)
        .join(' · ');
    if (text.isNotEmpty) return text;
  }
  return _collapseWhitespace(value.toString());
}

Object? _tryDecodeJson(String value) {
  if (!value.startsWith('{') && !value.startsWith('[')) return null;
  try {
    return jsonDecode(value);
  } catch (_) {
    return null;
  }
}

String _collapseWhitespace(String value) {
  return value.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// 设置面板返回值。
class _SessionSettingsResult {
  final String? model;
  final String? effort;
  final String? approvalPolicy;
  final String? sandboxMode;

  const _SessionSettingsResult({
    this.model,
    this.effort,
    this.approvalPolicy,
    this.sandboxMode,
  });
}

class _DropdownOptionText extends StatelessWidget {
  final String text;

  const _DropdownOptionText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      _readableOneLine(text),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
    );
  }
}

/// 会话设置弹窗：选择 model / effort / approval / sandbox。返回 null 表示取消。
class _SessionSettingsSheet extends StatefulWidget {
  final Map<String, dynamic>? config;
  final String currentModel;
  final String currentEffort;
  final String currentApproval;
  final String currentSandbox;

  const _SessionSettingsSheet({
    required this.config,
    required this.currentModel,
    required this.currentEffort,
    required this.currentApproval,
    required this.currentSandbox,
  });

  @override
  State<_SessionSettingsSheet> createState() => _SessionSettingsSheetState();
}

class _SessionSettingsSheetState extends State<_SessionSettingsSheet> {
  late String _model = widget.currentModel;
  late String _effort = widget.currentEffort;
  late String _approval = widget.currentApproval;
  late String _sandbox = widget.currentSandbox;

  List<Map<String, dynamic>> get _models {
    final raw = widget.config?['models'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  List<String> get _effortsForCurrentModel {
    Map<String, dynamic>? match;
    for (final m in _models) {
      if (m['id'] == _model) {
        match = m;
        break;
      }
    }
    if (match == null) return const [];
    final raw = match['reasoning_efforts'];
    if (raw is! List) return const [];
    return _stringOptions(raw);
  }

  List<String> get _approvalPolicies {
    final raw = widget.config?['approval_policies'];
    if (raw is! List) return const [];
    return _stringOptions(raw);
  }

  List<String> get _sandboxModes {
    final raw = widget.config?['sandbox_modes'];
    if (raw is! List) return const [];
    return _stringOptions(raw);
  }

  List<String> _stringOptions(List<dynamic> raw) {
    final values = <String>[];
    for (final item in raw) {
      final value = switch (item) {
        String() => item,
        num() => item.toString(),
        bool() => item.toString(),
        Map() => item['id']?.toString() ?? item['value']?.toString() ?? '',
        _ => '',
      };
      final normalized = _readableOneLine(value);
      if (normalized.isNotEmpty && !values.contains(normalized)) {
        values.add(normalized);
      }
    }
    return values;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    final modelOptions = <String>{
      ..._models
          .map((m) => _readableOneLine(m['id']))
          .where((s) => s.isNotEmpty),
      if (_model.isNotEmpty) _model,
    }.toList();
    final effortOptions = <String>{
      ..._effortsForCurrentModel,
      if (_effort.isNotEmpty) _effort,
    }.toList();
    final approvalOptions = <String>{
      ..._approvalPolicies,
      if (_approval.isNotEmpty) _approval,
    }.toList();
    final sandboxOptions = <String>{
      ..._sandboxModes,
      if (_sandbox.isNotEmpty) _sandbox,
    }.toList();

    String? safeValue(String value, List<String> options) {
      if (value.isEmpty) return null;
      return options.contains(value) ? value : null;
    }

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          top: 8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSheetHeader(title: l10n.chatSettingsTitle),
            const SizedBox(height: 4),
            Text(
              l10n.chatSettingsHint,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: safeValue(_model, modelOptions),
              decoration: InputDecoration(labelText: l10n.chatSettingsModel),
              items: modelOptions
                  .map(
                    (id) => DropdownMenuItem(
                      value: id,
                      child: _DropdownOptionText(id),
                    ),
                  )
                  .toList(),
              selectedItemBuilder: (_) =>
                  modelOptions.map((id) => _DropdownOptionText(id)).toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _model = value;
                  final supported = _effortsForCurrentModel;
                  if (_effort.isNotEmpty && !supported.contains(_effort)) {
                    _effort = supported.isNotEmpty ? supported.first : '';
                  }
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: safeValue(_effort, effortOptions),
              decoration: InputDecoration(labelText: l10n.chatSettingsEffort),
              items: effortOptions
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: _DropdownOptionText(_effortLabel(l10n, e)),
                    ),
                  )
                  .toList(),
              selectedItemBuilder: (_) => effortOptions
                  .map((e) => _DropdownOptionText(_effortLabel(l10n, e)))
                  .toList(),
              onChanged: effortOptions.isEmpty
                  ? null
                  : (value) {
                      if (value != null) setState(() => _effort = value);
                    },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: safeValue(_approval, approvalOptions),
              decoration: InputDecoration(labelText: l10n.chatSettingsApproval),
              items: approvalOptions
                  .map(
                    (id) => DropdownMenuItem(
                      value: id,
                      child: _DropdownOptionText(_approvalLabel(l10n, id)),
                    ),
                  )
                  .toList(),
              selectedItemBuilder: (_) => approvalOptions
                  .map((id) => _DropdownOptionText(_approvalLabel(l10n, id)))
                  .toList(),
              onChanged: approvalOptions.isEmpty
                  ? null
                  : (value) {
                      if (value != null) setState(() => _approval = value);
                    },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: safeValue(_sandbox, sandboxOptions),
              decoration: InputDecoration(labelText: l10n.chatSettingsSandbox),
              items: sandboxOptions
                  .map(
                    (id) => DropdownMenuItem(
                      value: id,
                      child: _DropdownOptionText(_sandboxLabel(l10n, id)),
                    ),
                  )
                  .toList(),
              selectedItemBuilder: (_) => sandboxOptions
                  .map((id) => _DropdownOptionText(_sandboxLabel(l10n, id)))
                  .toList(),
              onChanged: sandboxOptions.isEmpty
                  ? null
                  : (value) {
                      if (value != null) setState(() => _sandbox = value);
                    },
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  _SessionSettingsResult(
                    model: _model.isEmpty ? null : _model,
                    effort: _effort.isEmpty ? null : _effort,
                    approvalPolicy: _approval.isEmpty ? null : _approval,
                    sandboxMode: _sandbox.isEmpty ? null : _sandbox,
                  ),
                );
              },
              child: Text(l10n.chatSettingsApply),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  String _effortLabel(AppLocalizations l10n, String effort) {
    switch (effort.toLowerCase()) {
      case 'low':
        return l10n.effortLow;
      case 'medium':
        return l10n.effortMedium;
      case 'high':
        return l10n.effortHigh;
      default:
        return effort;
    }
  }
}
