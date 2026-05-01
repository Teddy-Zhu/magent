import 'package:dio/dio.dart';

class BootstrapData {
  final AgentData agent;
  final List<ProviderConfigData> providers;
  final List<ProjectSummary> projects;
  final int updatedAt;

  BootstrapData({
    required this.agent,
    required this.providers,
    required this.projects,
    required this.updatedAt,
  });

  factory BootstrapData.fromJson(Map<String, dynamic> json) {
    return BootstrapData(
      agent: AgentData.fromJson(json['agent'] ?? {}),
      providers: (json['providers'] as List?)?.map((p) => ProviderConfigData.fromJson(p)).toList() ?? [],
      projects: (json['projects'] as List?)?.map((p) => ProjectSummary.fromJson(p)).toList() ?? [],
      updatedAt: json['updated_at'] ?? 0,
    );
  }
}

class AgentData {
  final String version;

  AgentData({required this.version});

  factory AgentData.fromJson(Map<String, dynamic> json) {
    return AgentData(version: json['version'] ?? '');
  }
}

class ProviderConfigData {
  final String name;
  final String status;
  final String? version;
  final String? error;
  final Map<String, dynamic>? configSchema;

  ProviderConfigData({
    required this.name,
    required this.status,
    this.version,
    this.error,
    this.configSchema,
  });

  factory ProviderConfigData.fromJson(Map<String, dynamic> json) {
    return ProviderConfigData(
      name: json['name'] ?? '',
      status: json['status'] ?? 'unknown',
      version: json['version'],
      error: json['error'],
      configSchema: json['config_schema'],
    );
  }
}

class ProjectSummary {
  final String id;
  final String name;
  final String path;

  ProjectSummary({required this.id, required this.name, required this.path});

  factory ProjectSummary.fromJson(Map<String, dynamic> json) {
    return ProjectSummary(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      path: json['path'] ?? '',
    );
  }
}

class BootstrapSync {
  final Dio _dio;
  BootstrapData? _data;
  String? _configHash;

  BootstrapData? get data => _data;
  String? get configHash => _configHash;

  BootstrapSync(this._dio);

  Future<BootstrapData> sync() async {
    final checkResp = await _dio.get('/api/sync/check');
    final remoteHash = checkResp.data['config_hash'] as String?;

    if (remoteHash == _configHash && _data != null) {
      return _data!;
    }

    final resp = await _dio.get(
      '/api/sync/bootstrap',
      queryParameters: {'local_hash': _configHash ?? ''},
    );

    if (resp.statusCode == 304) {
      return _data!;
    }

    _data = BootstrapData.fromJson(resp.data);
    _configHash = remoteHash;
    return _data!;
  }

  List<String> getModels(String providerName) {
    final provider = _data?.providers.firstWhere(
      (p) => p.name == providerName,
      orElse: () => ProviderConfigData(name: '', status: 'unknown'),
    );
    if (provider?.configSchema == null) return [];
    final modelSchema = provider!.configSchema!['model'];
    if (modelSchema == null) return [];
    return List<String>.from(modelSchema['values'] ?? []);
  }

  String getDefaultModel(String providerName) {
    final provider = _data?.providers.firstWhere(
      (p) => p.name == providerName,
      orElse: () => ProviderConfigData(name: '', status: 'unknown'),
    );
    if (provider?.configSchema == null) return '';
    final modelSchema = provider!.configSchema!['model'];
    return modelSchema?['default'] ?? '';
  }

  List<String> getApprovalPolicies(String providerName) {
    final provider = _data?.providers.firstWhere(
      (p) => p.name == providerName,
      orElse: () => ProviderConfigData(name: '', status: 'unknown'),
    );
    if (provider?.configSchema == null) return [];
    final schema = provider!.configSchema!['approval_policy'];
    return List<String>.from(schema?['values'] ?? []);
  }

  List<String> getSandboxModes(String providerName) {
    final provider = _data?.providers.firstWhere(
      (p) => p.name == providerName,
      orElse: () => ProviderConfigData(name: '', status: 'unknown'),
    );
    if (provider?.configSchema == null) return [];
    final schema = provider!.configSchema!['sandbox_mode'];
    return List<String>.from(schema?['values'] ?? []);
  }
}
