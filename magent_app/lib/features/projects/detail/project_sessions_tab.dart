import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:magent_app/core/providers/api_provider.dart';
import 'package:magent_app/core/session/session_language.dart';
import 'package:magent_app/l10n/app_localizations.dart';

class ProjectSessionsTab extends StatefulWidget {
  final String projectId;
  final List<dynamic> sessions;
  final AppApiClient api;
  final bool archived;
  final ValueChanged<bool> onArchiveModeChanged;
  final Future<void> Function(String sessionId) onArchiveSession;
  final Future<void> Function(String sessionId) onUnarchiveSession;
  final Future<void> Function(String sessionId) onDeleteSession;
  final Future<void> Function() onRefresh;

  const ProjectSessionsTab({
    super.key,
    required this.projectId,
    required this.sessions,
    required this.api,
    required this.archived,
    required this.onArchiveModeChanged,
    required this.onArchiveSession,
    required this.onUnarchiveSession,
    required this.onDeleteSession,
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
    if (widget.projectId != oldWidget.projectId ||
        widget.archived != oldWidget.archived) {
      _visibleCount = _initialVisibleCount;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sessions = widget.sessions;

    final hidden = sessions.length > _visibleCount
        ? sessions.length - _visibleCount
        : 0;
    final visibleSessions = hidden > 0
        ? sessions.skip(hidden).toList(growable: false)
        : sessions;

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
        cacheExtent: 720,
        itemCount: sessions.isEmpty
            ? 2
            : visibleSessions.length + (hidden > 0 ? 1 : 0) + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _SessionArchiveToggle(
              archived: widget.archived,
              onChanged: widget.onArchiveModeChanged,
            );
          }
          if (sessions.isEmpty) {
            return _EmptySessionsState(
              archived: widget.archived,
              onCreate: () async {
                await context.push(
                  '/projects/${widget.projectId}/sessions/create',
                  extra: {'provider': 'codex'},
                );
                if (mounted) await widget.onRefresh();
              },
            );
          }
          final listIndex = index - 1;
          if (hidden > 0 && listIndex == 0) {
            return _LoadMoreSessionsBanner(
              hiddenCount: hidden,
              onTap: () {
                setState(() => _visibleCount += _pageSize);
              },
            );
          }

          final sessionIndex = hidden > 0 ? listIndex - 1 : listIndex;
          final s = visibleSessions[sessionIndex];
          final id = s['id'] as String? ?? '';
          final title = _sessionTitle(s, l10n);
          final status = SessionStatuses.normalizeOrStopped(s['status']);
          final provider = canonicalProviderId(Map<String, dynamic>.from(s));
          final isAiCommit =
              s['purpose']?.toString() == SessionPurposes.aiCommit;
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

          return Dismissible(
            key: ValueKey('session-${widget.archived}-$id'),
            direction: DismissDirection.horizontal,
            background: _SwipeActionBackground(
              alignment: Alignment.centerLeft,
              color: Theme.of(context).colorScheme.primary,
              icon: widget.archived
                  ? Icons.unarchive_outlined
                  : Icons.archive_outlined,
              label: widget.archived
                  ? l10n.sessionUnarchive
                  : l10n.sessionArchive,
            ),
            secondaryBackground: _SwipeActionBackground(
              alignment: Alignment.centerRight,
              color: Theme.of(context).colorScheme.error,
              icon: Icons.delete_outline,
              label: l10n.delete,
            ),
            confirmDismiss: (direction) async {
              if (direction == DismissDirection.startToEnd) {
                if (widget.archived) {
                  await _runAction(
                    () => widget.onUnarchiveSession(id),
                    l10n.sessionUnarchiveFailed,
                  );
                } else {
                  await _runAction(
                    () => widget.onArchiveSession(id),
                    l10n.sessionArchiveFailed,
                  );
                }
              } else if (direction == DismissDirection.endToStart) {
                await _confirmAndDelete(id, title);
              }
              return false;
            },
            child: Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: isRunning
                  ? statusColor.withValues(alpha: 0.08)
                  : Theme.of(context).colorScheme.surface,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () async {
                  await context.push('/sessions/$id');
                  if (mounted) await widget.onRefresh();
                },
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
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  height: 1.22,
                                                ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        if (isAiCommit) ...[
                                          _PurposePill(
                                            label: l10n.sessionPurposeAiCommit,
                                          ),
                                          const SizedBox(width: 6),
                                        ],
                                        _StatusPill(
                                          label: _statusLabel(l10n, status),
                                          color: statusColor,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      [
                                        if (provider != null &&
                                            provider.isNotEmpty)
                                          provider,
                                        _formatTime(createdAt),
                                      ].where((s) => s.isNotEmpty).join(' · '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
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
            ),
          );
        },
      ),
    );
  }

  String _sessionTitle(dynamic session, AppLocalizations l10n) {
    if (session is Map) {
      for (final key in [
        'last_text',
        'lastText',
        'title',
        'preview',
        'summary',
      ]) {
        final value = session[key]?.toString().trim();
        if (value != null && value.isNotEmpty) return value;
      }
    }
    return l10n.chatTitle;
  }

  Future<void> _runAction(
    Future<void> Function() action,
    String errorMessage,
  ) async {
    try {
      await action();
      if (mounted) await widget.onRefresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$errorMessage: $e')));
    }
  }

  Future<void> _confirmAndDelete(String sessionId, String title) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.sessionDeleteTitle),
        content: Text(l10n.sessionDeleteConfirm(title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runAction(
      () => widget.onDeleteSession(sessionId),
      l10n.sessionDeleteFailed,
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

  String _statusLabel(AppLocalizations l10n, dynamic status) {
    switch (SessionStatuses.normalize(status)) {
      case SessionStatuses.running:
        return l10n.statusRunning;
      case SessionStatuses.completed:
        return l10n.statusCompleted;
      case SessionStatuses.stopped:
        return l10n.statusStopped;
      case SessionStatuses.failed:
        return l10n.statusFailed;
      case SessionStatuses.lost:
        return l10n.statusLost;
      case null:
        return l10n.statusUnknown;
      default:
        return SessionStatuses.normalize(status)!;
    }
  }

  String _formatTime(String timestamp) {
    if (timestamp.isEmpty) return '';
    final l10n = AppLocalizations.of(context)!;
    try {
      final dt = DateTime.parse(timestamp);
      final diff = DateTime.now().difference(dt);
      if (diff.inDays > 0) return l10n.timeDaysAgo(diff.inDays);
      if (diff.inHours > 0) return l10n.timeHoursAgo(diff.inHours);
      if (diff.inMinutes > 0) return l10n.timeMinutesAgo(diff.inMinutes);
      return l10n.timeNow;
    } catch (_) {
      return timestamp;
    }
  }
}

class _SessionArchiveToggle extends StatelessWidget {
  final bool archived;
  final ValueChanged<bool> onChanged;

  const _SessionArchiveToggle({
    required this.archived,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SegmentedButton<bool>(
        segments: [
          ButtonSegment(
            value: false,
            icon: const Icon(Icons.inbox_outlined),
            label: Text(l10n.sessionsActive),
          ),
          ButtonSegment(
            value: true,
            icon: const Icon(Icons.archive_outlined),
            label: Text(l10n.sessionsArchived),
          ),
        ],
        selected: {archived},
        onSelectionChanged: (values) => onChanged(values.first),
        showSelectedIcon: false,
      ),
    );
  }
}

class _EmptySessionsState extends StatelessWidget {
  final bool archived;
  final VoidCallback onCreate;

  const _EmptySessionsState({required this.archived, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.sizeOf(context).height * 0.16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              archived ? Icons.archive_outlined : Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              archived ? l10n.sessionsArchivedEmpty : l10n.sessionsEmptyYet,
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              archived ? l10n.sessionsArchivedEmptySub : l10n.sessionsEmptySub,
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
            if (!archived) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                label: Text(l10n.sessionsCreate),
              ),
            ],
          ],
        ),
      ),
    );
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
        label: Text(
          AppLocalizations.of(context)!.sessionsLoadMore(hiddenCount),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

class _SwipeActionBackground extends StatelessWidget {
  final Alignment alignment;
  final Color color;
  final IconData icon;
  final String label;

  const _SwipeActionBackground({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isLeft = alignment == Alignment.centerLeft;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: alignment,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isLeft) Text(label, style: _labelStyle),
          if (!isLeft) const SizedBox(width: 8),
          Icon(icon, color: Colors.white, size: 20),
          if (isLeft) const SizedBox(width: 8),
          if (isLeft) Text(label, style: _labelStyle),
        ],
      ),
    );
  }

  static const _labelStyle = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.w700,
  );
}

class _PurposePill extends StatelessWidget {
  final String label;

  const _PurposePill({required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: scheme.onSecondaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
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
