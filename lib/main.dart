import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'camera_screen.dart';
import 'viewer_screen.dart';
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

class _HomeScreenState extends State<HomeScreen> {
  final _serverUrlController = TextEditingController(
    text: SignalingService.defaultServerUrl,
  );
  final _roomCodeController = TextEditingController();
  bool _showSettings = false;

  @override
  void dispose() {
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
                // 設定ボタン
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: IconButton(
                      onPressed: () =>
                          setState(() => _showSettings = !_showSettings),
                      icon: Icon(
                        _showSettings ? Icons.close : Icons.settings,
                        color: const Color(0xFFA69089),
                      ),
                    ),
                  ),
                ),

                // 設定パネル
                if (_showSettings) _buildSettingsPanel(),

                // アバター
                Container(
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
                        'images/coco.jpg',
                        width: 138,
                        height: 138,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'ココ丸ちゃんねる',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF8B736B),
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'お留守番中のココを見守るよ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFA69089),
                  ),
                ),
                const SizedBox(height: 48),

                // カメラモードボタン
                _buildModeButton(
                  context,
                  icon: Icons.video_camera_front,
                  title: 'カメラモード',
                  subtitle: 'お部屋に置いて撮影する',
                  onTap: () => _showPasswordSetupDialog(context),
                ),
                const SizedBox(height: 16),

                // ビュワーモードボタン
                _buildModeButton(
                  context,
                  icon: Icons.visibility,
                  title: 'ビュワーモード',
                  subtitle: '外出先から様子を見る',
                  onTap: () => _showRoomCodeDialog(context),
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
            child: const Text(
              'キャンセル',
              style: TextStyle(color: Color(0xFFA69089)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final pw = passwordController.text;
              if (pw.length >= 4) {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CameraScreen(
                      serverUrl: _serverUrlController.text,
                      password: pw,
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF9BAA),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              '配信開始',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
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
              'カメラ画面に表示されているルームコードとパスワードを入力してください',
              style: TextStyle(fontSize: 13, color: Color(0xFFA69089)),
            ),
            const SizedBox(height: 16),
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
                hintText: 'abc123def456',
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
            child: const Text(
              'キャンセル',
              style: TextStyle(color: Color(0xFFA69089)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final code = _roomCodeController.text.trim();
              final pw = passwordController.text;
              if (code.isNotEmpty && pw.isNotEmpty) {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ViewerScreen(
                      roomId: code,
                      serverUrl: _serverUrlController.text,
                      password: pw,
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF9BAA),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              '接続する',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
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
            const Icon(Icons.favorite, color: Color(0xFFFFE6EB), size: 20),
          ],
        ),
      ),
    );
  }
}
