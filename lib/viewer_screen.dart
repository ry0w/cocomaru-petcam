import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'services/signaling_service.dart';

class ViewerScreen extends StatefulWidget {
  final String roomId;
  final String serverUrl;

  const ViewerScreen({
    super.key,
    required this.roomId,
    required this.serverUrl,
  });

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  final SignalingService _signaling = SignalingService();
  RTCPeerConnection? _peerConnection;
  StreamSubscription? _signalingSubscription;

  bool _isConnected = false;
  String _status = '接続中...';

  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
  };

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _remoteRenderer.initialize();
    await _connectSignaling();
  }

  Future<void> _connectSignaling() async {
    try {
      await _signaling.connect(serverUrl: widget.serverUrl);
      _listenToSignaling();
      _signaling.joinRoom(widget.roomId);
      setState(() => _status = 'ルームに参加中...');
    } catch (e) {
      debugPrint('シグナリング接続失敗: $e');
      setState(() => _status = 'サーバーに接続できません');
    }
  }

  void _listenToSignaling() {
    _signalingSubscription = _signaling.messages.listen((msg) async {
      switch (msg['type']) {
        case 'room_joined':
          setState(() => _status = 'カメラからの接続を待っています...');
          break;

        case 'offer':
          setState(() => _status = '映像を受信中...');
          await _createPeerConnection();
          final sdp = msg['sdp'];
          await _peerConnection?.setRemoteDescription(
            RTCSessionDescription(sdp['sdp'], sdp['type']),
          );
          await _createAndSendAnswer();
          break;

        case 'candidate':
          final c = msg['candidate'];
          await _peerConnection?.addCandidate(
            RTCIceCandidate(c['candidate'], c['sdpMid'], c['sdpMLineIndex']),
          );
          break;

        case 'peer_disconnected':
          setState(() {
            _isConnected = false;
            _status = 'カメラが切断されました';
          });
          await _peerConnection?.close();
          _peerConnection = null;
          _remoteRenderer.srcObject = null;
          break;

        case 'disconnected':
          setState(() => _status = 'サーバーから切断されました');
          break;

        case 'error':
          setState(() => _status = 'エラー: ${msg['message']}');
          break;
      }
    });
  }

  Future<void> _createPeerConnection() async {
    _peerConnection = await createPeerConnection(_iceServers);

    // リモートストリームを受信
    _peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        setState(() {
          _remoteRenderer.srcObject = event.streams[0];
          _isConnected = true;
          _status = 'ココ丸を見守り中 🐾';
        });
      }
    };

    // ICE候補をシグナリングサーバー経由で送信
    _peerConnection!.onIceCandidate = (candidate) {
      _signaling.sendCandidate({
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    _peerConnection!.onIceConnectionState = (state) {
      debugPrint('ICE接続状態: $state');
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected) {
        setState(() {
          _isConnected = true;
          _status = 'ココ丸を見守り中 🐾';
        });
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        setState(() => _status = '接続に失敗しました');
      }
    };
  }

  Future<void> _createAndSendAnswer() async {
    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);
    _signaling.sendAnswer({'sdp': answer.sdp, 'type': answer.type});
  }

  void _disconnect() {
    _signaling.leave();
    _peerConnection?.close();
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _signalingSubscription?.cancel();
    _peerConnection?.close();
    _remoteRenderer.dispose();
    _signaling.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'ココ丸ちゃんねる (ビュワー)',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFFFF9BAA),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Stack(
        children: [
          // リモート映像
          Center(
            child: _isConnected
                ? RTCVideoView(
                    _remoteRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                  )
                : _buildWaitingView(),
          ),

          // ステータスオーバーレイ
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.6),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isConnected ? Icons.videocam : Icons.wifi_tethering,
                      color: _isConnected
                          ? Colors.greenAccent
                          : Colors.orangeAccent,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _status,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _disconnect,
        tooltip: '視聴終了',
        backgroundColor: Colors.redAccent,
        child: const Icon(Icons.call_end, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildWaitingView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: 60,
          height: 60,
          child: CircularProgressIndicator(
            color: Color(0xFFFF9BAA),
            strokeWidth: 3,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          _status,
          style: const TextStyle(
            fontSize: 18,
            color: Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'ルーム: ${widget.roomId}',
          style: const TextStyle(
            fontSize: 14,
            color: Colors.white38,
          ),
        ),
      ],
    );
  }
}
