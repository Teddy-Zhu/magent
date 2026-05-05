import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:magent_app/core/api/error_messages.dart';
import 'package:magent_app/core/providers/api_provider.dart';
import 'package:magent_app/core/repositories/bootstrap_repository.dart';
import 'package:magent_app/core/repositories/session_repository.dart';
import 'package:magent_app/core/storage/secure_storage.dart';
import 'package:magent_app/core/theme/theme.dart';
import 'package:magent_app/l10n/app_localizations.dart';

class SessionCreatePage extends ConsumerStatefulWidget {
  final String projectId;
  final String provider;

  const SessionCreatePage({
    super.key,
    required this.projectId,
    required this.provider,
  });

  @override
  ConsumerState<SessionCreatePage> createState() => _SessionCreatePageState();
}

class _SessionCreatePageState extends ConsumerState<SessionCreatePage> {
  String _selectedModel = '';
  String _selectedEffort = '';
  String _selectedApprovalPolicy = 'on-request';
  String _selectedSandboxMode = 'workspace-write';
  bool _creating = false;
  bool _showAdvanced = false;
  Map<String, dynamic> _providerConfig = {};
  bool _loadingConfig = true;
  String _configError = '';
  AppApiClient? _api;
  BootstrapRepository? _bootstrap;
  final _storage = AgentStorage();

  @override
  void initState() {
    super.initState();
    _init();
  }

  String _effectiveProvider = '';

  Future<void> _init() async {
    _api = await loadActiveApi(ref);
    if (_api == null) {
      if (mounted) {
        setState(() {
          _loadingConfig = false;
          _configError = AppLocalizations.of(context)!.noAgentConnected;
        });
      }
      return;
    }
    _bootstrap = createBootstrapRepository(ref, _api!);
    // Resolve provider: use passed-in value, or saved default, or first available
    String provider = widget.provider;
    if (provider.isEmpty) {
      provider = await _storage.getDefaultProvider() ?? '';
    }
    if (provider.isEmpty) {
      try {
        final providers = await _bootstrap!.getProviders();
        final available = providers
            .where((p) => p['status'] == 'available')
            .toList();
        if (available.isNotEmpty) {
          provider = available.first['name'] ?? '';
        }
      } catch (_) {}
    }
    _effectiveProvider = provider;
    if (provider.isEmpty) {
      if (mounted) {
        setState(() {
          _loadingConfig = false;
          _configError = AppLocalizations.of(context)!.sessionsNoProvider;
        });
      }
      return;
    }
    await _loadProviderConfig(provider);
  }

  Future<void> _loadProviderConfig(String name) async {
    if (_bootstrap == null) return;
    setState(() {
      _loadingConfig = true;
      _configError = '';
    });
    try {
      final provider = await _bootstrap!.getProvider(name);
      var config = Map<String, dynamic>.from(
        provider?['config'] as Map? ?? const {},
      );
      if (config.isEmpty) {
        final schema = Map<String, dynamic>.from(
          provider?['config_schema'] as Map? ?? const {},
        );
        config = _configFromSchema(schema);
      }

      final savedModel = await _storage.getDefaultModel(name);
      final savedEffort = await _storage.getDefaultEffort(name);

      final models = (config['models'] ?? []) as List<dynamic>;

      String model = '';
      if (models.isNotEmpty) {
        if (savedModel != null && models.any((m) => m['id'] == savedModel)) {
          model = savedModel;
        } else {
          final defaultModel = models.firstWhere(
            (m) => m['default'] == true,
            orElse: () => models.first,
          );
          model = defaultModel['id'] ?? '';
        }
      }

      List<String> efforts = [];
      if (model.isNotEmpty) {
        final modelData = models.cast<Map<String, dynamic>?>().firstWhere(
          (m) => m?['id'] == model,
          orElse: () => null,
        );
        if (modelData != null) {
          efforts = ((modelData['reasoning_efforts'] ?? []) as List<dynamic>)
              .cast<String>()
              .where((e) => e.isNotEmpty)
              .toList();
        }
      }

      String effort = '';
      if (efforts.isNotEmpty) {
        if (savedEffort != null && efforts.contains(savedEffort)) {
          effort = savedEffort;
        } else {
          effort = efforts.first;
        }
      }

      String approvalPolicy = _selectedApprovalPolicy;
      String sandboxMode = _selectedSandboxMode;
      final policies = (config['approval_policies'] ?? []) as List<dynamic>;
      if (policies.isNotEmpty && !policies.contains(approvalPolicy)) {
        approvalPolicy = policies.first as String;
      }
      final sandboxes = (config['sandbox_modes'] ?? []) as List<dynamic>;
      if (sandboxes.isNotEmpty && !sandboxes.contains(sandboxMode)) {
        sandboxMode = sandboxes.first as String;
      }

      if (mounted) {
        setState(() {
          _providerConfig = config;
          _selectedModel = model;
          _selectedEffort = effort;
          _selectedApprovalPolicy = approvalPolicy;
          _selectedSandboxMode = sandboxMode;
          _loadingConfig = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingConfig = false;
          _configError = localizedErrorMessage(
            AppLocalizations.of(context)!,
            e,
            action: AppLocalizations.of(context)!.sessionsLoadConfigFailed,
          );
        });
      }
    }
  }

