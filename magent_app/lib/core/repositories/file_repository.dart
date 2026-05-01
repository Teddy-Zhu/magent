import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:magent_app/core/api/api_exceptions.dart';
import 'package:magent_app/core/api/file_api.dart';
import 'package:magent_app/core/storage/app_database.dart';

class FileRepository {
  final String agentId;
  final FileApi _api;
  final AppDatabase _db;

  FileRepository({
    required this.agentId,
    required FileApi api,
    required AppDatabase db,
  }) : _api = api,
       _db = db;

  Future<Map<String, dynamic>?> getCachedDir(
    String projectId,
    String path,
  ) async {
    final row = await _db.getDirCache(agentId, projectId, _normalizePath(path));
    if (row == null) return null;
    return {
      'path': row.path,
      'hash': row.hash,
      'items': _decodeList(row.itemsJson),
    };
  }

  Future<Map<String, dynamic>> listDir(String projectId, String path) async {
    final normalized = _normalizePath(path);
    final cached = await _db.getDirCache(agentId, projectId, normalized);
    try {
      final data = await _api.listDir(
        projectId,
        normalized,
        knownHash: cached?.hash,
      );
      final hash = data['hash']?.toString() ?? '';
      await _db.upsertDirCache(
        DirCacheEntriesCompanion(
          agentId: Value(agentId),
          projectId: Value(projectId),
          path: Value(normalized),
          hash: Value(hash),
          itemsJson: Value(jsonEncode(data['items'] ?? const [])),
          updatedAt: Value(DateTime.now()),
        ),
      );
      return data;
    } on NotModifiedException {
      if (cached != null) {
        return {
          'path': cached.path,
          'hash': cached.hash,
          'items': _decodeList(cached.itemsJson),
        };
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getCachedFile(
    String projectId,
    String path, {
    int offset = 0,
    int limit = 1000,
  }) async {
    final normalized = _normalizePath(path);
    final rangeKey = _rangeKey(offset, limit);
    final row = await _db.getFileCache(
      agentId,
      projectId,
      normalized,
      rangeKey,
    );
    if (row == null) return null;
    return _fileCacheToMap(row);
  }

  Future<Map<String, dynamic>> readFile(
    String projectId,
    String path, {
    int offset = 0,
    int limit = 1000,
  }) async {
    final normalized = _normalizePath(path);
    final rangeKey = _rangeKey(offset, limit);
    final cached = await _db.getFileCache(
      agentId,
      projectId,
      normalized,
      rangeKey,
    );
    try {
      final data = await _api.readFile(
        projectId,
        normalized,
        knownHash: cached?.hash,
        offset: offset,
        limit: limit,
      );
      final hash = data['hash']?.toString() ?? '';
      await _db.upsertFileCache(
        FileCacheEntriesCompanion(
          agentId: Value(agentId),
          projectId: Value(projectId),
          path: Value(normalized),
          rangeKey: Value(rangeKey),
          hash: Value(hash),
          encoding: const Value('text'),
          content: Value(data['content']?.toString() ?? ''),
          size: Value(_parseInt(data['size'])),
          totalLines: Value(_parseInt(data['total_lines'])),
          offset: Value(_parseInt(data['offset']) ?? offset),
          limit: Value(_parseInt(data['limit']) ?? limit),
          updatedAt: Value(DateTime.now()),
        ),
      );
      return data;
    } on NotModifiedException {
      if (cached != null) return _fileCacheToMap(cached);
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getCachedRawFile(
    String projectId,
    String path, {
    int offset = 0,
    int limit = 0,
  }) async {
    final normalized = _normalizePath(path);
    final rangeKey = _rawRangeKey(offset, limit);
    final row = await _db.getFileCache(
      agentId,
      projectId,
      normalized,
      rangeKey,
    );
    if (row == null) return null;
    return _rawCacheToMap(row);
  }

  Future<Map<String, dynamic>> readRawFile(
    String projectId,
    String path, {
    int offset = 0,
    int limit = 0,
  }) async {
    final normalized = _normalizePath(path);
    final rangeKey = _rawRangeKey(offset, limit);
    final cached = await _db.getFileCache(
      agentId,
      projectId,
      normalized,
      rangeKey,
    );
    try {
      final data = await _api.readRawFile(
        projectId,
        normalized,
        knownHash: cached?.hash,
        offset: offset,
        limit: limit,
      );
      final hash = data['hash']?.toString() ?? '';
      await _db.upsertFileCache(
        FileCacheEntriesCompanion(
          agentId: Value(agentId),
          projectId: Value(projectId),
          path: Value(normalized),
          rangeKey: Value(rangeKey),
          hash: Value(hash),
          encoding: Value(data['encoding']?.toString()),
          content: Value(jsonEncode(data)),
          size: Value(_parseInt(data['size'])),
          totalLines: const Value.absent(),
          offset: Value(_parseInt(data['offset']) ?? offset),
          limit: Value(_parseInt(data['limit']) ?? limit),
          updatedAt: Value(DateTime.now()),
        ),
      );
      return data;
    } on NotModifiedException {
      if (cached != null) return _rawCacheToMap(cached);
      rethrow;
    }
  }

  String _normalizePath(String path) {
    if (path == '.' || path == '/') return '';
    return path;
  }

  String _rangeKey(int offset, int limit) => '$offset:$limit';

  String _rawRangeKey(int offset, int limit) => 'raw:$offset:$limit';

  Map<String, dynamic> _fileCacheToMap(FileCacheEntry row) {
    return {
      'path': row.path,
      'hash': row.hash,
      'encoding': row.encoding ?? 'text',
      'content': row.content,
      'size': row.size,
      'total_lines': row.totalLines,
      'offset': row.offset,
      'limit': row.limit,
    };
  }

  Map<String, dynamic> _rawCacheToMap(FileCacheEntry row) {
    final decoded = jsonDecode(row.content);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return {
      'path': row.path,
      'hash': row.hash,
      'encoding': row.encoding,
      'data': row.content,
      'size': row.size,
      'offset': row.offset,
      'limit': row.limit,
    };
  }

  List<dynamic> _decodeList(String value) {
    final decoded = jsonDecode(value);
    if (decoded is List) return decoded;
    return const [];
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}
