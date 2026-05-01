import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:magent_app/core/providers/api_provider.dart';
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
    await _loadProjects();
  }

  Future<void> _loadProjects() async {
    if (_api == null) return;
    try {
      final projects = await _api!.client.listProjects();
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
      builder: (_) => _CreateProjectDialog(api: _api!),
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
        await _api!.client.deleteProject(id);
        await _loadProjects();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Delete failed: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Projects'),
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
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.folder_open, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('No projects yet'),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _api == null ? null : _createProject,
                        icon: const Icon(Icons.add),
                        label: const Text('Create Project'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadProjects,
                  child: ListView.builder(
                    itemCount: _projects.length,
                    itemBuilder: (context, index) {
                      final project = _projects[index];
                      final id = project['id'] as String? ?? '';
                      final name = project['name'] as String? ?? '';
                      final path = project['path'] as String? ?? '';
                      final provider = project['default_provider'] as String? ?? 'codex';

                      return Dismissible(
                        key: Key(id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          color: Colors.red,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (_) async {
                          await _deleteProject(id, name);
                          return false;
                        },
                        child: ListTile(
                          leading: const Icon(Icons.folder, color: Colors.amber),
                          title: Text(name),
                          subtitle: Text(path, style: const TextStyle(fontSize: 12)),
                          trailing: Chip(
                            label: Text(provider, style: const TextStyle(fontSize: 11)),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onTap: () => context.push('/projects/$id'),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _CreateProjectDialog extends StatefulWidget {
  final AppApiClient api;

  const _CreateProjectDialog({required this.api});

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
      final resp = await widget.api.client.dio.get('/api/dirs/home');
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
      await widget.api.client.createProject(name, _selectedPath);
      if (mounted) Navigator.pop(context, {'name': name, 'path': _selectedPath});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Create failed: $e')),
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
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
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
