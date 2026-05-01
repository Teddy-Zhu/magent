import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:magent_app/core/api/git_api.dart';
import 'package:magent_app/core/api/file_api.dart';

class ProjectFilesTab extends StatefulWidget {
  final String projectId;
  final FileApi fileApi;
  final GitApi gitApi;

  const ProjectFilesTab({
    super.key,
    required this.projectId,
    required this.fileApi,
    required this.gitApi,
  });

  @override
  State<ProjectFilesTab> createState() => _ProjectFilesTabState();
}

class _ProjectFilesTabState extends State<ProjectFilesTab> {
  final List<String> _pathStack = [''];
  final List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String _error = '';
  bool _pulling = false;

  String get _currentPath => _pathStack.last;

  @override
  void initState() {
    super.initState();
    _loadDir();
  }

  Future<void> _loadDir() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final resp = await widget.fileApi.listDir(widget.projectId, _currentPath);
      final items = (resp['items'] ?? []) as List<dynamic>;
      if (mounted) {
        setState(() {
          _items.clear();
          _items.addAll(items.cast<Map<String, dynamic>>());
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = '$e'; });
    }
  }

  void _navigateToDir(String name) {
    setState(() {
      _pathStack.add(_currentPath.isEmpty ? name : '$_currentPath/$name');
    });
    _loadDir();
  }

  void _navigateBack() {
    if (_pathStack.length > 1) {
      setState(() => _pathStack.removeLast());
      _loadDir();
    }
  }

  void _navigateToRoot() {
    if (_pathStack.length > 1) {
      setState(() {
        _pathStack.clear();
        _pathStack.add('');
      });
      _loadDir();
    }
  }

  Future<void> _pull() async {
    setState(() => _pulling = true);
    try {
      // Use git pull via the git API - we need to call pull through a generic git endpoint
      // For now, show a message that pull is coming
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pull not yet implemented on agent')),
        );
      }
    } finally {
      if (mounted) setState(() => _pulling = false);
    }
  }

  Future<void> _push() async {
    try {
      await widget.gitApi.push(widget.projectId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Push successful'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Push failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showGitLog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _GitLogSheet(
        gitApi: widget.gitApi,
        fileApi: widget.fileApi,
        projectId: widget.projectId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canGoUp = _pathStack.length > 1;

    return PopScope(
      canPop: !canGoUp,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && canGoUp) _navigateBack();
      },
      child: Column(
        children: [
          // Path bar + actions
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                if (canGoUp)
                  IconButton(
                    icon: const Icon(Icons.arrow_upward, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: _navigateToRoot,
                    tooltip: 'Root',
                  ),
                const SizedBox(width: 4),
                Expanded(
                  child: GestureDetector(
                    onTap: canGoUp ? _navigateToRoot : null,
                    child: Text(
                      _currentPath.isEmpty ? '/' : _currentPath,
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'monospace',
                        color: Colors.grey[700],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                // Log button
                SizedBox(
                  height: 30,
                  child: OutlinedButton.icon(
                    onPressed: () => _showGitLog(context),
                    icon: const Icon(Icons.history, size: 14),
                    label: const Text('Log', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Pull button
                SizedBox(
                  height: 30,
                  child: OutlinedButton.icon(
                    onPressed: _pulling ? null : _pull,
                    icon: _pulling
                        ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5))
                        : const Icon(Icons.download, size: 14),
                    label: const Text('Pull', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Push button
                SizedBox(
                  height: 30,
                  child: OutlinedButton.icon(
                    onPressed: _push,
                    icon: const Icon(Icons.upload, size: 14),
                    label: const Text('Push', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // File list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                    ? Center(child: Text(_error))
                    : RefreshIndicator(
                        onRefresh: _loadDir,
                        child: ListView.builder(
                          itemCount: (canGoUp ? 1 : 0) + _items.length,
                          itemBuilder: (context, index) {
                            if (canGoUp && index == 0) {
                              return ListTile(
                                leading: const Icon(Icons.folder, color: Colors.amber, size: 22),
                                title: const Text('..', style: TextStyle(fontWeight: FontWeight.w500)),
                                subtitle: Text(
                                  _pathStack.length > 2 ? _pathStack[_pathStack.length - 2] : '/',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                dense: true,
                                onTap: _navigateBack,
                              );
                            }

                            final itemIndex = canGoUp ? index - 1 : index;
                            final item = _items[itemIndex];
                            final isDir = item['type'] == 'dir';
                            final name = item['name'] as String? ?? '';
                            final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
                            final fileType = isDir ? null : _getFileType(ext);

                            return ListTile(
                              leading: Icon(
                                isDir ? Icons.folder : _getFileIcon(ext, fileType),
                                color: isDir ? Colors.amber : _getFileColor(fileType),
                                size: 22,
                              ),
                              title: Text(name, style: const TextStyle(fontSize: 13)),
                              subtitle: isDir
                                  ? null
                                  : Text(_formatSize(item['size'] as int? ?? 0),
                                      style: const TextStyle(fontSize: 11)),
                              trailing: isDir ? const Icon(Icons.chevron_right, size: 18) : null,
                              dense: true,
                              onTap: () {
                                if (isDir) {
                                  _navigateToDir(name);
                                } else {
                                  _openFile(name);
                                }
                              },
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  void _openFile(String name) {
    final filePath = _currentPath.isEmpty ? name : '$_currentPath/$name';
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    final fileType = _getFileType(ext);

    if (fileType == _FileType.image) {
      _showImageFile(filePath);
    } else if (fileType == _FileType.markdown) {
      _showMarkdownFile(filePath);
    } else if (fileType == _FileType.code) {
      _showCodeFile(filePath, _highlightLanguage(ext));
    } else {
      _showTextFile(filePath);
    }
  }

  Future<void> _showImageFile(String path) async {
    try {
      final resp = await widget.fileApi.readRawFile(widget.projectId, path);
      final encoding = resp['encoding'] as String? ?? 'text';
      final data = resp['data'] as String? ?? '';
      final mime = resp['mime'] as String? ?? '';

      if (mounted && encoding == 'base64') {
        final bytes = base64Decode(data);
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => _ImageSheet(path: path, bytes: bytes, mime: mime),
        );
      }
    } catch (e) {
      if (mounted) _showSnackBar('Read failed: $e');
    }
  }

  Future<void> _showMarkdownFile(String path) async {
    try {
      final resp = await widget.fileApi.readRawFile(widget.projectId, path);
      final data = resp['data'] as String? ?? '';
      if (mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => _MarkdownSheet(path: path, content: data),
        );
      }
    } catch (e) {
      if (mounted) _showSnackBar('Read failed: $e');
    }
  }

  Future<void> _showCodeFile(String path, String lang) async {
    try {
      final resp = await widget.fileApi.readRawFile(widget.projectId, path);
      final data = resp['data'] as String? ?? '';
      if (mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => _CodeSheet(path: path, content: data, language: lang),
        );
      }
    } catch (e) {
      if (mounted) _showSnackBar('Read failed: $e');
    }
  }

  Future<void> _showTextFile(String path) async {
    try {
      final resp = await widget.fileApi.readFile(widget.projectId, path);
      final content = resp['content'] as String? ?? '';
      if (mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => _TextFileSheet(path: path, content: content),
        );
      }
    } catch (e) {
      if (mounted) _showSnackBar('Read failed: $e');
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  _FileType _getFileType(String ext) {
    const imageExts = {'png', 'jpg', 'jpeg', 'gif', 'bmp', 'webp', 'ico', 'svg'};
    const markdownExts = {'md', 'markdown'};
    const codeExts = {
      'dart', 'go', 'js', 'ts', 'jsx', 'tsx', 'py', 'java', 'kt', 'swift',
      'c', 'cpp', 'h', 'hpp', 'cs', 'rs', 'rb', 'php', 'sh', 'bash', 'zsh',
      'sql', 'html', 'css', 'scss', 'less', 'xml', 'yaml', 'yml', 'toml',
      'json', 'ini', 'cfg', 'conf',
    };
    if (imageExts.contains(ext)) return _FileType.image;
    if (markdownExts.contains(ext)) return _FileType.markdown;
    if (codeExts.contains(ext)) return _FileType.code;
    return _FileType.text;
  }

  String _highlightLanguage(String ext) {
    const map = {
      'dart': 'dart', 'go': 'go', 'js': 'javascript', 'ts': 'typescript',
      'jsx': 'javascript', 'tsx': 'typescript', 'py': 'python', 'java': 'java',
      'kt': 'kotlin', 'swift': 'swift', 'c': 'c', 'cpp': 'cpp', 'h': 'c',
      'hpp': 'cpp', 'cs': 'csharp', 'rs': 'rust', 'rb': 'ruby', 'php': 'php',
      'sh': 'bash', 'bash': 'bash', 'zsh': 'bash', 'sql': 'sql',
      'html': 'html', 'css': 'css', 'scss': 'scss', 'xml': 'xml',
      'yaml': 'yaml', 'yml': 'yaml', 'toml': 'ini', 'json': 'json',
    };
    return map[ext] ?? 'plaintext';
  }

  IconData _getFileIcon(String ext, _FileType? type) {
    if (type == _FileType.image) return Icons.image;
    if (type == _FileType.markdown) return Icons.description;
    if (type == _FileType.code) {
      switch (ext) {
        case 'dart': return Icons.code;
        case 'go': return Icons.code;
        case 'js': case 'ts': case 'jsx': case 'tsx': return Icons.javascript;
        case 'json': return Icons.data_object;
        case 'yaml': case 'yml': return Icons.settings;
        default: return Icons.code;
      }
    }
    return Icons.insert_drive_file;
  }

  Color? _getFileColor(_FileType? type) {
    if (type == _FileType.image) return Colors.green;
    if (type == _FileType.markdown) return Colors.purple;
    if (type == _FileType.code) return Colors.blue;
    return Colors.grey;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// --- Git Log Sheet ---

class _GitLogSheet extends StatefulWidget {
  final GitApi gitApi;
  final FileApi fileApi;
  final String projectId;

  const _GitLogSheet({
    required this.gitApi,
    required this.fileApi,
    required this.projectId,
  });

  @override
  State<_GitLogSheet> createState() => _GitLogSheetState();
}

class _GitLogSheetState extends State<_GitLogSheet> {
  final List<dynamic> _commits = [];
  bool _loading = true;
  int _offset = 0;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadCommits();
  }

  Future<void> _loadCommits() async {
    try {
      final commits = await widget.gitApi.getLog(widget.projectId, limit: 30, offset: _offset);
      if (mounted) {
        setState(() {
          _commits.addAll(commits);
          _hasMore = commits.length >= 30;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[300]!))),
              child: Row(
                children: [
                  const Icon(Icons.history, size: 18),
                  const SizedBox(width: 8),
                  const Text('Commit Log', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _commits.isEmpty
                      ? const Center(child: Text('No commits'))
                      : NotificationListener<ScrollNotification>(
                          onNotification: (n) {
                            if (n is ScrollEndNotification &&
                                n.metrics.pixels >= n.metrics.maxScrollExtent - 200 &&
                                _hasMore) {
                              _offset += 30;
                              _loadCommits();
                            }
                            return false;
                          },
                          child: ListView.builder(
                            controller: scrollController,
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
                                  width: 10, height: 10,
                                  margin: const EdgeInsets.only(top: 6),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                title: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                                subtitle: Text('$author · $shortHash', style: const TextStyle(fontSize: 11)),
                                trailing: Text(_formatTime(timestamp), style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                onTap: () => _openCommitDetail(hash, message),
                              );
                            },
                          ),
                        ),
            ),
          ],
        );
      },
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

  void _openCommitDetail(String hash, String message) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CommitDetailSheet2(
        gitApi: widget.gitApi,
        fileApi: widget.fileApi,
        projectId: widget.projectId,
        hash: hash,
        message: message,
      ),
    );
  }
}

class _CommitDetailSheet2 extends StatefulWidget {
  final GitApi gitApi;
  final FileApi fileApi;
  final String projectId;
  final String hash;
  final String message;

  const _CommitDetailSheet2({
    required this.gitApi,
    required this.fileApi,
    required this.projectId,
    required this.hash,
    required this.message,
  });

  @override
  State<_CommitDetailSheet2> createState() => _CommitDetailSheet2State();
}

class _CommitDetailSheet2State extends State<_CommitDetailSheet2> {
  List<dynamic> _files = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    try {
      final resp = await widget.gitApi.getCommitFiles(widget.projectId, widget.hash);
      if (mounted) setState(() { _files = (resp['files'] ?? []) as List<dynamic>; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shortHash = widget.hash.length > 7 ? widget.hash.substring(0, 7) : widget.hash;

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
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[300]!))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(shortHash, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: widget.hash));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1)));
                        },
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(widget.message, style: const TextStyle(fontWeight: FontWeight.w500)),
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
                                child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _statusColor(status))),
                              ),
                              title: Text(path, style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
                              onTap: () => _openFileDiff(path),
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
      case 'A': return Colors.green;
      case 'M': return Colors.orange;
      case 'D': return Colors.red;
      case 'R': return Colors.blue;
      default: return Colors.grey;
    }
  }

  void _openFileDiff(String path) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CommitFileDiffSheet2(
        gitApi: widget.gitApi,
        projectId: widget.projectId,
        hash: widget.hash,
        path: path,
      ),
    );
  }
}

class _CommitFileDiffSheet2 extends StatefulWidget {
  final GitApi gitApi;
  final String projectId;
  final String hash;
  final String path;

  const _CommitFileDiffSheet2({
    required this.gitApi,
    required this.projectId,
    required this.hash,
    required this.path,
  });

  @override
  State<_CommitFileDiffSheet2> createState() => _CommitFileDiffSheet2State();
}

class _CommitFileDiffSheet2State extends State<_CommitFileDiffSheet2> {
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
      final resp = await widget.gitApi.getCommitFileDiff(widget.projectId, widget.hash, widget.path);
      if (mounted) setState(() { _content = resp['content'] as String? ?? ''; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _content = 'Failed to load: $e'; });
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
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[300]!))),
              child: Row(
                children: [
                  const Icon(Icons.code, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(widget.path, style: const TextStyle(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                  Tooltip(
                    message: _wrap ? 'No wrap' : 'Wrap',
                    child: IconButton(
                      icon: Icon(_wrap ? Icons.wrap_text : Icons.horizontal_rule, size: 18),
                      onPressed: () => setState(() => _wrap = !_wrap),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _content));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1)));
                    },
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
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
        bgColor = Colors.blue[50]!; textColor = Colors.blue[700]!; fontWeight = FontWeight.w500;
      } else if (line.startsWith('+')) {
        bgColor = Colors.green[50]!; textColor = Colors.green[900]!;
      } else if (line.startsWith('-')) {
        bgColor = Colors.red[50]!; textColor = Colors.red[900]!;
      } else if (line.startsWith('diff --git') || line.startsWith('index ') || line.startsWith('---') || line.startsWith('+++')) {
        bgColor = Colors.grey[100]!; textColor = Colors.grey[700]!; fontWeight = FontWeight.w500;
      } else {
        bgColor = Colors.transparent;
      }
      lineWidgets.add(Container(
        color: bgColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
        child: Text(line.isEmpty ? ' ' : line, style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: textColor, fontWeight: fontWeight), softWrap: _wrap),
      ));
    }
    final content = Column(crossAxisAlignment: CrossAxisAlignment.start, children: lineWidgets);
    if (_wrap) return SingleChildScrollView(controller: scrollController, child: content);
    return SingleChildScrollView(controller: scrollController, child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: content));
  }
}

