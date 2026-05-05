import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magent_app/core/api/error_messages.dart';
import 'package:magent_app/core/providers/app_settings_provider.dart';
import 'package:magent_app/core/repositories/file_repository.dart';
import 'package:magent_app/core/repositories/git_repository.dart';
import 'package:magent_app/core/theme/theme.dart';
import 'package:magent_app/l10n/app_localizations.dart';

class ProjectFilesTab extends StatefulWidget {
  final String projectId;
  final FileRepository file;
  final GitRepository git;

  const ProjectFilesTab({
    super.key,
    required this.projectId,
    required this.file,
    required this.git,
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
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final cached = await widget.file.getCachedDir(
        widget.projectId,
        _currentPath,
      );
      if (mounted && cached != null) {
        final cachedItems = (cached['items'] ?? []) as List<dynamic>;
        setState(() {
          _items.clear();
          _items.addAll(cachedItems.cast<Map<String, dynamic>>());
          _loading = false;
        });
      }
      final resp = await widget.file.listDir(widget.projectId, _currentPath);
      final items = (resp['items'] ?? []) as List<dynamic>;
      if (mounted) {
        setState(() {
          _items.clear();
          _items.addAll(items.cast<Map<String, dynamic>>());
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = localizedErrorMessage(AppLocalizations.of(context)!, e);
        });
      }
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
      await widget.git.pull(widget.projectId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.gitPullSuccessful),
            backgroundColor: AppStatusColors.of(context).running.foreground,
          ),
        );
        await _loadDir();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizedErrorMessage(
                AppLocalizations.of(context)!,
                e,
                action: AppLocalizations.of(context)!.gitPullFailed,
              ),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _pulling = false);
    }
  }

  Future<void> _push() async {
    try {
      await widget.git.push(widget.projectId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.gitPushSuccessful),
            backgroundColor: AppStatusColors.of(context).running.foreground,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizedErrorMessage(
                AppLocalizations.of(context)!,
                e,
                action: AppLocalizations.of(context)!.gitPushFailed,
              ),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _showGitLog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _GitLogSheet(
        git: widget.git,
        file: widget.file,
        projectId: widget.projectId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canGoUp = _pathStack.length > 1;
    final l10n = AppLocalizations.of(context)!;

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
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5))),
            ),
            child: Row(
              children: [
                if (canGoUp)
                  IconButton(
                    icon: const Icon(Icons.arrow_upward, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    onPressed: _navigateToRoot,
                    tooltip: l10n.gitRoot,
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
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                    label: Text(
                      l10n.gitLog,
                      style: const TextStyle(fontSize: 11),
                    ),
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
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 1.5),
                          )
                        : const Icon(Icons.download, size: 14),
                    label: Text(
                      l10n.gitPull,
                      style: const TextStyle(fontSize: 11),
                    ),
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
                    label: Text(
                      l10n.gitPush,
                      style: const TextStyle(fontSize: 11),
                    ),
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
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: (canGoUp ? 1 : 0) + _items.length,
                      itemBuilder: (context, index) {
                        if (canGoUp && index == 0) {
                          final parentLabel = _pathStack.length > 2
                              ? _pathStack[_pathStack.length - 2]
                              : '/';
                          return _FileRow(
                            icon: Icons.folder,
                            iconColor:
                                Theme.of(context).colorScheme.tertiary,
                            name: '..',
                            subtitle: parentLabel,
                            isDir: true,
                            onTap: _navigateBack,
                          );
                        }

                        final itemIndex = canGoUp ? index - 1 : index;
                        final item = _items[itemIndex];
                        final isDir = item['type'] == 'dir';
                        final name = item['name'] as String? ?? '';
                        final ext = name.contains('.')
                            ? name.split('.').last.toLowerCase()
                            : '';
                        final fileType = isDir ? null : _getFileType(ext);

                        return _FileRow(
                          icon: isDir
                              ? Icons.folder
                              : _getFileIcon(ext, fileType),
                          iconColor: isDir
                              ? Theme.of(context).colorScheme.tertiary
                              : _getFileColor(fileType),
                          name: name,
                          subtitle: isDir
                              ? null
                              : _formatSize(item['size'] as int? ?? 0),
                          isDir: isDir,
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
      final cached = await widget.file.getCachedRawFile(widget.projectId, path);
      var sheetShown = false;
      if (mounted && cached != null) {
        sheetShown = _showImageSheetFromRaw(path, cached);
      }
      final resp = await widget.file.readRawFile(widget.projectId, path);
      if (mounted && !sheetShown) {
        _showImageSheetFromRaw(path, resp);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          localizedErrorMessage(
            AppLocalizations.of(context)!,
            e,
            action: AppLocalizations.of(context)!.filesReadFailed,
          ),
        );
      }
    }
  }

  Future<void> _showMarkdownFile(String path) async {
    await _showRawTextFile(
      path,
      (notifier) => _MarkdownSheet(path: path, content: notifier),
    );
  }

  Future<void> _showCodeFile(String path, String lang) async {
    await _showRawTextFile(
      path,
      (notifier) => _CodeSheet(path: path, content: notifier, language: lang),
    );
  }

  bool _showImageSheetFromRaw(String path, Map<String, dynamic> raw) {
    final encoding = raw['encoding'] as String? ?? 'text';
    final data = raw['data'] as String? ?? '';
    final mime = raw['mime'] as String? ?? '';
    if (encoding != 'base64' || data.isEmpty) return false;
    final bytes = base64Decode(data);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ImageSheet(path: path, bytes: bytes, mime: mime),
    );
    return true;
  }

  Future<void> _showRawTextFile(
    String path,
    Widget Function(ValueListenable<String> content) builder,
  ) async {
    try {
      final cached = await widget.file.getCachedRawFile(widget.projectId, path);
      ValueNotifier<String>? contentNotifier;
      var sheetClosed = false;
      if (mounted && cached != null) {
        contentNotifier = ValueNotifier<String>(
          cached['data'] as String? ?? '',
        );
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => builder(contentNotifier!),
        ).whenComplete(() {
          sheetClosed = true;
          contentNotifier?.dispose();
        });
      }
      final resp = await widget.file.readRawFile(widget.projectId, path);
      final data = resp['data'] as String? ?? '';
      if (!mounted) return;
      if (contentNotifier != null) {
        if (!sheetClosed) contentNotifier.value = data;
      } else {
        final notifier = ValueNotifier<String>(data);
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => builder(notifier),
        ).whenComplete(notifier.dispose);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          localizedErrorMessage(
            AppLocalizations.of(context)!,
            e,
            action: AppLocalizations.of(context)!.filesReadFailed,
          ),
        );
      }
    }
  }

  Future<void> _showTextFile(String path) async {
    try {
      final cached = await widget.file.getCachedFile(widget.projectId, path);
      ValueNotifier<String>? contentNotifier;
      var sheetClosed = false;
      if (mounted && cached != null) {
        contentNotifier = ValueNotifier<String>(
          cached['content'] as String? ?? '',
        );
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => _TextFileSheet(path: path, content: contentNotifier!),
        ).whenComplete(() {
          sheetClosed = true;
          contentNotifier?.dispose();
        });
      }
      final resp = await widget.file.readFile(widget.projectId, path);
      final content = resp['content'] as String? ?? '';
      if (!mounted) return;
      if (contentNotifier != null) {
        if (!sheetClosed) contentNotifier.value = content;
      } else {
        final notifier = ValueNotifier<String>(content);
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => _TextFileSheet(path: path, content: notifier),
        ).whenComplete(notifier.dispose);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          localizedErrorMessage(
            AppLocalizations.of(context)!,
            e,
            action: AppLocalizations.of(context)!.filesReadFailed,
          ),
        );
      }
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  _FileType _getFileType(String ext) {
    const imageExts = {
      'png',
      'jpg',
      'jpeg',
      'gif',
      'bmp',
      'webp',
      'ico',
      'svg',
    };
    const markdownExts = {'md', 'markdown'};
    const codeExts = {
      'dart',
      'go',
      'js',
      'ts',
      'jsx',
      'tsx',
      'py',
      'java',
      'kt',
      'swift',
      'c',
      'cpp',
      'h',
      'hpp',
      'cs',
      'rs',
      'rb',
      'php',
      'sh',
      'bash',
      'zsh',
      'sql',
      'html',
      'css',
      'scss',
      'less',
      'xml',
      'yaml',
      'yml',
      'toml',
      'json',
      'ini',
      'cfg',
      'conf',
    };
    if (imageExts.contains(ext)) return _FileType.image;
    if (markdownExts.contains(ext)) return _FileType.markdown;
    if (codeExts.contains(ext)) return _FileType.code;
    return _FileType.text;
  }

  String _highlightLanguage(String ext) {
    const map = {
      'dart': 'dart',
      'go': 'go',
      'js': 'javascript',
      'ts': 'typescript',
      'jsx': 'javascript',
      'tsx': 'typescript',
      'py': 'python',
      'java': 'java',
      'kt': 'kotlin',
      'swift': 'swift',
      'c': 'c',
      'cpp': 'cpp',
      'h': 'c',
      'hpp': 'cpp',
      'cs': 'csharp',
      'rs': 'rust',
      'rb': 'ruby',
      'php': 'php',
      'sh': 'bash',
      'bash': 'bash',
      'zsh': 'bash',
      'sql': 'sql',
      'html': 'html',
      'css': 'css',
      'scss': 'scss',
      'xml': 'xml',
      'yaml': 'yaml',
      'yml': 'yaml',
      'toml': 'ini',
      'json': 'json',
    };
    return map[ext] ?? 'plaintext';
  }

  IconData _getFileIcon(String ext, _FileType? type) {
    if (type == _FileType.image) return Icons.image;
    if (type == _FileType.markdown) return Icons.description;
    if (type == _FileType.code) {
      switch (ext) {
        case 'dart':
          return Icons.code;
        case 'go':
          return Icons.code;
        case 'js':
        case 'ts':
        case 'jsx':
        case 'tsx':
          return Icons.javascript;
        case 'json':
          return Icons.data_object;
        case 'yaml':
        case 'yml':
          return Icons.settings;
        default:
          return Icons.code;
      }
    }
    return Icons.insert_drive_file;
  }

  Color? _getFileColor(_FileType? type) {
    final scheme = Theme.of(context).colorScheme;
    final statusColors = AppStatusColors.of(context);
    if (type == _FileType.image) return statusColors.running.foreground;
    if (type == _FileType.markdown) return scheme.tertiary;
    if (type == _FileType.code) return statusColors.info.foreground;
    return scheme.onSurfaceVariant;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// 紧凑且垂直居中的文件/目录行。固定高度 44，title 与 subtitle 整体居中。
class _FileRow extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String name;
  final String? subtitle;
  final bool isDir;
  final VoidCallback onTap;

  const _FileRow({
    required this.icon,
    required this.name,
    required this.isDir,
    required this.onTap,
    this.iconColor,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.2,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.2,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isDir)
              Icon(
                Icons.chevron_right,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}

/// 文件查看器 Sheet 顶栏专用的紧凑图标按钮：32×32 触摸区、无 padding，
/// 让多按钮组合在窄屏也能完整显示。
class _ViewerToolbarButton extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback? onPressed;

  const _ViewerToolbarButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final btn = IconButton(
      icon: Icon(icon, size: 18),
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      splashRadius: 18,
    );
    if (tooltip == null) return btn;
    return Tooltip(message: tooltip!, child: btn);
  }
}

