import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magent_app/core/providers/api_provider.dart';
import 'package:magent_app/core/storage/app_database.dart';

class CacheSettingsPage extends ConsumerStatefulWidget {
  const CacheSettingsPage({super.key});

  @override
  ConsumerState<CacheSettingsPage> createState() => _CacheSettingsPageState();
}

class _CacheSettingsPageState extends ConsumerState<CacheSettingsPage> {
  AppApiClient? _api;
  CacheBucketStats _git = const CacheBucketStats(entries: 0, bytes: 0);
  CacheBucketStats _file = const CacheBucketStats(entries: 0, bytes: 0);
  CacheBucketStats _session = const CacheBucketStats(entries: 0, bytes: 0);
  bool _loading = true;
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = await loadActiveApi(ref);
    if (!mounted) return;
    _api = api;
    if (api == null) {
      setState(() => _loading = false);
      return;
    }
    await _refreshStats();
  }

  Future<void> _refreshStats() async {
    final api = _api;
    if (api == null) return;
    final db = ref.read(appDatabaseProvider);
    final stats = await Future.wait([
      db.getGitCacheStats(api.agentId),
      db.getFileCacheStats(api.agentId),
      db.getSessionCacheStats(api.agentId),
    ]);
    if (!mounted) return;
    setState(() {
      _git = stats[0];
      _file = stats[1];
      _session = stats[2];
      _loading = false;
    });
  }

  Future<void> _clearCache(String type) async {
    final api = _api;
    if (api == null) return;
    setState(() => _clearing = true);
    final db = ref.read(appDatabaseProvider);
    switch (type) {
      case 'git':
        await db.clearGitDisplayCache(api.agentId);
      case 'file':
        await db.clearFileDisplayCache(api.agentId);
      case 'session':
        await db.clearSessionDisplayCache(api.agentId);
      case 'all':
        await db.clearAllDisplayCaches(api.agentId);
    }
    await _refreshStats();
    if (!mounted) return;
    setState(() => _clearing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_labelForType(type)} cache cleared')),
    );
  }

  void _confirmClearAll() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Caches'),
        content: const Text(
          'This removes local display caches only. Provider history, Git state, and files remain the source of truth.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearCache('all');
            },
            child: const Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cache Management')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _api == null
          ? const Center(child: Text('No agent connected'))
          : RefreshIndicator(
              onRefresh: _refreshStats,
              child: ListView(
                children: [
                  _buildCacheTile(
                    icon: Icons.alt_route,
                    title: 'Git Display Cache',
                    stats: _git,
                    onClear: () => _clearCache('git'),
                  ),
                  _buildCacheTile(
                    icon: Icons.description,
                    title: 'File Display Cache',
                    stats: _file,
                    onClear: () => _clearCache('file'),
                  ),
                  _buildCacheTile(
                    icon: Icons.event_note,
                    title: 'Session Display Cache',
                    stats: _session,
                    onClear: () => _clearCache('session'),
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: OutlinedButton.icon(
                      onPressed: _clearing ? null : _confirmClearAll,
                      icon: const Icon(Icons.delete_sweep),
                      label: const Text('Clear All Display Caches'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCacheTile({
    required IconData icon,
    required String title,
    required CacheBucketStats stats,
    required VoidCallback onClear,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text('${stats.entries} entries · ${_formatBytes(stats.bytes)}'),
      trailing: TextButton(
        onPressed: _clearing || stats.entries == 0 ? null : onClear,
        child: const Text('Clear'),
      ),
    );
  }

  String _labelForType(String type) {
    switch (type) {
      case 'git':
        return 'Git';
      case 'file':
        return 'File';
      case 'session':
        return 'Session';
      default:
        return 'All';
    }
  }

  String _formatBytes(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }
    if (unit == 0) return '$bytes ${units[unit]}';
    return '${size.toStringAsFixed(1)} ${units[unit]}';
  }
}
