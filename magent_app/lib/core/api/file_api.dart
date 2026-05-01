import 'package:dio/dio.dart';
import 'package:magent_app/core/api/api_exceptions.dart';

class FileApi {
  static const _apiPrefix = '/api/v1';

  final Dio _dio;

  FileApi(this._dio);

  Future<Map<String, dynamic>> listDir(
    String projectId,
    String path, {
    String? knownHash,
  }) async {
    final params = <String, dynamic>{'path': path};
    if (knownHash != null) params['known_hash'] = knownHash;
    final resp = await _dio.get(
      '$_apiPrefix/projects/$projectId/files/dir',
      queryParameters: params,
      options: Options(
        headers: knownHash == null ? null : {'If-None-Match': knownHash},
        validateStatus: (status) =>
            status != null && status >= 200 && status < 400,
      ),
    );
    if (resp.statusCode == 304) throw const NotModifiedException();
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
      'path': path,
      'offset': offset,
      'limit': limit,
    };
    if (knownHash != null) params['known_hash'] = knownHash;
    final resp = await _dio.get(
      '$_apiPrefix/projects/$projectId/files/content',
      queryParameters: params,
      options: Options(
        headers: knownHash == null ? null : {'If-None-Match': knownHash},
        validateStatus: (status) =>
            status != null && status >= 200 && status < 400,
      ),
    );
    if (resp.statusCode == 304) throw const NotModifiedException();
    return resp.data['data'];
  }

  Future<Map<String, dynamic>> readRawFile(
    String projectId,
    String path, {
    String? knownHash,
    int offset = 0,
    int limit = 0,
  }) async {
    final params = <String, dynamic>{
      'path': path,
      'offset': offset,
      'limit': limit,
    };
    if (knownHash != null) params['known_hash'] = knownHash;
    final resp = await _dio.get(
      '$_apiPrefix/projects/$projectId/files/blob',
      queryParameters: params,
      options: Options(
        headers: knownHash == null ? null : {'If-None-Match': knownHash},
        validateStatus: (status) =>
            status != null && status >= 200 && status < 400,
      ),
    );
    if (resp.statusCode == 304) throw const NotModifiedException();
    return resp.data['data'];
  }
}
