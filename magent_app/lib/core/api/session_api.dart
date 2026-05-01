import 'package:dio/dio.dart';

class SessionApi {
  final Dio _dio;

  SessionApi(this._dio);

  Future<Map<String, dynamic>> createSession({
    required String provider,
    required String projectId,
    String? model,
    String? approvalPolicy,
    String? sandboxMode,
    String? prompt,
  }) async {
    final data = <String, dynamic>{
      'provider': provider,
      'project_id': projectId,
    };
    if (model != null) data['model'] = model;
    if (approvalPolicy != null) data['approval_policy'] = approvalPolicy;
    if (sandboxMode != null) data['sandbox_mode'] = sandboxMode;
    if (prompt != null) data['prompt'] = prompt;
    final resp = await _dio.post('/api/sessions', data: data);
    return resp.data['data'];
  }

  Future<Map<String, dynamic>> getSession(String id) async {
    final resp = await _dio.get('/api/sessions/$id');
    return resp.data['data'];
  }

  Future<List<dynamic>> listSessions(String projectId) async {
    final resp = await _dio.get('/api/sessions', queryParameters: {'project_id': projectId});
    return resp.data['data'] ?? [];
  }

  Future<void> sendInput(String sessionId, String input) async {
    await _dio.post('/api/sessions/$sessionId/input', data: {'input': input});
  }

  Future<void> interrupt(String sessionId) async {
    await _dio.post('/api/sessions/$sessionId/interrupt');
  }

  Future<void> stop(String sessionId) async {
    await _dio.post('/api/sessions/$sessionId/stop');
  }

  Future<Map<String, dynamic>> fork(String sessionId) async {
    final resp = await _dio.post('/api/sessions/$sessionId/fork');
    return resp.data['data'];
  }

  Future<List<dynamic>> getEvents(String sessionId, {int afterSeq = 0, int limit = 100}) async {
    final resp = await _dio.get('/api/sessions/$sessionId/events', queryParameters: {
      'after_seq': afterSeq,
      'limit': limit,
    });
    return resp.data['data'] ?? [];
  }

  Future<void> approve(String approvalId, String action) async {
    await _dio.post('/api/sessions/approve', data: {
      'approval_id': approvalId,
      'action': action,
    });
  }
}
