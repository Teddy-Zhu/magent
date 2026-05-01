import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magent_app/core/providers/api_provider.dart';

class ProvidersPage extends ConsumerStatefulWidget {
  const ProvidersPage({super.key});

  @override
  ConsumerState<ProvidersPage> createState() => _ProvidersPageState();
}

class _ProvidersPageState extends ConsumerState<ProvidersPage> {
  List<dynamic> _providers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  Future<void> _loadProviders() async {
    final api = await loadActiveApi(ref);
    if (api == null || !mounted) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final resp = await api.client.dio.get('/api/providers');
      if (mounted) {
        setState(() {
          _providers = resp.data['data'] ?? [];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Providers')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _providers.isEmpty
              ? const Center(child: Text('No providers found'))
              : ListView.builder(
                  itemCount: _providers.length,
                  itemBuilder: (context, index) => _ProviderTile(
                    provider: _providers[index],
                    onTap: () => _showProviderDetail(_providers[index]),
                  ),
                ),
    );
  }

  void _showProviderDetail(Map<String, dynamic> provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ProviderDetailSheet(provider: provider),
    );
  }
}

class _ProviderTile extends StatelessWidget {
  final Map<String, dynamic> provider;
  final VoidCallback onTap;

  const _ProviderTile({required this.provider, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = provider['name'] as String? ?? 'unknown';
    final status = provider['status'] as String? ?? 'unknown';
    final version = provider['version'] as String? ?? '';
    final runMode = provider['run_mode'] as String? ?? '';
    final available = status == 'available';

    return ListTile(
      leading: _buildIcon(name, available),
      title: Text(name[0].toUpperCase() + name.substring(1)),
      subtitle: Text(
        [
          if (version.isNotEmpty) 'v$version',
          if (runMode.isNotEmpty) runMode,
          if (!available) provider['error'] ?? 'Not available',
        ].join(' · '),
        style: TextStyle(color: available ? null : Colors.grey),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: available ? Colors.green[50] : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          available ? 'Available' : 'Unavailable',
          style: TextStyle(
            fontSize: 12,
            color: available ? Colors.green[700] : Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _buildIcon(String name, bool available) {
    IconData icon;
    switch (name) {
      case 'codex':
        icon = Icons.smart_toy;
        break;
      case 'claude':
        icon = Icons.psychology;
        break;
      case 'aider':
        icon = Icons.code;
        break;
      default:
        icon = Icons.extension;
    }
    return Icon(icon, color: available ? Colors.blue : Colors.grey);
  }
}

class _ProviderDetailSheet extends StatelessWidget {
  final Map<String, dynamic> provider;

  const _ProviderDetailSheet({required this.provider});

  @override
  Widget build(BuildContext context) {
    final caps = provider['capabilities'] as Map<String, dynamic>? ?? {};

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      expand: false,
      builder: (context, scrollController) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              provider['name'] ?? 'Unknown',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            if (provider['binary'] != null)
              Text('Binary: ${provider['binary']}',
                  style: TextStyle(color: Colors.grey[600])),
            if (provider['run_mode'] != null)
              Text('Mode: ${provider['run_mode']}',
                  style: TextStyle(color: Colors.grey[600])),
            const Divider(height: 24),
            Text('Capabilities', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _buildCapTile('Resume', caps['supports_resume'] ?? false),
            _buildCapTile('Fork', caps['supports_fork'] ?? false),
            _buildCapTile('Steer', caps['supports_steer'] ?? false),
            _buildCapTile('Interrupt', caps['supports_interrupt'] ?? false),
            _buildCapTile('Compact', caps['supports_compact'] ?? false),
            _buildCapTile('Rollback', caps['supports_rollback'] ?? false),
            _buildCapTile('Approval', caps['supports_approval'] ?? false),
            _buildCapTile('File System', caps['supports_file_system'] ?? false),
            _buildCapTile('MCP', caps['supports_mcp'] ?? false),
            _buildCapTile('PTY', caps['supports_pty'] ?? false),
            _buildCapTile('Streaming', caps['streaming_output'] ?? false),
            _buildCapTile('Structured Output', caps['structured_output'] ?? false),
          ],
        );
      },
    );
  }

  Widget _buildCapTile(String label, bool supported) {
    return ListTile(
      dense: true,
      leading: Icon(
        supported ? Icons.check_circle : Icons.cancel,
        color: supported ? Colors.green : Colors.grey[400],
        size: 20,
      ),
      title: Text(label),
    );
  }
}
