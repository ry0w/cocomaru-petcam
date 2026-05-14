import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'services/signaling_service.dart';

class CameraScreen extends StatefulWidget {
  final String serverUrl;
  final String password;

  const CameraScreen({super.key, required this.serverUrl, required this.password});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with TickerProviderStateMixin {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final SignalingService _signaling = SignalingService();
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  StreamSubscription? _signalingSubscription;

  String? _roomId;
  bool _isCameraReady = false;
  bool _isViewerConnected = false;
  String _status = 'カメラを起動中...';

  // Animations
  late final AnimationController _pulseController;
  late final AnimationController _qrFadeController;

  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
  };

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _qrFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

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
          'facingMode': 'environment',
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
      _signaling.createRoom(password: widget.password);
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
          _qrFadeController.forward();
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
          setState(() => _status = '配信中');
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

    _localStream?.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });

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
        setState(() => _status = '配信中');
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
    _pulseController.dispose();
    _qrFadeController.dispose();
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
          'ココ丸ちゃんねる',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFFFF9BAA),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Camera preview
          Center(
            child: _isCameraReady
                ? RTCVideoView(_localRenderer)
                : const CircularProgressIndicator(color: Color(0xFFFF9BAA)),
          ),

          // Status overlay
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
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // Status with pulsing dot
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isViewerConnected)
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (_, __) => Container(
                              width: 10,
                              height: 10,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.redAccent.withOpacity(
                                    0.4 + _pulseController.value * 0.6),
                              ),
                            ),
                          )
                        else
                          Icon(
                            Icons.wifi_tethering,
                            color: Colors.orangeAccent,
                            size: 18,
                          ),
                        if (!_isViewerConnected) const SizedBox(width: 8),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          child: Text(
                            _status,
                            key: ValueKey(_status),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // QR Code + Room code overlay (center)
          if (_roomId != null && !_isViewerConnected)
            Center(
              child: FadeTransition(
                opacity: _qrFadeController,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF9BAA).withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'ビューワーで読み取ってね',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFA69089),
                        ),
                      ),
                      const SizedBox(height: 16),
                      QrImageView(
                        data: _roomId!,
                        version: QrVersions.auto,
                        size: 180,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Color(0xFFFF9BAA),
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Color(0xFF8B736B),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF0F5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SelectableText(
                          _roomId!,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                            color: Color(0xFF8B736B),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'ルームコード（タップでコピー可）',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFFA69089),
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
        onPressed: _hangUp,
        tooltip: '配信終了',
        backgroundColor: Colors.redAccent,
        child: const Icon(Icons.call_end, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
