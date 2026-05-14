import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// WebRTCシグナリングサーバーとの通信を管理するサービス
class SignalingService {
  WebSocketChannel? _channel;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  /// サーバーからのメッセージストリーム
  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  /// サーバーURL（環境に応じて自動検出）
  static String get defaultServerUrl {
    if (kIsWeb) {
      final uri = Uri.base;
      final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
      // 本番: 同一オリジン / 開発: localhost:8080
      if (uri.port == 8080 || uri.scheme == 'https') {
        return '$wsScheme://${uri.host}:${uri.port}';
      }
      return 'ws://${uri.host}:8080';
    }
    return 'ws://10.0.2.2:8080';
  }

  /// シグナリングサーバーに接続
  Future<void> connect({String? serverUrl}) async {
    final url = serverUrl ?? defaultServerUrl;
    debugPrint('シグナリングサーバーに接続中: $url');

    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      await _channel!.ready;

      _channel!.stream.listen(
        (data) {
          try {
            final msg = jsonDecode(data as String) as Map<String, dynamic>;
            debugPrint('受信: ${msg['type']}');
            _messageController.add(msg);
          } catch (e) {
            debugPrint('メッセージのパースに失敗: $e');
          }
        },
        onError: (error) {
          debugPrint('WebSocketエラー: $error');
          _messageController.addError(error);
        },
        onDone: () {
          debugPrint('WebSocket切断');
          _messageController.add({'type': 'disconnected'});
        },
      );

      debugPrint('シグナリングサーバーに接続しました');
    } catch (e) {
      debugPrint('接続に失敗しました: $e');
      rethrow;
    }
  }

  /// メッセージを送信
  void send(Map<String, dynamic> message) {
    if (_channel != null) {
      final data = jsonEncode(message);
      debugPrint('送信: ${message['type']}');
      _channel!.sink.add(data);
    }
  }

  /// ルームを作成（カメラ側、パスワード必須）
  void createRoom({required String password}) {
    send({'type': 'create_room', 'password': password});
  }

  /// ルームに参加（ビューワー側、パスワード必須）
  void joinRoom(String roomId, {required String password}) {
    send({'type': 'join_room', 'roomId': roomId, 'password': password});
  }

  /// WebRTC Offer を送信
  void sendOffer(Map<String, dynamic> offer) {
    send({'type': 'offer', 'sdp': offer});
  }

  /// WebRTC Answer を送信
  void sendAnswer(Map<String, dynamic> answer) {
    send({'type': 'answer', 'sdp': answer});
  }

  /// ICE Candidate を送信
  void sendCandidate(Map<String, dynamic> candidate) {
    send({'type': 'candidate', 'candidate': candidate});
  }

  /// ルームから退出
  void leave() {
    send({'type': 'leave'});
  }

  /// 接続を閉じる
  Future<void> disconnect() async {
    await _channel?.sink.close();
    _channel = null;
  }

  /// リソースを解放
  void dispose() {
    _channel?.sink.close();
    _messageController.close();
  }
}
