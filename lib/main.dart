import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'camera_screen.dart';
import 'viewer_screen.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js' as js;
import 'services/signaling_service.dart';

void main() {
  runApp(const CocomaruApp());
}

class CocomaruApp extends StatelessWidget {
  const CocomaruApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ココ丸ちゃんねる',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFB6C1),
          primary: const Color(0xFFFF9BAA),
          surface: Colors.white,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.mPlusRounded1cTextTheme(),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final _serverUrlController = TextEditingController(
    text: SignalingService.defaultServerUrl,
  );
  final _roomCodeController = TextEditingController();
  bool _showSettings = false;

  // Animations
  late final AnimationController _floatController;
  late final AnimationController _fadeController;
  late final AnimationController _heartController;

  @override
  void initState() {
    super.initState();

    // Avatar floating animation
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    // Staggered fade-in for buttons
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    // Heart pulse
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatController.dispose();
    _fadeController.dispose();
    _heartController.dispose();
    _serverUrlController.dispose();
    _roomCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9FA),
      body: SafeArea(
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFF9FA), Color(0xFFFFE6EB)],
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Settings button
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: IconButton(
                      onPressed: () =>
                          setState(() => _showSettings = !_showSettings),
                      icon: AnimatedRotation(
                        turns: _showSettings ? 0.25 : 0,
                        duration: const Duration(milliseconds: 300),
                        child: Icon(
                          _showSettings ? Icons.close : Icons.settings,
                          color: const Color(0xFFA69089),
                        ),
                      ),
                    ),
                  ),
                ),

                // Settings panel with animation
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: _showSettings ? _buildSettingsPanel() : const SizedBox.shrink(),
                ),

                // Floating avatar
                AnimatedBuilder(
                  animation: _floatController,
                  builder: (context, child) {
                    final dy = sin(_floatController.value * pi) * 10;
                    return Transform.translate(
                      offset: Offset(0, -dy),
                      child: child,
                    );
                  },
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 6),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF9BAA).withOpacity(0.3),
                          blurRadius: 24,
                          spreadRadius: 6,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Center(
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/coco.jpg',
                          width: 138,
                          height: 138,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Title fade-in
                FadeTransition(
                  opacity: CurvedAnimation(
                    parent: _fadeController,
                    curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
                  ),
                  child: const Text(
                    'ココ丸ちゃんねる',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF8B736B),
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                FadeTransition(
                  opacity: CurvedAnimation(
                    parent: _fadeController,
                    curve: const Interval(0.2, 0.6, curve: Curves.easeOut),
                  ),
                  child: const Text(
                    'お留守番中のココを見守るよ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFA69089),
                    ),
                  ),
                ),
                const SizedBox(height: 48),

                // Camera button - staggered slide + fade
                SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.3),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: _fadeController,
                    curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
                  )),
                  child: FadeTransition(
                    opacity: CurvedAnimation(
                      parent: _fadeController,
                      curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
                    ),
                    child: _buildModeButton(
                      context,
                      icon: Icons.video_camera_front,
                      title: 'カメラモード',
                      subtitle: 'お部屋に置いて撮影する',
                      onTap: () => _showPasswordSetupDialog(context),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Viewer button - staggered slide + fade
                SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.3),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: _fadeController,
                    curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
                  )),
                  child: FadeTransition(
                    opacity: CurvedAnimation(
                      parent: _fadeController,
                      curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
                    ),
                    child: _buildModeButton(
                      context,
                      icon: Icons.visibility,
                      title: 'ビュワーモード',
                      subtitle: '外出先から様子を見る',
                      onTap: () => _showRoomCodeDialog(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF9BAA).withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'サーバー設定',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF8B736B),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _serverUrlController,
            decoration: InputDecoration(
              labelText: 'シグナリングサーバーURL',
              hintText: 'ws://localhost:8080',
              prefixIcon:
                  const Icon(Icons.dns, color: Color(0xFFA69089), size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFFFE6EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFFF9BAA)),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            style: const TextStyle(fontSize: 14, color: Color(0xFF6B5B4F)),
          ),
          const SizedBox(height: 8),
          const Text(
            'HTTPS使用時は wss:// に変更してください',
            style: TextStyle(fontSize: 12, color: Color(0xFFA69089)),
          ),
        ],
      ),
    );
  }

  void _showPasswordSetupDialog(BuildContext context) {
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.lock, color: Color(0xFFFF9BAA)),
            SizedBox(width: 8),
            Text(
              'パスワードを設定',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF8B736B),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'ビューワーが接続する際に必要なパスワードを設定してください（4文字以上）',
              style: TextStyle(fontSize: 13, color: Color(0xFFA69089)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8B736B),
              ),
              decoration: InputDecoration(
                hintText: 'パスワード',
                prefixIcon: const Icon(Icons.lock_outline,
                    color: Color(0xFFA69089), size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFFFE6EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      const BorderSide(color: Color(0xFFFF9BAA), width: 2),
                ),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル',
                style: TextStyle(color: Color(0xFFA69089))),
          ),
          ElevatedButton(
            onPressed: () {
              final pw = passwordController.text;
              if (pw.length >= 4) {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (_, __, ___) => CameraScreen(
                      serverUrl: _serverUrlController.text,
                      password: pw,
                    ),
                    transitionsBuilder: (_, animation, __, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    transitionDuration: const Duration(milliseconds: 400),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF9BAA),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('配信開始',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _scanQrFromImage(TextEditingController controller) {
    if (!kIsWeb) return;

    final input = html.FileUploadInputElement()..accept = 'image/*';
    input.click();

    input.onChange.listen((event) {
      final file = input.files?.first;
      if (file == null) return;

      final reader = html.FileReader();
      reader.readAsDataUrl(file);
      reader.onLoadEnd.listen((_) {
        final dataUrl = reader.result as String;
        final img = html.ImageElement(src: dataUrl);
        img.onLoad.listen((_) {
          final canvas = html.CanvasElement(
            width: img.width,
            height: img.height,
          );
          final ctx = canvas.context2D;
          ctx.drawImage(img, 0, 0);
          final imageData = ctx.getImageData(0, 0, img.width!, img.height!);

          // Call jsQR
          final result = js.context.callMethod('jsQR', [
            imageData.data,
            img.width,
            img.height,
          ]);

          if (result != null) {
            final data = (result as js.JsObject)['data'] as String;
            controller.text = data;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('ルームコード読み取り完了: $data'),
                backgroundColor: const Color(0xFFFF9BAA),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('QRコードを読み取れませんでした'),
                backgroundColor: Colors.grey,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            );
          }
        });
      });
    });
  }

  void _showRoomCodeDialog(BuildContext context) {
    _roomCodeController.clear();
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.key, color: Color(0xFFFF9BAA)),
            SizedBox(width: 8),
            Text(
              'ルームに接続',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF8B736B),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'QR画像を読み取るか、ルームコードを手入力してください',
              style: TextStyle(fontSize: 13, color: Color(0xFFA69089)),
            ),
            const SizedBox(height: 12),
            // QR読み取りボタン
            if (kIsWeb)
              GestureDetector(
                onTap: () => _scanQrFromImage(_roomCodeController),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF9BAA), Color(0xFFFFB6C1)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF9BAA).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.qr_code_scanner, color: Colors.white, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'QR画像から読み取り',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (kIsWeb) const SizedBox(height: 12),
            if (kIsWeb)
              const Row(
                children: [
                  Expanded(child: Divider(color: Color(0xFFFFE6EB))),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('または',
                        style: TextStyle(fontSize: 12, color: Color(0xFFA69089))),
                  ),
                  Expanded(child: Divider(color: Color(0xFFFFE6EB))),
                ],
              ),
            if (kIsWeb) const SizedBox(height: 12),
            TextField(
              controller: _roomCodeController,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                color: Color(0xFF8B736B),
              ),
              decoration: InputDecoration(
                labelText: 'ルームコード',
                prefixIcon: const Icon(Icons.meeting_room,
                    color: Color(0xFFA69089), size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFFFE6EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      const BorderSide(color: Color(0xFFFF9BAA), width: 2),
                ),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8B736B),
              ),
              decoration: InputDecoration(
                labelText: 'パスワード',
                prefixIcon: const Icon(Icons.lock_outline,
                    color: Color(0xFFA69089), size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFFFE6EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      const BorderSide(color: Color(0xFFFF9BAA), width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル',
                style: TextStyle(color: Color(0xFFA69089))),
          ),
          ElevatedButton(
            onPressed: () {
              final code = _roomCodeController.text.trim();
              final pw = passwordController.text;
              if (code.isNotEmpty && pw.isNotEmpty) {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (_, __, ___) => ViewerScreen(
                      roomId: code,
                      serverUrl: _serverUrlController.text,
                      password: pw,
                    ),
                    transitionsBuilder: (_, animation, __, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    transitionDuration: const Duration(milliseconds: 400),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF9BAA),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('接続する',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 300,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF9BAA).withOpacity(0.25),
              blurRadius: 16,
              offset: const Offset(0, 8),
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F5),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFFE6EB), width: 2),
              ),
              child: Icon(icon, color: const Color(0xFFFF9BAA), size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF8B736B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFA69089),
                    ),
                  ),
                ],
              ),
            ),
            // Pulsing heart
            AnimatedBuilder(
              animation: _heartController,
              builder: (context, child) {
                final scale = 1.0 + _heartController.value * 0.3;
                return Transform.scale(scale: scale, child: child);
              },
              child: const Icon(Icons.favorite, color: Color(0xFFFF9BAA), size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
