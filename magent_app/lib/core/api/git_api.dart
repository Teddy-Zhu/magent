import 'package:dio/dio.dart';

class GitApi {
  final Dio _dio;

  GitApi(this._dio);

  Future<Map<String, dynamic>> getSummary(String projectId) async {
    final resp = await _dio.get('/api/git/summary', queryParameters: {'project_id': projectId});
    return resp.data['data'];
  }

  Future<Map<String, dynamic>> getChanges(String projectId, {int baseVersion = 0}) async {
    final resp = await _dio.get('/api/git/changes', queryParameters: {
      'project_id': projectId,
      'base_version': baseVersion,
    });
    return resp.data['data'];
  }

  Future<Map<String, dynamic>> getFileDiff(
    String projectId,
    String path,
    String diffHash, {
    int offset = 0,
    int limit = 200,
    bool staged = false,
  }) async {
    final resp = await _dio.get('/api/git/diff/file', queryParameters: {
      'project_id': projectId,
      'path': path,
      'diff_hash': diffHash,
      'offset': offset,
      'limit': limit,
      'staged': staged.toString(),
    });
    return resp.data['data'];
  }

  Future<void> stage(String projectId, List<String> paths) async {
    await _dio.post('/api/git/stage', data: {
      'project_id': projectId,
      'paths': paths,
    });
  }

  Future<void> unstage(String projectId, List<String> paths) async {
    await _dio.post('/api/git/unstage', data: {
      'project_id': projectId,
      'paths': paths,
    });
  }

  Future<void> discard(String projectId, List<String> paths) async {
    await _dio.post('/api/git/discard', data: {
      'project_id': projectId,
      'paths': paths,
    });
  }

  Future<void> commit(String projectId, String message, {bool all = false}) async {
    await _dio.post('/api/git/commit', data: {
      'project_id': projectId,
      'message': message,
      'all': all,
    });
  }

  Future<String> suggestCommitMessage(String projectId) async {
    final resp = await _dio.post('/api/git/commit/suggest', data: {
      'project_id': projectId,
    });
    return resp.data['data']['message'] as String? ?? '';
  }

  Future<Map<String, dynamic>> push(
    String projectId, {
    String remote = 'origin',
    String? branch,
    bool force = false,
  }) async {
    final resp = await _dio.post('/api/git/push', data: {
      'project_id': projectId,
      'remote': remote,
      'branch': branch,
      'force': force,
    });
    return resp.data['data'] ?? {};
  }

  Future<List<dynamic>> getLog(String projectId, {int limit = 50, int offset = 0}) async {
    final resp = await _dio.get('/api/git/log', queryParameters: {
      'project_id': projectId,
      'limit': limit,
      'offset': offset,
    });
    final data = resp.data['data'];
    if (data is List) return data;
    return (data as Map<String, dynamic>?)?['commits'] ?? [];
  }

  Future<List<dynamic>> getBranches(String projectId) async {
    final resp = await _dio.get('/api/git/branches', queryParameters: {
      'project_id': projectId,
    });
    final data = resp.data['data'];
    if (data is List) return data;
    return (data as Map<String, dynamic>?)?['branches'] ?? [];
  }

  Future<Map<String, dynamic>> getCommitFiles(String projectId, String hash) async {
    final resp = await _dio.get('/api/git/commit/files', queryParameters: {
      'project_id': projectId,
      'hash': hash,
    });
    return resp.data['data'];
  }

  Future<Map<String, dynamic>> getCommitFileDiff(String projectId, String hash, String path) async {
    final resp = await _dio.get('/api/git/commit/file-diff', queryParameters: {
      'project_id': projectId,
      'hash': hash,
      'path': path,
    });
    return resp.data['data'];
  }
}
