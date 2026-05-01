import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:magent_app/core/providers/api_provider.dart';

class ProjectSessionsTab extends StatelessWidget {
  final String projectId;
  final List<dynamic> sessions;
  final AppApiClient api;
  final VoidCallback onRefresh;

  const ProjectSessionsTab({
    super.key,
    required this.projectId,
    required this.sessions,
    required this.api,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No sessions yet', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
            const SizedBox(height: 8),
            Text('Start a new AI coding session', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () async {
                await context.push('/projects/$projectId/sessions/create');
                onRefresh();
              },
              icon: const Icon(Icons.add),
              label: const Text('New Session'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final s = sessions[index];
        final id = s['id'] as String? ?? '';
        final title = s['title'] as String? ?? 'Session';
        final status = s['status'] as String? ?? '';
        final provider = s['provider'] as String? ?? '';
        final createdAt = s['created_at'] as String? ?? '';
        final isRunning = status == 'running';

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isRunning ? Colors.green[50] : Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    isRunning ? Icons.play_circle : Icons.stop_circle,
                    color: isRunning ? Colors.green : Colors.grey,
                    size: 22,
                  ),
                  if (isRunning)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withValues(alpha: 0.4),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              [if (provider.isNotEmpty) provider, _formatTime(createdAt)].where((s) => s.isNotEmpty).join(' · '),
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isRunning ? Colors.green[50] : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 11,
                  color: isRunning ? Colors.green[700] : Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            onTap: () => context.push('/sessions/$id'),
          ),
        );
      },
    );
  }

  String _formatTime(String timestamp) {
    if (timestamp.isEmpty) return '';
    try {
      final dt = DateTime.parse(timestamp);
      final diff = DateTime.now().difference(dt);
      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
      return 'now';
    } catch (_) {
      return timestamp;
    }
  }
}
