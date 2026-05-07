import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magent_app/core/repositories/bootstrap_repository.dart';
import 'package:magent_app/core/storage/app_database.dart';

void main() {
  late AppDatabase db;
  late _ProviderConfigAdapter adapter;
  late BootstrapRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    adapter = _ProviderConfigAdapter();
    final dio = Dio(
      BaseOptions(baseUrl: 'http://example.test', validateStatus: (_) => true),
    )..httpClientAdapter = adapter;
    repo = BootstrapRepository(agentId: 'agent-a', dio: dio, db: db);
  });

  tearDown(() async {
    await db.close();
  });

  test('provider config request is deduplicated and cached', () async {
    final first = repo.fetchProviderConfig('codex');
    final second = repo.fetchProviderConfig('codex');

    await adapter.waitForConfigRequest();
    expect(adapter.configRequests, 1);

    adapter.completeConfigResponse();

    expect(await first, containsPair('models', isA<List<dynamic>>()));
    expect(await second, containsPair('models', isA<List<dynamic>>()));

    final cached = await repo.fetchProviderConfig('codex');
    expect(cached, containsPair('skills', isA<List<dynamic>>()));
    expect(adapter.configRequests, 1);
  });

  test('provider config force refresh bypasses cache', () async {
    adapter.completeConfigResponse();
    await repo.fetchProviderConfig('codex');

    adapter.resetConfigResponse();
    final refreshed = repo.fetchProviderConfig('codex', force: true);

    await adapter.waitForConfigRequest();
    expect(adapter.configRequests, 2);

    adapter.completeConfigResponse();
    expect(await refreshed, containsPair('skills', isA<List<dynamic>>()));
  });

  test('bootstrap refresh initializes once per app process', () async {
    final agentId = 'agent-bootstrap-once';
    final firstRepo = BootstrapRepository(
      agentId: agentId,
      dio: adapter.dio,
      db: db,
    );
    final secondRepo = BootstrapRepository(
      agentId: agentId,
      dio: adapter.dio,
      db: db,
    );

    final first = firstRepo.refresh();
    final second = secondRepo.refresh();

    await adapter.waitForBootstrapRequest();
    expect(adapter.bootstrapRequests, 1);

    adapter.completeBootstrapResponse();

    expect((await first).fromCache, isFalse);
    expect((await second).fromCache, isFalse);

    final cached = await secondRepo.refresh();
    expect(cached.fromCache, isTrue);
    expect(adapter.bootstrapRequests, 1);
  });

  test('bootstrap force refresh bypasses process initialization', () async {
    final agentId = 'agent-bootstrap-force';
    final bootstrapRepo = BootstrapRepository(
      agentId: agentId,
      dio: adapter.dio,
      db: db,
    );

    final first = bootstrapRepo.refresh();
    await adapter.waitForBootstrapRequest();
    adapter.completeBootstrapResponse();
    await first;

    adapter.resetBootstrapResponse();
    final forced = bootstrapRepo.refresh(force: true);

    await adapter.waitForBootstrapRequest();
    expect(adapter.bootstrapRequests, 2);

    adapter.completeBootstrapResponse();
    expect((await forced).fromCache, isFalse);
  });
}

class _ProviderConfigAdapter implements HttpClientAdapter {
  int configRequests = 0;
  int bootstrapRequests = 0;
  Completer<void> _configResponse = Completer<void>();
  Completer<void> _configRequest = Completer<void>();
  Completer<void> _bootstrapResponse = Completer<void>();
  Completer<void> _bootstrapRequest = Completer<void>();

  Future<void> waitForConfigRequest() => _configRequest.future;
  Future<void> waitForBootstrapRequest() => _bootstrapRequest.future;

  Dio get dio => Dio(
    BaseOptions(baseUrl: 'http://example.test', validateStatus: (_) => true),
  )..httpClientAdapter = this;

  void completeConfigResponse() {
    if (!_configResponse.isCompleted) {
      _configResponse.complete();
    }
  }

  void resetConfigResponse() {
    _configResponse = Completer<void>();
    _configRequest = Completer<void>();
  }

  void completeBootstrapResponse() {
    if (!_bootstrapResponse.isCompleted) {
      _bootstrapResponse.complete();
    }
  }

  void resetBootstrapResponse() {
    _bootstrapResponse = Completer<void>();
    _bootstrapRequest = Completer<void>();
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path == '/api/v1/providers/codex/config') {
      configRequests += 1;
      if (!_configRequest.isCompleted) {
        _configRequest.complete();
      }
      await _configResponse.future;
      return ResponseBody.fromString(
        jsonEncode({
          'data': {
            'models': [
              {'id': 'gpt-test', 'name': 'GPT Test'},
            ],
            'skills': [
              {'name': 'skill-a', 'path': '/tmp/skill-a/SKILL.md'},
            ],
          },
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    if (options.path == '/api/v1/bootstrap' ||
        options.path == '/api/v1/bootstrap/refresh') {
      bootstrapRequests += 1;
      if (!_bootstrapRequest.isCompleted) {
        _bootstrapRequest.complete();
      }
      await _bootstrapResponse.future;
      return ResponseBody.fromString(
        jsonEncode({
          'data': {
            'projects': [
              {'id': 'p1', 'name': 'Project One', 'path': '/tmp/project-one'},
            ],
            'providers': [
              {
                'name': 'codex',
                'status': 'available',
                'config': {
                  'models': [
                    {'id': 'gpt-test', 'name': 'GPT Test'},
                  ],
                },
              },
            ],
          },
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
          'etag': ['bootstrap-test-hash'],
        },
      );
    }

    return ResponseBody.fromString(
      jsonEncode({
        'error': {'message': 'unexpected path: ${options.path}'},
      }),
      404,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
