import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

import 'chat_screen.dart';
import 'camera_screen.dart';
import 'camera_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CAMgent',
      theme: ThemeData(useMaterial3: true),
      home: const PermissionGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// 권한 요청/점검 게이트
class PermissionGate extends StatefulWidget {
  const PermissionGate({Key? key}) : super(key: key);

  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate> {
  bool _checking = true;     // 현재 권한 점검 중
  bool _requesting = false;  // 권한 요청 중
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkAlreadyGranted();
  }

  /// 플랫폼/SDK에 맞는 권한 목록 구성
  Future<List<Permission>> _buildPerms() async {
    final perms = <Permission>[Permission.camera];

    if (Platform.isAndroid) {
      final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt ?? 0;

      // 저장은 MediaStore로 하므로 보통 추가 권한이 필요 없지만,
      // 하위 SDK 호환을 위해 선택적으로 요청
      if (sdk < 30) {
        perms.add(Permission.storage);              // Android 10 이하
      } else {
        // Android 11~12: 대부분 불필요하지만, 기기 설정/롬에 따라 필요할 수 있어 옵션
        // 거부되어도 앱은 동작함
        perms.add(Permission.manageExternalStorage);
      }
    } else if (Platform.isIOS) {
      // iOS는 갤러리 저장 시 photos 권한 체크
      perms.addAll([Permission.photos, Permission.photosAddOnly]);
    }

    return perms;
  }

  /// 앱 시작 시: 이미 모두 허용돼 있으면 메인으로 바로 이동
  Future<void> _checkAlreadyGranted() async {
    final perms = await _buildPerms();

    // 현재 상태만 확인 (요청 X)
    final statuses = await Future.wait(perms.map((p) => p.status));
    final allGranted = statuses.every((s) => s.isGranted);

    if (!mounted) return;

    if (allGranted) {
      // 바로 메인으로 교체
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      });
    } else {
      setState(() => _checking = false); // 권한 화면을 표시
    }
  }

  /// 버튼 눌렀을 때: 일괄 요청하고 통과하면 메인으로 이동
  Future<void> _requestAndStart() async {
    setState(() {
      _requesting = true;
      _error = null;
    });

    try {
      final perms = await _buildPerms();
      final results = await perms.request();

      final allGranted = results.values.every((s) => s.isGranted);
      if (!allGranted) {
        throw Exception('필수 권한이 모두 허용되지 않았습니다.');
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1) 권한 상태 점검 중이면 로딩
    if (_checking || _requesting) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 2) 점검 결과: 아직 미허용 → 안내 + 요청 버튼
    return Scaffold(
      appBar: AppBar(title: const Text('권한 요청')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '앱을 사용하려면 다음 권한이 필요합니다:\n\n'
                  '• 카메라 접근\n'
                  '• 저장소 접근(사진 저장)\n',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _requestAndStart,
              child: const Text('권한 요청 및 시작'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 권한 통과 후 실제 앱 화면
class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  CameraSettings? _cameraSettings;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _currentIndex == 0
          ? ChatScreen(onSettingsReceived: (s) {
        setState(() {
          _cameraSettings = s;
          _currentIndex = 1;
        });
      })
          : CameraScreen(
        cameraSettings: _cameraSettings,
        onBackToChat: () => setState(() => _currentIndex = 0),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: '어시스턴트'),
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: '카메라'),
        ],
      ),
    );
  }

}
