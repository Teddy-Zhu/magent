import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:magent_app/core/storage/secure_storage.dart';

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
        const SnackBar(content: Text('Agent selected')),
      );
    }
  }

  Future<void> _deleteAgent(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Agent'),
        content: Text('Remove "$name"? This will disconnect from this agent.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _storage.deleteAgent(id);
      await _loadAgents();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$name" removed')),
        );
      }
    }
  }

  void _goToProjects() {
    context.push('/projects');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agents'),
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
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.dns_outlined, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('No agents configured'),
                      const SizedBox(height: 8),
                      const Text(
                        'Add an agent to get started',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await context.push('/agents/connect');
                          _loadAgents();
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add Agent'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _agents.length,
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
                        color: Colors.red,
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (_) async {
                        await _deleteAgent(id, name);
                        return false;
                      },
                      child: ListTile(
                        leading: Stack(
                          children: [
                            const Icon(Icons.computer, size: 32),
                            if (isActive)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Theme.of(context).scaffoldBackgroundColor,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Text(name),
                        subtitle: Text(url, style: const TextStyle(fontSize: 12)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () async {
                                final edited = await context.push<bool>('/agents/edit/$id');
                                if (edited == true) _loadAgents();
                              },
                            ),
                            if (isActive)
                              FilledButton(
                                onPressed: _goToProjects,
                                child: const Text('Enter'),
                              )
                            else
                              OutlinedButton(
                                onPressed: () => _selectAgent(id),
                                child: const Text('Select'),
                              ),
                          ],
                        ),
                        onTap: isActive
                            ? _goToProjects
                            : () => _selectAgent(id),
                      ),
                    );
                  },
                ),
    );
  }
}
