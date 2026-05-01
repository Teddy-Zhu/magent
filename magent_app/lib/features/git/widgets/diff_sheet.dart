import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:magent_app/core/api/error_messages.dart';
import 'package:magent_app/core/repositories/file_repository.dart';
import 'package:magent_app/core/repositories/git_repository.dart';

/// Shared bottom sheet for displaying git diff content.
/// Handles text diffs, images, and binary files.
class DiffSheet extends StatefulWidget {
  final GitRepository git;
  final FileRepository? file;
  final String projectId;
  final String path;
  final String diffHash;
  final bool isBinary;
  final bool staged;

  const DiffSheet({
    super.key,
    required this.git,
    this.file,
    required this.projectId,
    required this.path,
    required this.diffHash,
    this.isBinary = false,
    this.staged = false,
  });

  static Future<void> show({
    required BuildContext context,
    required GitRepository git,
    FileRepository? file,
    required String projectId,
    required String path,
    required String diffHash,
    bool isBinary = false,
    bool staged = false,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DiffSheet(
        git: git,
        file: file,
        projectId: projectId,
        path: path,
        diffHash: diffHash,
        isBinary: isBinary,
        staged: staged,
      ),
    );
  }

  @override
  State<DiffSheet> createState() => _DiffSheetState();
}

class _DiffSheetState extends State<DiffSheet> {
  static const _pageSize = 200;

