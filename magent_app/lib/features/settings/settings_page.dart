import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:magent_app/core/providers/api_provider.dart';
import 'package:magent_app/core/providers/app_settings_provider.dart';
import 'package:magent_app/core/services/app_settings_service.dart';
import 'package:magent_app/core/storage/secure_storage.dart';
import 'package:magent_app/core/theme/theme.dart';
import 'package:magent_app/l10n/app_localizations.dart';
import 'package:magent_app/shared/widgets/app_list_tile.dart';
import 'package:magent_app/shared/widgets/app_loading.dart';
import 'package:magent_app/shared/widgets/app_section.dart';
import 'package:magent_app/shared/widgets/app_sheet_header.dart';

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
          ? const AppLoading()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              cacheExtent: 640,
              children: [
                AppSection(
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
                AppSection(
                  title: l10n.settingsDefaultCli,
                  icon: Icons.tune,
                  children: [_buildDefaultProviderTile(l10n)],
                ),
                AppSection(
                  title: l10n.settingsSession,
                  icon: Icons.chat_bubble_outline,
                  children: [
                    _buildSessionOpenAtBottomTile(l10n),
                    _buildSessionTurnPageSizeTile(l10n),
                    _buildShowAiCommitSessionsTile(l10n),
                  ],
                ),
                AppSection(
                  title: l10n.settingsAppearance,
                  icon: Icons.palette_outlined,
                  children: [
                    _buildThemeModeTile(l10n),
                    _buildViewerFontScaleTile(l10n),
                  ],
                ),
                AppSection(
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
                AppSection(
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
                AppSection(
                  title: l10n.settingsAbout,
                  icon: Icons.info_outline,
                  children: [
                    AppListTile(
                      leadingIcon: Icons.tag,
                      title: Text(l10n.settingsVersion),
                      subtitle: const Text('1.0.0-dev'),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildSessionOpenAtBottomTile(AppLocalizations l10n) {
    return AppListTile(
      leadingIcon: Icons.vertical_align_bottom,
      title: Text(l10n.settingsSessionOpenAtBottom),
      subtitle: Text(l10n.settingsSessionOpenAtBottomSub),
      onTap: _toggleSessionOpenAtBottom,
      trailing: Switch(
        value: _sessionOpenAtBottom,
        onChanged: _setSessionOpenAtBottom,
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

  Widget _buildSessionTurnPageSizeTile(AppLocalizations l10n) {
    final pageSize = ref
        .watch(sessionTurnPageSizeControllerProvider)
        .maybeWhen(
          data: (v) => v,
          orElse: () => AppSettingsService.sessionTurnPageSizeDefault,
        );
    return AppListTile(
      leadingIcon: Icons.format_list_numbered,
      title: Text(l10n.settingsSessionTurnPageSize),
      subtitle: Text(
        '${l10n.settingsSessionTurnPageSizeSub}\n'
        '${l10n.settingsSessionTurnPageSizeValue(pageSize)}',
      ),
      onTap: () => _showSessionTurnPageSizePicker(l10n),
      showChevron: true,
    );
  }

  void _showSessionTurnPageSizePicker(AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
            child: Consumer(
              builder: (context, ref, _) {
                final pageSize = ref
                    .watch(sessionTurnPageSizeControllerProvider)
                    .maybeWhen(
                      data: (v) => v,
                      orElse: () =>
                          AppSettingsService.sessionTurnPageSizeDefault,
                    );
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppSheetHeader(
                      title: l10n.settingsSessionTurnPageSize,
                      subtitle: l10n.settingsSessionTurnPageSizeSub,
                      icon: Icons.format_list_numbered,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                      child: _SessionTurnPageSizePreview(pageSize: pageSize),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Text(
                            AppSettingsService.sessionTurnPageSizeMin
                                .toString(),
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Expanded(
                            child: Slider(
                              min: AppSettingsService.sessionTurnPageSizeMin
                                  .toDouble(),
                              max: AppSettingsService.sessionTurnPageSizeMax
                                  .toDouble(),
                              divisions:
                                  AppSettingsService.sessionTurnPageSizeMax -
                                  AppSettingsService.sessionTurnPageSizeMin,
                              value: pageSize.toDouble(),
                              label: pageSize.toString(),
                              onChanged: (v) => ref
                                  .read(
                                    sessionTurnPageSizeControllerProvider
                                        .notifier,
                                  )
                                  .setPageSize(v.round()),
                            ),
                          ),
                          Text(
                            AppSettingsService.sessionTurnPageSizeMax
                                .toString(),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          _SessionTurnPageSizePresetButton(
                            label: '1',
                            value: 1,
                            current: pageSize,
                          ),
                          const SizedBox(width: 8),
                          _SessionTurnPageSizePresetButton(
                            label: '5',
                            value: 5,
                            current: pageSize,
                          ),
                          const SizedBox(width: 8),
                          _SessionTurnPageSizePresetButton(
                            label: '20',
                            value: 20,
                            current: pageSize,
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed:
                                pageSize ==
                                    AppSettingsService
                                        .sessionTurnPageSizeDefault
                                ? null
                                : () => ref
                                      .read(
                                        sessionTurnPageSizeControllerProvider
                                            .notifier,
                                      )
                                      .setPageSize(
                                        AppSettingsService
                                            .sessionTurnPageSizeDefault,
                                      ),
                            child: Text(l10n.viewerFontSizeReset),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildShowAiCommitSessionsTile(AppLocalizations l10n) {
    return AppListTile(
      leadingIcon: Icons.auto_fix_high,
      title: Text(l10n.settingsShowAiCommitSessions),
      subtitle: Text(l10n.settingsShowAiCommitSessionsSub),
      onTap: _toggleShowAiCommitSessions,
      trailing: Switch(
        value: _showAiCommitSessions,
        onChanged: _setShowAiCommitSessions,
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
    return AppListTile(
      leadingIcon: Icons.dark_mode_outlined,
      title: Text(l10n.settingsThemeMode),
      subtitle: Text(_themeModeLabel(l10n, _themeMode)),
      onTap: () => _showThemeModePicker(l10n),
      showChevron: true,
    );
  }

  void _showThemeModePicker(AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppSheetHeader(
                title: l10n.settingsThemeMode,
                icon: Icons.dark_mode_outlined,
              ),
              ...AppThemeModeSetting.values.map((mode) {
                final selected = _themeMode == mode;
                return ListTile(
                  title: Text(_themeModeLabel(l10n, mode)),
                  leading: Icon(
                    selected ? Icons.check_circle : Icons.circle_outlined,
                    color: selected ? scheme.primary : scheme.onSurfaceVariant,
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
              }),
            ],
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

  Widget _buildViewerFontScaleTile(AppLocalizations l10n) {
    final scale = ref
        .watch(viewerFontScaleControllerProvider)
        .maybeWhen(data: (v) => v, orElse: () => 1.0);
    return AppListTile(
      leadingIcon: Icons.format_size,
      title: Text(l10n.settingsViewerFontSize),
      subtitle: Text(
        '${l10n.settingsViewerFontSizeSub}\n'
        '${(12 * scale).toStringAsFixed(0)}pt · ×${scale.toStringAsFixed(2)}',
      ),
      onTap: () => _showViewerFontScalePicker(l10n),
      showChevron: true,
    );
  }

  void _showViewerFontScalePicker(AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
            child: Consumer(
              builder: (context, ref, _) {
                final scale = ref
                    .watch(viewerFontScaleControllerProvider)
                    .maybeWhen(data: (v) => v, orElse: () => 1.0);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppSheetHeader(
                      title: l10n.settingsViewerFontSize,
                      subtitle: l10n.settingsViewerFontSizeSub,
                      icon: Icons.format_size,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                      child: _ViewerFontPreview(scale: scale),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Text(
                            'A',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Expanded(
                            child: Slider(
                              min: AppSettingsService.viewerFontScaleMin,
                              max: AppSettingsService.viewerFontScaleMax,
                              divisions: 15,
                              value: scale,
                              label: '×${scale.toStringAsFixed(2)}',
                              onChanged: (v) => ref
                                  .read(
                                    viewerFontScaleControllerProvider.notifier,
                                  )
                                  .setScale(v),
                            ),
                          ),
                          const Text('A', style: TextStyle(fontSize: 22)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          _ViewerFontPresetButton(
                            label: l10n.viewerFontSizeSmall,
                            value: 0.9,
                            current: scale,
                          ),
                          const SizedBox(width: 8),
                          _ViewerFontPresetButton(
                            label: l10n.viewerFontSizeMedium,
                            value: 1.0,
                            current: scale,
                          ),
                          const SizedBox(width: 8),
                          _ViewerFontPresetButton(
                            label: l10n.viewerFontSizeLarge,
                            value: 1.2,
                            current: scale,
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: scale == 1.0
                                ? null
                                : () => ref
                                      .read(
                                        viewerFontScaleControllerProvider
                                            .notifier,
                                      )
                                      .setScale(1.0),
                            child: Text(l10n.viewerFontSizeReset),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildAiCommitSettingsTile(AppLocalizations l10n) {
    return AppListTile(
      leadingIcon: Icons.auto_awesome,
      title: Text(l10n.settingsAiCommitModel),
      subtitle: Text(_aiCommitSettingsSummary(l10n)),
      onTap: () => _showAiCommitSettingsSheet(l10n),
      showChevron: true,
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
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppSheetHeader(
                    title: l10n.settingsAiCommitModel,
                    subtitle: l10n.settingsAiCommitModelSub,
                    icon: Icons.auto_awesome,
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      children: [
                        for (final provider in available)
                          _AiCommitProviderSettings(
                            provider: Map<String, dynamic>.from(
                              provider as Map,
                            ),
                            selectedModel:
                                _aiCommitModels[provider['name']?.toString() ??
                                    ''] ??
                                '',
                            selectedEffort:
                                _aiCommitEfforts[provider['name']?.toString() ??
                                    ''] ??
                                '',
                            onChanged: _setAiCommitProviderSettings,
                            effortLabel: (effort) => _effortLabel(effort, l10n),
                          ),
                      ],
                    ),
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
    final scheme = Theme.of(context).colorScheme;

    return AppListTile(
      leadingIcon: Icons.smart_toy,
      title: Text(l10n.settingsDefaultCli),
      subtitle: Text(
        _defaultProvider ?? l10n.sessionsModelDefault,
        style: TextStyle(
          color: _defaultProvider != null ? null : scheme.onSurfaceVariant,
        ),
      ),
      onTap: () => _showDefaultProviderPicker(l10n, available),
      showChevron: true,
    );
  }

  void _showDefaultProviderPicker(
    AppLocalizations l10n,
    List<dynamic> available,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        final statusColors = AppStatusColors.of(context);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppSheetHeader(
                title: l10n.settingsDefaultCli,
                icon: Icons.smart_toy,
              ),
              ListTile(
                title: Text(l10n.sessionsModelDefault),
                leading: Icon(
                  _defaultProvider == null
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                  color: _defaultProvider == null
                      ? statusColors.running.foreground
                      : scheme.onSurfaceVariant,
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
                    color: selected
                        ? statusColors.running.foreground
                        : scheme.onSurfaceVariant,
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

  Widget _buildNavTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return AppListTile(
      leadingIcon: icon,
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: onTap,
      showChevron: true,
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
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
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
              decoration: InputDecoration(labelText: l10n.sessionsModel),
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
                decoration: InputDecoration(labelText: l10n.sessionsEffort),
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

class _ViewerFontPreview extends StatelessWidget {
  final double scale;
  const _ViewerFontPreview({required this.scale});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Text(
        '''def hello(name):
    print(f"Hello, {name}!")

hello("Magent")''',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12 * scale,
          height: 1.45,
          color: scheme.onSurface,
        ),
      ),
    );
  }
}

class _SessionTurnPageSizePreview extends StatelessWidget {
  final int pageSize;

  const _SessionTurnPageSizePreview({required this.pageSize});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.format_list_numbered, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              AppLocalizations.of(
                context,
              )!.settingsSessionTurnPageSizeValue(pageSize),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionTurnPageSizePresetButton extends StatelessWidget {
  final String label;
  final int value;
  final int current;

  const _SessionTurnPageSizePresetButton({
    required this.label,
    required this.value,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    final selected = current == value;
    return Consumer(
      builder: (context, ref, _) {
        final style = selected
            ? FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
              )
            : OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
              );
        Future<void> onTap() => ref
            .read(sessionTurnPageSizeControllerProvider.notifier)
            .setPageSize(value);
        return selected
            ? FilledButton(onPressed: onTap, style: style, child: Text(label))
            : OutlinedButton(
                onPressed: onTap,
                style: style,
                child: Text(label),
              );
      },
    );
  }
}

class _ViewerFontPresetButton extends StatelessWidget {
  final String label;
  final double value;
  final double current;
  const _ViewerFontPresetButton({
    required this.label,
    required this.value,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    final selected = (current - value).abs() < 0.01;
    return Consumer(
      builder: (context, ref, _) {
        final style = selected
            ? FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
              )
            : OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
              );
        Future<void> onTap() => ref
            .read(viewerFontScaleControllerProvider.notifier)
            .setScale(value);
        return selected
            ? FilledButton(onPressed: onTap, style: style, child: Text(label))
            : OutlinedButton(
                onPressed: onTap,
                style: style,
                child: Text(label),
              );
      },
    );
  }
}
