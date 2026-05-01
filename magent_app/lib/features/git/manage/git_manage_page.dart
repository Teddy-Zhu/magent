import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:magent_app/core/api/error_messages.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magent_app/core/providers/api_provider.dart';
import 'package:magent_app/core/repositories/file_repository.dart';
import 'package:magent_app/core/repositories/git_repository.dart';
import 'package:magent_app/features/git/widgets/diff_sheet.dart';
import 'package:magent_app/features/git/widgets/commit_sheet.dart';

class GitManagePage extends ConsumerStatefulWidget {
  final String projectId;

  const GitManagePage({super.key, required this.projectId});

  @override
  ConsumerState<GitManagePage> createState() => _GitManagePageState();
}

class _GitManagePageState extends ConsumerState<GitManagePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  AppApiClient? _api;
  GitRepository? _gitRepo;
  FileRepository? _fileRepo;
  StreamSubscription<Map<String, dynamic>>? _gitInvalidationSub;
  final _gitInvalidationSignal = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _init();
  }

  Future<void> _init() async {
    _api = await loadActiveApi(ref);
    if (_api != null) {
      final db = ref.read(appDatabaseProvider);
      _gitRepo = GitRepository(agentId: _api!.agentId, api: _api!.git, db: db);
      _fileRepo = FileRepository(
        agentId: _api!.agentId,
        api: _api!.file,
        db: db,
      );
      _connectRealtime();
    }
    if (mounted) setState(() {});
  }

  void _connectRealtime() {
    final engine = ref.read(syncEngineProvider);
    if (engine == null) return;
    _gitInvalidationSub = engine.gitInvalidations.listen((event) {
      if (!mounted) return;
      if (event['project_id']?.toString() != widget.projectId) return;
      _gitInvalidationSignal.value++;
    });
  }

  @override
  void dispose() {
    _gitInvalidationSub?.cancel();
    _gitInvalidationSignal.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Git'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Status', icon: Icon(Icons.compare_arrows, size: 18)),
            Tab(text: 'Log', icon: Icon(Icons.history, size: 18)),
            Tab(text: 'Branches', icon: Icon(Icons.account_tree, size: 18)),
          ],
        ),
      ),
      body: _api == null
          ? const Center(child: Text('No agent connected'))
          : TabBarView(
              controller: _tabController,
              children: [
                _StatusTab(
                  git: _gitRepo!,
                  file: _fileRepo!,
                  projectId: widget.projectId,
                  invalidationSignal: _gitInvalidationSignal,
                ),
                _LogTab(api: _api!, projectId: widget.projectId),
                _BranchesTab(api: _api!, projectId: widget.projectId),
              ],
            ),
    );
  }
}

// ==================== Status Tab ====================

class _StatusTab extends StatefulWidget {
  final GitRepository git;
  final FileRepository file;
  final String projectId;
  final ValueListenable<int>? invalidationSignal;
  const _StatusTab({
    required this.git,
    required this.file,
    required this.projectId,
    this.invalidationSignal,
  });

  @override
  State<_StatusTab> createState() => _StatusTabState();
}

class _StatusTabState extends State<_StatusTab>
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
            _buildSummaryCard(),
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
            _buildActionBar(stagedCount, hasSelection),
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
        itemCount: files.length,
        itemBuilder: (context, index) {
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
}

// ==================== Log Tab ====================

class _LogTab extends StatefulWidget {
  final AppApiClient api;
  final String projectId;
  const _LogTab({required this.api, required this.projectId});

  @override
  State<_LogTab> createState() => _LogTabState();
}

