import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:magent_app/core/providers/api_provider.dart';
import 'package:magent_app/core/providers/app_settings_provider.dart';
import 'package:magent_app/core/services/app_settings_service.dart';
import 'package:magent_app/core/storage/secure_storage.dart';
import 'package:magent_app/l10n/app_localizations.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _settings = AppSettingsService();
  String? _defaultProvider;
  List<dynamic> _providers = [];
  bool _sessionOpenAtBottom = true;
  bool _showAiCommitSessions = false;
  AppThemeModeSetting _themeMode = AppThemeModeSetting.system;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final storage = AgentStorage();
    final provider = await storage.getDefaultProvider();
    final sessionOpenAtBottom = await _settings.getSessionOpenAtBottom();
    final showAiCommitSessions = await _settings.getShowAiCommitSessions();
    final themeMode = await _settings.getThemeMode();

    final api = await loadActiveApi(ref);
    List<dynamic> providers = [];
    if (api != null) {
      try {
        final bootstrap = createBootstrapRepository(ref, api);
        providers = await bootstrap.getProviders();
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _defaultProvider = provider;
        _providers = providers;
        _sessionOpenAtBottom = sessionOpenAtBottom;
        _showAiCommitSessions = showAiCommitSessions;
        _themeMode = themeMode;
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              cacheExtent: 640,
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
                  children: [_buildDefaultProviderTile(l10n)],
                ),
                _buildSection(
                  context,
                  title: l10n.settingsSession,
                  icon: Icons.chat_bubble_outline,
                  children: [
                    _buildSessionOpenAtBottomTile(l10n),
                    _buildShowAiCommitSessionsTile(l10n),
                  ],
                ),
                _buildSection(
                  context,
                  title: l10n.settingsAppearance,
                  icon: Icons.palette_outlined,
                  children: [_buildThemeModeTile(l10n)],
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
                      onTap: () => context.go('/projects'),
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
                    _SettingsTile(
                      icon: Icons.tag,
                      title: Text(l10n.settingsVersion),
                      subtitle: const Text('1.0.0-dev'),
                      onTap: null,
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildSessionOpenAtBottomTile(AppLocalizations l10n) {
    return _SettingsTile(
      icon: Icons.vertical_align_bottom,
      title: Text(l10n.settingsSessionOpenAtBottom),
      subtitle: Text(l10n.settingsSessionOpenAtBottomSub),
      onTap: _toggleSessionOpenAtBottom,
      trailing: Switch(
        value: _sessionOpenAtBottom,
        onChanged: (value) => _setSessionOpenAtBottom(value),
      ),
    );
  }

  Future<void> _toggleSessionOpenAtBottom() {
    return _setSessionOpenAtBottom(!_sessionOpenAtBottom);
  }

  Future<void> _setSessionOpenAtBottom(bool value) async {
    await _settings.setSessionOpenAtBottom(value);
    if (mounted) {
      setState(() => _sessionOpenAtBottom = value);
    }
  }

  Widget _buildShowAiCommitSessionsTile(AppLocalizations l10n) {
    return _SettingsTile(
      icon: Icons.auto_fix_high,
      title: Text(l10n.settingsShowAiCommitSessions),
      subtitle: Text(l10n.settingsShowAiCommitSessionsSub),
      onTap: _toggleShowAiCommitSessions,
      trailing: Switch(
        value: _showAiCommitSessions,
        onChanged: (value) => _setShowAiCommitSessions(value),
      ),
    );
  }

  Future<void> _toggleShowAiCommitSessions() {
    return _setShowAiCommitSessions(!_showAiCommitSessions);
  }

  Future<void> _setShowAiCommitSessions(bool value) async {
    await ref
        .read(showAiCommitSessionsControllerProvider.notifier)
        .setVisible(value);
    if (mounted) {
      setState(() => _showAiCommitSessions = value);
    }
  }

  Widget _buildThemeModeTile(AppLocalizations l10n) {
    return _SettingsTile(
      icon: Icons.dark_mode_outlined,
      title: Text(l10n.settingsThemeMode),
      subtitle: Text(_themeModeLabel(l10n, _themeMode)),
      onTap: () => _showThemeModePicker(l10n),
    );
  }

  void _showThemeModePicker(AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: AppThemeModeSetting.values.map((mode) {
              final selected = _themeMode == mode;
              return ListTile(
                title: Text(_themeModeLabel(l10n, mode)),
                leading: Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                onTap: () async {
                  final nav = Navigator.of(context);
                  await ref
                      .read(themeModeControllerProvider.notifier)
                      .setMode(mode);
                  if (mounted) {
                    setState(() => _themeMode = mode);
                    nav.pop();
                  }
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  String _themeModeLabel(AppLocalizations l10n, AppThemeModeSetting mode) {
    switch (mode) {
      case AppThemeModeSetting.light:
        return l10n.themeLight;
      case AppThemeModeSetting.dark:
        return l10n.themeDark;
      case AppThemeModeSetting.system:
        return l10n.themeSystem;
    }
  }

  Widget _buildDefaultProviderTile(AppLocalizations l10n) {
    final available = _providers
        .where((p) => p['status'] == 'available')
        .toList();

    return _SettingsTile(
      icon: Icons.smart_toy,
      title: Text(l10n.settingsDefaultCli),
      subtitle: Text(
        _defaultProvider ?? l10n.sessionsModelDefault,
        style: TextStyle(color: _defaultProvider != null ? null : Colors.grey),
      ),
      onTap: () => _showDefaultProviderPicker(l10n, available),
    );
  }

  void _showDefaultProviderPicker(
    AppLocalizations l10n,
    List<dynamic> available,
  ) {
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
                  _defaultProvider == null
                      ? Icons.check_circle
                      : Icons.circle_outlined,
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
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
          child: Row(
            children: [
              Icon(icon, size: 16, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
        ),
        Card(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1)
                  Divider(
                    height: 1,
                    indent: 58,
                    color: scheme.outlineVariant.withValues(alpha: 0.55),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNavTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return _SettingsTile(
      icon: icon,
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Widget title;
  final Widget subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  DefaultTextStyle.merge(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    child: title,
                  ),
                  const SizedBox(height: 3),
                  DefaultTextStyle.merge(
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    child: subtitle,
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ] else if (onTap != null) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
