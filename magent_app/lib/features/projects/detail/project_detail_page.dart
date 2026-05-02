import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:magent_app/core/providers/api_provider.dart';
import 'package:magent_app/core/providers/app_settings_provider.dart';
import 'package:magent_app/core/repositories/bootstrap_repository.dart';
import 'package:magent_app/core/repositories/file_repository.dart';
import 'package:magent_app/core/repositories/git_repository.dart';
import 'package:magent_app/core/repositories/session_repository.dart';
import 'package:magent_app/core/session/session_language.dart';
import 'package:magent_app/core/storage/secure_storage.dart';
import 'package:magent_app/features/projects/detail/project_sessions_tab.dart';
import 'package:magent_app/features/projects/detail/project_changes_tab.dart';
import 'package:magent_app/features/projects/detail/project_files_tab.dart';
import 'package:magent_app/l10n/app_localizations.dart';

class ProjectDetailPage extends ConsumerStatefulWidget {
  final String projectId;

  const ProjectDetailPage({super.key, required this.projectId});

  @override
  ConsumerState<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends ConsumerState<ProjectDetailPage> {
  int _currentTab = 0;
  Map<String, dynamic>? _project;
  List<dynamic> _sessions = [];
  bool _loading = true;
  bool _showArchivedSessions = false;
  AppApiClient? _api;
  BootstrapRepository? _bootstrap;
  SessionRepository? _repo;
  GitRepository? _gitRepo;
  FileRepository? _fileRepo;
  StreamSubscription<Map<String, dynamic>>? _gitInvalidationSub;
  StreamSubscription<List<Map<String, dynamic>>>? _sessionsSub;
  final _gitInvalidationSignal = ValueNotifier<int>(0);

  List<dynamic> _providers = [];
  String _selectedProvider = '';
  final _storage = AgentStorage();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _api = await loadActiveApi(ref);
    if (_api == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final db = ref.read(appDatabaseProvider);
    _bootstrap = createBootstrapRepository(ref, _api!);
    _repo = SessionRepository(
      agentId: _api!.agentId,
      api: _api!.session,
      db: db,
    );
    _gitRepo = GitRepository(agentId: _api!.agentId, api: _api!.git, db: db);
    _fileRepo = FileRepository(agentId: _api!.agentId, api: _api!.file, db: db);
    _subscribeSessions();
    _connectRealtime();
    // Load saved provider first (fast, local) so UI is ready immediately
    final saved = await _storage.getDefaultProvider();
    if (saved != null && saved.isNotEmpty && mounted) {
      setState(() => _selectedProvider = saved);
    }
    // Then load everything in parallel
    await Future.wait([_loadProject(), _loadSessions(), _loadProviders()]);
  }

  void _connectRealtime() {
    final engine = ref.read(syncEngineProvider);
    if (engine == null) return;
    _gitInvalidationSub = engine.gitInvalidations.listen((event) {
      if (!mounted) return;
      if (event['project_id']?.toString() != widget.projectId) return;
      _gitInvalidationSignal.value++;
    });
  }

  void _subscribeSessions() {
    _sessionsSub?.cancel();
    _sessionsSub = _repo!
        .watchSessions(widget.projectId, archived: _showArchivedSessions)
        .listen((sessions) {
          if (!mounted) return;
          setState(() {
            _sessions = sessions;
            _loading = false;
          });
        });
  }

  Future<void> _loadProject() async {
    if (_bootstrap == null) return;
    try {
      final project = await _bootstrap!.getProject(widget.projectId);
      if (mounted) setState(() => _project = project);
    } catch (_) {}
  }

  Future<void> _loadSessions() async {
    if (_repo == null) return;
    try {
      // 1. Load from local DB first (immediate)
      final localSessions = await _repo!.getSessions(
        widget.projectId,
        archived: _showArchivedSessions,
      );
      if (mounted && localSessions.isNotEmpty) {
        setState(() {
          _sessions = localSessions;
          _loading = false;
        });
      } else if (mounted) {
        setState(() => _loading = false);
      }

      // 2. Sync from API in background
      await _repo!.refreshSessions(
        widget.projectId,
        archived: _showArchivedSessions,
      );
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadProviders() async {
    if (_bootstrap == null) return;
    try {
      final providers = await _bootstrap!.getProviders();
      final available = providers
          .where((p) => p['status'] == 'available')
          .toList();
      available.sort((a, b) {
        final nameA = (a['name'] as String? ?? '').toLowerCase();
        final nameB = (b['name'] as String? ?? '').toLowerCase();
        if (nameA == 'codex') return -1;
        if (nameB == 'codex') return 1;
        return nameA.compareTo(nameB);
      });

      final savedProvider = await _storage.getDefaultProvider();

      if (mounted) {
        setState(() {
          _providers = available;
          if (available.isNotEmpty) {
            if (savedProvider != null &&
                savedProvider.isNotEmpty &&
                available.any((p) => p['name'] == savedProvider)) {
              _selectedProvider = savedProvider;
            } else {
              _selectedProvider = available.first['name'] ?? '';
            }
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _refreshAll() async {
    await Future.wait([_loadProject(), _loadSessions()]);
  }

  void _onProviderChanged(String provider) {
    setState(() => _selectedProvider = provider);
    _storage.setDefaultProvider(provider);
  }

  void _setSessionsArchiveView(bool archived) {
    if (_showArchivedSessions == archived) return;
    setState(() {
      _showArchivedSessions = archived;
      _sessions = [];
      _loading = true;
    });
    _subscribeSessions();
    _loadSessions();
  }

  @override
  void dispose() {
    _gitInvalidationSub?.cancel();
    _sessionsSub?.cancel();
    _gitInvalidationSignal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final name = _project?['name'] as String? ?? l10n.untitledProject;

    return Scaffold(
      appBar: AppBar(
        title: _currentTab == 0
            ? Text(name)
            : _currentTab == 1
            ? Text(l10n.gitChanges)
            : Text(l10n.filesTitle),
        actions: [
          if (_currentTab == 0 && _providers.length > 1)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _buildProviderSelector(),
            ),
          if (_currentTab == 0)
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: l10n.sessionsCreate,
              onPressed: _selectedProvider.isEmpty
                  ? null
                  : () async {
                      await context.push(
                        '/projects/${widget.projectId}/sessions/create',
                        extra: {'provider': _selectedProvider},
                      );
                      _loadSessions();
                    },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _api == null
          ? Center(child: Text(l10n.noAgentConnected))
          : _buildTabContent(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: (index) => setState(() => _currentTab = index),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.chat_bubble_outline),
            selectedIcon: const Icon(Icons.chat_bubble),
            label: l10n.sessionsTitle,
          ),
          NavigationDestination(
            icon: const Icon(Icons.compare_arrows),
            selectedIcon: const Icon(Icons.compare_arrows),
            label: l10n.gitChanges,
          ),
          NavigationDestination(
            icon: const Icon(Icons.folder_open),
            selectedIcon: const Icon(Icons.folder),
            label: l10n.filesTitle,
          ),
        ],
      ),
      floatingActionButton: _currentTab == 0
          ? FloatingActionButton(
              onPressed: _selectedProvider.isEmpty
                  ? null
                  : () async {
                      await context.push(
                        '/projects/${widget.projectId}/sessions/create',
                        extra: {'provider': _selectedProvider},
                      );
                      _loadSessions();
                    },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildProviderSelector() {
    return PopupMenuButton<String>(
      onSelected: _onProviderChanged,
      itemBuilder: (ctx) => _providers.map((p) {
        final name = p['name'] as String? ?? '';
        return PopupMenuItem(
          value: name,
          child: Row(
            children: [
              Icon(_providerIcon(name), size: 16),
              const SizedBox(width: 8),
              Text(name[0].toUpperCase() + name.substring(1)),
              if (name == _selectedProvider) ...[
                const Spacer(),
                Icon(
                  Icons.check,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.primaryContainer.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_providerIcon(_selectedProvider), size: 14),
            const SizedBox(width: 4),
            Text(
              _selectedProvider.isNotEmpty
                  ? _selectedProvider[0].toUpperCase() +
                        _selectedProvider.substring(1)
                  : 'Provider',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.arrow_drop_down, size: 16),
          ],
        ),
      ),
    );
  }

  IconData _providerIcon(String name) {
    switch (name) {
      case 'codex':
        return Icons.smart_toy;
      case 'claude':
        return Icons.psychology;
      case 'aider':
        return Icons.terminal;
      default:
        return Icons.extension;
    }
  }

  Widget _buildTabContent() {
    switch (_currentTab) {
      case 0:
        return ProjectSessionsTab(
          projectId: widget.projectId,
          sessions: _visibleSessions,
          api: _api!,
          archived: _showArchivedSessions,
          onArchiveModeChanged: _setSessionsArchiveView,
          onArchiveSession: _archiveSession,
          onUnarchiveSession: _unarchiveSession,
          onDeleteSession: _deleteSession,
          onRefresh: _refreshAll,
        );
      case 1:
        return ProjectChangesTab(
          projectId: widget.projectId,
          git: _gitRepo!,
          file: _fileRepo!,
          invalidationSignal: _gitInvalidationSignal,
          onViewLog: () => context.push(
            '/git/manage',
            extra: {'projectId': widget.projectId},
          ),
          onViewBranches: () => context.push(
            '/git/manage',
            extra: {'projectId': widget.projectId},
          ),
        );
      case 2:
        return ProjectFilesTab(
          projectId: widget.projectId,
          file: _fileRepo!,
          git: _gitRepo!,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  List<dynamic> get _visibleSessions {
    final showAiCommitSessions = ref
        .watch(showAiCommitSessionsControllerProvider)
        .maybeWhen(data: (value) => value, orElse: () => false);
    if (showAiCommitSessions) return _sessions;
    return _sessions
        .where((session) {
          if (session is! Map) return true;
          return session['purpose']?.toString() != SessionPurposes.aiCommit;
        })
        .toList(growable: false);
  }

  Future<void> _archiveSession(String sessionId) async {
    if (_repo == null) return;
    await _repo!.archiveSession(sessionId);
    await _loadSessions();
  }

  Future<void> _unarchiveSession(String sessionId) async {
    if (_repo == null) return;
    await _repo!.unarchiveSession(sessionId, projectId: widget.projectId);
    await _loadSessions();
  }

  Future<void> _deleteSession(String sessionId) async {
    if (_repo == null) return;
    await _repo!.deleteSession(sessionId);
    await _loadSessions();
  }
}