enum _FileType { image, markdown, code, text }

// --- File viewer sheets (reused from original file_browser_page.dart) ---

class _ImageSheet extends StatelessWidget {
  final String path;
  final Uint8List bytes;
  final String mime;
  const _ImageSheet({required this.path, required this.bytes, required this.mime});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8, maxChildSize: 0.95, minChildSize: 0.3, expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            _header(context),
            Expanded(
              child: InteractiveViewer(
                minScale: 0.5, maxScale: 5.0,
                child: Center(child: Image.memory(bytes, fit: BoxFit.contain)),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[300]!))),
      child: Row(
        children: [
          const Icon(Icons.image, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(path, style: const TextStyle(fontWeight: FontWeight.w500))),
          Text('${(bytes.length / 1024).toStringAsFixed(1)} KB', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }
}

class _MarkdownSheet extends StatelessWidget {
  final String path;
  final String content;
  const _MarkdownSheet({required this.path, required this.content});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8, maxChildSize: 0.95, minChildSize: 0.3, expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            _header(context),
            Expanded(child: Markdown(data: content, controller: scrollController, padding: const EdgeInsets.all(16))),
          ],
        );
      },
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[300]!))),
      child: Row(
        children: [
          const Icon(Icons.description, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(path, style: const TextStyle(fontWeight: FontWeight.w500))),
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }
}

