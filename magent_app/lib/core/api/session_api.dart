import 'package:dio/dio.dart';
import 'package:magent_app/core/repositories/session_repository.dart';

class SessionApi implements SessionApiLike {
  static const _apiPrefix = '/api/v1';

  final Dio _dio;

  SessionApi(this._dio);

  @override
  Future<Map<String, dynamic>> createSession({
    required String providerId,
    required String projectId,
    String? model,
    String? effort,
    String? approvalPolicy,
    String? sandboxMode,
    String? prompt,
  }) async {
    final data = <String, dynamic>{
      'provider_id': providerId,
      'project_id': projectId,
    };
    if (model != null) data['model'] = model;
    if (effort != null) data['effort'] = effort;
    if (approvalPolicy != null) data['approval_policy'] = approvalPolicy;
    if (sandboxMode != null) data['sandbox_mode'] = sandboxMode;
    if (prompt != null) data['prompt'] = prompt;
    final resp = await _dio.post('$_apiPrefix/sessions', data: data);
    return resp.data['data'];
  }

  @override
  Future<Map<String, dynamic>> getSession(String id) async {
    final resp = await _dio.get('$_apiPrefix/sessions/$id');
    return resp.data['data'];
  }

  @override
  Future<List<dynamic>> listSessions(String projectId) async {
    final resp = await _dio.get(
      '$_apiPrefix/sessions',
      queryParameters: {'project_id': projectId},
    );
    return resp.data['data'] ?? [];
  }

  @override
  Future<void> sendInput(
    String sessionId,
    String input, {
    List<Map<String, dynamic>> items = const [],
  }) async {
    await _dio.post(
      '$_apiPrefix/sessions/$sessionId/input',
      data: {
        'input': input,
        if (items.isNotEmpty) 'items': items,
      },
    );
  }

  @override
  Future<void> resume(String sessionId) async {
    await _dio.post('$_apiPrefix/sessions/$sessionId/resume');
  }

  @override
  Future<void> interrupt(String sessionId) async {
    await _dio.post('$_apiPrefix/sessions/$sessionId/interrupt');
  }

  @override
  Future<void> stop(String sessionId) async {
    await _dio.post('$_apiPrefix/sessions/$sessionId/stop');
  }

  @override
  Future<Map<String, dynamic>> fork(String sessionId) async {
    final resp = await _dio.post('$_apiPrefix/sessions/$sessionId/fork');
    return resp.data['data'];
  }

  @override
  Future<Map<String, dynamic>> getEventsPage(
    String sessionId, {
    String? cursor,
    int limit = 500,
  }) async {
    final resp = await _dio.get(
      '$_apiPrefix/sessions/$sessionId/events',
      queryParameters: {
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        'limit': limit,
      },
    );
    return Map<String, dynamic>.from(resp.data['data'] as Map? ?? {});
  }

  @override
  Future<Map<String, dynamic>> getItemsPage(
    String sessionId, {
    String? cursor,
    int limit = 200,
  }) async {
    final resp = await _dio.get(
      '$_apiPrefix/sessions/$sessionId/items',
      queryParameters: {
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        'limit': limit,
      },
    );
    return Map<String, dynamic>.from(resp.data['data'] as Map? ?? {});
  }

  @override
  Future<void> approve(
    String sessionId,
    String approvalId,
    String action,
  ) async {
    await _dio.post(
      '$_apiPrefix/sessions/$sessionId/approvals/$approvalId',
      data: {'decision': action},
    );
  }
}
