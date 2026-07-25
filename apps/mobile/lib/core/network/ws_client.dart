import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../config.dart';

typedef WsHandler = void Function(String event, Map<String, dynamic> payload);

class WsClient {
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  final _handlers = <WsHandler>[];
  final _rooms = <String>{};
  bool _handshakeOk = false;

  bool get isConnected =>
      _channel != null && _handshakeOk && _sub != null;

  void addHandler(WsHandler handler) {
    if (!_handlers.contains(handler)) {
      _handlers.add(handler);
    }
  }

  void removeHandler(WsHandler handler) => _handlers.remove(handler);

  Future<void> connect(String token) async {
    await disconnect().timeout(
      const Duration(seconds: 3),
      onTimeout: () {
        _sub = null;
        _channel = null;
        _handshakeOk = false;
      },
    );

    final ready = Completer<void>();
    _handshakeOk = false;

    final uri = Uri.parse(
      '${AppConfig.wsBaseUrl}/ws?token=${Uri.encodeComponent(token)}',
    );
    _channel = WebSocketChannel.connect(uri);
    try {
      await _channel!.ready.timeout(const Duration(seconds: 8));
    } catch (_) {
      // Keep listening; handshake event or stream error will settle ready.
    }

    _sub = _channel!.stream.listen(
      (raw) {
        try {
          final message = jsonDecode(raw as String) as Map<String, dynamic>;
          final event = message['event'] as String? ?? '';
          final payload =
              (message['payload'] as Map<String, dynamic>?) ?? {};
          if (event == 'connected' && !ready.isCompleted) {
            _handshakeOk = true;
            ready.complete();
          }
          for (final handler in List<WsHandler>.from(_handlers)) {
            handler(event, payload);
          }
        } catch (_) {
          // Ignore malformed frames.
        }
      },
      onError: (_) {
        _handshakeOk = false;
        if (!ready.isCompleted) {
          ready.completeError(StateError('ws_error'));
        }
        _channel = null;
      },
      onDone: () {
        _handshakeOk = false;
        _channel = null;
        _sub = null;
        if (!ready.isCompleted) {
          ready.completeError(StateError('ws_closed'));
        }
      },
    );

    try {
      await ready.future.timeout(const Duration(seconds: 10));
    } catch (_) {
      // Proceed anyway so callers can still attempt subscribe/reconnect.
      _handshakeOk = _channel != null;
    }

    // Re-join rooms after reconnect.
    for (final room in List<String>.from(_rooms)) {
      _channel?.sink.add(jsonEncode({'action': 'subscribe', 'room': room}));
    }
  }

  void subscribe(String room) {
    _rooms.add(room);
    if (_channel == null) return;
    _channel!.sink.add(jsonEncode({'action': 'subscribe', 'room': room}));
  }

  Future<void> disconnect() async {
    _rooms.clear();
    _handshakeOk = false;
    await _sub?.cancel();
    _sub = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }
}
