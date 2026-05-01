import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:magent_app/core/providers/api_provider.dart';
import 'package:magent_app/core/storage/secure_storage.dart';
import 'package:magent_app/l10n/app_localizations.dart';

class SessionCreatePage extends ConsumerStatefulWidget {
  final String projectId;

  const SessionCreatePage({super.key, required this.projectId});

  @override
  ConsumerState<SessionCreatePage> createState() => _SessionCreatePageState();
}

class _SessionCreatePageState extends ConsumerState<SessionCreatePage> {
  String _selectedProvider = '';
  String _selectedModel = '';
  String _selectedEffort = '';
  String _selectedApprovalPolicy = 'on-request';
  String _selectedSandboxMode = 'workspace-write';
  bool _creating = false;
  bool _showAdvanced = false;
  List<dynamic> _providers = [];
  Map<String, dynamic> _providerConfig = {};
  bool _loadingProviders = true;
  AppApiClient? _api;
  final _storage = AgentStorage();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _api = await loadActiveApi(ref);
    if (_api == null) {
      if (mounted) setState(() => _loadingProviders = false);
      return;
    }
    await _loadProviders();
  }

  List<dynamic> _sortProviders(List<dynamic> providers) {
    // Sort: codex first, then alphabetically
    final sorted = List<dynamic>.from(providers);
    sorted.sort((a, b) {
      final nameA = (a['name'] as String? ?? '').toLowerCase();
      final nameB = (b['name'] as String? ?? '').toLowerCase();
      if (nameA == 'codex') return -1;
      if (nameB == 'codex') return 1;
      return nameA.compareTo(nameB);
    });
    return sorted;
  }

  Future<void> _loadProviders() async {
    if (_api == null) return;
    try {
      final resp = await _api!.client.dio.get('/api/providers');
      final providers = (resp.data['data'] ?? []) as List<dynamic>;
      final available = providers.where((p) => p['status'] == 'available').toList();
      final sorted = _sortProviders(available);

      // Load last used provider
      final savedProvider = await _storage.getDefaultProvider();

      if (mounted) {
        setState(() {
          _providers = sorted;
          _loadingProviders = false;
          if (sorted.isNotEmpty) {
            if (savedProvider != null &&
                savedProvider.isNotEmpty &&
                sorted.any((p) => p['name'] == savedProvider)) {
              _selectedProvider = savedProvider;
            } else {
              _selectedProvider = sorted.first['name'] ?? '';
            }
          }
        });
        if (_selectedProvider.isNotEmpty) {
          _loadProviderConfig(_selectedProvider);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _loadingProviders = false);
    }
  }

  Future<void> _loadProviderConfig(String name) async {
    if (_api == null) return;
    try {
      final resp = await _api!.client.dio.get('/api/providers/$name/config');
      final config = resp.data['data'] as Map<String, dynamic>? ?? {};

      // Load saved defaults for this provider
      final savedModel = await _storage.getDefaultModel(name);
      final savedEffort = await _storage.getDefaultEffort(name);

      // Compute model, effort from config directly (not via getters that depend on state)
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

      // Get efforts for selected model
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
        });
      }
    } catch (_) {}
  }

  bool get _supportsApproval => (_providerConfig['approval_policies'] as List<dynamic>?)?.isNotEmpty ?? false;
  bool get _supportsSandbox => (_providerConfig['sandbox_modes'] as List<dynamic>?)?.isNotEmpty ?? false;
  bool get _supportsModelSwitch => (_providerConfig['models'] as List<dynamic>?)?.isNotEmpty ?? false;

  List<dynamic> get _models => (_providerConfig['models'] ?? []) as List<dynamic>;
  List<String> get _approvalPolicies =>
      ((_providerConfig['approval_policies'] ?? []) as List<dynamic>).cast<String>();
  List<String> get _sandboxModes =>
      ((_providerConfig['sandbox_modes'] ?? []) as List<dynamic>).cast<String>();

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
    if (_api == null || _selectedProvider.isEmpty) return;
    setState(() => _creating = true);

    // Save user choices as defaults
    await _storage.setDefaultProvider(_selectedProvider);
    if (_selectedModel.isNotEmpty) {
      await _storage.setDefaultModel(_selectedProvider, _selectedModel);
    }
    if (_selectedEffort.isNotEmpty) {
      await _storage.setDefaultEffort(_selectedProvider, _selectedEffort);
    }

    try {
      final data = <String, dynamic>{
        'provider': _selectedProvider,
        'project_id': widget.projectId,
      };
      if (_selectedModel.isNotEmpty) data['model'] = _selectedModel;
      if (_selectedEffort.isNotEmpty) data['effort'] = _selectedEffort;
      if (_supportsApproval) data['approval_policy'] = _selectedApprovalPolicy;
      if (_supportsSandbox) data['sandbox_mode'] = _selectedSandboxMode;

      final resp = await _api!.client.dio.post('/api/sessions', data: data);
      final sessionId = resp.data['data']['id'];

      if (mounted) context.push('/sessions/$sessionId');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.sessionsCreateFailed}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.sessionsCreate)),
      body: _loadingProviders
          ? Center(child: Text(l10n.loading))
          : _providers.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.warning_amber, size: 48, color: Colors.orange),
                        const SizedBox(height: 16),
                        Text(l10n.sessionsNoProvider, textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Provider & Model
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.sessionsProvider, style: theme.textTheme.titleSmall),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: _providers.map((p) {
                                  final name = p['name'] as String? ?? '';
                                  final icon = _providerIcon(name);
                                  return ChoiceChip(
                                    avatar: Icon(icon, size: 16),
                                    label: Text(name[0].toUpperCase() + name.substring(1)),
                                    selected: _selectedProvider == name,
                                    onSelected: (v) {
                                      setState(() {
                                        _selectedProvider = name;
                                        _selectedModel = '';
                                        _selectedEffort = '';
                                        _providerConfig = {};
                                      });
                                      _loadProviderConfig(name);
                                    },
                                  );
                                }).toList(),
                              ),
                              if (_supportsModelSwitch) ...[
                                const SizedBox(height: 16),
                                Text(l10n.sessionsModel, style: theme.textTheme.titleSmall),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedModel.isEmpty ? null : _selectedModel,
                                  items: [
                                    DropdownMenuItem(value: '', child: Text(l10n.sessionsModelDefault)),
                                    ..._models.map((m) => DropdownMenuItem(
                                      value: m['id'] as String,
                                      child: Text(m['name'] as String? ?? m['id'] as String),
                                    )),
                                  ],
                                  onChanged: (v) {
                                    final newModel = v ?? '';
                                    // Compute efforts for new model
                                    List<String> efforts = [];
                                    if (newModel.isNotEmpty) {
                                      final modelData = _models.cast<Map<String, dynamic>?>().firstWhere(
                                        (m) => m?['id'] == newModel,
                                        orElse: () => null,
                                      );
                                      if (modelData != null) {
                                        efforts = ((modelData['reasoning_efforts'] ?? []) as List<dynamic>)
                                            .cast<String>()
                                            .where((e) => e.isNotEmpty)
                                            .toList();
                                      }
                                    }
                                    setState(() {
                                      _selectedModel = newModel;
                                      _selectedEffort = efforts.isNotEmpty ? efforts.first : '';
                                    });
                                  },
                                  decoration: const InputDecoration(border: OutlineInputBorder()),
                                ),
                              ],
                              if (_supportsEffort) ...[
                                const SizedBox(height: 16),
                                Text(l10n.sessionsEffort, style: theme.textTheme.titleSmall),
                                const SizedBox(height: 8),
                                Builder(
                                  builder: (context) {
                                    final efforts = _reasoningEfforts;
                                    if (efforts.isEmpty) return const SizedBox.shrink();
                                    final validEffort = efforts.contains(_selectedEffort)
                                        ? _selectedEffort
                                        : efforts.first;
                                    return InputDecorator(
                                      decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4)),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          isExpanded: true,
                                          value: validEffort,
                                          items: efforts.map((e) =>
                                            DropdownMenuItem(value: e, child: Text(_effortLabel(e, l10n))),
                                          ).toList(),
                                          onChanged: (v) => setState(() => _selectedEffort = v ?? ''),
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
                          title: Text(l10n.settingsDefaultCli, style: theme.textTheme.titleSmall),
                          initiallyExpanded: _showAdvanced,
                          onExpansionChanged: (v) => setState(() => _showAdvanced = v),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_supportsApproval) ...[
                                    Text(l10n.sessionsApproval, style: theme.textTheme.bodySmall),
                                    const SizedBox(height: 8),
                                    SegmentedButton<String>(
                                      segments: _approvalPolicies.map((p) =>
                                        ButtonSegment(value: p, label: Text(_policyLabel(p, l10n))),
                                      ).toList(),
                                      selected: {_selectedApprovalPolicy},
                                      onSelectionChanged: (v) => setState(() => _selectedApprovalPolicy = v.first),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                  if (_supportsSandbox) ...[
                                    Text(l10n.sessionsSandbox, style: theme.textTheme.bodySmall),
                                    const SizedBox(height: 8),
                                    SegmentedButton<String>(
                                      segments: _sandboxModes.map((m) =>
                                        ButtonSegment(value: m, label: Text(_sandboxLabel(m, l10n))),
                                      ).toList(),
                                      selected: {_selectedSandboxMode},
                                      onSelectionChanged: (v) => setState(() => _selectedSandboxMode = v.first),
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
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.play_arrow),
                          label: Text(l10n.sessionsCreateBtn),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  IconData _providerIcon(String name) {
    switch (name) {
      case 'codex': return Icons.smart_toy;
      case 'claude': return Icons.psychology;
      case 'aider': return Icons.code;
      default: return Icons.extension;
    }
  }

  String _policyLabel(String policy, AppLocalizations l10n) {
    switch (policy) {
      case 'untrusted': return l10n.approvalStrict;
      case 'on-request': return l10n.approvalNormal;
      case 'never': return l10n.approvalAuto;
      default: return policy;
    }
  }

  String _sandboxLabel(String mode, AppLocalizations l10n) {
    switch (mode) {
      case 'read-only': return l10n.sandboxReadOnly;
      case 'workspace-write': return l10n.sandboxWorkspace;
      case 'danger-full-access': return l10n.sandboxFull;
      default: return mode;
    }
  }

  String _effortLabel(String effort, AppLocalizations l10n) {
    switch (effort) {
      case 'low': return l10n.effortLow;
      case 'medium': return l10n.effortMedium;
      case 'high': return l10n.effortHigh;
      default: return effort;
    }
  }
}
