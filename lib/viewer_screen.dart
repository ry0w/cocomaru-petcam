import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'services/signaling_service.dart';

// Web-only imports for screenshot & fullscreen
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class ViewerScreen extends StatefulWidget {
  final String roomId;
  final String serverUrl;
  final String password;

  const ViewerScreen({
    super.key,
    required this.roomId,
    required this.serverUrl,
    required this.password,
  });

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen>
    with TickerProviderStateMixin {
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  final SignalingService _signaling = SignalingService();
  RTCPeerConnection? _peerConnection;
  StreamSubscription? _signalingSubscription;

  bool _isConnected = false;
  String _status = '接続中...';

  // Controls
  bool _controlsVisible = true;
  bool _isMuted = false;
  double _brightness = 0.0;

  // Animations
  late final AnimationController _controlsAnimController;
  late final AnimationController _pulseController;

  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
  };

  @override
  void initState() {
    super.initState();

    _controlsAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

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
      _signaling.joinRoom(widget.roomId, password: widget.password);
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

    _peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        setState(() {
          _remoteRenderer.srcObject = event.streams[0];
          _isConnected = true;
          _status = 'ココ丸を見守り中';
        });
      }
    };

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
          _status = 'ココ丸を見守り中';
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

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) {
      _controlsAnimController.forward();
    } else {
      _controlsAnimController.reverse();
    }
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    final audioTracks = _remoteRenderer.srcObject?.getAudioTracks();
    if (audioTracks != null) {
      for (final track in audioTracks) {
        track.enabled = !_isMuted;
      }
    }
  }

  void _saveScreenshot() {
    if (!kIsWeb) return;
    try {
      final video = html.document.querySelector('video') as html.VideoElement?;
      if (video == null) {
        debugPrint('Video element not found');
        return;
      }
      final canvas = html.CanvasElement(
        width: video.videoWidth,
        height: video.videoHeight,
      );
      canvas.context2D.drawImage(video, 0, 0);
      final dataUrl = canvas.toDataUrl('image/png');
      final anchor = html.AnchorElement(href: dataUrl)
        ..setAttribute(
            'download', 'cocomaru_${DateTime.now().millisecondsSinceEpoch}.png')
        ..click();

      // Show feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('スクリーンショットを保存しました'),
          backgroundColor: const Color(0xFFFF9BAA),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Screenshot failed: $e');
    }
  }

  void _toggleFullscreen() {
    if (!kIsWeb) return;
    try {
      final doc = html.document.documentElement;
      if (html.document.fullscreenElement != null) {
        html.document.exitFullscreen();
      } else {
        doc?.requestFullscreen();
      }
    } catch (e) {
      debugPrint('Fullscreen failed: $e');
    }
  }

  void _disconnect() {
    _signaling.leave();
    _peerConnection?.close();
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _controlsAnimController.dispose();
    _pulseController.dispose();
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
          'ココ丸ちゃんねる',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFFFF9BAA),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: GestureDetector(
        onTap: _isConnected ? _toggleControls : null,
        child: Stack(
          children: [
            // Remote video with brightness filter
            Center(
              child: _isConnected
                  ? ColorFiltered(
                      colorFilter: ColorFilter.matrix(<double>[
                        1 + _brightness, 0, 0, 0, _brightness * 50,
                        0, 1 + _brightness, 0, 0, _brightness * 50,
                        0, 0, 1 + _brightness, 0, _brightness * 50,
                        0, 0, 0, 1, 0,
                      ]),
                      child: RTCVideoView(
                        _remoteRenderer,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                      ),
                    )
                  : _buildWaitingView(),
            ),

            // Top status overlay
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
                ),
              ),
            ),

            // Bottom controls bar
            if (_isConnected)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: _controlsAnimController,
                    curve: Curves.easeInOut,
                  )),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.8),
                          Colors.black.withOpacity(0.4),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Brightness slider
                        Row(
                          children: [
                            const Icon(Icons.brightness_low,
                                color: Colors.white54, size: 18),
                            Expanded(
                              child: SliderTheme(
                                data: SliderThemeData(
                                  activeTrackColor: const Color(0xFFFF9BAA),
                                  inactiveTrackColor: Colors.white24,
                                  thumbColor: const Color(0xFFFF9BAA),
                                  overlayColor:
                                      const Color(0xFFFF9BAA).withOpacity(0.2),
                                  thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 8),
                                ),
                                child: Slider(
                                  value: _brightness,
                                  min: -0.5,
                                  max: 0.5,
                                  onChanged: (v) =>
                                      setState(() => _brightness = v),
                                ),
                              ),
                            ),
                            const Icon(Icons.brightness_high,
                                color: Colors.white54, size: 18),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Control buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _controlButton(
                              Icons.camera_alt_outlined,
                              'スクショ',
                              _saveScreenshot,
                            ),
                            _controlButton(
                              _isMuted ? Icons.volume_off : Icons.volume_up,
                              _isMuted ? 'ミュート中' : '音声ON',
                              _toggleMute,
                            ),
                            _controlButton(
                              Icons.fullscreen,
                              '全画面',
                              _toggleFullscreen,
                            ),
                            _controlButton(
                              Icons.call_end,
                              '終了',
                              _disconnect,
                              color: Colors.redAccent,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _controlButton(IconData icon, String label, VoidCallback onTap,
      {Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (color ?? Colors.white).withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: (color ?? Colors.white).withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Icon(icon, color: color ?? Colors.white, size: 22),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildWaitingView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _pulseController,
          builder: (_, child) {
            final scale = 0.9 + _pulseController.value * 0.1;
            return Transform.scale(scale: scale, child: child);
          },
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFFF9BAA).withOpacity(0.5),
                width: 3,
              ),
            ),
            child: const Center(
              child: SizedBox(
                width: 50,
                height: 50,
                child: CircularProgressIndicator(
                  color: Color(0xFFFF9BAA),
                  strokeWidth: 3,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: Text(
            _status,
            key: ValueKey(_status),
            style: const TextStyle(
              fontSize: 18,
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'ルーム: ${widget.roomId}',
          style: const TextStyle(fontSize: 14, color: Colors.white38),
        ),
        const SizedBox(height: 32),
        GestureDetector(
          onTap: _disconnect,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
            ),
            child: const Text(
              '切断する',
              style: TextStyle(color: Colors.redAccent, fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }
}
