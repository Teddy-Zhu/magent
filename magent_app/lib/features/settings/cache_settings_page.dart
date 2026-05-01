import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magent_app/core/providers/api_provider.dart';
import 'package:magent_app/core/storage/app_database.dart';
import 'package:magent_app/l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.cacheCleared(_labelForType(l10n, type)))),
    );
  }

  void _confirmClearAll() {
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.cacheClearAllCaches),
        content: Text(l10n.cacheClearConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearCache('all');
            },
            child: Text(
              l10n.cacheClearAll,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsCacheManage)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _api == null
          ? Center(child: Text(l10n.noAgentConnected))
          : RefreshIndicator(
              onRefresh: _refreshStats,
              child: ListView(
                children: [
                  _buildCacheTile(
                    icon: Icons.alt_route,
                    title: l10n.cacheGitDisplay,
                    stats: _git,
                    onClear: () => _clearCache('git'),
                  ),
                  _buildCacheTile(
                    icon: Icons.description,
                    title: l10n.cacheFileDisplay,
                    stats: _file,
                    onClear: () => _clearCache('file'),
                  ),
                  _buildCacheTile(
                    icon: Icons.event_note,
                    title: l10n.cacheSessionDisplay,
                    stats: _session,
                    onClear: () => _clearCache('session'),
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: OutlinedButton.icon(
                      onPressed: _clearing ? null : _confirmClearAll,
                      icon: const Icon(Icons.delete_sweep),
                      label: Text(l10n.cacheClearAllDisplayCaches),
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
    final l10n = AppLocalizations.of(context)!;
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(
        '${l10n.cacheEntries(stats.entries)} · ${_formatBytes(stats.bytes)}',
      ),
      trailing: TextButton(
        onPressed: _clearing || stats.entries == 0 ? null : onClear,
        child: Text(l10n.cacheClear),
      ),
    );
  }

  String _labelForType(AppLocalizations l10n, String type) {
    switch (type) {
      case 'git':
        return 'Git';
      case 'file':
        return l10n.filesTitle;
      case 'session':
        return l10n.sessionsTitle;
      default:
        return l10n.cacheClearAll;
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
