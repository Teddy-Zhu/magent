import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class WsClient {
  final String url;
  final String token;
  WebSocketChannel? _channel;
  final _eventController = StreamController<Map<String, dynamic>>.broadcast();
  Timer? _reconnectTimer;
  bool _isConnected = false;
  bool _helloSent = false;
  final Map<String, String?> _subscriptions = {};

  Stream<Map<String, dynamic>> get events => _eventController.stream;
  bool get isConnected => _isConnected;

  WsClient({required this.url, required this.token});

  void connect() {
    if (_channel != null) return;
    final wsUrl = url.replaceFirst('http', 'ws');
    _channel = WebSocketChannel.connect(
      Uri.parse('$wsUrl/api/v1/ws?token=$token'),
    );

    _channel!.stream.listen(
      (data) {
        final event = jsonDecode(data as String);
        _trackRealtimeCursor(event);
        _eventController.add(event);
      },
      onDone: () {
        _channel = null;
        _isConnected = false;
        _reconnectTimer?.cancel();
        _reconnectTimer = Timer(Duration(seconds: 2), connect);
      },
      onError: (error) {
        _channel = null;
        _isConnected = false;
      },
    );

    _isConnected = true;
    _resendState();
  }

  void hello({List<Map<String, String>> openSessions = const []}) {
    _helloSent = true;
    for (final session in openSessions) {
      final sessionId = session['session_id'];
      if (sessionId == null || sessionId.isEmpty) continue;
      _subscriptions[sessionId] = session['cursor'];
    }
    _sendHello();
  }

  void subscribeSession(String sessionId, {String? cursor}) {
    _subscriptions[sessionId] = cursor;
    send({
      'type': 'session.subscribe',
      'session_id': sessionId,
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
    });
  }

  void unsubscribeSession(String sessionId) {
    _subscriptions.remove(sessionId);
    send({'type': 'session.unsubscribe', 'session_id': sessionId});
  }

  void _resendState() {
    if (!_helloSent && _subscriptions.isEmpty) return;
    if (_helloSent) {
      _sendHello();
      return;
    }
    for (final entry in _subscriptions.entries) {
      send({
        'type': 'session.subscribe',
        'session_id': entry.key,
        if (entry.value != null && entry.value!.isNotEmpty)
          'cursor': entry.value,
      });
    }
  }

  void _sendHello() {
    send({
      'type': 'client.hello',
      'open_sessions': [
        for (final entry in _subscriptions.entries)
          {
            'session_id': entry.key,
            if (entry.value != null && entry.value!.isNotEmpty)
              'cursor': entry.value,
          },
      ],
    });
  }

  void _trackRealtimeCursor(dynamic event) {
    if (event is! Map) return;
    final sessionId = event['session_id']?.toString();
    final cursor =
        event['ws_cursor']?.toString() ?? event['ws_seq']?.toString();
    if (sessionId == null ||
        sessionId.isEmpty ||
        cursor == null ||
        cursor.isEmpty) {
      return;
    }
    if (_subscriptions.containsKey(sessionId)) {
      _subscriptions[sessionId] = cursor;
    }
  }

  void send(Map<String, dynamic> message) {
    _channel?.sink.add(jsonEncode(message));
  }

  void dispose() {
    disconnect();
    _eventController.close();
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
  }

  void close() {
    disconnect();
    _eventController.close();
  }
}
