import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:magent_app/core/storage/secure_storage.dart';
import 'package:magent_app/l10n/app_localizations.dart';

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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.agentsRemove),
        content: Text(AppLocalizations.of(context)!.agentsRemoveConfirm(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              AppLocalizations.of(context)!.agentsRemoveAction,
              style: const TextStyle(color: Colors.red),
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
          ? const Center(child: CircularProgressIndicator())
          : _agents.isEmpty
          ? _AgentEmptyState(
              onAdd: () async {
                await context.push('/agents/connect');
                _loadAgents();
              },
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
                      color: Theme.of(context).colorScheme.error,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (_) async {
                    await _deleteAgent(id, name);
                    return false;
                  },
                  child: _AgentListItem(
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

class _AgentEmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _AgentEmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.dns_outlined,
                size: 34,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              l10n.agentsEmpty,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.agentsEmptySub,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: Text(l10n.agentsAdd),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgentListItem extends StatelessWidget {
  final String name;
  final String url;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onPrimary;

  const _AgentListItem({
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
    final l10n = AppLocalizations.of(context)!;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
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
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color:
                                Theme.of(context).cardTheme.color ??
                                scheme.surface,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (isActive) ...[
                          const SizedBox(width: 8),
                          _ActivePill(label: l10n.agentsActive),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                tooltip: l10n.edit,
                onPressed: onEdit,
              ),
              IconButton.filledTonal(
                icon: Icon(
                  isActive ? Icons.arrow_forward : Icons.check,
                  size: 18,
                ),
                tooltip: isActive ? l10n.agentsEnter : l10n.agentsActive,
                onPressed: onPrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivePill extends StatelessWidget {
  final String label;

  const _ActivePill({required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: scheme.brightness == Brightness.dark
              ? Colors.green.shade200
              : Colors.green.shade700,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
