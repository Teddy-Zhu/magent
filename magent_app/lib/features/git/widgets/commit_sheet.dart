import 'package:flutter/material.dart';
import 'package:magent_app/core/api/error_messages.dart';
import 'package:magent_app/core/repositories/git_repository.dart';
import 'package:magent_app/core/storage/secure_storage.dart';
import 'package:magent_app/core/theme/theme.dart';
import 'package:magent_app/l10n/app_localizations.dart';
import 'package:magent_app/shared/widgets/app_sheet_header.dart';

/// Shared bottom sheet for commit operations.
class CommitSheet extends StatefulWidget {
  final GitRepository git;
  final String projectId;
  final VoidCallback? onCommitted;

  const CommitSheet({
    super.key,
    required this.git,
    required this.projectId,
    this.onCommitted,
  });

  static Future<void> show({
    required BuildContext context,
    required GitRepository git,
    required String projectId,
    VoidCallback? onCommitted,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          CommitSheet(git: git, projectId: projectId, onCommitted: onCommitted),
    );
  }

  @override
  State<CommitSheet> createState() => _CommitSheetState();
}

class _CommitSheetState extends State<CommitSheet> {
  final _messageController = TextEditingController();
  bool _commitAll = false;
  bool _committing = false;
  bool _suggesting = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: scheme.error));
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    final statusColors = AppStatusColors.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: statusColors.running.foreground,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _suggestMessage() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _suggesting = true);
    try {
      final storage = AgentStorage();
      final provider = await storage.getDefaultProvider() ?? 'codex';
      final providerId = provider.isEmpty ? 'codex' : provider;
      final message = await widget.git.suggestCommitMessage(
        widget.projectId,
        providerId: providerId,
        model: await storage.getAiCommitModel(providerId),
        effort: await storage.getAiCommitEffort(providerId),
      );
      if (mounted && message.isNotEmpty) {
        _messageController.text = message;
        _showSuccess(l10n.gitAiMessageGenerated);
      } else if (mounted) {
        _showError(l10n.gitAiReturnedEmpty);
      }
    } catch (e) {
      _showError(
        localizedErrorMessage(l10n, e, action: l10n.gitAiSuggestionFailed),
      );
    } finally {
      if (mounted) setState(() => _suggesting = false);
    }
  }

  Future<void> _commit() async {
    final l10n = AppLocalizations.of(context)!;
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      _showError(l10n.gitCommitMessageRequired);
      return;
    }

    setState(() => _committing = true);
    try {
      await widget.git.commit(widget.projectId, message, all: _commitAll);
      widget.onCommitted?.call();
      _showSuccess(l10n.gitCommitSuccessful);
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      _showError(localizedErrorMessage(l10n, e, action: l10n.gitCommitFailed));
    } finally {
      if (mounted) setState(() => _committing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.8,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              AppSheetHeader(
                title: l10n.gitCommit,
                icon: Icons.commit,
                onClose: () => Navigator.pop(context),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        labelText: l10n.gitCommitMsg,
                        hintText: l10n.gitCommitMessageHint,
                        suffixIcon: Tooltip(
                          message: l10n.gitAiSuggest,
                          child: IconButton(
                            icon: _suggesting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.auto_awesome),
                            onPressed: _suggesting ? null : _suggestMessage,
                          ),
                        ),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 36,
                      child: OutlinedButton.icon(
                        onPressed: _suggesting ? null : _suggestMessage,
                        icon: _suggesting
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.auto_awesome, size: 16),
                        label: Text(
                          _suggesting
                              ? l10n.gitGenerating
                              : l10n.gitAiGenerateMessage,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      title: Text(l10n.gitStageAllChanges),
                      value: _commitAll,
                      onChanged: (v) => setState(() => _commitAll = v ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _committing ? null : _commit,
                      icon: _committing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.commit),
                      label: Text(l10n.gitCommit),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
