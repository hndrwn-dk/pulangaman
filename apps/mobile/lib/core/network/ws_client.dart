import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../config.dart';

typedef WsHandler = void Function(String event, Map<String, dynamic> payload);

class WsClient {
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  final _handlers = <WsHandler>[];

  bool get isConnected => _channel != null;

  void addHandler(WsHandler handler) => _handlers.add(handler);
  void removeHandler(WsHandler handler) => _handlers.remove(handler);

  Future<void> connect(String token) async {
    await disconnect().timeout(
      const Duration(seconds: 3),
      onTimeout: () {
        _sub = null;
        _channel = null;
      },
    );
    final uri = Uri.parse('${AppConfig.wsBaseUrl}/ws?token=${Uri.encodeComponent(token)}');
    _channel = WebSocketChannel.connect(uri);
    try {
      await _channel!.ready.timeout(const Duration(seconds: 8));
    } catch (_) {
      // Keep channel; stream errors handled by listen / next reconnect.
    }
    _sub = _channel!.stream.listen((raw) {
      try {
        final message = jsonDecode(raw as String) as Map<String, dynamic>;
        final event = message['event'] as String? ?? '';
        final payload = (message['payload'] as Map<String, dynamic>?) ?? {};
        for (final handler in List<WsHandler>.from(_handlers)) {
          handler(event, payload);
        }
      } catch (_) {
        // Ignore malformed frames.
      }
    }, onError: (_) {}, onDone: () {});
  }

  void subscribe(String room) {
    _channel?.sink.add(jsonEncode({'action': 'subscribe', 'room': room}));
  }

  Future<void> disconnect() async {
    await _sub?.cancel();
    _sub = null;
    await _channel?.sink.close();
    _channel = null;
  }
}
