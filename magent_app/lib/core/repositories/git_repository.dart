import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:magent_app/core/api/api_exceptions.dart';
import 'package:magent_app/core/api/git_api.dart';
import 'package:magent_app/core/storage/app_database.dart';

class GitSnapshot {
  final Map<String, dynamic>? summary;
  final List<dynamic> files;
  final bool fromCache;

  const GitSnapshot({
    required this.summary,
    required this.files,
    required this.fromCache,
  });
}

class GitRepository {
  final String agentId;
  final GitApi _api;
  final AppDatabase _db;

  GitRepository({
    required this.agentId,
    required GitApi api,
    required AppDatabase db,
  }) : _api = api,
       _db = db;

  Future<GitSnapshot?> getCachedSnapshot(String projectId) async {
    final summary = await _db.getGitSummary(agentId, projectId);
    final changes = await _db.getGitChanges(agentId, projectId);
    if (summary == null && changes == null) return null;
    return GitSnapshot(
      summary: summary == null ? null : _decodeMap(summary.dataJson),
      files: changes == null ? const [] : _decodeList(changes.filesJson),
      fromCache: true,
    );
  }

  Future<GitSnapshot> refreshSnapshot(String projectId) async {
    final cachedSummary = await _db.getGitSummary(agentId, projectId);
    final cachedChanges = await _db.getGitChanges(agentId, projectId);

    Map<String, dynamic>? summary;
    var version = cachedSummary?.version ?? cachedChanges?.version ?? 0;

    try {
      summary = await _api.getSummary(
        projectId,
        knownVersion: cachedSummary?.version,
      );
      version = _parseInt(summary['version']) ?? version;
      await _db.upsertGitSummary(
        GitSummaryEntriesCompanion(
          agentId: Value(agentId),
          projectId: Value(projectId),
          version: Value(version),
          dataJson: Value(jsonEncode(summary)),
          updatedAt: Value(DateTime.now()),
        ),
      );
    } on NotModifiedException {
      summary = cachedSummary == null
          ? null
          : _decodeMap(cachedSummary.dataJson);
      version = cachedSummary?.version ?? version;
    }

    List<dynamic> files;
    try {
      final changes = await _api.getChanges(
        projectId,
        baseVersion: cachedChanges?.version ?? 0,
      );
      final changedVersion = _parseInt(changes['version']) ?? version;
      files = List<dynamic>.from(changes['files'] as List? ?? const []);
      await _db.upsertGitChanges(
        GitChangesEntriesCompanion(
          agentId: Value(agentId),
          projectId: Value(projectId),
          version: Value(changedVersion),
          filesJson: Value(jsonEncode(files)),
          updatedAt: Value(DateTime.now()),
        ),
      );
    } on NotModifiedException {
      files = cachedChanges == null
          ? const []
          : _decodeList(cachedChanges.filesJson);
    }

    return GitSnapshot(summary: summary, files: files, fromCache: false);
  }

  Future<GitSnapshot> getSnapshot(String projectId) async {
    final cached = await getCachedSnapshot(projectId);
    if (cached != null) return cached;
    return refreshSnapshot(projectId);
  }

  Future<Map<String, dynamic>> getFileDiff(
    String projectId,
    String path,
    String diffHash, {
    int offset = 0,
    int limit = 200,
    bool staged = false,
  }) {
    return _api.getFileDiff(
      projectId,
      path,
      diffHash,
      offset: offset,
      limit: limit,
      staged: staged,
    );
  }

  Future<void> stage(String projectId, List<String> paths) async {
    await _api.stage(projectId, paths);
    await refreshSnapshot(projectId);
  }

  Future<void> unstage(String projectId, List<String> paths) async {
    await _api.unstage(projectId, paths);
    await refreshSnapshot(projectId);
  }

  Future<void> discard(String projectId, List<String> paths) async {
    await _api.discard(projectId, paths);
    await refreshSnapshot(projectId);
  }

  Future<void> commit(
    String projectId,
    String message, {
    bool all = false,
  }) async {
    await _api.commit(projectId, message, all: all);
    await refreshSnapshot(projectId);
  }

  Future<Map<String, dynamic>> push(
    String projectId, {
    String remote = 'origin',
    String? branch,
    bool force = false,
  }) async {
    final result = await _api.push(
      projectId,
      remote: remote,
      branch: branch,
      force: force,
    );
    await refreshSnapshot(projectId);
    return result;
  }

  Future<Map<String, dynamic>> pull(
    String projectId, {
    String? remote,
    String? branch,
    bool rebase = false,
  }) async {
    final result = await _api.pull(
      projectId,
      remote: remote,
      branch: branch,
      rebase: rebase,
    );
    await refreshSnapshot(projectId);
    return result;
  }

  Future<String> suggestCommitMessage(
    String projectId, {
    String? providerId,
    String? model,
    String? effort,
  }) {
    return _api.suggestCommitMessage(
      projectId,
      providerId: providerId,
      model: model,
      effort: effort,
    );
  }

  Future<List<dynamic>> getLog(
    String projectId, {
    int limit = 50,
    int offset = 0,
  }) {
    return _api.getLog(projectId, limit: limit, offset: offset);
  }

  Future<List<dynamic>> getBranches(String projectId) {
    return _api.getBranches(projectId);
  }

  Future<Map<String, dynamic>> getCommitFiles(String projectId, String hash) {
    return _api.getCommitFiles(projectId, hash);
  }

  Future<Map<String, dynamic>> getCommitFileDiff(
    String projectId,
    String hash,
    String path,
  ) {
    return _api.getCommitFileDiff(projectId, hash, path);
  }

  Map<String, dynamic> _decodeMap(String value) {
    final decoded = jsonDecode(value);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return <String, dynamic>{};
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
