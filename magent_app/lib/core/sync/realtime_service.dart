import 'dart:async';

import 'package:magent_app/core/api/ws_client.dart';

abstract class RealtimeTransport {
  Stream<Map<String, dynamic>> get events;

  void start();

  void subscribeSession(String sessionId, {String? cursor});

  void unsubscribeSession(String sessionId);

  void pause();

  void resume();

  void dispose();
}

class RealtimeService implements RealtimeTransport {
  final WsClient _client;
  var _started = false;

  RealtimeService({required String url, required String token})
    : _client = WsClient(url: url, token: token);

  @override
  Stream<Map<String, dynamic>> get events => _client.events;

  @override
  void start() {
    if (_started) return;
    _started = true;
    _client.hello();
    _client.connect();
  }

  @override
  void subscribeSession(String sessionId, {String? cursor}) {
    start();
    _client.subscribeSession(sessionId, cursor: cursor);
  }

  @override
  void unsubscribeSession(String sessionId) {
    _client.unsubscribeSession(sessionId);
  }

  StreamSubscription<Map<String, dynamic>> listen(
    void Function(Map<String, dynamic> event) onData,
  ) {
    start();
    return events.listen(onData);
  }

  @override
  void dispose() {
    _client.dispose();
  }

  @override
  void pause() {
    _started = false;
    _client.disconnect();
  }

  @override
  void resume() {
    start();
  }
}
