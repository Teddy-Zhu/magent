import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:magent_app/core/api/error_messages.dart';
import 'package:magent_app/core/providers/api_provider.dart';
import 'package:magent_app/core/repositories/bootstrap_repository.dart';
import 'package:magent_app/core/theme/theme.dart';
import 'package:magent_app/l10n/app_localizations.dart';
import 'package:magent_app/shared/widgets/app_empty_state.dart';
import 'package:magent_app/shared/widgets/app_list_tile.dart';
import 'package:magent_app/shared/widgets/app_loading.dart';
import 'package:magent_app/shared/widgets/app_pill.dart';
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
  String _activeAgentName = '';
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
    final activeAgent = await ref.read(secureStorageProvider).getActiveAgent();
    final agentName = activeAgent?['name']?.trim() ?? '';
    if (mounted) {
      setState(() {
        _activeAgentName = agentName.isEmpty
            ? (activeAgent?['url'] ?? '')
            : agentName;
      });
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
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.projectsDelete),
        content: Text(l10n.projectsDeleteConfirm(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              l10n.delete,
              style: TextStyle(color: scheme.error),
            ),
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
                localizedErrorMessage(
                  AppLocalizations.of(context)!,
                  e,
                  action: AppLocalizations.of(context)!.projectsDeleteFailed,
                ),
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
    final scheme = Theme.of(context).colorScheme;

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
          ? const AppLoading()
          : _projects.isEmpty
          ? AppEmptyState(
              icon: Icons.folder_open,
              title: l10n.projectsEmpty,
              subtitle: l10n.projectsEmptySub,
              action: FilledButton.icon(
                onPressed: _api == null ? null : _createProject,
                icon: const Icon(Icons.add),
                label: Text(l10n.projectsCreate),
              ),
            )
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
                        color: scheme.errorContainer,
                        borderRadius: AppRadius.rmd,
                      ),
                      child: Icon(Icons.delete, color: scheme.onErrorContainer),
                    ),
                    confirmDismiss: (_) async {
                      await _deleteProject(id, name);
                      return false;
                    },
                    child: _ProjectCard(
                      name: name,
                      path: path,
                      provider: provider,
                      agentName: _activeAgentName,
                      onTap: () => context.push('/projects/$id'),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final String name;
  final String path;
  final String provider;
  final String agentName;
  final VoidCallback onTap;

  const _ProjectCard({
    required this.name,
    required this.path,
    required this.provider,
    required this.agentName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final title = name.isEmpty ? l10n.untitledProject : name;
    final providerLabel = provider.isEmpty ? 'default' : provider;
    final hasAgent = agentName.isNotEmpty;

    return Card(
      child: AppListTile(
        onTap: onTap,
        tone: AppListTileTone.tertiary,
        showChevron: true,
        title: Row(
          children: [
            if (hasAgent) ...[
              _AgentBadge(name: agentName),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            AppPill(
              label: providerLabel,
              color: scheme.secondary,
              variant: AppPillVariant.tonal,
              maxWidth: 96,
            ),
          ],
        ),
        subtitle: Row(
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 项目卡片左侧的 agent 标签：用 hub icon + 文字显示当前激活 agent 的名字。
class _AgentBadge extends StatelessWidget {
  final String name;

  const _AgentBadge({required this.name});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 110),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: 0.7),
          borderRadius: AppRadius.rxs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.hub_outlined,
              size: 11,
              color: scheme.onPrimaryContainer,
            ),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: scheme.onPrimaryContainer,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ],
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
            content: Text(
              localizedErrorMessage(
                AppLocalizations.of(context)!,
                e,
                action: AppLocalizations.of(context)!.projectsCreateFailed,
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(l10n.projectsCreate),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: InputDecoration(labelText: l10n.projectsName),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickDir,
            borderRadius: AppRadius.rmd,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: l10n.projectsDirectory,
                suffixIcon: const Icon(Icons.folder_open),
              ),
              child: Text(
                _selectedPath.isEmpty ? l10n.projectsSelectDir : _selectedPath,
                style: TextStyle(
                  color: _selectedPath.isEmpty
                      ? scheme.onSurfaceVariant
                      : scheme.onSurface,
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
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _creating ? null : _create,
          child: _creating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.create),
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
