import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:magent_app/core/storage/app_database.dart';

class BootstrapRepository implements BootstrapSyncStore {
  final String agentId;
  final Dio _dio;
  final AppDatabase _db;

  BootstrapRepository({
    required this.agentId,
    required Dio dio,
    required AppDatabase db,
  }) : _dio = dio,
       _db = db;

  Future<BootstrapSnapshot> getCachedSnapshot() async {
    final projects = await _db.getProjects(agentId);
    final providers = await _db.getProviders(agentId);
    return BootstrapSnapshot(
      projects: projects.map(_projectToMap).toList(),
      providers: _sortProviders(providers.map(_providerToMap).toList()),
      fromCache: true,
    );
  }

  Stream<List<Map<String, dynamic>>> watchProjects() {
    return _db
        .watchProjects(agentId)
        .map((rows) => rows.map(_projectToMap).toList());
  }

  Stream<List<Map<String, dynamic>>> watchProviders() {
    return _db
        .watchProviders(agentId)
        .map((rows) => _sortProviders(rows.map(_providerToMap).toList()));
  }

  @override
  Future<BootstrapSnapshot> refresh({bool force = false}) async {
    final cachedHash = force
        ? null
        : await _db.getSyncHash(agentId, 'bootstrap', 'global');
    final options = Options(
      headers: {
        if (cachedHash != null && cachedHash.isNotEmpty)
          'If-None-Match': cachedHash,
      },
      validateStatus: (status) => status == 200 || status == 304,
    );
    final resp = force
        ? await _dio.post('/api/v1/bootstrap/refresh', options: options)
        : await _dio.get('/api/v1/bootstrap', options: options);

    if (resp.statusCode == 304) {
      return getCachedSnapshot();
    }

    final data = Map<String, dynamic>.from(resp.data['data'] as Map? ?? {});
    final now = DateTime.now();
    final projects = (data['projects'] as List? ?? const [])
        .whereType<Map>()
        .map((p) => Map<String, dynamic>.from(p))
        .toList();
    final providers = (data['providers'] as List? ?? const [])
        .whereType<Map>()
        .map((p) => Map<String, dynamic>.from(p))
        .toList();

    await _db.replaceProjects(
      agentId,
      projects.map((p) => _projectCompanion(p, now)).toList(),
    );
    await _db.replaceProviders(
      agentId,
      providers.map((p) => _providerCompanion(p, now)).toList(),
    );

    final hash =
        resp.headers.value('etag') ??
        data['hash']?.toString() ??
        _fallbackHash(data);
    await _db.setSyncState(agentId, 'bootstrap', 'global', hash: hash);

    return BootstrapSnapshot(
      projects: projects,
      providers: _sortProviders(providers),
      fromCache: false,
    );
  }

  Future<List<Map<String, dynamic>>> getProjects() async {
    final cached = await _db.getProjects(agentId);
    if (cached.isNotEmpty) {
      refresh().catchError((_) => BootstrapSnapshot.empty());
      return cached.map(_projectToMap).toList();
    }
    return (await refresh()).projects;
  }

  Future<List<Map<String, dynamic>>> refreshProjects() async {
    return (await refresh(force: true)).projects;
  }

  Future<Map<String, dynamic>?> getProject(String id) async {
    final cached = await _db.getProjectEntry(agentId, id);
    if (cached != null) {
      refresh().catchError((_) => BootstrapSnapshot.empty());
      return _projectToMap(cached);
    }
    await refresh();
    final fresh = await _db.getProjectEntry(agentId, id);
    return fresh == null ? null : _projectToMap(fresh);
  }

  Future<List<Map<String, dynamic>>> getProviders() async {
    final cached = await _db.getProviders(agentId);
    if (cached.isNotEmpty) {
      refresh().catchError((_) => BootstrapSnapshot.empty());
      return _sortProviders(cached.map(_providerToMap).toList());
    }
    return (await refresh()).providers;
  }

  Future<List<Map<String, dynamic>>> refreshProviders() async {
    return (await refresh(force: true)).providers;
  }

  Future<Map<String, dynamic>?> getProvider(String name) async {
    final cached = await _db.getProviderEntry(agentId, name);
    if (cached != null) {
      refresh().catchError((_) => BootstrapSnapshot.empty());
      return _providerToMap(cached);
    }
    await refresh();
    final fresh = await _db.getProviderEntry(agentId, name);
    return fresh == null ? null : _providerToMap(fresh);
  }

  Future<Map<String, dynamic>> createProject(String name, String path) async {
    final resp = await _dio.post(
      '/api/v1/projects',
      data: {'name': name, 'path': path},
    );
    final project = Map<String, dynamic>.from(resp.data['data'] as Map? ?? {});
    if (project.isNotEmpty) {
      await _db.upsertProject(_projectCompanion(project, DateTime.now()));
    }
    await refresh(force: true);
    return project;
  }

