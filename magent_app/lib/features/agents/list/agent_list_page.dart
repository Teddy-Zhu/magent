import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:magent_app/core/storage/secure_storage.dart';
import 'package:magent_app/core/theme/theme.dart';
import 'package:magent_app/l10n/app_localizations.dart';
import 'package:magent_app/shared/widgets/app_empty_state.dart';
import 'package:magent_app/shared/widgets/app_list_tile.dart';
import 'package:magent_app/shared/widgets/app_loading.dart';
import 'package:magent_app/shared/widgets/app_pill.dart';

class AgentListPage extends StatefulWidget {
  const AgentListPage({super.key});

  @override
  State<AgentListPage> createState() => _AgentListPageState();
}

class _AgentListPageState extends State<AgentListPage> {
  final _storage = AgentStorage();
  List<Map<String, String>> _agents = [];
  String? _activeAgentId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAgents();
  }

  Future<void> _loadAgents() async {
    final agents = await _storage.loadAgents();
    final activeId = await _storage.getActiveAgentId();
    if (mounted) {
      setState(() {
        _agents = agents;
        _activeAgentId = activeId;
        _loading = false;
      });
    }
  }

  Future<void> _selectAgent(String id) async {
    await _storage.setActiveAgent(id);
    if (mounted) {
      setState(() => _activeAgentId = id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.agentSelected)),
      );
    }
  }

  Future<void> _deleteAgent(String id, String name) async {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.agentsRemove),
        content: Text(l10n.agentsRemoveConfirm(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              l10n.agentsRemoveAction,
              style: TextStyle(color: scheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _storage.deleteAgent(id);
      await _loadAgents();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.agentRemoved(name)),
          ),
        );
      }
    }
  }

  void _goToProjects() {
    context.go('/projects');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.agentsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await context.push('/agents/connect');
              _loadAgents();
            },
          ),
        ],
      ),
      body: _loading
          ? const AppLoading()
          : _agents.isEmpty
          ? AppEmptyState(
              icon: Icons.dns_outlined,
              title: l10n.agentsEmpty,
              subtitle: l10n.agentsEmptySub,
              action: FilledButton.icon(
                onPressed: () async {
                  await context.push('/agents/connect');
                  _loadAgents();
                },
                icon: const Icon(Icons.add),
                label: Text(l10n.agentsAdd),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              cacheExtent: 640,
              itemCount: _agents.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final agent = _agents[index];
                final id = agent['id'] ?? '';
                final name = agent['name'] ?? 'Unknown';
                final url = agent['url'] ?? '';
                final isActive = id == _activeAgentId;

                return Dismissible(
                  key: Key(id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      borderRadius: AppRadius.rmd,
                    ),
                    child: Icon(Icons.delete, color: scheme.onErrorContainer),
                  ),
                  confirmDismiss: (_) async {
                    await _deleteAgent(id, name);
                    return false;
                  },
                  child: _AgentCard(
                    name: name,
                    url: url,
                    isActive: isActive,
                    onTap: isActive ? _goToProjects : () => _selectAgent(id),
                    onEdit: () async {
                      final edited = await context.push<bool>(
                        '/agents/edit/$id',
                      );
                      if (edited == true) _loadAgents();
                    },
                    onPrimary: isActive
                        ? _goToProjects
                        : () => _selectAgent(id),
                  ),
                );
              },
            ),
    );
  }
}

class _AgentCard extends StatelessWidget {
  final String name;
  final String url;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onPrimary;

  const _AgentCard({
    required this.name,
    required this.url,
    required this.isActive,
    required this.onTap,
    required this.onEdit,
    required this.onPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusColors = AppStatusColors.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Card(
      child: AppListTile(
        onTap: onTap,
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.6),
                borderRadius: AppRadius.rsm,
              ),
              child: Icon(
                Icons.computer,
                size: 22,
                color: scheme.onPrimaryContainer,
              ),
            ),
            if (isActive)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: statusColors.running.foreground,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          Theme.of(context).cardTheme.color ?? scheme.surface,
                      width: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 8),
              AppPill.status(
                label: l10n.agentsActive,
                palette: statusColors.running,
                maxWidth: 64,
              ),
            ],
          ],
        ),
        subtitle: Text(url, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: l10n.edit,
              onPressed: onEdit,
              visualDensity: VisualDensity.compact,
            ),
            IconButton.filledTonal(
              icon: Icon(
                isActive ? Icons.arrow_forward : Icons.check,
                size: 18,
              ),
              tooltip: isActive ? l10n.agentsEnter : l10n.agentsActive,
              onPressed: onPrimary,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}
