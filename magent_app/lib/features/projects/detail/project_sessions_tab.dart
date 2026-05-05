import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:magent_app/core/providers/api_provider.dart';
import 'package:magent_app/core/session/session_language.dart';
import 'package:magent_app/core/theme/theme.dart';
import 'package:magent_app/l10n/app_localizations.dart';
import 'package:magent_app/shared/widgets/app_empty_state.dart';
import 'package:magent_app/shared/widgets/app_pill.dart';

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
    final scheme = Theme.of(context).colorScheme;
    final statusColors = AppStatusColors.of(context);
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
        cacheExtent: 1200,
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: false,
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
          final sessionMap = Map<String, dynamic>.from(s as Map);
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
          final meta = _SessionMeta.fromSession(
            sessionMap,
            timeText: _formatTime(createdAt),
          );
          final palette = _statusPalette(statusColors, status);

          return RepaintBoundary(
            child: Dismissible(
              key: ValueKey('session-${widget.archived}-$id'),
              direction: DismissDirection.horizontal,
              background: _SwipeActionBackground(
                alignment: Alignment.centerLeft,
                color: scheme.primary,
                icon: widget.archived
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
                label: widget.archived
                    ? l10n.sessionUnarchive
                    : l10n.sessionArchive,
              ),
              secondaryBackground: _SwipeActionBackground(
                alignment: Alignment.centerRight,
                color: scheme.error,
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
              child: _SessionCard(
                title: title,
                status: status,
                statusLabel: _statusLabel(l10n, status),
                palette: palette,
                isAiCommit: isAiCommit,
                aiCommitLabel: l10n.sessionPurposeAiCommit,
                aiCommitPalette: statusColors.info,
                meta: meta,
                onTap: () async {
                  await context.push('/sessions/$id');
                  if (mounted) await widget.onRefresh();
                },
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
    final scheme = Theme.of(context).colorScheme;
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
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
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

  StatusPalette _statusPalette(AppStatusColors colors, String status) {
    switch (status) {
      case 'running':
        return colors.running;
      case 'failed':
        return colors.error;
      case 'stopped':
        return colors.warning;
      case 'completed':
        return colors.success;
      default:
        return colors.neutral;
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

/// session 卡片标题下方的元信息四元组：来源 / 模型 / 推理强度 / 时间。
/// 来源识别优先级：source > source_kind > runner_type > provider_id。
class _SessionMeta {
  final String? source;
  final String? model;
  final String? effort;
  final String time;

  const _SessionMeta({
    this.source,
    this.model,
    this.effort,
    required this.time,
  });

  factory _SessionMeta.fromSession(
    Map<String, dynamic> session, {
    required String timeText,
  }) {
    String? takeString(String key) {
      final value = session[key]?.toString().trim();
      return (value == null || value.isEmpty) ? null : value;
    }

    String? sourceLabel;
    for (final key in const [
      'source',
      'source_kind',
      'sourceKind',
      'runner_type',
      'runnerType',
    ]) {
      final raw = takeString(key);
      if (raw != null) {
        sourceLabel = _normalizeSourceLabel(raw);
        break;
      }
    }
    sourceLabel ??= () {
      final providerId = canonicalProviderId(session);
      if (providerId == null || providerId.isEmpty) return null;
      return _normalizeSourceLabel(providerId);
    }();

    return _SessionMeta(
      source: sourceLabel,
      model: takeString('model'),
      effort: takeString('effort'),
      time: timeText,
    );
  }

  bool get hasAny =>
      (source != null && source!.isNotEmpty) ||
      (model != null && model!.isNotEmpty) ||
      (effort != null && effort!.isNotEmpty) ||
      time.isNotEmpty;
}

/// 单个 session 卡片：抽离为独立 widget 以便 Flutter 复用、降低 itemBuilder
/// 中重复构建的开销，避免滚动时 jank。
class _SessionCard extends StatelessWidget {
  final String title;
  final String status;
  final String statusLabel;
  final StatusPalette palette;
  final bool isAiCommit;
  final String aiCommitLabel;
  final StatusPalette aiCommitPalette;
  final _SessionMeta meta;
  final VoidCallback onTap;

  const _SessionCard({
    required this.title,
    required this.status,
    required this.statusLabel,
    required this.palette,
    required this.isAiCommit,
    required this.aiCommitLabel,
    required this.aiCommitPalette,
    required this.meta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isRunning = status == SessionStatuses.running;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isRunning
          ? palette.background.withValues(alpha: 0.55)
          : scheme.surface,
      child: InkWell(
        borderRadius: AppRadius.rmd,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
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
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              height: 1.22,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isAiCommit) ...[
                          AppPill.status(
                            label: aiCommitLabel,
                            palette: aiCommitPalette,
                            maxWidth: 92,
                          ),
                          const SizedBox(width: 6),
                        ],
                        AppPill.status(
                          label: statusLabel,
                          palette: palette,
                          maxWidth: 72,
                        ),
                      ],
                    ),
                    if (meta.hasAny) ...[
                      const SizedBox(height: 6),
                      _SessionMetaLine(meta: meta),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 把 [_SessionMeta] 渲染为同一行内的多个独立小 chip：
/// `[来源] [模型] [强度] [时间]`，单行不换行；model 可被 ellipsis 截断。
class _SessionMetaLine extends StatelessWidget {
  final _SessionMeta meta;

  const _SessionMetaLine({required this.meta});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final children = <Widget>[];

    void addFixed(Widget chip) {
      if (children.isNotEmpty) children.add(const SizedBox(width: 6));
      children.add(chip);
    }

    void addFlexible(Widget chip) {
      if (children.isNotEmpty) children.add(const SizedBox(width: 6));
      children.add(Flexible(child: chip));
    }

    if (meta.source != null && meta.source!.isNotEmpty) {
      addFixed(_MetaChip(text: meta.source!, color: scheme.tertiary));
    }
    if (meta.model != null && meta.model!.isNotEmpty) {
      // model 可能很长（gpt-5.5-codex），允许收缩 + ellipsis。
      addFlexible(_MetaChip(text: meta.model!, color: scheme.primary));
    }
    if (meta.effort != null && meta.effort!.isNotEmpty) {
      addFixed(_MetaChip(text: meta.effort!, color: scheme.secondary));
    }
    if (meta.time.isNotEmpty) {
      addFixed(
        _MetaChip(
          text: meta.time,
          color: scheme.onSurfaceVariant,
          subtle: true,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.max,
      children: children,
    );
  }
}

/// 元信息小 chip：紧凑、tonal 背景；subtle=true 时只用文本（无背景），
/// 用于时间这种次要信息。
class _MetaChip extends StatelessWidget {
  final String text;
  final Color color;
  final bool subtle;

  const _MetaChip({
    required this.text,
    required this.color,
    this.subtle = false,
  });

  @override
  Widget build(BuildContext context) {
    final textWidget = Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
    );
    if (subtle) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: textWidget,
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: AppRadius.rxs,
      ),
      child: textWidget,
    );
  }
}

/// session 卡片的元信息（模型 / 推理强度 / 来源）。
String _normalizeSourceLabel(String raw) {
  if (raw.isEmpty) return raw;
  // codex 的 source 枚举：cli / vscode / exec / appServer / subAgent /
  // subAgentReview / subAgentCompact / subAgentThreadSpawn / subAgentOther /
  // unknown。统一成更紧凑的小写形式。
  final lower = raw.toLowerCase().replaceAll('_', '-');
  if (lower.startsWith('subagent')) return 'subagent';
  switch (lower) {
    case 'appserver':
    case 'app-server':
      return 'app-server';
    case 'codex-cli':
      return 'cli';
    case 'vs-code':
      return 'vscode';
    default:
      return lower;
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
    return AppEmptyState(
      icon: archived ? Icons.archive_outlined : Icons.chat_bubble_outline,
      title: archived ? l10n.sessionsArchivedEmpty : l10n.sessionsEmptyYet,
      subtitle:
          archived ? l10n.sessionsArchivedEmptySub : l10n.sessionsEmptySub,
      topGap: MediaQuery.sizeOf(context).height * 0.06,
      action: archived
          ? null
          : FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: Text(l10n.sessionsCreate),
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
    final scheme = Theme.of(context).colorScheme;
    final onColor = ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? scheme.onPrimary
        : scheme.onError;
    final labelStyle = TextStyle(
      color: onColor,
      fontWeight: FontWeight.w700,
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: alignment,
      decoration: BoxDecoration(
        color: color,
        borderRadius: AppRadius.rmd,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isLeft) Text(label, style: labelStyle),
          if (!isLeft) const SizedBox(width: 8),
          Icon(icon, color: onColor, size: 20),
          if (isLeft) const SizedBox(width: 8),
          if (isLeft) Text(label, style: labelStyle),
        ],
      ),
    );
  }
}
