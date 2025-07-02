// lib/main.dart

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

import 'camera_settings.dart';
import 'requirements_screen.dart';
import 'camera_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _requestPermissions();
  List<CameraDescription> cams;
  try {
    cams = await availableCameras();
  } catch (_) {
    cams = [];
  }
  runApp(MyApp(cameras: cams));
}

Future<void> _requestPermissions() async {
  await Permission.camera.request();
  await Permission.storage.request();
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
          RequirementsScreen(onSettingsReceived: (s) {
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
