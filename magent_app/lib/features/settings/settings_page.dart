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
  final Map<String, String> _aiCommitModels = {};
  final Map<String, String> _aiCommitEfforts = {};
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
    final aiCommitModels = <String, String>{};
    final aiCommitEfforts = <String, String>{};
    for (final p in providers) {
      final name = p['name']?.toString() ?? '';
      if (name.isEmpty) continue;
      aiCommitModels[name] = await storage.getAiCommitModel(name) ?? '';
      aiCommitEfforts[name] = await storage.getAiCommitEffort(name) ?? '';
    }

    if (mounted) {
      setState(() {
        _defaultProvider = provider;
        _providers = providers;
        _aiCommitModels
          ..clear()
          ..addAll(aiCommitModels);
        _aiCommitEfforts
          ..clear()
          ..addAll(aiCommitEfforts);
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
                    _buildAiCommitSettingsTile(l10n),
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

  Widget _buildAiCommitSettingsTile(AppLocalizations l10n) {
    return _SettingsTile(
      icon: Icons.auto_awesome,
      title: Text(l10n.settingsAiCommitModel),
      subtitle: Text(_aiCommitSettingsSummary(l10n)),
      onTap: () => _showAiCommitSettingsSheet(l10n),
    );
  }

  String _aiCommitSettingsSummary(AppLocalizations l10n) {
    final available = _availableProviders;
    if (available.isEmpty) return l10n.sessionsNoProvider;
    final provider = _defaultProvider?.isNotEmpty == true
        ? _defaultProvider!
        : available.first['name']?.toString() ?? 'codex';
    final model = _aiCommitModels[provider] ?? '';
    final effort = _aiCommitEfforts[provider] ?? '';
    return [
      _providerLabel(provider),
      if (model.isNotEmpty) model else l10n.sessionsModelDefault,
      if (effort.isNotEmpty) _effortLabel(effort, l10n),
    ].join(' · ');
  }

  List<dynamic> get _availableProviders =>
      _providers.where((p) => p['status'] == 'available').toList();

  void _showAiCommitSettingsSheet(AppLocalizations l10n) {
    final available = _availableProviders;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        if (available.isEmpty) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l10n.sessionsNoProvider),
            ),
          );
        }
        return SafeArea(
          child: DraggableScrollableSheet(
            initialChildSize: 0.62,
            minChildSize: 0.36,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) {
              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    l10n.settingsAiCommitModel,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.settingsAiCommitModelSub,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final provider in available)
                    _AiCommitProviderSettings(
                      provider: Map<String, dynamic>.from(provider as Map),
                      selectedModel:
                          _aiCommitModels[provider['name']?.toString() ?? ''] ??
                          '',
                      selectedEffort:
                          _aiCommitEfforts[provider['name']?.toString() ??
                              ''] ??
                          '',
                      onChanged: _setAiCommitProviderSettings,
                      effortLabel: (effort) => _effortLabel(effort, l10n),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _setAiCommitProviderSettings(
    String provider,
    String model,
    String effort,
  ) async {
    final storage = AgentStorage();
    await storage.setAiCommitModel(provider, model);
    await storage.setAiCommitEffort(provider, effort);
    if (mounted) {
      setState(() {
        _aiCommitModels[provider] = model;
        _aiCommitEfforts[provider] = effort;
      });
    }
  }

  String _providerLabel(String name) {
    if (name.isEmpty) return '';
    return name[0].toUpperCase() + name.substring(1);
  }

  String _effortLabel(String effort, AppLocalizations l10n) {
    switch (effort) {
      case 'low':
        return l10n.effortLow;
      case 'medium':
        return l10n.effortMedium;
      case 'high':
        return l10n.effortHigh;
      default:
        return effort;
    }
  }

  Widget _buildDefaultProviderTile(AppLocalizations l10n) {
    final available = _availableProviders;

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

class _AiCommitProviderSettings extends StatelessWidget {
  final Map<String, dynamic> provider;
  final String selectedModel;
  final String selectedEffort;
  final Future<void> Function(String provider, String model, String effort)
  onChanged;
  final String Function(String effort) effortLabel;

  const _AiCommitProviderSettings({
    required this.provider,
    required this.selectedModel,
    required this.selectedEffort,
    required this.onChanged,
    required this.effortLabel,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final name = provider['name']?.toString() ?? '';
    final config = Map<String, dynamic>.from(provider['config'] as Map? ?? {});
    final models = (config['models'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .where((m) => (m['id']?.toString() ?? '').isNotEmpty)
        .toList();
    final effectiveModel = _validModel(models, selectedModel);
    final efforts = _effortsForModel(models, effectiveModel);
    final effectiveEffort = efforts.contains(selectedEffort)
        ? selectedEffort
        : efforts.isNotEmpty
        ? efforts.first
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_providerIcon(name), size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  _providerLabel(name),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: effectiveModel,
              decoration: InputDecoration(
                labelText: l10n.sessionsModel,
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: '',
                  child: Text(l10n.sessionsModelDefault),
                ),
                ...models.map(
                  (m) => DropdownMenuItem(
                    value: m['id']?.toString() ?? '',
                    child: Text(
                      m['name']?.toString().isNotEmpty == true
                          ? m['name'].toString()
                          : m['id'].toString(),
                    ),
                  ),
                ),
              ],
              onChanged: (value) {
                final model = value ?? '';
                final nextEfforts = _effortsForModel(models, model);
                final effort = nextEfforts.contains(effectiveEffort)
                    ? effectiveEffort
                    : nextEfforts.isNotEmpty
                    ? nextEfforts.first
                    : '';
                onChanged(name, model, effort);
              },
            ),
            if (efforts.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: effectiveEffort,
                decoration: InputDecoration(
                  labelText: l10n.sessionsEffort,
                  border: const OutlineInputBorder(),
                ),
                items: efforts
                    .map(
                      (effort) => DropdownMenuItem(
                        value: effort,
                        child: Text(effortLabel(effort)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  onChanged(name, effectiveModel, value ?? '');
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _validModel(List<Map<String, dynamic>> models, String model) {
    if (model.isEmpty) return '';
    return models.any((m) => m['id']?.toString() == model) ? model : '';
  }

  List<String> _effortsForModel(List<Map<String, dynamic>> models, String id) {
    if (id.isEmpty) {
      final defaults = <String>{};
      for (final model in models) {
        for (final effort
            in (model['reasoning_efforts'] as List? ?? const [])) {
          if (effort.toString().isNotEmpty) defaults.add(effort.toString());
        }
      }
      return defaults.toList();
    }
    final model = models.cast<Map<String, dynamic>?>().firstWhere(
      (m) => m?['id']?.toString() == id,
      orElse: () => null,
    );
    if (model == null) return const [];
    return (model['reasoning_efforts'] as List? ?? const [])
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  IconData _providerIcon(String name) {
    switch (name) {
      case 'codex':
        return Icons.smart_toy;
      case 'claude':
        return Icons.psychology;
      case 'aider':
        return Icons.code;
      default:
        return Icons.extension;
    }
  }

  String _providerLabel(String name) {
    if (name.isEmpty) return '';
    return name[0].toUpperCase() + name.substring(1);
  }
}