  Future<void> deleteProject(String id) async {
    await _dio.delete('/api/v1/projects/$id');
    await _db.removeProjectEntry(agentId, id);
    await refresh(force: true);
  }

  Future<Map<String, dynamic>> updateProject(
    String id, {
    String? name,
    String? path,
    String? defaultProvider,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (path != null) data['path'] = path;
    if (defaultProvider != null) data['default_provider'] = defaultProvider;
    final resp = await _dio.put('/api/v1/projects/$id', data: data);
    final project = Map<String, dynamic>.from(resp.data['data'] as Map? ?? {});
    if (project.isNotEmpty) {
      await _db.upsertProject(_projectCompanion(project, DateTime.now()));
    }
    await refresh(force: true);
    return project;
  }

  ProjectEntriesCompanion _projectCompanion(
    Map<String, dynamic> project,
    DateTime now,
  ) {
    final updatedAt = _parseDateTime(project['updated_at']) ?? now;
    return ProjectEntriesCompanion(
      agentId: Value(agentId),
      id: Value(project['id']?.toString() ?? ''),
      name: Value(project['name']?.toString() ?? ''),
      path: Value(project['path']?.toString() ?? ''),
      defaultProvider: Value(
        project['default_provider']?.toString() ?? 'codex',
      ),
      revision: Value(_parseInt(project['revision'])),
      dataJson: Value(jsonEncode(project)),
      createdAt: Value(_parseDateTime(project['created_at'])),
      updatedAt: Value(updatedAt),
      deletedAt: Value(_parseDateTime(project['deleted_at'])),
    );
  }

  ProviderEntriesCompanion _providerCompanion(
    Map<String, dynamic> provider,
    DateTime now,
  ) {
    return ProviderEntriesCompanion(
      agentId: Value(agentId),
      name: Value(provider['name']?.toString() ?? ''),
      status: Value(provider['status']?.toString() ?? 'unknown'),
      version: Value(provider['version']?.toString()),
      runMode: Value(provider['run_mode']?.toString()),
      capabilitiesJson: Value(jsonEncode(provider['capabilities'] ?? {})),
      configJson: Value(jsonEncode(provider['config'] ?? {})),
      configSchemaJson: Value(jsonEncode(provider['config_schema'] ?? {})),
      dataJson: Value(jsonEncode(provider)),
      revision: Value(_parseInt(provider['revision'])),
      updatedAt: Value(_parseDateTime(provider['updated_at']) ?? now),
    );
  }

  Map<String, dynamic> _projectToMap(ProjectEntry row) {
    final data = _decodeMap(row.dataJson);
    data.addAll({
      'id': row.id,
      'name': row.name,
      'path': row.path,
      'default_provider': row.defaultProvider,
      if (row.revision != null) 'revision': row.revision,
      if (row.createdAt != null) 'created_at': row.createdAt!.toIso8601String(),
      'updated_at': row.updatedAt.toIso8601String(),
    });
    return data;
  }

  Map<String, dynamic> _providerToMap(ProviderEntry row) {
    final data = _decodeMap(row.dataJson);
    data.addAll({
      'name': row.name,
      'status': row.status,
      if (row.version != null) 'version': row.version,
      if (row.runMode != null) 'run_mode': row.runMode,
      'capabilities': _decodeMap(row.capabilitiesJson),
      'config': _decodeMap(row.configJson),
      'config_schema': _decodeMap(row.configSchemaJson),
      if (row.revision != null) 'revision': row.revision,
      'updated_at': row.updatedAt.toIso8601String(),
    });
    return data;
  }

  List<Map<String, dynamic>> _sortProviders(List<Map<String, dynamic>> items) {
    items.sort((a, b) {
      final nameA = (a['name']?.toString() ?? '').toLowerCase();
      final nameB = (b['name']?.toString() ?? '').toLowerCase();
      if (nameA == 'codex' && nameB != 'codex') return -1;
      if (nameB == 'codex' && nameA != 'codex') return 1;
      return nameA.compareTo(nameB);
    });
    return items;
  }

  Map<String, dynamic> _decodeMap(String value) {
    final decoded = jsonDecode(value);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return <String, dynamic>{};
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(
        value > 1000000000000 ? value : value * 1000,
      );
    }
    return DateTime.tryParse(value.toString());
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  String _fallbackHash(Map<String, dynamic> data) {
    return base64Url.encode(utf8.encode(jsonEncode(data)));
  }
}

abstract class BootstrapSyncStore {
  Future<BootstrapSnapshot> refresh({bool force = false});
}

class BootstrapSnapshot {
  final List<Map<String, dynamic>> projects;
  final List<Map<String, dynamic>> providers;
  final bool fromCache;

  const BootstrapSnapshot({
    required this.projects,
    required this.providers,
    required this.fromCache,
  });

  factory BootstrapSnapshot.empty() {
    return const BootstrapSnapshot(
      projects: [],
      providers: [],
      fromCache: true,
    );
  }
}