class _LogTabState extends State<_LogTab> {
  final List<dynamic> _commits = [];
  bool _loading = true;
  int _offset = 0;
  bool _hasMore = true;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _loadCommits();
  }

  Future<void> _loadCommits() async {
    if (_loadingMore) return;
    if (_offset > 0) setState(() => _loadingMore = true);
    try {
      final commits = await widget.api.git.getLog(
        widget.projectId,
        limit: 50,
        offset: _offset,
      );
      if (mounted) {
        setState(() {
          _commits.addAll(commits);
          _hasMore = commits.length >= 50;
          _loading = false;
          _loadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_commits.isEmpty) return const Center(child: Text('No commits'));

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollEndNotification &&
            n.metrics.pixels >= n.metrics.maxScrollExtent - 200 &&
            _hasMore &&
            !_loadingMore) {
          _offset += 50;
          _loadCommits();
        }
        return false;
      },
      child: ListView.builder(
        itemCount: _commits.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _commits.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final commit = _commits[index];
          final hash = commit['hash'] as String? ?? '';
          final message = commit['message'] as String? ?? '';
          final author = commit['author'] as String? ?? '';
          final timestamp = commit['timestamp'] as String? ?? '';
          final shortHash = hash.length > 7 ? hash.substring(0, 7) : hash;

          return ListTile(
            leading: Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
            title: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
            subtitle: Text(
              '$author · $shortHash',
              style: const TextStyle(fontSize: 11),
            ),
            trailing: Text(
              _formatTime(timestamp),
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            onTap: () => _openCommitDetail(commit as Map<String, dynamic>),
          );
        },
      ),
    );
  }

  String _formatTime(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      final diff = DateTime.now().difference(dt);
      if (diff.inDays > 0) return '${diff.inDays}d';
      if (diff.inHours > 0) return '${diff.inHours}h';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m';
      return 'now';
    } catch (_) {
      return timestamp;
    }
  }

  void _openCommitDetail(Map<String, dynamic> commit) {
    final hash = commit['hash'] as String? ?? '';
    final message = commit['message'] as String? ?? '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CommitDetailSheet(
        api: widget.api,
        projectId: widget.projectId,
        hash: hash,
        message: message,
      ),
    );
  }
}

class _CommitDetailSheet extends StatefulWidget {
  final AppApiClient api;
  final String projectId;
  final String hash;
  final String message;
  const _CommitDetailSheet({
    required this.api,
    required this.projectId,
    required this.hash,
    required this.message,
  });

  @override
  State<_CommitDetailSheet> createState() => _CommitDetailSheetState();
}

