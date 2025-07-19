// lib/main.dart

import 'package:camgent/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

import 'camera_settings.dart';
import 'requirements_screen.dart';
import 'camera_screen.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _requestAllPermissions();
  List<CameraDescription> cams;
  try {
    cams = await availableCameras();
  } catch (_) {
    cams = [];
  }
  runApp(MyApp(cameras: cams));
}

Future<void> _requestAllPermissions() async {
  final perms = <Permission>[
    Permission.camera,
    Permission.storage,
    Permission.photos,                 // iOS 사진 읽기
    Permission.photosAddOnly,          // iOS14+ 사진 추가 전용
    Permission.microphone,             // 음성 녹화
  ];

  // Android 11+ (API 30+) 관리형 저장소 권한 추가
  if (Platform.isAndroid) {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdkInt = androidInfo.version.sdkInt ?? 0;
    if (sdkInt >= 30) {
      perms.add(Permission.manageExternalStorage);
    }
  }
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  const MyApp({Key? key, required this.cameras}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '요구사항 & 카메라 앱',
      theme: ThemeData(useMaterial3: true),
      home: MainScreen(cameras: cameras),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const MainScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  CameraSettings? _cameraSettings;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          ChatScreen(onSettingsReceived: (s) {
            setState(() {
              _cameraSettings = s;
              _currentIndex = 1;
            });
          }),
          CameraScreen(
            cameras: widget.cameras,
            cameraSettings: _cameraSettings,
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: '요구사항',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt),
            label: '카메라',
          ),
        ],
      ),
    );
  }
}