// --- Git Log Sheet ---

class _GitLogSheet extends StatefulWidget {
  final GitRepository git;
  final FileRepository file;
  final String projectId;

  const _GitLogSheet({
    required this.git,
    required this.file,
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
      final commits = await widget.git.getLog(
        widget.projectId,
        limit: 30,
        offset: _offset,
      );
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
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.history, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context)!.gitCommitLog,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
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
                  : _commits.isEmpty
                  ? Center(
                      child: Text(AppLocalizations.of(context)!.gitNoCommits),
                    )
                  : NotificationListener<ScrollNotification>(
                      onNotification: (n) {
                        if (n is ScrollEndNotification &&
                            n.metrics.pixels >=
                                n.metrics.maxScrollExtent - 200 &&
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
                          final timestamp =
                              commit['timestamp'] as String? ?? '';
                          final shortHash = hash.length > 7
                              ? hash.substring(0, 7)
                              : hash;

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
                              style: const TextStyle(fontSize: 13),
                            ),
                            subtitle: Text(
                              '$author · $shortHash',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: Text(
                              _formatTime(timestamp),
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
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
      return AppLocalizations.of(context)!.timeNow;
    } catch (_) {
      return timestamp;
    }
  }

  void _openCommitDetail(String hash, String message) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CommitDetailSheet2(
        git: widget.git,
        file: widget.file,
        projectId: widget.projectId,
        hash: hash,
        message: message,
      ),
    );
  }
}

class _CommitDetailSheet2 extends StatefulWidget {
  final GitRepository git;
  final FileRepository file;
  final String projectId;
  final String hash;
  final String message;

