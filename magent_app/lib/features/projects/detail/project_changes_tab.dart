import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:magent_app/core/api/error_messages.dart';
import 'package:magent_app/core/repositories/file_repository.dart';
import 'package:magent_app/core/repositories/git_repository.dart';
import 'package:magent_app/features/git/widgets/commit_sheet.dart';
import 'package:magent_app/features/git/widgets/diff_sheet.dart';

class ProjectChangesTab extends StatefulWidget {
  final String projectId;
  final GitRepository git;
  final FileRepository file;
  final ValueListenable<int>? invalidationSignal;
  final VoidCallback? onViewLog;
  final VoidCallback? onViewBranches;

  const ProjectChangesTab({
    super.key,
    required this.projectId,
    required this.git,
    required this.file,
    this.invalidationSignal,
    this.onViewLog,
    this.onViewBranches,
  });

  @override
  State<ProjectChangesTab> createState() => _ProjectChangesTabState();
}

class _ProjectChangesTabState extends State<ProjectChangesTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _summary;
  List<dynamic> _allFiles = [];
  bool _loading = true;
  bool _operating = false;
  bool _pushing = false;
  final Set<String> _selectedPaths = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() => _selectedPaths.clear());
    });
    widget.invalidationSignal?.addListener(_handleInvalidation);
    _load();
  }

  @override
  void dispose() {
    widget.invalidationSignal?.removeListener(_handleInvalidation);
    _tabController.dispose();
    super.dispose();
  }

  void _handleInvalidation() {
    _refreshFromInvalidation();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final cached = await widget.git.getCachedSnapshot(widget.projectId);
      if (mounted && cached != null) {
        setState(() {
          _summary = cached.summary;
          _allFiles = cached.files;
          _loading = false;
        });
      }
      final snapshot = await widget.git.refreshSnapshot(widget.projectId);
      if (mounted) {
        setState(() {
          _summary = snapshot.summary;
          _allFiles = snapshot.files;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshFromInvalidation() async {
    if (!mounted) return;
    try {
      final snapshot = await widget.git.refreshSnapshot(widget.projectId);
      if (mounted) {
        setState(() {
          _summary = snapshot.summary;
          _allFiles = snapshot.files;
          _loading = false;
        });
      }
    } catch (_) {}
  }

  List<dynamic> get _stagedFiles =>
      _allFiles.where((f) => f['staged'] == true).toList();
  List<dynamic> get _unstagedFiles =>
      _allFiles.where((f) => f['staged'] != true).toList();

  bool get _isStagedTab => _tabController.index == 0;

  List<dynamic> get _currentFiles =>
      _isStagedTab ? _stagedFiles : _unstagedFiles;

  void _toggleSelect(String path) {
    setState(() {
      if (_selectedPaths.contains(path)) {
        _selectedPaths.remove(path);
      } else {
        _selectedPaths.add(path);
      }
    });
  }

  void _selectAll() {
    setState(() {
      final paths = _currentFiles.map((f) => f['path'] as String).toSet();
      if (_selectedPaths.containsAll(paths)) {
        _selectedPaths.clear();
      } else {
        _selectedPaths.addAll(paths);
      }
    });
  }

  Future<void> _stageSelected() async {
    if (_selectedPaths.isEmpty) return;
    setState(() => _operating = true);
    try {
      await widget.git.stage(widget.projectId, _selectedPaths.toList());
      setState(() => _selectedPaths.clear());
      await _load();
    } catch (e) {
      if (mounted) _showError(e, action: 'Stage failed');
    } finally {
      if (mounted) setState(() => _operating = false);
    }
  }

  Future<void> _unstageSelected() async {
    if (_selectedPaths.isEmpty) return;
    setState(() => _operating = true);
    try {
      await widget.git.unstage(widget.projectId, _selectedPaths.toList());
      setState(() => _selectedPaths.clear());
      await _load();
    } catch (e) {
      if (mounted) _showError(e, action: 'Unstage failed');
    } finally {
      if (mounted) setState(() => _operating = false);
    }
  }

  Future<void> _discardSelected() async {
    if (_selectedPaths.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('放弃更改'),
        content: Text('确定放弃 ${_selectedPaths.length} 个文件的更改？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('放弃', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => _operating = true);
      try {
        await widget.git.discard(widget.projectId, _selectedPaths.toList());
        setState(() => _selectedPaths.clear());
        await _load();
      } catch (e) {
        if (mounted) _showError(e, action: 'Discard failed');
      } finally {
        if (mounted) setState(() => _operating = false);
      }
    }
  }

  Future<void> _push({bool force = false}) async {
    setState(() => _pushing = true);
    try {
      await widget.git.push(widget.projectId, force: force);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Push successful'),
            backgroundColor: Colors.green,
          ),
        );
        await _load();
      }
    } catch (e) {
      if (mounted) _showError(e, action: 'Push failed');
    } finally {
      if (mounted) setState(() => _pushing = false);
    }
  }

  void _showError(Object error, {String? action}) {
    final msg = error is String
        ? error
        : userFriendlyErrorMessage(error, action: action);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _openDiff(dynamic file) {
    DiffSheet.show(
      context: context,
      git: widget.git,
      file: widget.file,
      projectId: widget.projectId,
      path: file['path'] as String? ?? '',
      diffHash: file['diff_hash'] as String? ?? '',
      isBinary: file['binary'] == true,
      staged: file['staged'] == true,
    );
  }

  void _openCommitSheet() {
    CommitSheet.show(
      context: context,
      git: widget.git,
      projectId: widget.projectId,
      onCommitted: _load,
    );
  }

  void _confirmForcePush() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Force Push'),
        content: const Text(
          'Force push will overwrite remote history. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _push(force: true);
            },
            child: const Text(
              'Force Push',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final hasChanges = _allFiles.isNotEmpty;
    final stagedCount = _stagedFiles.length;
    final hasSelection = _selectedPaths.isNotEmpty;

    return Stack(
      children: [
        Column(
          children: [
            // Summary card
            _buildSummaryCard(),
            // Tab bar
            Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
              ),
              child: TabBar(
                controller: _tabController,
                tabs: [
                  Tab(text: 'Staged ($stagedCount)'),
                  Tab(text: 'Unstaged (${_unstagedFiles.length})'),
                ],
              ),
            ),
            // Action bar
            _buildActionBar(stagedCount, hasSelection),
            // File list
            Expanded(
              child: hasChanges
                  ? _buildFileList()
                  : Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 64,
                            color: Colors.green[200],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Working tree clean',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
        if (_operating)
          Container(
            color: Colors.black.withValues(alpha: 0.05),
            child: const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('Processing...'),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    final branch = _summary?['branch'] as String? ?? '';
    final upstream = _summary?['upstream'] as String? ?? '';
    final ahead = _summary?['ahead'] ?? 0;
    final behind = _summary?['behind'] ?? 0;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.alt_route, size: 16, color: Colors.blue[600]),
            const SizedBox(width: 6),
            Text(
              branch,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            if (upstream.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                '→ $upstream',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
            const Spacer(),
            if (ahead > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '↑$ahead',
                  style: TextStyle(fontSize: 11, color: Colors.blue[700]),
                ),
              ),
            if (behind > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '↓$behind',
                  style: TextStyle(fontSize: 11, color: Colors.orange[700]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionBar(int stagedCount, bool hasSelection) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: hasSelection
            ? Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.3)
            : Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: hasSelection
            ? [
                Text(
                  '${_selectedPaths.length} selected',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                if (_isStagedTab)
                  SizedBox(
                    height: 30,
                    child: FilledButton(
                      onPressed: _operating ? null : _unstageSelected,
                      style: _barFilledStyle(),
                      child: const Text(
                        'Unstage',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  )
                else ...[
                  SizedBox(
                    height: 30,
                    child: FilledButton(
                      onPressed: _operating ? null : _stageSelected,
                      style: _barFilledStyle(),
                      child: const Text(
                        'Stage',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    height: 30,
                    child: OutlinedButton(
                      onPressed: _operating ? null : _discardSelected,
                      style: _barOutlinedStyle(),
                      child: const Text(
                        'Discard',
                        style: TextStyle(fontSize: 12, color: Colors.red),
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _selectedPaths.clear()),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 30,
                    minHeight: 30,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ]
            : [
                SizedBox(
                  height: 30,
                  child: OutlinedButton.icon(
                    onPressed: _currentFiles.isNotEmpty ? _selectAll : null,
                    icon: const Icon(Icons.checklist, size: 16),
                    label: const Text('Select', style: TextStyle(fontSize: 12)),
                    style: _barOutlinedStyle(horizontal: 10),
                  ),
                ),
                const Spacer(),
                if (_isStagedTab)
                  SizedBox(
                    height: 30,
                    child: FilledButton.icon(
                      onPressed: (stagedCount > 0 && !_operating)
                          ? _openCommitSheet
                          : null,
                      icon: const Icon(Icons.commit, size: 16),
                      label: const Text(
                        'Commit',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: _barFilledStyle(horizontal: 10),
                    ),
                  ),
                if (_isStagedTab) const SizedBox(width: 6),
                SizedBox(
                  height: 30,
                  child: FilledButton.tonal(
                    onPressed: _pushing ? null : () => _push(),
                    onLongPress: _pushing ? null : _confirmForcePush,
                    style: _barTonalStyle(horizontal: 10),
                    child: _pushing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload, size: 18),
                  ),
                ),
              ],
      ),
    );
  }

  ButtonStyle _barFilledStyle({double horizontal = 12}) {
    return FilledButton.styleFrom(
      padding: EdgeInsets.symmetric(horizontal: horizontal),
      minimumSize: const Size(0, 30),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  ButtonStyle _barOutlinedStyle({double horizontal = 12}) {
    return OutlinedButton.styleFrom(
      padding: EdgeInsets.symmetric(horizontal: horizontal),
      minimumSize: const Size(0, 30),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  ButtonStyle _barTonalStyle({double horizontal = 12}) {
    return FilledButton.styleFrom(
      padding: EdgeInsets.symmetric(horizontal: horizontal),
      minimumSize: const Size(0, 30),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildFileList() {
    final files = _currentFiles;
    if (files.isEmpty) {
      return Center(
        child: Text(
          _isStagedTab ? 'No staged files' : 'No unstaged files',
          style: TextStyle(color: Colors.grey[500]),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        itemCount: files.length + 2, // +1 for bottom links, +1 for padding
        itemBuilder: (context, index) {
          if (index == files.length) return _buildBottomLinks();
          if (index == files.length + 1) return const SizedBox(height: 80);
          final file = files[index];
          return _buildFileTile(file);
        },
      ),
    );
  }

  Widget _buildFileTile(dynamic file) {
    final path = file['path'] as String? ?? '';
    final status = file['status'] as String? ?? '';
    final additions = file['additions'] as int? ?? 0;
    final deletions = file['deletions'] as int? ?? 0;
    final isBinary = file['binary'] == true;
    final fileName = path.contains('/') ? path.split('/').last : path;
    final selected = _selectedPaths.contains(path);

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      leading: GestureDetector(
        onTap: () => _toggleSelect(path),
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey[400]!,
              width: 1.5,
            ),
          ),
          child: selected
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : _statusIconSmall(status),
        ),
      ),
      title: Text(
        fileName,
        style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: path.contains('/')
          ? Text(
              path.substring(0, path.lastIndexOf('/')),
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isBinary)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'binary',
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
            ),
          if (additions > 0 && !isBinary)
            Text(
              '+$additions',
              style: TextStyle(
                fontSize: 11,
                color: Colors.green[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          if (deletions > 0 && !isBinary) ...[
            const SizedBox(width: 4),
            Text(
              '-$deletions',
              style: TextStyle(
                fontSize: 11,
                color: Colors.red[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
      onTap: () {
        if (_selectedPaths.isNotEmpty) {
          _toggleSelect(path);
        } else {
          _openDiff(file);
        }
      },
      onLongPress: () => _toggleSelect(path),
    );
  }

  Widget _statusIconSmall(String status) {
    switch (status) {
      case 'modified':
        return Icon(Icons.edit, size: 12, color: Colors.orange[600]);
      case 'added':
        return Icon(Icons.add, size: 12, color: Colors.green[600]);
      case 'deleted':
        return Icon(Icons.remove, size: 12, color: Colors.red[600]);
      case 'untracked':
        return Icon(Icons.help_outline, size: 12, color: Colors.grey[500]);
      default:
        return Icon(Icons.circle, size: 8, color: Colors.grey[400]);
    }
  }

  Widget _buildBottomLinks() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: widget.onViewLog,
            icon: const Icon(Icons.history, size: 16),
            label: const Text('Commit Log', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: widget.onViewBranches,
            icon: const Icon(Icons.account_tree, size: 16),
            label: const Text('Branches', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
