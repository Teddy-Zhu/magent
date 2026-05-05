import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magent_app/core/providers/api_provider.dart';
import 'package:magent_app/core/theme/theme.dart';
import 'package:magent_app/l10n/app_localizations.dart';
import 'package:magent_app/shared/widgets/app_empty_state.dart';
import 'package:magent_app/shared/widgets/app_loading.dart';
import 'package:magent_app/shared/widgets/app_pill.dart';
import 'package:magent_app/shared/widgets/app_sheet_header.dart';

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
      final providers = await createBootstrapRepository(
        ref,
        api,
      ).getProviders();
      if (mounted) {
        setState(() {
          _providers = providers;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.providersTitle)),
      body: _loading
          ? const AppLoading()
          : _providers.isEmpty
          ? AppEmptyState(
              icon: Icons.extension_outlined,
              title: l10n.providersEmpty,
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              itemCount: _providers.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
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
    final scheme = Theme.of(context).colorScheme;
    final statusColors = AppStatusColors.of(context);
    final name = provider['name'] as String? ?? 'unknown';
    final status = provider['status'] as String? ?? 'unknown';
    final version = provider['version'] as String? ?? '';
    final runMode = provider['run_mode'] as String? ?? '';
    final available = status == 'available';
    final l10n = AppLocalizations.of(context)!;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.rmd,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: available
                      ? scheme.primaryContainer.withValues(alpha: 0.6)
                      : scheme.surfaceContainerHigh,
                  borderRadius: AppRadius.rsm,
                ),
                child: Icon(
                  _iconFor(name),
                  size: 20,
                  color: available
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name[0].toUpperCase() + name.substring(1),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (version.isNotEmpty) 'v$version',
                        if (runMode.isNotEmpty) runMode,
                        if (!available)
                          provider['error'] ?? l10n.providersNotAvailable,
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AppPill.status(
                label: available
                    ? l10n.providersAvailable
                    : l10n.providersUnavailable,
                palette: available
                    ? statusColors.running
                    : statusColors.neutral,
                maxWidth: 84,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String name) {
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
}

class _ProviderDetailSheet extends StatelessWidget {
  final Map<String, dynamic> provider;

  const _ProviderDetailSheet({required this.provider});

  @override
  Widget build(BuildContext context) {
    final caps = provider['capabilities'] as Map<String, dynamic>? ?? {};
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final name = provider['name']?.toString() ?? l10n.providersUnknown;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppSheetHeader(
              title: name,
              icon: Icons.extension,
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  if (provider['binary'] != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${l10n.providersBinary}: ${provider['binary']}',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  if (provider['run_mode'] != null)
                    Text(
                      '${l10n.providersMode}: ${provider['run_mode']}',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  const Divider(height: 24),
                  Text(
                    l10n.providersCapabilities,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _buildCapTile(
                    context,
                    l10n.capabilityResume,
                    caps['supports_resume'] ?? false,
                  ),
                  _buildCapTile(context, l10n.capabilityFork,
                      caps['supports_fork'] ?? false),
                  _buildCapTile(
                    context,
                    l10n.capabilitySteer,
                    caps['supports_steer'] ?? false,
                  ),
                  _buildCapTile(
                    context,
                    l10n.capabilityInterrupt,
                    caps['supports_interrupt'] ?? false,
                  ),
                  _buildCapTile(
                    context,
                    l10n.capabilityCompact,
                    caps['supports_compact'] ?? false,
                  ),
                  _buildCapTile(
                    context,
                    l10n.capabilityRollback,
                    caps['supports_rollback'] ?? false,
                  ),
                  _buildCapTile(
                    context,
                    l10n.capabilityApproval,
                    caps['supports_approval'] ?? false,
                  ),
                  _buildCapTile(
                    context,
                    l10n.capabilityFileSystem,
                    caps['supports_file_system'] ?? false,
                  ),
                  _buildCapTile(context, l10n.capabilityMcp,
                      caps['supports_mcp'] ?? false),
                  _buildCapTile(context, l10n.capabilityPty,
                      caps['supports_pty'] ?? false),
                  _buildCapTile(
                    context,
                    l10n.capabilityStreaming,
                    caps['streaming_output'] ?? false,
                  ),
                  _buildCapTile(
                    context,
                    l10n.capabilityStructuredOutput,
                    caps['structured_output'] ?? false,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCapTile(BuildContext context, String label, bool supported) {
    final scheme = Theme.of(context).colorScheme;
    final statusColors = AppStatusColors.of(context);
    return ListTile(
      dense: true,
      leading: Icon(
        supported ? Icons.check_circle : Icons.cancel,
        color: supported
            ? statusColors.running.foreground
            : scheme.onSurfaceVariant.withValues(alpha: 0.6),
        size: 20,
      ),
      title: Text(label),
    );
  }
}
