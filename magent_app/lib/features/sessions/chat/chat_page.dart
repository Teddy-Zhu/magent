import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:magent_app/core/providers/api_provider.dart';

class ChatPage extends ConsumerStatefulWidget {
  final String sessionId;

  const ChatPage({super.key, required this.sessionId});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final List<Map<String, dynamic>> _events = [];
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _loading = true;
  int _lastSeq = 0;
  AppApiClient? _api;
  Map<String, dynamic>? _session;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _api = await loadActiveApi(ref);
    if (_api == null || !mounted) return;
    await _loadSession();
    await _loadEvents();
  }

  Future<void> _loadSession() async {
    if (_api == null) return;
    try {
      final resp = await _api!.client.dio.get('/api/sessions/${widget.sessionId}');
      if (mounted) {
        setState(() {
          _session = resp.data['data'];
        });
      }
    } catch (_) {}
  }

  Future<void> _loadEvents() async {
    if (_api == null) return;
    try {
      final events = await _api!.session.getEvents(
        widget.sessionId,
        afterSeq: _lastSeq,
        limit: 500,
      );
      if (mounted) {
        setState(() {
          for (final e in events) {
            final seq = e['seq'] as int? ?? 0;
            if (seq > _lastSeq) {
              _lastSeq = seq;
              _events.add(Map<String, dynamic>.from(e));
            }
          }
          _loading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendInput() async {
    final input = _inputController.text.trim();
    if (input.isEmpty || _api == null) return;

    _inputController.clear();
    setState(() {
      _events.add({
        'type': 'user.input',
        'data': {'content': input},
      });
    });
    _scrollToBottom();

    try {
      await _api!.session.sendInput(widget.sessionId, input);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Send failed: $e')),
        );
      }
    }
  }

  Future<void> _interrupt() async {
    if (_api == null) return;
    try {
      await _api!.session.interrupt(widget.sessionId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Interrupt failed: $e')),
        );
      }
    }
  }

  Future<void> _stop() async {
    if (_api == null) return;
    try {
      await _api!.session.stop(widget.sessionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session stopped')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stop failed: $e')),
        );
      }
    }
  }

  Future<void> _respondApproval(String approvalId, String action) async {
    if (_api == null) return;
    try {
      await _api!.session.approve(approvalId, action);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Approval failed: $e')),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = _session?['status'] as String? ?? '';
    final title = _session?['title'] as String? ?? 'Session';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16)),
            if (status.isNotEmpty)
              Text(status, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadEvents),
          IconButton(icon: const Icon(Icons.stop), onPressed: _stop),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _events.isEmpty
                    ? const Center(child: Text('No events yet'))
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: _events.length,
                        itemBuilder: (context, index) {
                          return _buildEventWidget(_events[index]);
                        },
                      ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildEventWidget(Map<String, dynamic> event) {
    final type = event['type'] as String? ?? '';
    final data = event['data'];

    switch (type) {
      case 'user.input':
        return _UserBubble(content: data?['content'] ?? '');
      case 'session.message':
        return _MessageBubble(content: data?['text'] ?? '');
      case 'session.output':
        return _MessageBubble(content: data?['content'] ?? '');
      case 'session.command_completed':
        return _ToolCallCard(
          icon: Icons.terminal,
          title: data?['command'] ?? '',
          output: data?['output'] ?? '',
          success: data?['exit_code'] == 0,
        );
      case 'session.file_write':
        return _ToolCallCard(
          icon: Icons.edit_note,
          title: data?['path'] ?? '',
          output: '+${data?['additions'] ?? 0} -${data?['deletions'] ?? 0}',
          success: true,
        );
      case 'session.approval_request':
        return _ApprovalCard(
          request: data,
          onRespond: (action) =>
              _respondApproval(data?['id']?.toString() ?? '', action),
        );
      case 'session.error':
        return _ErrorCard(message: data?['error'] ?? data?['message'] ?? 'Unknown error');
      case 'session.exited':
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              'Session exited (code: ${data?['exit_code'] ?? 0})',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _QuickButton(label: 'Continue', onPressed: () {
                _inputController.text = 'continue';
                _sendInput();
              }),
              _QuickButton(label: 'Summarize', onPressed: () {
                _inputController.text = 'summarize what you have done so far';
                _sendInput();
              }),
              _QuickButton(label: 'Interrupt', onPressed: _interrupt),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputController,
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onSubmitted: (_) => _sendInput(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: _sendInput,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class _UserBubble extends StatelessWidget {
  final String content;
  const _UserBubble({required this.content});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Flexible(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(content),
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: const Icon(Icons.person, color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String content;
  const _MessageBubble({required this.content});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(child: Icon(Icons.smart_toy)),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: MarkdownBody(data: content),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolCallCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String output;
  final bool success;

  const _ToolCallCard({
    required this.icon,
    required this.title,
    required this.output,
    required this.success,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        child: ExpansionTile(
          leading: Icon(icon, color: success ? Colors.green : Colors.red),
          title: Text(title, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
          subtitle: Text(
            output.length > 100 ? '${output.substring(0, 100)}...' : output,
            style: const TextStyle(fontSize: 12),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText(output, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  final dynamic request;
  final void Function(String action) onRespond;

  const _ApprovalCard({this.request, required this.onRespond});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning, color: Theme.of(context).colorScheme.error),
                  const SizedBox(width: 8),
                  const Text('Approval Required', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Text(request?['command'] ?? request?['file_path'] ?? 'Unknown operation'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => onRespond('decline'),
                    child: const Text('Decline'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => onRespond('acceptForSession'),
                    child: const Text('Allow for Session'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => onRespond('accept'),
                    child: const Text('Allow'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.error, color: Theme.of(context).colorScheme.error),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _QuickButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(label: Text(label), onPressed: onPressed),
    );
  }
}