class _CodeSheet extends StatefulWidget {
  final String path;
  final String content;
  final String language;
  const _CodeSheet({required this.path, required this.content, required this.language});

  @override
  State<_CodeSheet> createState() => _CodeSheetState();
}

class _CodeSheetState extends State<_CodeSheet> {
  bool _wrap = false;

  @override
  Widget build(BuildContext context) {
    final codeView = HighlightView(
      widget.content, language: widget.language, theme: githubTheme,
      padding: const EdgeInsets.all(16),
      textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 12),
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.8, maxChildSize: 0.95, minChildSize: 0.3, expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[300]!))),
              child: Row(
                children: [
                  const Icon(Icons.code, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(widget.path, style: const TextStyle(fontWeight: FontWeight.w500))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
                    child: Text(widget.language, style: TextStyle(fontSize: 10, color: Colors.blue[700])),
                  ),
                  Tooltip(
                    message: _wrap ? 'No wrap' : 'Wrap',
                    child: IconButton(
                      icon: Icon(_wrap ? Icons.wrap_text : Icons.horizontal_rule, size: 18),
                      onPressed: () => setState(() => _wrap = !_wrap),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: widget.content));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1)));
                    },
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Expanded(
              child: _wrap
                  ? SingleChildScrollView(controller: scrollController, child: codeView)
                  : SingleChildScrollView(
                      controller: scrollController,
                      child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: codeView),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _TextFileSheet extends StatefulWidget {
  final String path;
  final String content;
  const _TextFileSheet({required this.path, required this.content});

  @override
  State<_TextFileSheet> createState() => _TextFileSheetState();
}

class _TextFileSheetState extends State<_TextFileSheet> {
  bool _wrap = false;

  @override
  Widget build(BuildContext context) {
    final textView = SelectableText(
      widget.content,
      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.8, maxChildSize: 0.95, minChildSize: 0.3, expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[300]!))),
              child: Row(
                children: [
                  const Icon(Icons.description, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(widget.path, style: const TextStyle(fontWeight: FontWeight.w500))),
                  Tooltip(
                    message: _wrap ? 'No wrap' : 'Wrap',
                    child: IconButton(
                      icon: Icon(_wrap ? Icons.wrap_text : Icons.horizontal_rule, size: 18),
                      onPressed: () => setState(() => _wrap = !_wrap),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: widget.content));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1)));
                    },
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Expanded(
              child: _wrap
                  ? SingleChildScrollView(controller: scrollController, padding: const EdgeInsets.all(16), child: textView)
                  : SingleChildScrollView(
                      controller: scrollController,
                      child: SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(16), child: textView),
                    ),
            ),
          ],
        );
      },
    );
  }
}
