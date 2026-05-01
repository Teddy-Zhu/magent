import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:magent_app/core/providers/api_provider.dart';
import 'package:magent_app/core/session/session_language.dart';

class ProjectSessionsTab extends StatefulWidget {
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
  State<ProjectSessionsTab> createState() => _ProjectSessionsTabState();
}

class _ProjectSessionsTabState extends State<ProjectSessionsTab> {
  static const _initialVisibleCount = 80;
  static const _pageSize = 80;
  int _visibleCount = _initialVisibleCount;

  @override
  void didUpdateWidget(covariant ProjectSessionsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.projectId != oldWidget.projectId) {
      _visibleCount = _initialVisibleCount;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = widget.sessions;

    if (sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No sessions yet',
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Start a new AI coding session',
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () async {
                await context.push(
                  '/projects/${widget.projectId}/sessions/create',
                  extra: {'provider': 'codex'},
                );
                widget.onRefresh();
              },
              icon: const Icon(Icons.add),
              label: const Text('New Session'),
            ),
          ],
        ),
      );
    }

    final hidden = sessions.length > _visibleCount
        ? sessions.length - _visibleCount
        : 0;
    final visibleSessions = hidden > 0
        ? sessions.skip(hidden).toList(growable: false)
        : sessions;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
      cacheExtent: 720,
      itemCount: visibleSessions.length + (hidden > 0 ? 1 : 0),
      itemBuilder: (context, index) {
        if (hidden > 0 && index == 0) {
          return _LoadMoreSessionsBanner(
            hiddenCount: hidden,
            onTap: () {
              setState(() => _visibleCount += _pageSize);
            },
          );
        }

        final sessionIndex = hidden > 0 ? index - 1 : index;
        final s = visibleSessions[sessionIndex];
        final id = s['id'] as String? ?? '';
        final title =
            s['title'] as String? ??
            s['preview'] as String? ??
            s['summary'] as String? ??
            'Session';
        final status = SessionStatuses.normalizeOrStopped(s['status']);
        final provider = canonicalProviderId(Map<String, dynamic>.from(s));
        final rawCreated = s['created_at'] ?? s['createdAt'];
        final String createdAt;
        if (rawCreated is int) {
          createdAt = DateTime.fromMillisecondsSinceEpoch(
            rawCreated * 1000,
          ).toIso8601String();
        } else {
          createdAt = rawCreated as String? ?? '';
        }
        final isRunning = status == SessionStatuses.running;
        final statusColor = _statusColor(context, status);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: isRunning
              ? statusColor.withValues(alpha: 0.08)
              : Theme.of(context).colorScheme.surface,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => context.push('/sessions/$id'),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(8),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          _SessionStatusIcon(status: status),
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
                                        title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _StatusPill(
                                      label: SessionStatuses.label(status),
                                      color: statusColor,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  [
                                    if (provider != null && provider.isNotEmpty)
                                      provider,
                                    _formatTime(createdAt),
                                  ].where((s) => s.isNotEmpty).join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _statusColor(BuildContext context, String status) {
    final scheme = Theme.of(context).colorScheme;
    switch (status) {
      case 'running':
        return Colors.green;
      case 'failed':
        return scheme.error;
      case 'stopped':
        return Colors.orange;
      case 'completed':
        return scheme.primary;
      default:
        return scheme.onSurfaceVariant;
    }
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

class _LoadMoreSessionsBanner extends StatelessWidget {
  final int hiddenCount;
  final VoidCallback onTap;

  const _LoadMoreSessionsBanner({
    required this.hiddenCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.unfold_more, size: 16),
        label: Text('还有 $hiddenCount 个更早会话，点击加载'),
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

class _SessionStatusIcon extends StatelessWidget {
  final String status;

  const _SessionStatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (status) {
      'running' => Colors.green,
      'failed' => scheme.error,
      'stopped' => Colors.orange,
      'completed' => scheme.primary,
      _ => scheme.onSurfaceVariant,
    };
    final icon = switch (status) {
      'running' => Icons.play_arrow,
      'failed' => Icons.error_outline,
      'stopped' => Icons.pause,
      'completed' => Icons.check,
      _ => Icons.chat_bubble_outline,
    };

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 72),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
