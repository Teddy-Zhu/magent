import 'package:flutter/material.dart';
import 'package:magent_app/core/api/git_api.dart';

/// Shared bottom sheet for commit operations.
class CommitSheet extends StatefulWidget {
  final GitApi gitApi;
  final String projectId;
  final VoidCallback? onCommitted;

  const CommitSheet({
    super.key,
    required this.gitApi,
    required this.projectId,
    this.onCommitted,
  });

  static Future<void> show({
    required BuildContext context,
    required GitApi gitApi,
    required String projectId,
    VoidCallback? onCommitted,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CommitSheet(
        gitApi: gitApi,
        projectId: projectId,
        onCommitted: onCommitted,
      ),
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
  String _status = '';

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _suggestMessage() async {
    setState(() { _suggesting = true; _status = ''; });
    try {
      final message = await widget.gitApi.suggestCommitMessage(widget.projectId);
      if (mounted && message.isNotEmpty) {
        _messageController.text = message;
        setState(() => _status = 'AI message generated');
      }
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('No staged changes')) {
        setState(() => _status = 'No staged changes. Stage files first.');
      } else {
        setState(() => _status = 'AI suggestion failed: $e');
      }
    } finally {
      if (mounted) setState(() => _suggesting = false);
    }
  }

  Future<void> _commit() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      setState(() => _status = 'Commit message is required');
      return;
    }

    setState(() { _committing = true; _status = 'Committing...'; });
    try {
      await widget.gitApi.commit(widget.projectId, message, all: _commitAll);
      setState(() => _status = 'Commit successful');
      widget.onCommitted?.call();
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _status = 'Commit failed: $e');
    } finally {
      if (mounted) setState(() => _committing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.commit, size: 18),
                    const SizedBox(width: 8),
                    const Text('Commit', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Body
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Commit message
                    TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        labelText: 'Commit message',
                        hintText: 'feat: describe your changes...',
                        border: const OutlineInputBorder(),
                        suffixIcon: Tooltip(
                          message: 'AI suggest',
                          child: IconButton(
                            icon: _suggesting
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
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
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.auto_awesome, size: 16),
                        label: Text(_suggesting ? 'Generating...' : 'AI Generate Message'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      title: const Text('Stage all changes (-a)'),
                      value: _commitAll,
                      onChanged: (v) => setState(() => _commitAll = v ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _committing ? null : _commit,
                      icon: _committing
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.commit),
                      label: const Text('Commit'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                      ),
                    ),
                    if (_status.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _status.contains('failed') || _status.contains('No staged')
                              ? Colors.red[50]
                              : _status.contains('successful') || _status.contains('generated')
                                  ? Colors.green[50]
                                  : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _status.contains('failed') || _status.contains('No staged')
                                  ? Icons.error_outline
                                  : _status.contains('successful') || _status.contains('generated')
                                      ? Icons.check_circle_outline
                                      : Icons.info_outline,
                              size: 18,
                              color: _status.contains('failed') || _status.contains('No staged')
                                  ? Colors.red
                                  : _status.contains('successful') || _status.contains('generated')
                                      ? Colors.green
                                      : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_status, style: const TextStyle(fontSize: 13))),
                          ],
                        ),
                      ),
                    ],
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
