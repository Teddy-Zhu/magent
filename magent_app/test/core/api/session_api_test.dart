import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magent_app/core/api/session_api.dart';

void main() {
  test('createSession sends canonical provider_id field', () async {
    late Map<String, dynamic> requestBody;
    final dio =
        Dio(
            BaseOptions(
              baseUrl: 'http://example.test',
              validateStatus: (_) => true,
            ),
          )
          ..httpClientAdapter = _CaptureAdapter((options) {
            requestBody = Map<String, dynamic>.from(options.data as Map);
            return ResponseBody.fromString(
              jsonEncode({
                'data': {'id': 's1'},
              }),
              200,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            );
          });

    final api = SessionApi(dio);
    final session = await api.createSession(
      providerId: 'codex',
      projectId: 'p1',
      approvalPolicy: 'on-request',
      sandboxMode: 'workspace-write',
    );

    expect(session['id'], 's1');
    expect(requestBody['provider_id'], 'codex');
    expect(requestBody.containsKey('provider'), isFalse);
  });

  test('sendInput includes structured input items when provided', () async {
    late Map<String, dynamic> requestBody;
    final dio = Dio(
      BaseOptions(
        baseUrl: 'http://example.test',
        validateStatus: (_) => true,
      ),
    )..httpClientAdapter = _CaptureAdapter((options) {
      requestBody = Map<String, dynamic>.from(options.data as Map);
      return ResponseBody.fromString(
        jsonEncode({'data': null}),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    });

    final api = SessionApi(dio);
    await api.sendInput('s1', r'$skill-creator hello', items: [
      {
        'type': 'skill',
        'name': 'skill-creator',
        'path': '/tmp/skill/SKILL.md',
      },
    ]);

    expect(requestBody['input'], r'$skill-creator hello');
    expect(requestBody['items'], isA<List>());
    expect((requestBody['items'] as List).single['type'], 'skill');
  });
}

class _CaptureAdapter implements HttpClientAdapter {
  _CaptureAdapter(this._handler);

  final ResponseBody Function(RequestOptions options) _handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}
