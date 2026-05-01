import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:magent_app/core/api/error_messages.dart';
import 'package:magent_app/core/providers/api_provider.dart';
import 'package:magent_app/core/repositories/bootstrap_repository.dart';
import 'package:magent_app/l10n/app_localizations.dart';
import 'package:magent_app/shared/widgets/dir_picker.dart';

class ProjectListPage extends ConsumerStatefulWidget {
  const ProjectListPage({super.key});

  @override
  ConsumerState<ProjectListPage> createState() => _ProjectListPageState();
}

class _ProjectListPageState extends ConsumerState<ProjectListPage> {
  List<dynamic> _projects = [];
  bool _loading = true;
  AppApiClient? _api;
  BootstrapRepository? _bootstrap;
  StreamSubscription<List<Map<String, dynamic>>>? _projectsSub;

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
    ref.read(syncEngineProvider)?.start();
    _bootstrap = createBootstrapRepository(ref, _api!);
    _projectsSub = _bootstrap!.watchProjects().listen((projects) {
      if (!mounted) return;
      setState(() {
        _projects = projects;
        _loading = false;
      });
    });
    await _loadProjects();
  }

  Future<void> _loadProjects() async {
    if (_bootstrap == null) return;
    try {
      final projects = await _bootstrap!.getProjects();
      if (mounted) {
        setState(() {
          _projects = projects;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createProject() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _CreateProjectDialog(api: _api!, bootstrap: _bootstrap!),
    );
    if (result != null) {
      await _loadProjects();
    }
  }

  Future<void> _deleteProject(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Project'),
        content: Text('Delete "$name"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && _api != null) {
      try {
        await _bootstrap!.deleteProject(id);
        await _loadProjects();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                userFriendlyErrorMessage(e, action: 'Delete failed'),
              ),
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _projectsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.projectsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _api == null ? null : _createProject,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _projects.isEmpty
          ? _ProjectEmptyState(onCreate: _api == null ? null : _createProject)
          : RefreshIndicator(
              onRefresh: _loadProjects,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                cacheExtent: 640,
                itemCount: _projects.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final project = _projects[index];
                  final id = project['id'] as String? ?? '';
                  final name = project['name'] as String? ?? '';
                  final path = project['path'] as String? ?? '';
                  final provider =
                      project['default_provider'] as String? ?? 'codex';

                  return Dismissible(
                    key: Key(id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.error,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (_) async {
                      await _deleteProject(id, name);
                      return false;
                    },
                    child: _ProjectListItem(
                      name: name,
                      path: path,
                      provider: provider,
                      onTap: () => context.push('/projects/$id'),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _ProjectEmptyState extends StatelessWidget {
  final VoidCallback? onCreate;

  const _ProjectEmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.folder_open,
                size: 34,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              l10n.projectsEmpty,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '添加一个工作目录后即可创建会话、查看变更和浏览文件。',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: Text(l10n.projectsCreate),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectListItem extends StatelessWidget {
  final String name;
  final String path;
  final String provider;
  final VoidCallback onTap;

  const _ProjectListItem({
    required this.name,
    required this.path,
    required this.provider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = name.isEmpty ? 'Untitled Project' : name;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.folder,
                  color: scheme.onTertiaryContainer,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _ProviderPill(provider: provider),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(
                          Icons.account_tree_outlined,
                          size: 14,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            path,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProviderPill extends StatelessWidget {
  final String provider;

  const _ProviderPill({required this.provider});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = provider.isEmpty ? 'default' : provider;

    return Container(
      constraints: const BoxConstraints(maxWidth: 96),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: scheme.onSecondaryContainer,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CreateProjectDialog extends StatefulWidget {
  final AppApiClient api;
  final BootstrapRepository bootstrap;

  const _CreateProjectDialog({required this.api, required this.bootstrap});

  @override
  State<_CreateProjectDialog> createState() => _CreateProjectDialogState();
}

class _CreateProjectDialogState extends State<_CreateProjectDialog> {
  final _nameController = TextEditingController();
  String _selectedPath = '';
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _loadHome();
  }

  Future<void> _loadHome() async {
    try {
      final resp = await widget.api.client.dio.get('/api/v1/dirs/home');
      if (mounted) {
        setState(() {
          _selectedPath = resp.data['data']['path'] as String;
        });
      }
    } catch (_) {}
  }

  Future<void> _pickDir() async {
    final path = await showDirPicker(context, initialPath: _selectedPath);
    if (path != null) {
      setState(() => _selectedPath = path);
      // Auto-fill name from directory name
      if (_nameController.text.isEmpty) {
        final parts = path.split('/');
        if (parts.isNotEmpty) {
          _nameController.text = parts.last;
        }
      }
    }
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _selectedPath.isEmpty) return;

    setState(() => _creating = true);
    try {
      await widget.bootstrap.createProject(name, _selectedPath);
      if (mounted) {
        Navigator.pop(context, {'name': name, 'path': _selectedPath});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userFriendlyErrorMessage(e, action: 'Create failed')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Project'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Project Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickDir,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Directory',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.folder_open),
              ),
              child: Text(
                _selectedPath.isEmpty ? 'Select directory...' : _selectedPath,
                style: TextStyle(
                  color: _selectedPath.isEmpty ? Colors.grey : null,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _creating ? null : _create,
          child: _creating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