class _CommitDetailSheetState extends State<_CommitDetailSheet> {
  List<dynamic> _files = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    try {
      final resp = await widget.api.git.getCommitFiles(
        widget.projectId,
        widget.hash,
      );
      if (mounted) {
        setState(() {
          _files = (resp['files'] ?? []) as List<dynamic>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shortHash = widget.hash.length > 7
        ? widget.hash.substring(0, 7)
        : widget.hash;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.3,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          shortHash,
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: widget.hash));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Copied'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.message,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _files.isEmpty
                  ? const Center(child: Text('No files changed'))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: _files.length,
                      itemBuilder: (context, index) {
                        final file = _files[index];
                        final status = file['status'] as String? ?? '';
                        final path = file['path'] as String? ?? '';
                        return ListTile(
                          dense: true,
                          leading: Container(
                            width: 24,
                            alignment: Alignment.center,
                            child: Text(
                              status,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _statusColor(status),
                              ),
                            ),
                          ),
                          title: Text(
                            path,
                            style: const TextStyle(
                              fontSize: 13,
                              fontFamily: 'monospace',
                            ),
                          ),
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              builder: (_) => _CommitFileDiffSheet(
                                api: widget.api,
                                projectId: widget.projectId,
                                hash: widget.hash,
                                path: path,
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'A':
        return Colors.green;
      case 'M':
        return Colors.orange;
      case 'D':
        return Colors.red;
      case 'R':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}

class _CommitFileDiffSheet extends StatefulWidget {
  final AppApiClient api;
  final String projectId;
  final String hash;
  final String path;
  const _CommitFileDiffSheet({
    required this.api,
    required this.projectId,
    required this.hash,
    required this.path,
  });

  @override
  State<_CommitFileDiffSheet> createState() => _CommitFileDiffSheetState();
}

class _CommitFileDiffSheetState extends State<_CommitFileDiffSheet> {
  String _content = '';
  bool _loading = true;
  bool _wrap = false;

  @override
  void initState() {
    super.initState();
    _loadDiff();
  }

  Future<void> _loadDiff() async {
    try {
      final resp = await widget.api.git.getCommitFileDiff(
        widget.projectId,
        widget.hash,
        widget.path,
      );
      if (mounted) {
        setState(() {
          _content = resp['content'] as String? ?? '';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _content = userFriendlyErrorMessage(e, action: '加载失败');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.3,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.code, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.path,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Tooltip(
                    message: _wrap ? 'No wrap' : 'Wrap',
                    child: IconButton(
                      icon: Icon(
                        _wrap ? Icons.wrap_text : Icons.horizontal_rule,
                        size: 18,
                      ),
                      onPressed: () => setState(() => _wrap = !_wrap),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _content));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Copied'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildContent(scrollController),
            ),
          ],
        );
      },
    );
  }

  Widget _buildContent(ScrollController scrollController) {
    final lines = _content.split('\n');
    final lineWidgets = <Widget>[];

    for (final line in lines) {
      Color bgColor;
      Color textColor = Colors.black87;
      FontWeight fontWeight = FontWeight.normal;

      if (line.startsWith('@@')) {
        bgColor = Colors.blue[50]!;
        textColor = Colors.blue[700]!;
        fontWeight = FontWeight.w500;
      } else if (line.startsWith('+')) {
        bgColor = Colors.green[50]!;
        textColor = Colors.green[900]!;
      } else if (line.startsWith('-')) {
        bgColor = Colors.red[50]!;
        textColor = Colors.red[900]!;
      } else if (line.startsWith('diff --git') ||
          line.startsWith('index ') ||
          line.startsWith('---') ||
          line.startsWith('+++')) {
        bgColor = Colors.grey[100]!;
        textColor = Colors.grey[700]!;
        fontWeight = FontWeight.w500;
      } else {
        bgColor = Colors.transparent;
      }

      lineWidgets.add(
        Container(
          color: bgColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
          child: Text(
            line.isEmpty ? ' ' : line,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: textColor,
              fontWeight: fontWeight,
            ),
            softWrap: _wrap,
          ),
        ),
      );
    }

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lineWidgets,
    );

    if (_wrap) {
      return SingleChildScrollView(
        controller: scrollController,
        child: content,
      );
    }
    return SingleChildScrollView(
      controller: scrollController,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: content,
      ),
    );
  }
}

// ==================== Branches Tab ====================

class _BranchesTab extends StatefulWidget {
  final AppApiClient api;
  final String projectId;
  const _BranchesTab({required this.api, required this.projectId});

  @override
  State<_BranchesTab> createState() => _BranchesTabState();
}

class _BranchesTabState extends State<_BranchesTab> {
  List<dynamic> _branches = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final branches = await widget.api.git.getBranches(widget.projectId);
      if (mounted) {
        setState(() {
          _branches = branches;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_branches.isEmpty) return const Center(child: Text('No branches'));

    return ListView.builder(
      itemCount: _branches.length,
      itemBuilder: (context, index) {
        final branch = _branches[index];
        final name = branch['name'] as String? ?? '';
        final isCurrent = branch['current'] as bool? ?? false;
        final isRemote =
            name.startsWith('origin/') || name.startsWith('remote/');

        return ListTile(
          leading: Icon(
            isCurrent
                ? Icons.check_circle
                : (isRemote ? Icons.cloud : Icons.account_tree),
            color: isCurrent
                ? Colors.green
                : (isRemote ? Colors.blue : Colors.grey),
            size: 20,
          ),
          title: Text(
            name,
            style: TextStyle(
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
          trailing: isCurrent
              ? Chip(
                  label: const Text('current', style: TextStyle(fontSize: 10)),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )
              : null,
        );
      },
    );
  }
}
