import 'package:flutter/material.dart';
import 'package:magent_app/core/providers/api_provider.dart';
import 'package:magent_app/core/storage/secure_storage.dart';
import 'package:magent_app/l10n/app_localizations.dart';
import 'package:magent_app/shared/widgets/app_loading.dart';
import 'package:magent_app/shared/widgets/app_sheet_header.dart';

class DirPickerSheet extends StatefulWidget {
  final String? initialPath;

  const DirPickerSheet({super.key, this.initialPath});

  @override
  State<DirPickerSheet> createState() => _DirPickerSheetState();
}

class _DirPickerSheetState extends State<DirPickerSheet> {
  String _currentPath = '';
  String _parentPath = '';
  List<dynamic> _entries = [];
  bool _loading = true;
  AppApiClient? _api;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final storage = AgentStorage();
    final agents = await storage.loadAgents();
    if (agents.isEmpty || !mounted) return;
    final activeId = await storage.getActiveAgentId();
    Map<String, String>? agent;
    if (activeId != null) {
      for (final a in agents) {
        if (a['id'] == activeId) {
          agent = a;
          break;
        }
      }
    }
    agent ??= agents.first;
    _api = createApiClient(agent['url'] ?? '', agent['token'] ?? '');

    if (widget.initialPath != null && widget.initialPath!.isNotEmpty) {
      await _loadDir(widget.initialPath!);
    } else {
      await _loadHome();
    }
  }

  Future<void> _loadHome() async {
    if (_api == null) return;
    try {
      final resp = await _api!.client.dio.get('/api/v1/dirs/home');
      final homePath = resp.data['data']['path'] as String;
      await _loadDir(homePath);
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadDir(String path) async {
    if (_api == null) return;
    setState(() => _loading = true);
    try {
      final resp = await _api!.client.dio.get(
        '/api/v1/dirs/list',
        queryParameters: {'path': path},
      );
      final data = resp.data['data'];
      if (mounted) {
        setState(() {
          _currentPath = data['path'] ?? path;
          _parentPath = data['parent'] ?? '';
          _entries = data['entries'] ?? [];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            AppSheetHeader(
              title: _currentPath.isEmpty ? l10n.filesTitle : _currentPath,
              icon: Icons.folder_outlined,
            ),
            if (_parentPath.isNotEmpty && _parentPath != _currentPath)
              ListTile(
                leading: const Icon(Icons.arrow_upward, size: 20),
                title: const Text('..'),
                dense: true,
                onTap: () => _loadDir(_parentPath),
              ),
            Expanded(
              child: _loading
                  ? const AppLoading()
                  : _entries.isEmpty
                  ? Center(
                      child: Text(
                        l10n.filesNoSubdirectories,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: _entries.length,
                      itemBuilder: (context, index) {
                        final entry = _entries[index];
                        return ListTile(
                          leading: Icon(
                            Icons.folder,
                            color: scheme.tertiary,
                            size: 20,
                          ),
                          title: Text(entry['name'] ?? ''),
                          dense: true,
                          onTap: () => _loadDir(entry['path']),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, _currentPath),
                  child: Text(l10n.filesSelectPath(_currentPath)),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

Future<String?> showDirPicker(BuildContext context, {String? initialPath}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (_) => DirPickerSheet(initialPath: initialPath),
  );
}
