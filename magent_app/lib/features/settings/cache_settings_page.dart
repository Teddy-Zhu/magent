import 'package:flutter/material.dart';

class CacheSettingsPage extends StatefulWidget {
  const CacheSettingsPage({super.key});

  @override
  State<CacheSettingsPage> createState() => _CacheSettingsPageState();
}

class _CacheSettingsPageState extends State<CacheSettingsPage> {
  String _gitCacheSize = 'Calculating...';
  String _fileCacheSize = 'Calculating...';
  String _eventCacheSize = 'Calculating...';
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _calculateCacheSizes();
  }

  void _calculateCacheSizes() {
    // Cache size estimation (would connect to API in production)
    setState(() {
      _gitCacheSize = '~2.4 MB';
      _fileCacheSize = '~1.1 MB';
      _eventCacheSize = '~0.8 MB';
    });
  }

  Future<void> _clearCache(String type) async {
    setState(() => _clearing = true);
    // Would call API to clear cache
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      _clearing = false;
      _calculateCacheSizes();
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$type cache cleared')),
      );
    }
  }

  void _confirmClearAll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Caches'),
        content: const Text('This will remove all cached data. Files and diffs will need to be re-fetched. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearCache('All');
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
      body: ListView(
        children: [
          _buildCacheTile(
            icon: Icons.alt_route,
            title: 'Git Diff Cache',
            subtitle: _gitCacheSize,
            onClear: () => _clearCache('Git diff'),
          ),
          _buildCacheTile(
            icon: Icons.description,
            title: 'File Cache',
            subtitle: _fileCacheSize,
            onClear: () => _clearCache('File'),
          ),
          _buildCacheTile(
            icon: Icons.event_note,
            title: 'Session Event Cache',
            subtitle: _eventCacheSize,
            onClear: () => _clearCache('Event'),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: _clearing ? null : _confirmClearAll,
              icon: const Icon(Icons.delete_sweep),
              label: const Text('Clear All Caches'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCacheTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onClear,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: TextButton(
        onPressed: _clearing ? null : onClear,
        child: const Text('Clear'),
      ),
    );
  }
}
