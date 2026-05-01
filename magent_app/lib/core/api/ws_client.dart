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

  Stream<Map<String, dynamic>> get events => _eventController.stream;
  bool get isConnected => _isConnected;

  WsClient({required this.url, required this.token});

  void connect() {
    final wsUrl = url.replaceFirst('http', 'ws');
    _channel = WebSocketChannel.connect(
      Uri.parse('$wsUrl/api/ws?token=$token'),
    );

    _channel!.stream.listen(
      (data) {
        final event = jsonDecode(data as String);
        _eventController.add(event);
      },
      onDone: () {
        _isConnected = false;
        _reconnectTimer?.cancel();
        _reconnectTimer = Timer(Duration(seconds: 2), connect);
      },
      onError: (error) {
        _isConnected = false;
      },
    );

    _isConnected = true;
  }

  void send(Map<String, dynamic> message) {
    _channel?.sink.add(jsonEncode(message));
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _eventController.close();
  }
}
