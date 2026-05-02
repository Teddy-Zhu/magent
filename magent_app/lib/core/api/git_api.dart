import 'package:dio/dio.dart';
import 'package:magent_app/core/api/api_exceptions.dart';

class GitApi {
  static const _apiPrefix = '/api/v1';

  final Dio _dio;

  GitApi(this._dio);

  Future<Map<String, dynamic>> getSummary(
    String projectId, {
    int? knownVersion,
  }) async {
    final resp = await _dio.get(
      '$_apiPrefix/projects/$projectId/git/summary',
      options: Options(
        headers: knownVersion == null
            ? null
            : {'If-None-Match': knownVersion.toString()},
        validateStatus: (status) =>
            status != null && status >= 200 && status < 400,
      ),
    );
    if (resp.statusCode == 304) throw const NotModifiedException();
    return resp.data['data'];
  }

  Future<Map<String, dynamic>> getChanges(
    String projectId, {
    int baseVersion = 0,
  }) async {
    final resp = await _dio.get(
      '$_apiPrefix/projects/$projectId/git/changes',
      queryParameters: {'base_version': baseVersion},
      options: Options(
        validateStatus: (status) =>
            status != null && status >= 200 && status < 400,
      ),
    );
    if (resp.statusCode == 304) throw const NotModifiedException();
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
    final resp = await _dio.get(
      '$_apiPrefix/projects/$projectId/git/diff/file',
      queryParameters: {
        'path': path,
        'diff_hash': diffHash,
        'offset': offset,
        'limit': limit,
        'staged': staged.toString(),
      },
    );
    return resp.data['data'];
  }

  Future<void> stage(String projectId, List<String> paths) async {
    await _dio.post(
      '$_apiPrefix/projects/$projectId/git/stage',
      data: {'paths': paths},
    );
  }

  Future<void> unstage(String projectId, List<String> paths) async {
    await _dio.post(
      '$_apiPrefix/projects/$projectId/git/unstage',
      data: {'paths': paths},
    );
  }

  Future<void> discard(String projectId, List<String> paths) async {
    await _dio.post(
      '$_apiPrefix/projects/$projectId/git/discard',
      data: {'paths': paths, 'confirm': true},
    );
  }

  Future<void> commit(
    String projectId,
    String message, {
    bool all = false,
  }) async {
    await _dio.post(
      '$_apiPrefix/projects/$projectId/git/commit',
      data: {'message': message, 'all': all},
    );
  }

  Future<String> suggestCommitMessage(
    String projectId, {
    String? providerId,
    String? model,
    String? effort,
  }) async {
    final resp = await _dio.post(
      '$_apiPrefix/projects/$projectId/git/commit/suggest',
      data: {
        if (providerId != null && providerId.isNotEmpty)
          'provider_id': providerId,
        if (model != null && model.isNotEmpty) 'model': model,
        if (effort != null && effort.isNotEmpty) 'effort': effort,
      },
    );
    final data = resp.data['data'] as Map<String, dynamic>? ?? {};
    final error = data['error'] as String?;
    if (error != null && error.isNotEmpty) {
      throw Exception(error);
    }
    return data['message'] as String? ?? '';
  }

  Future<Map<String, dynamic>> push(
    String projectId, {
    String remote = 'origin',
    String? branch,
    bool force = false,
  }) async {
    final resp = await _dio.post(
      '$_apiPrefix/projects/$projectId/git/push',
      data: {
        'remote': remote,
        'branch': branch,
        'force': force,
        'confirm_force': force,
      },
    );
    return resp.data['data'] ?? {};
  }

  Future<Map<String, dynamic>> pull(
    String projectId, {
    String? remote,
    String? branch,
    bool rebase = false,
  }) async {
    final resp = await _dio.post(
      '$_apiPrefix/projects/$projectId/git/pull',
      data: {'remote': remote, 'branch': branch, 'rebase': rebase},
    );
    return resp.data['data'] ?? {};
  }

  Future<List<dynamic>> getLog(
    String projectId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final resp = await _dio.get(
      '$_apiPrefix/projects/$projectId/git/log',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    final data = resp.data['data'];
    if (data is List) return data;
    return (data as Map<String, dynamic>?)?['commits'] ?? [];
  }

  Future<List<dynamic>> getBranches(String projectId) async {
    final resp = await _dio.get('$_apiPrefix/projects/$projectId/git/branches');
    final data = resp.data['data'];
    if (data is List) return data;
    return (data as Map<String, dynamic>?)?['branches'] ?? [];
  }

  Future<Map<String, dynamic>> getCommitFiles(
    String projectId,
    String hash,
  ) async {
    final resp = await _dio.get(
      '$_apiPrefix/projects/$projectId/git/commit/files',
      queryParameters: {'hash': hash},
    );
    return resp.data['data'];
  }

  Future<Map<String, dynamic>> getCommitFileDiff(
    String projectId,
    String hash,
    String path,
  ) async {
    final resp = await _dio.get(
      '$_apiPrefix/projects/$projectId/git/commit/file-diff',
      queryParameters: {'hash': hash, 'path': path},
    );
    return resp.data['data'];
  }
}