  const _CommitDetailSheet2({
    required this.git,
    required this.file,
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
      final resp = await widget.git.getCommitFiles(
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
                border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5))),
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
                            SnackBar(
                              content: Text(
                                AppLocalizations.of(context)!.copied,
                              ),
                              duration: const Duration(seconds: 1),
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
                  ? Center(
                      child: Text(
                        AppLocalizations.of(context)!.gitNoFilesChanged,
                      ),
                    )
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
    final statusColors = AppStatusColors.of(context);
    switch (status) {
      case 'A':
        return statusColors.running.foreground;
      case 'M':
        return statusColors.warning.foreground;
      case 'D':
        return statusColors.error.foreground;
      case 'R':
        return statusColors.info.foreground;
      default:
        return statusColors.neutral.foreground;
    }
  }

  void _openFileDiff(String path) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CommitFileDiffSheet2(
        git: widget.git,
        projectId: widget.projectId,
        hash: widget.hash,
        path: path,
      ),
    );
  }
}

class _CommitFileDiffSheet2 extends StatefulWidget {
  final GitRepository git;
  final String projectId;
  final String hash;
  final String path;

  const _CommitFileDiffSheet2({
    required this.git,
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
      final resp = await widget.git.getCommitFileDiff(
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
          _content = localizedErrorMessage(
            AppLocalizations.of(context)!,
            e,
            action: AppLocalizations.of(context)!.filesLoadFailed,
          );
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
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.code, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.path,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _ViewerToolbarButton(
                    tooltip: _wrap
                        ? AppLocalizations.of(context)!.noWrap
                        : AppLocalizations.of(context)!.wrap,
                    icon: _wrap ? Icons.wrap_text : Icons.horizontal_rule,
                    onPressed: () => setState(() => _wrap = !_wrap),
                  ),
                  _ViewerToolbarButton(
                    icon: Icons.copy,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _content));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(AppLocalizations.of(context)!.copied),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                  _ViewerToolbarButton(
                    icon: Icons.close,
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
    final scheme = Theme.of(context).colorScheme;
    final statusColors = AppStatusColors.of(context);
    final lines = _content.split('\n');
    final lineWidgets = <Widget>[];
    for (final line in lines) {
      Color bgColor;
      Color textColor = scheme.onSurface;
      FontWeight fontWeight = FontWeight.normal;
      if (line.startsWith('@@')) {
        bgColor = statusColors.info.background;
        textColor = statusColors.info.foreground;
        fontWeight = FontWeight.w600;
      } else if (line.startsWith('+')) {
        bgColor = statusColors.running.background;
        textColor = statusColors.running.foreground;
      } else if (line.startsWith('-')) {
        bgColor = statusColors.error.background;
        textColor = statusColors.error.foreground;
      } else if (line.startsWith('diff --git') ||
          line.startsWith('index ') ||
          line.startsWith('---') ||
          line.startsWith('+++')) {
        bgColor = scheme.surfaceContainerHigh;
        textColor = scheme.onSurfaceVariant;
        fontWeight = FontWeight.w600;
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

enum _FileType { image, markdown, code, text }

// --- File viewer sheets (reused from original file_browser_page.dart) ---

class _ImageSheet extends StatelessWidget {
  final String path;
  final Uint8List bytes;
  final String mime;
  const _ImageSheet({
    required this.path,
    required this.bytes,
    required this.mime,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      minChildSize: 0.3,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            _header(context),
            Expanded(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 5.0,
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
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          const Icon(Icons.image, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              path,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            '${(bytes.length / 1024).toStringAsFixed(1)} KB',
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class _MarkdownSheet extends ConsumerStatefulWidget {
  final String path;
  final ValueListenable<String> content;
  const _MarkdownSheet({required this.path, required this.content});

  @override
  ConsumerState<_MarkdownSheet> createState() => _MarkdownSheetState();
}

class _MarkdownSheetState extends ConsumerState<_MarkdownSheet> {
  /// 默认渲染模式；切换为 true 后以源码（带高亮）显示，参考代码查看体验。
  bool _sourceMode = false;
  bool _wrap = false;

  @override
  Widget build(BuildContext context) {
    final fontScale = ref
        .watch(viewerFontScaleControllerProvider)
        .maybeWhen(data: (v) => v, orElse: () => 1.0);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      minChildSize: 0.3,
      expand: false,
      builder: (context, scrollController) {
        return ValueListenableBuilder<String>(
          valueListenable: widget.content,
          builder: (context, value, _) {
            return Column(
              children: [
                _header(context, value),
                Expanded(
                  child: _sourceMode
                      ? _buildSource(value, scrollController, fontScale, isDark)
                      : Markdown(
                          data: value,
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSource(
    String content,
    ScrollController scrollController,
    double fontScale,
    bool isDark,
  ) {
    final codeView = HighlightView(
      content,
      language: 'markdown',
      theme: isDark ? atomOneDarkTheme : githubTheme,
      padding: const EdgeInsets.all(16),
      textStyle: TextStyle(
        fontFamily: 'monospace',
        fontSize: 12 * fontScale,
        height: 1.45,
      ),
    );
    return _wrap
        ? SingleChildScrollView(
            controller: scrollController,
            child: codeView,
          )
        : SingleChildScrollView(
            controller: scrollController,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: codeView,
            ),
          );
  }

  Widget _header(BuildContext context, String content) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.description, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.path,
              style: const TextStyle(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _ViewerToolbarButton(
            tooltip: _sourceMode ? l10n.viewerRenderMode : l10n.viewerSourceMode,
            icon: _sourceMode ? Icons.visibility : Icons.code,
            onPressed: () => setState(() => _sourceMode = !_sourceMode),
          ),
          if (_sourceMode)
            _ViewerToolbarButton(
              tooltip: _wrap ? l10n.noWrap : l10n.wrap,
              icon: _wrap ? Icons.wrap_text : Icons.horizontal_rule,
              onPressed: () => setState(() => _wrap = !_wrap),
            ),
          _ViewerToolbarButton(
            icon: Icons.copy,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: content));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.copied),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
          _ViewerToolbarButton(
            icon: Icons.close,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class _CodeSheet extends ConsumerStatefulWidget {
  final String path;
  final ValueListenable<String> content;
  final String language;
  const _CodeSheet({
    required this.path,
    required this.content,
    required this.language,
  });

  @override
  ConsumerState<_CodeSheet> createState() => _CodeSheetState();
}

class _CodeSheetState extends ConsumerState<_CodeSheet> {
  bool _wrap = false;

  @override
  Widget build(BuildContext context) {
    final fontScale = ref
        .watch(viewerFontScaleControllerProvider)
        .maybeWhen(data: (v) => v, orElse: () => 1.0);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      minChildSize: 0.3,
      expand: false,
      builder: (context, scrollController) {
        return ValueListenableBuilder<String>(
          valueListenable: widget.content,
          builder: (context, content, _) {
            final codeView = HighlightView(
              content,
              language: widget.language,
              theme: isDark ? atomOneDarkTheme : githubTheme,
              padding: const EdgeInsets.all(16),
              textStyle: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12 * fontScale,
                height: 1.45,
              ),
            );
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.code, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.path,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppStatusColors.of(context).info.background,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.language,
                          style: TextStyle(
                            fontSize: 10,
                            color: AppStatusColors.of(context).info.foreground,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      _ViewerToolbarButton(
                        tooltip: _wrap
                            ? AppLocalizations.of(context)!.noWrap
                            : AppLocalizations.of(context)!.wrap,
                        icon: _wrap ? Icons.wrap_text : Icons.horizontal_rule,
                        onPressed: () => setState(() => _wrap = !_wrap),
                      ),
                      _ViewerToolbarButton(
                        icon: Icons.copy,
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: content));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                AppLocalizations.of(context)!.copied,
                              ),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                      _ViewerToolbarButton(
                        icon: Icons.close,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _wrap
                      ? SingleChildScrollView(
                          controller: scrollController,
                          child: codeView,
                        )
                      : SingleChildScrollView(
                          controller: scrollController,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: codeView,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _TextFileSheet extends ConsumerStatefulWidget {
  final String path;
  final ValueListenable<String> content;
  const _TextFileSheet({required this.path, required this.content});

  @override
  ConsumerState<_TextFileSheet> createState() => _TextFileSheetState();
}

class _TextFileSheetState extends ConsumerState<_TextFileSheet> {
  bool _wrap = false;

  @override
  Widget build(BuildContext context) {
    final fontScale = ref
        .watch(viewerFontScaleControllerProvider)
        .maybeWhen(data: (v) => v, orElse: () => 1.0);
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      minChildSize: 0.3,
      expand: false,
      builder: (context, scrollController) {
        return ValueListenableBuilder<String>(
          valueListenable: widget.content,
          builder: (context, content, _) {
            final textView = SelectableText(
              content,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12 * fontScale,
                height: 1.45,
              ),
            );
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.description, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.path,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _ViewerToolbarButton(
                        tooltip: _wrap
                            ? AppLocalizations.of(context)!.noWrap
                            : AppLocalizations.of(context)!.wrap,
                        icon: _wrap ? Icons.wrap_text : Icons.horizontal_rule,
                        onPressed: () => setState(() => _wrap = !_wrap),
                      ),
                      _ViewerToolbarButton(
                        icon: Icons.copy,
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: content));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                AppLocalizations.of(context)!.copied,
                              ),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                      _ViewerToolbarButton(
                        icon: Icons.close,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _wrap
                      ? SingleChildScrollView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          child: textView,
                        )
                      : SingleChildScrollView(
                          controller: scrollController,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.all(16),
                            child: textView,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
