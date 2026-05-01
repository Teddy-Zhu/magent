import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:magent_app/core/providers/api_provider.dart';
import 'package:magent_app/core/storage/secure_storage.dart';
import 'package:magent_app/l10n/app_localizations.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  String? _defaultProvider;
  List<dynamic> _providers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final storage = AgentStorage();
    final provider = await storage.getDefaultProvider();

    final api = await loadActiveApi(ref);
    List<dynamic> providers = [];
    if (api != null) {
      try {
        final resp = await api.client.dio.get('/api/providers');
        providers = (resp.data['data'] ?? []) as List<dynamic>;
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _defaultProvider = provider;
        _providers = providers;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _buildSection(
                  context,
                  title: l10n.settingsAgent,
                  icon: Icons.dns,
                  children: [
                    _buildNavTile(
                      icon: Icons.link,
                      title: l10n.settingsManageAgents,
                      subtitle: l10n.settingsManageAgentsSub,
                      onTap: () => context.go('/agents'),
                    ),
                    _buildNavTile(
                      icon: Icons.extension,
                      title: l10n.settingsProviders,
                      subtitle: l10n.settingsProvidersSub,
                      onTap: () => context.push('/settings/providers'),
                    ),
                  ],
                ),
                _buildSection(
                  context,
                  title: l10n.settingsDefaultCli,
                  icon: Icons.tune,
                  children: [
                    _buildDefaultProviderTile(l10n),
                  ],
                ),
                _buildSection(
                  context,
                  title: l10n.settingsGit,
                  icon: Icons.alt_route,
                  children: [
                    _buildNavTile(
                      icon: Icons.compare_arrows,
                      title: l10n.settingsGitManage,
                      subtitle: l10n.settingsGitManageSub,
                      onTap: () => context.push('/projects'),
                    ),
                  ],
                ),
                _buildSection(
                  context,
                  title: l10n.settingsCache,
                  icon: Icons.storage,
                  children: [
                    _buildNavTile(
                      icon: Icons.cleaning_services,
                      title: l10n.settingsCacheManage,
                      subtitle: l10n.settingsCacheManageSub,
                      onTap: () => context.push('/settings/cache'),
                    ),
                  ],
                ),
                _buildSection(
                  context,
                  title: l10n.settingsAbout,
                  icon: Icons.info_outline,
                  children: [
                    ListTile(
                      title: Text(l10n.settingsVersion),
                      subtitle: const Text('1.0.0-dev'),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildDefaultProviderTile(AppLocalizations l10n) {
    final available = _providers.where((p) => p['status'] == 'available').toList();

    return ListTile(
      leading: const Icon(Icons.smart_toy),
      title: Text(l10n.settingsDefaultCli),
      subtitle: Text(
        _defaultProvider ?? l10n.sessionsModelDefault,
        style: TextStyle(color: _defaultProvider != null ? null : Colors.grey),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showDefaultProviderPicker(l10n, available),
    );
  }

  void _showDefaultProviderPicker(AppLocalizations l10n, List<dynamic> available) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(l10n.sessionsModelDefault),
                leading: Icon(
                  _defaultProvider == null ? Icons.check_circle : Icons.circle_outlined,
                  color: _defaultProvider == null ? Colors.green : Colors.grey,
                ),
                onTap: () async {
                  final storage = AgentStorage();
                  final nav = Navigator.of(context);
                  await storage.setDefaultProvider('');
                  if (mounted) {
                    setState(() => _defaultProvider = null);
                    nav.pop();
                  }
                },
              ),
              ...available.map((p) {
                final name = p['name'] as String? ?? '';
                final selected = _defaultProvider == name;
                return ListTile(
                  title: Text(name[0].toUpperCase() + name.substring(1)),
                  leading: Icon(
                    selected ? Icons.check_circle : Icons.circle_outlined,
                    color: selected ? Colors.green : Colors.grey,
                  ),
                  onTap: () async {
                    final storage = AgentStorage();
                    final nav = Navigator.of(context);
                    await storage.setDefaultProvider(name);
                    if (mounted) {
                      setState(() => _defaultProvider = name);
                      nav.pop();
                    }
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Row(
            children: [
              Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        ...children,
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildNavTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
