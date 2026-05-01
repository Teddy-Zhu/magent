import 'package:dio/dio.dart';

class FileApi {
  final Dio _dio;

  FileApi(this._dio);

  Future<Map<String, dynamic>> listDir(
    String projectId,
    String path, {
    String? knownHash,
  }) async {
    final params = <String, dynamic>{
      'project_id': projectId,
      'path': path,
    };
    if (knownHash != null) params['known_hash'] = knownHash;
    final resp = await _dio.get('/api/files/list', queryParameters: params);
    return resp.data['data'];
  }

  Future<Map<String, dynamic>> readFile(
    String projectId,
    String path, {
    String? knownHash,
    int offset = 0,
    int limit = 1000,
  }) async {
    final params = <String, dynamic>{
      'project_id': projectId,
      'path': path,
      'offset': offset,
      'limit': limit,
    };
    if (knownHash != null) params['known_hash'] = knownHash;
    final resp = await _dio.get('/api/files/read', queryParameters: params);
    return resp.data['data'];
  }

  Future<Map<String, dynamic>> readRawFile(String projectId, String path) async {
    final resp = await _dio.get('/api/files/raw', queryParameters: {
      'project_id': projectId,
      'path': path,
    });
    return resp.data['data'];
  }
}
