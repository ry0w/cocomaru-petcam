import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'services/signaling_service.dart';

class CameraScreen extends StatefulWidget {
  final String serverUrl;

  const CameraScreen({super.key, required this.serverUrl});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final SignalingService _signaling = SignalingService();
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  StreamSubscription? _signalingSubscription;

  String? _roomId;
  bool _isCameraReady = false;
  bool _isViewerConnected = false;
  String _status = 'カメラを起動中...';

  // STUN/TURNサーバー設定
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
    await _localRenderer.initialize();
    await _startCamera();
    await _connectSignaling();
  }

  Future<void> _startCamera() async {
    try {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {
          'facingMode': 'environment', // 背面カメラ（ペット撮影用）
          'width': {'ideal': 1280},
          'height': {'ideal': 720},
        },
      });
      _localRenderer.srcObject = _localStream;
      setState(() {
        _isCameraReady = true;
        _status = 'サーバーに接続中...';
      });
    } catch (e) {
      debugPrint('カメラの起動に失敗: $e');
      setState(() => _status = 'カメラの起動に失敗しました');
    }
  }

  Future<void> _connectSignaling() async {
    try {
      await _signaling.connect(serverUrl: widget.serverUrl);
      _listenToSignaling();
      _signaling.createRoom();
      setState(() => _status = 'ルームを作成中...');
    } catch (e) {
      debugPrint('シグナリング接続失敗: $e');
      setState(() => _status = 'サーバーに接続できません');
    }
  }

  void _listenToSignaling() {
    _signalingSubscription = _signaling.messages.listen((msg) async {
      switch (msg['type']) {
        case 'room_created':
          setState(() {
            _roomId = msg['roomId'] as String;
            _status = 'ビューワーの接続を待っています';
          });
          break;

        case 'viewer_connected':
          setState(() {
            _isViewerConnected = true;
            _status = '接続を確立中...';
          });
          await _createPeerConnection();
          await _createAndSendOffer();
          break;

        case 'answer':
          final sdp = msg['sdp'];
          await _peerConnection?.setRemoteDescription(
            RTCSessionDescription(sdp['sdp'], sdp['type']),
          );
          setState(() => _status = '配信中 🐾');
          break;

        case 'candidate':
          final c = msg['candidate'];
          await _peerConnection?.addCandidate(
            RTCIceCandidate(c['candidate'], c['sdpMid'], c['sdpMLineIndex']),
          );
          break;

        case 'peer_disconnected':
          setState(() {
            _isViewerConnected = false;
            _status = 'ビューワーが切断されました';
          });
          await _peerConnection?.close();
          _peerConnection = null;
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

    // ローカルストリームのトラックを追加
    _localStream?.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });

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
        setState(() => _status = '配信中 🐾');
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        setState(() => _status = '接続に失敗しました');
      }
    };
  }

  Future<void> _createAndSendOffer() async {
    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    _signaling.sendOffer({'sdp': offer.sdp, 'type': offer.type});
  }

  void _hangUp() {
    _signaling.leave();
    _peerConnection?.close();
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream?.dispose();
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _signalingSubscription?.cancel();
    _peerConnection?.close();
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream?.dispose();
    _localRenderer.dispose();
    _signaling.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'ココ丸ちゃんねる (カメラ)',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFFFF9BAA),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Stack(
        children: [
          // カメラプレビュー
          Center(
            child: _isCameraReady
                ? RTCVideoView(_localRenderer)
                : const CircularProgressIndicator(color: Color(0xFFFF9BAA)),
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
                child: Column(
                  children: [
                    // ステータス表示
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isViewerConnected
                              ? Icons.videocam
                              : Icons.wifi_tethering,
                          color: _isViewerConnected
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
                    // ルームコード表示
                    if (_roomId != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.key, color: Colors.white70, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'ルームコード: $_roomId',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _hangUp,
        tooltip: '配信終了',
        backgroundColor: Colors.redAccent,
        child: const Icon(Icons.call_end, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
