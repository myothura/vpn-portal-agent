import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import 'package:vpn_agent_app/core/services/remote_config_service.dart';
import 'package:vpn_agent_app/features/auth/services/auth_service.dart';

/// Realtime chat for the agent app via Laravel Reverb (Pusher protocol).
/// Subscribes to `private-agent.{agentId}.chat` — firehose of this agent's
/// assigned users' chats. Emits each incoming message map to listeners.
class AgentRealtimeService {
  AgentRealtimeService._();
  static final AgentRealtimeService instance = AgentRealtimeService._();

  static const String _appKey = 'ge9g2emzlgdbhoq877w7';

  // Ordered, de-duplicated, non-empty realtime hosts from RemoteConfig.
  // These are BARE HOSTS (no scheme, no /api) — the HTTP keys are full URLs
  // and the two formats are not interchangeable.
  static List<String> get _hosts {
    final rc = RemoteConfigService();
    final raw = <String>[
      rc.realtimeHost,
      rc.realtimeBackupHost,
      rc.realtimeBackupHost2,
      rc.realtimeBackupHost3,
    ];
    final seen = <String>{};
    final out = <String>[];
    for (final h in raw) {
      if (h.isEmpty) continue;
      if (seen.add(h)) out.add(h);
    }
    if (out.isEmpty) {
      out.addAll(['control.vpnportal.org', 'my-backup-api.org']);
    }
    return out;
  }

  // Advances on each failed reconnect so successive retries walk
  // primary -> backup -> backup2 -> backup3 -> primary ...
  int _hostIndex = 0;

  String get _host {
    final hosts = _hosts;
    return hosts[_hostIndex % hosts.length];
  }

  final AuthService _auth = AuthService();
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _pingTimer;
  Timer? _reconnectTimer;

  String? _socketId;
  int? _agentId;
  String? _token;
  String? _channelName;

  bool _starting = false;
  bool _wantConnected = false;
  int _reconnectAttempts = 0;

  final List<void Function(Map<String, dynamic>)> _listeners = [];

  void addListener(void Function(Map<String, dynamic>) cb) {
    if (!_listeners.contains(cb)) _listeners.add(cb);
  }

  void removeListener(void Function(Map<String, dynamic>) cb) {
    _listeners.remove(cb);
  }

  Future<void> start() async {
    if (_starting) return;
    if (_channel != null && _channelName != null) return;
    _starting = true;
    _wantConnected = true;
    try {
      _token = await _auth.getToken();
      _agentId = await _auth.getAgentId();
      if (_token == null || _agentId == null) {
        debugPrint('[AgentRealtime] missing token/agentId - abort');
        return;
      }
      _channelName = 'private-agent.$_agentId.chat';
      await _connect();
    } catch (e) {
      debugPrint('[AgentRealtime] start error: $e');
    } finally {
      _starting = false;
    }
  }

  Future<void> _connect() async {
    final uri = Uri.parse(
      'wss://$_host/app/$_appKey?protocol=7&client=flutter-agent&version=1.0',
    );
    debugPrint('[AgentRealtime] connecting $uri');
    _channel = WebSocketChannel.connect(uri);
    _sub = _channel!.stream.listen(
      _onData,
      onError: (e) {
        debugPrint('[AgentRealtime] socket error: $e');
        _scheduleReconnect();
      },
      onDone: () {
        debugPrint('[AgentRealtime] socket closed');
        _scheduleReconnect();
      },
      cancelOnError: true,
    );
  }

  Future<void> _onData(dynamic raw) async {
    try {
      final Map<String, dynamic> evt = jsonDecode(raw as String);
      final String event = evt['event'] ?? '';
      switch (event) {
        case 'pusher:connection_established':
          final data = _decodeData(evt['data']);
          _socketId = data['socket_id']?.toString();
          _reconnectAttempts = 0;
          debugPrint('[AgentRealtime] connected socket_id=$_socketId');
          _startPing();
          await _subscribe();
          break;
        case 'pusher_internal:subscription_succeeded':
          debugPrint('[AgentRealtime] subscribed ${evt['channel']}');
          break;
        case 'pusher:error':
          debugPrint('[AgentRealtime] pusher error: ${evt['data']}');
          break;
        case 'pusher:ping':
          _send({'event': 'pusher:pong', 'data': {}});
          break;
        case 'chat.new':
          final msg = _decodeData(evt['data']);
          if (msg.isNotEmpty) _emit(Map<String, dynamic>.from(msg));
          break;
        default:
          break;
      }
    } catch (e) {
      debugPrint('[AgentRealtime] onData error: $e');
    }
  }

  Map<String, dynamic> _decodeData(dynamic d) {
    if (d == null) return {};
    if (d is Map) return Map<String, dynamic>.from(d);
    if (d is String) {
      try {
        final p = jsonDecode(d);
        return p is Map ? Map<String, dynamic>.from(p) : {};
      } catch (_) {
        return {};
      }
    }
    return {};
  }

  Future<void> _subscribe() async {
    if (_channelName == null || _socketId == null) return;
    try {
      final res = await _dio.post(
        'https://$_host/api/broadcasting/auth',
        data: {'socket_id': _socketId, 'channel_name': _channelName},
        options: Options(headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
        }),
      );
      final auth = res.data is Map ? res.data['auth'] : null;
      if (auth == null) {
        debugPrint('[AgentRealtime] auth missing: ${res.data}');
        return;
      }
      _send({
        'event': 'pusher:subscribe',
        'data': {'auth': auth, 'channel': _channelName},
      });
    } catch (e) {
      debugPrint('[AgentRealtime] subscribe auth failed: $e');
    }
  }

  void _emit(Map<String, dynamic> msg) {
    for (final cb in List.of(_listeners)) {
      try {
        cb(msg);
      } catch (e) {
        debugPrint('[AgentRealtime] listener error: $e');
      }
    }
  }

  void _send(Map<String, dynamic> payload) {
    try {
      _channel?.sink.add(jsonEncode(payload));
    } catch (e) {
      debugPrint('[AgentRealtime] send error: $e');
    }
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _send({'event': 'pusher:ping', 'data': {}});
    });
  }

  void _scheduleReconnect() {
    _pingTimer?.cancel();
    _sub?.cancel();
    _sub = null;
    _channel = null;
    _socketId = null;
    if (!_wantConnected) return;
    _reconnectTimer?.cancel();
    final delay = Duration(seconds: (2 * (_reconnectAttempts + 1)).clamp(2, 30));
    _reconnectAttempts++;
    _hostIndex++;
    debugPrint('[AgentRealtime] reconnect in ${delay.inSeconds}s via $_host');
    _reconnectTimer = Timer(delay, () => _connect());
  }

  Future<void> stop() async {
    _wantConnected = false;
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    await _sub?.cancel();
    await _channel?.sink.close(ws_status.normalClosure);
    _channel = null;
    _socketId = null;
    _channelName = null;
  }
}