  List<Map<String, dynamic>> _lines = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  bool _wrap = false;
  String _error = '';
  Uint8List? _imageBytes;
  int _nextOffset = 0;
  int _totalLines = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // For image files, load as raw image
    if (_isImageFile(widget.path)) {
      await _loadImage();
      return;
    }
    // For binary files, show a message
    if (widget.isBinary) {
      setState(() {
        _loading = false;
        _error = 'Binary file - cannot display diff';
      });
      return;
    }
    // For text files, load diff
    await _loadDiff();
  }

  bool _isImageFile(String path) {
    final ext = path.contains('.') ? path.split('.').last.toLowerCase() : '';
    return {
      'png',
      'jpg',
      'jpeg',
      'gif',
      'bmp',
      'webp',
      'ico',
      'svg',
    }.contains(ext);
  }

  Future<void> _loadImage() async {
    if (widget.file == null) {
      setState(() {
        _loading = false;
        _error = 'Cannot display image - no file API';
      });
      return;
    }
    try {
      final resp = await widget.file!.readRawFile(
        widget.projectId,
        widget.path,
      );
      final encoding = resp['encoding'] as String? ?? 'text';
      final data = resp['data'] as String? ?? '';
      if (mounted) {
        if (encoding == 'base64' && data.isNotEmpty) {
          setState(() {
            _imageBytes = base64Decode(data);
            _loading = false;
          });
        } else {
          setState(() {
            _loading = false;
            _error = 'Image data not available';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = userFriendlyErrorMessage(e, action: '加载图片失败');
        });
      }
    }
  }

  Future<void> _loadDiff() async {
    try {
      final resp = await widget.git.getFileDiff(
        widget.projectId,
        widget.path,
        widget.diffHash,
        offset: 0,
        limit: _pageSize,
        staged: widget.staged,
      );
      final lines = (resp['lines'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      final offset = resp['offset'] as int? ?? 0;
      final total = resp['total_lines'] as int? ?? lines.length;
      if (mounted) {
        setState(() {
          _lines = lines;
          _nextOffset = offset + lines.length;
          _totalLines = total;
          _hasMore = _nextOffset < total;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = userFriendlyErrorMessage(e, action: '加载 Diff 失败');
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final resp = await widget.git.getFileDiff(
        widget.projectId,
        widget.path,
        widget.diffHash,
        offset: _nextOffset,
        limit: _pageSize,
        staged: widget.staged,
      );
      final lines = (resp['lines'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      final offset = resp['offset'] as int? ?? _nextOffset;
      final total = resp['total_lines'] as int? ?? _totalLines;
      if (mounted) {
        setState(() {
          _lines.addAll(lines);
          _nextOffset = offset + lines.length;
          _totalLines = total;
          _hasMore = _nextOffset < total;
          _loadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingMore = false;
          _error = userFriendlyErrorMessage(e, action: '加载 Diff 失败');
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
            _buildHeader(context),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error.isNotEmpty
                  ? _buildErrorOrInfo()
                  : _imageBytes != null
                  ? _buildImageViewer()
                  : _buildDiffList(scrollController),
            ),
          ],
        );
      },
    );
  }

  Widget _buildErrorOrInfo() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            widget.isBinary ? Icons.insert_drive_file : Icons.error_outline,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 12),
          Text(_error, style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildImageViewer() {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 5.0,
      child: Center(child: Image.memory(_imageBytes!, fit: BoxFit.contain)),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          Icon(_imageBytes != null ? Icons.image : Icons.code, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.path,
              style: const TextStyle(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_imageBytes != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                '${(_imageBytes!.length / 1024).toStringAsFixed(1)} KB',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ),
          if (_lines.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildStatBadge(),
            ),
          if (_lines.isNotEmpty && _totalLines > 0)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                '${_lines.length}/$_totalLines',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ),
          if (_lines.isNotEmpty)
            Tooltip(
              message: _wrap ? 'Disable wrap' : 'Enable wrap',
              child: IconButton(
                icon: Icon(
                  _wrap ? Icons.wrap_text : Icons.horizontal_rule,
                  size: 18,
                ),
                onPressed: () => setState(() => _wrap = !_wrap),
              ),
            ),
          if (_lines.isNotEmpty || _imageBytes != null)
            IconButton(
              icon: const Icon(Icons.copy, size: 18),
              onPressed: () {
                if (_imageBytes != null) {
                  Clipboard.setData(ClipboardData(text: widget.path));
                } else {
                  final text = _lines
                      .map((l) {
                        final type = l['type'] as String? ?? 'context';
                        final content = l['content'] as String? ?? '';
                        final prefix = type == 'add'
                            ? '+'
                            : type == 'del'
                            ? '-'
                            : ' ';
                        return '$prefix$content';
                      })
                      .join('\n');
                  Clipboard.setData(ClipboardData(text: text));
                }
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
    );
  }

  Widget _buildStatBadge() {
    int adds = 0, dels = 0;
    for (final line in _lines) {
      final type = line['type'] as String? ?? '';
      if (type == 'add') adds++;
      if (type == 'del') dels++;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '+$adds',
          style: TextStyle(
            fontSize: 11,
            color: Colors.green[700],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '-$dels',
          style: TextStyle(
            fontSize: 11,
            color: Colors.red[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDiffList(ScrollController scrollController) {
    if (_lines.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              widget.isBinary ? 'Binary file' : 'No text changes',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              widget.path,
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
      );
    }

    final listView = ListView.builder(
      controller: scrollController,
      itemCount: _lines.length + (_hasMore || _loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _lines.length) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Center(
              child: _loadingMore
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : TextButton(
                      onPressed: _loadMore,
                      child: const Text('Load more'),
                    ),
            ),
          );
        }
        return _buildDiffLine(_lines[index]);
      },
    );

    final listener = NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.pixels >=
            notification.metrics.maxScrollExtent - 240) {
          _loadMore();
        }
        return false;
      },
      child: listView,
    );

    if (_wrap) return listener;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(width: 1200, child: listener),
    );
  }

  Widget _buildDiffLine(Map<String, dynamic> line) {
    final type = line['type'] as String? ?? 'context';
    final content = line['content'] as String? ?? '';
    final oldLine = line['old_line'] as int?;
    final newLine = line['new_line'] as int?;

    Color bgColor;
    Color? textColor;
    String prefix;

    switch (type) {
      case 'add':
        bgColor = Colors.green[50]!;
        textColor = Colors.green[900]!;
        prefix = '+';
        break;
      case 'del':
        bgColor = Colors.red[50]!;
        textColor = Colors.red[900]!;
        prefix = '-';
        break;
      default:
        bgColor = Colors.transparent;
        textColor = null;
        prefix = ' ';
    }

    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Text(
              oldLine?.toString() ?? '',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 11,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 2),
          SizedBox(
            width: 44,
            child: Text(
              newLine?.toString() ?? '',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 11,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$prefix$content',
              style: TextStyle(
                color: textColor,
                fontFamily: 'monospace',
                fontSize: 12,
              ),
              softWrap: _wrap,
            ),
          ),
        ],
      ),
    );
  }
}
