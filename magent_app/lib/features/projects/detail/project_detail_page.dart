import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:magent_app/core/providers/api_provider.dart';
import 'package:magent_app/features/projects/detail/project_sessions_tab.dart';
import 'package:magent_app/features/projects/detail/project_changes_tab.dart';
import 'package:magent_app/features/projects/detail/project_files_tab.dart';

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
  AppApiClient? _api;

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
    await Future.wait([_loadProject(), _loadSessions()]);
  }

  Future<void> _loadProject() async {
    if (_api == null) return;
    try {
      final resp = await _api!.client.dio.get('/api/projects/${widget.projectId}');
      if (mounted) setState(() => _project = resp.data['data']);
    } catch (_) {}
  }

  Future<void> _loadSessions() async {
    if (_api == null) return;
    try {
      final sessions = await _api!.session.listSessions(widget.projectId);
      if (mounted) setState(() { _sessions = sessions; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([_loadProject(), _loadSessions()]);
  }

  @override
  Widget build(BuildContext context) {
    final name = _project?['name'] as String? ?? 'Project';

    return Scaffold(
      appBar: AppBar(
        title: _currentTab == 0
            ? Text(name)
            : _currentTab == 1
                ? const Text('Changes')
                : const Text('Files'),
        actions: [
          if (_currentTab == 0)
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'New Session',
              onPressed: () async {
                await context.push('/projects/${widget.projectId}/sessions/create');
                _loadSessions();
              },
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _api == null
              ? const Center(child: Text('No agent connected'))
              : _buildTabContent(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: (index) => setState(() => _currentTab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Sessions',
          ),
          NavigationDestination(
            icon: Icon(Icons.compare_arrows),
            selectedIcon: Icon(Icons.compare_arrows),
            label: 'Changes',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_open),
            selectedIcon: Icon(Icons.folder),
            label: 'Files',
          ),
        ],
      ),
      floatingActionButton: _currentTab == 0
          ? FloatingActionButton(
              onPressed: () async {
                await context.push('/projects/${widget.projectId}/sessions/create');
                _loadSessions();
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildTabContent() {
    switch (_currentTab) {
      case 0:
        return ProjectSessionsTab(
          projectId: widget.projectId,
          sessions: _sessions,
          api: _api!,
          onRefresh: _refreshAll,
        );
      case 1:
        return ProjectChangesTab(
          projectId: widget.projectId,
          api: _api!,
          onViewLog: () => context.push('/git/manage', extra: {'projectId': widget.projectId}),
          onViewBranches: () => context.push('/git/manage', extra: {'projectId': widget.projectId}),
        );
      case 2:
        return ProjectFilesTab(
          projectId: widget.projectId,
          fileApi: _api!.file,
          gitApi: _api!.git,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
