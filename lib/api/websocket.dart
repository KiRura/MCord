import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:mcord/storage/token_storage.dart';

class DiscordWebSocket {
  static final DiscordWebSocket _instance = DiscordWebSocket._internal();
  factory DiscordWebSocket() => _instance;
  DiscordWebSocket._internal();

  WebSocketChannel? _channel;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  int _sequence = 0;
  bool _isConnected = false;
  final _messageStreamController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _messageUpdateStreamController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _messageDeleteStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messageStream =>
      _messageStreamController.stream;
  Stream<Map<String, dynamic>> get messageUpdateStream =>
      _messageUpdateStreamController.stream;
  Stream<Map<String, dynamic>> get messageDeleteStream =>
      _messageDeleteStreamController.stream;

  Future<void> connect() async {
    if (_isConnected) return;

    try {
      final token = await TokenStorage.getToken();
      if (token == null) throw Exception('トークンが見つかりません');

      // 既存の接続をクリーンアップ
      _cleanup();

      // WebSocket接続を確立
      _channel = WebSocketChannel.connect(
        Uri.parse('wss://gateway.discord.gg/?v=9&encoding=json'),
      );

      // メッセージリスナーを設定
      _channel!.stream.listen(
        (message) => _handleMessage(message),
        onError: (error) => _handleError(error),
        onDone: () => _handleDisconnect(),
      );

      // 初期化メッセージを送信
      _sendIdentify(token);
      _isConnected = true;
    } catch (e) {
      print('WebSocket接続エラー: $e');
      _scheduleReconnect();
    }
  }

  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message);

      // データの型チェック
      if (data is! Map<String, dynamic>) {
        print('予期しないデータ形式: ${data.runtimeType} - $data');
        return;
      }

      final op = data['op'] as int?;
      if (op == null) {
        print('opコードがありません: $data');
        return;
      }

      final d = data['d'];
      final s = data['s'] as int?;
      final t = data['t'] as String?;

      // シーケンス番号を更新
      if (s != null) _sequence = s;

      switch (op) {
        case 0: // Dispatch
          if (t == null) break;

          // dがMapでない場合はスキップ
          if (d is! Map<String, dynamic>) {
            print('無効なデータ形式 - イベント: $t, データ: $d');
            break;
          }

          switch (t) {
            case 'MESSAGE_CREATE':
              _messageStreamController.add(d);
              break;
            case 'MESSAGE_UPDATE':
              _messageUpdateStreamController.add(d);
              break;
            case 'MESSAGE_DELETE':
              _messageDeleteStreamController.add(d);
              break;
            default:
              print('未処理のイベント: $t');
          }
          break;
        case 10: // Hello
          if (d is Map<String, dynamic> &&
              d.containsKey('heartbeat_interval')) {
            _startHeartbeat(d['heartbeat_interval'] as int);
          } else {
            print('無効なHelloメッセージ: $d');
          }
          break;
        case 11: // Heartbeat ACK
          break;
        default:
          print('未処理のOPコード: $op');
      }
    } catch (e) {
      print('メッセージ処理エラー: $e');
    }
  }

  void _sendIdentify(String token) {
    final identify = {
      'op': 2,
      'd': {
        'token': token,
        'properties': {'os': 'windows', 'browser': 'mcord', 'device': 'mcord'},
        'intents': 513, // GUILD_MESSAGES (1 << 9) | DIRECT_MESSAGES (1 << 12)
      },
    };
    _channel?.sink.add(jsonEncode(identify));
  }

  void _startHeartbeat(int interval) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      Duration(milliseconds: interval),
      (timer) => _sendHeartbeat(),
    );
  }

  void _sendHeartbeat() {
    final heartbeat = {'op': 1, 'd': _sequence};
    _channel?.sink.add(jsonEncode(heartbeat));
  }

  void _handleError(error) {
    print('WebSocketエラー: $error');
    _handleDisconnect();
  }

  void _handleDisconnect() {
    _cleanup();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      connect();
    });
  }

  void _cleanup() {
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _isConnected = false;
  }

  void disconnect() {
    _cleanup();
    _messageStreamController.close();
    _messageUpdateStreamController.close();
    _messageDeleteStreamController.close();
  }
}