  bool get _supportsApproval =>
      (_providerConfig['approval_policies'] as List<dynamic>?)?.isNotEmpty ??
      false;
  bool get _supportsSandbox =>
      (_providerConfig['sandbox_modes'] as List<dynamic>?)?.isNotEmpty ?? false;
  bool get _supportsModelSwitch =>
      (_providerConfig['models'] as List<dynamic>?)?.isNotEmpty ?? false;

  List<dynamic> get _models =>
      (_providerConfig['models'] ?? []) as List<dynamic>;
  List<String> get _approvalPolicies =>
      ((_providerConfig['approval_policies'] ?? []) as List<dynamic>)
          .cast<String>();
  List<String> get _sandboxModes =>
      ((_providerConfig['sandbox_modes'] ?? []) as List<dynamic>)
          .cast<String>();

  List<String> get _reasoningEfforts {
    if (_selectedModel.isEmpty) return [];
    final model = _models.cast<Map<String, dynamic>?>().firstWhere(
      (m) => m?['id'] == _selectedModel,
      orElse: () => null,
    );
    if (model == null) return [];
    return ((model['reasoning_efforts'] ?? []) as List<dynamic>)
        .cast<String>()
        .where((e) => e.isNotEmpty)
        .toList();
  }

  bool get _supportsEffort => _reasoningEfforts.isNotEmpty;

