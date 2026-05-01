import 'package:dio/dio.dart';

class ApiClient {
  late final Dio dio;
  final String baseUrl;
  final String token;

  ApiClient({required this.baseUrl, required this.token}) {
    dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      headers: {'Authorization': 'Bearer $token'},
    ));
    dio.interceptors.add(LogInterceptor());
  }

  // Agent
  Future<Map<String, dynamic>> getAgentInfo() async {
    final resp = await dio.get('/api/agent/info');
    return resp.data['data'];
  }

  // Projects
  Future<List<dynamic>> listProjects() async {
    final resp = await dio.get('/api/projects');
    return resp.data['data'] ?? [];
  }

  Future<Map<String, dynamic>> createProject(String name, String path) async {
    final resp = await dio.post('/api/projects', data: {'name': name, 'path': path});
    return resp.data['data'];
  }

  Future<Map<String, dynamic>> getProject(String id) async {
    final resp = await dio.get('/api/projects/$id');
    return resp.data['data'];
  }

  Future<Map<String, dynamic>> updateProject(String id, {String? name, String? path}) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (path != null) data['path'] = path;
    final resp = await dio.put('/api/projects/$id', data: data);
    return resp.data['data'];
  }

  Future<void> deleteProject(String id) async {
    await dio.delete('/api/projects/$id');
  }
}
