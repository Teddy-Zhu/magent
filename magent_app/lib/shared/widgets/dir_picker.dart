import 'package:flutter/material.dart';
import 'package:magent_app/core/providers/api_provider.dart';
import 'package:magent_app/core/storage/secure_storage.dart';

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
        if (a['id'] == activeId) { agent = a; break; }
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
      final resp = await _api!.client.dio.get('/api/dirs/home');
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
      final resp = await _api!.client.dio.get('/api/dirs/list', queryParameters: {'path': path});
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
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.folder, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _currentPath,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Navigation
            if (_parentPath.isNotEmpty && _parentPath != _currentPath)
              ListTile(
                leading: const Icon(Icons.arrow_upward, size: 20),
                title: const Text('..'),
                dense: true,
                onTap: () => _loadDir(_parentPath),
              ),
            // Entries
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _entries.isEmpty
                      ? const Center(child: Text('No subdirectories'))
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: _entries.length,
                          itemBuilder: (context, index) {
                            final entry = _entries[index];
                            return ListTile(
                              leading: const Icon(Icons.folder, color: Colors.amber, size: 20),
                              title: Text(entry['name'] ?? ''),
                              dense: true,
                              onTap: () => _loadDir(entry['path']),
                            );
                          },
                        ),
            ),
            // Select button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, _currentPath),
                  child: Text('Select: $_currentPath'),
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