  Future<void> _createSession() async {
    if (_api == null || _effectiveProvider.isEmpty) return;
    setState(() => _creating = true);

    if (_selectedModel.isNotEmpty) {
      await _storage.setDefaultModel(_effectiveProvider, _selectedModel);
    }
    if (_selectedEffort.isNotEmpty) {
      await _storage.setDefaultEffort(_effectiveProvider, _selectedEffort);
    }

    try {
      final data = <String, dynamic>{
        'provider_id': _effectiveProvider,
        'project_id': widget.projectId,
      };
      if (_selectedModel.isNotEmpty) data['model'] = _selectedModel;
      if (_selectedEffort.isNotEmpty) data['effort'] = _selectedEffort;
      if (_supportsApproval) data['approval_policy'] = _selectedApprovalPolicy;
      if (_supportsSandbox) data['sandbox_mode'] = _selectedSandboxMode;

      final session = await _api!.session.createSession(
        providerId: data['provider_id'] as String,
        projectId: data['project_id'] as String,
        model: data['model'] as String?,
        effort: data['effort'] as String?,
        approvalPolicy: data['approval_policy'] as String?,
        sandboxMode: data['sandbox_mode'] as String?,
      );
      final sessionId = session['id']?.toString() ?? '';
      if (sessionId.isEmpty) return;
      final repo = SessionRepository(
        agentId: _api!.agentId,
        api: _api!.session,
        db: ref.read(appDatabaseProvider),
      );
      await repo.upsertSession(session, projectId: widget.projectId);

      if (mounted) context.pushReplacement('/sessions/$sessionId');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizedErrorMessage(
                AppLocalizations.of(context)!,
                e,
                action: AppLocalizations.of(context)!.sessionsCreateFailed,
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Map<String, dynamic> _configFromSchema(Map<String, dynamic> schema) {
    final modelSchema = schema['model'] as Map?;
    final approvalSchema = schema['approval_policy'] as Map?;
    final sandboxSchema = schema['sandbox_mode'] as Map?;
    return {
      if (modelSchema != null)
        'models': [
          for (final value in (modelSchema['values'] as List? ?? const []))
            {
              'id': value.toString(),
              'name': value.toString(),
              'default': value == modelSchema['default'],
            },
          if ((modelSchema['values'] as List? ?? const []).isEmpty &&
              modelSchema['default'] != null)
            {
              'id': modelSchema['default'].toString(),
              'name': modelSchema['default'].toString(),
              'default': true,
            },
        ],
      if (approvalSchema != null)
        'approval_policies': [
          for (final value in (approvalSchema['values'] as List? ?? const []))
            value.toString(),
        ],
      if (sandboxSchema != null)
        'sandbox_modes': [
          for (final value in (sandboxSchema['values'] as List? ?? const []))
            value.toString(),
        ],
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final providerName = _effectiveProvider.isNotEmpty
        ? _effectiveProvider[0].toUpperCase() + _effectiveProvider.substring(1)
        : '';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.sessionsCreate),
            if (providerName.isNotEmpty)
              Text(
                providerName,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
      body: _loadingConfig
          ? Center(child: Text(l10n.loading))
          : _configError.isNotEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.warning_amber,
                      size: 48,
                      color: AppStatusColors.of(context).warning.foreground,
                    ),
                    const SizedBox(height: 16),
                    Text(_configError, textAlign: TextAlign.center),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Model & Effort
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_supportsModelSwitch) ...[
                            Text(
                              l10n.sessionsModel,
                              style: theme.textTheme.titleSmall,
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedModel.isEmpty
                                  ? null
                                  : _selectedModel,
                              items: [
                                DropdownMenuItem(
                                  value: '',
                                  child: Text(l10n.sessionsModelDefault),
                                ),
                                ..._models.map(
                                  (m) => DropdownMenuItem(
                                    value: m['id'] as String,
                                    child: Text(
                                      m['name'] as String? ?? m['id'] as String,
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (v) {
                                final newModel = v ?? '';
                                List<String> efforts = [];
                                if (newModel.isNotEmpty) {
                                  final modelData = _models
                                      .cast<Map<String, dynamic>?>()
                                      .firstWhere(
                                        (m) => m?['id'] == newModel,
                                        orElse: () => null,
                                      );
                                  if (modelData != null) {
                                    efforts =
                                        ((modelData['reasoning_efforts'] ?? [])
                                                as List<dynamic>)
                                            .cast<String>()
                                            .where((e) => e.isNotEmpty)
                                            .toList();
                                  }
                                }
                                setState(() {
                                  _selectedModel = newModel;
                                  _selectedEffort = efforts.isNotEmpty
                                      ? efforts.first
                                      : '';
                                });
                              },
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                          if (_supportsEffort) ...[
                            const SizedBox(height: 16),
                            Text(
                              l10n.sessionsEffort,
                              style: theme.textTheme.titleSmall,
                            ),
                            const SizedBox(height: 8),
                            Builder(
                              builder: (context) {
                                final efforts = _reasoningEfforts;
                                if (efforts.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                final validEffort =
                                    efforts.contains(_selectedEffort)
                                    ? _selectedEffort
                                    : efforts.first;
                                return InputDecorator(
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      isExpanded: true,
                                      value: validEffort,
                                      items: efforts
                                          .map(
                                            (e) => DropdownMenuItem(
                                              value: e,
                                              child: Text(
                                                _effortLabel(e, l10n),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (v) => setState(
                                        () => _selectedEffort = v ?? '',
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Advanced settings
                  Card(
                    child: ExpansionTile(
                      title: Text(
                        l10n.settingsDefaultCli,
                        style: theme.textTheme.titleSmall,
                      ),
                      initiallyExpanded: _showAdvanced,
                      onExpansionChanged: (v) =>
                          setState(() => _showAdvanced = v),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_supportsApproval) ...[
                                Text(
                                  l10n.sessionsApproval,
                                  style: theme.textTheme.bodySmall,
                                ),
                                const SizedBox(height: 8),
                                SegmentedButton<String>(
                                  segments: _approvalPolicies
                                      .map(
                                        (p) => ButtonSegment(
                                          value: p,
                                          label: Text(_policyLabel(p, l10n)),
                                        ),
                                      )
                                      .toList(),
                                  selected: {_selectedApprovalPolicy},
                                  onSelectionChanged: (v) => setState(
                                    () => _selectedApprovalPolicy = v.first,
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                              if (_supportsSandbox) ...[
                                Text(
                                  l10n.sessionsSandbox,
                                  style: theme.textTheme.bodySmall,
                                ),
                                const SizedBox(height: 8),
                                SegmentedButton<String>(
                                  segments: _sandboxModes
                                      .map(
                                        (m) => ButtonSegment(
                                          value: m,
                                          label: Text(_sandboxLabel(m, l10n)),
                                        ),
                                      )
                                      .toList(),
                                  selected: {_selectedSandboxMode},
                                  onSelectionChanged: (v) => setState(
                                    () => _selectedSandboxMode = v.first,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Create button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _creating ? null : _createSession,
                      icon: _creating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.play_arrow),
                      label: Text(l10n.sessionsCreateBtn),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  String _policyLabel(String policy, AppLocalizations l10n) {
    switch (policy) {
      case 'untrusted':
        return l10n.approvalStrict;
      case 'on-request':
        return l10n.approvalNormal;
      case 'never':
        return l10n.approvalAuto;
      default:
        return policy;
    }
  }

  String _sandboxLabel(String mode, AppLocalizations l10n) {
    switch (mode) {
      case 'read-only':
        return l10n.sandboxReadOnly;
      case 'workspace-write':
        return l10n.sandboxWorkspace;
      case 'danger-full-access':
        return l10n.sandboxFull;
      default:
        return mode;
    }
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
}
