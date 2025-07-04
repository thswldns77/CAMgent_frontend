// lib/camera_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'camera_settings.dart';

// camera_screen.dart 맨 위에
const int _FLASH_MODE_OFF = 0;
const int _FLASH_MODE_SINGLE = 1;
const int _FLASH_MODE_TORCH = 2;

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final CameraSettings? cameraSettings;
  const CameraScreen({
    Key? key,
    required this.cameras,
    this.cameraSettings,
  }) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  // 1) MethodChannel 선언 (MainActivity.java 의 CHANNEL 값과 동일해야 합니다)
  static const _platform = MethodChannel('camera_settings_channel');

  CameraController? _ctrl;
  bool _initd = false;
  String? _error;
  final _shots = <String>[];

  @override
  void initState() {
    super.initState();
    _initCam();
  }

  Future<void> _initCam() async {
    if (widget.cameras.isEmpty) {
      setState(() => _error = '사용 가능한 카메라가 없습니다.');
      return;
    }
    try {
      _ctrl = CameraController(widget.cameras[0], ResolutionPreset.medium);
      await _ctrl!.initialize();
      if (!mounted) return;
      setState(() {
        _initd = true;
        _error = null;
      });
      // Flutter 설정 적용
      await _applySettings();
    } catch (e) {
      if (mounted) setState(() => _error = '초기화 실패: $e');
    }
  }

  Future<void> _applySettings() async {
    final s = widget.cameraSettings;
    if (_ctrl == null || !_ctrl!.value.isInitialized || s == null) return;

    // --- 2) Flutter camera 패키지로 적용 가능한 설정 ---
    try {
      if (s.controlAeExposureCompensation != null) {
        await _ctrl!.setExposureOffset(s.controlAeExposureCompensation!);
      }
      if (s.flashMode != null) {
        await _ctrl!.setFlashMode(
          FlashMode.values.firstWhere(
            (m) => m.toString().split('.').last.toLowerCase() ==
                   s.flashMode!.toLowerCase(),
            orElse: () => FlashMode.auto,
          ),
        );
      }
    } catch (_) {
      // Flutter 적용 실패해도 네이티브 연동은 시도
    }

    // --- 3) 네이티브(MainActivity.java) 쪽에 Settings 전달 ---
    final nativeParams = <String, dynamic>{};

    if (s.sensorSensitivity != null) {
      nativeParams['SENSOR_SENSITIVITY'] = s.sensorSensitivity;
    }
    if (s.sensorExposureTime != null) {
      // 네이티브는 나노초(long) 단위 기대
      nativeParams['SENSOR_EXPOSURE_TIME'] =
          (s.sensorExposureTime! * 1e9).toInt();
    }
    if (s.controlAeExposureCompensation != null) {
      nativeParams['CONTROL_AE_EXPOSURE_COMPENSATION'] =
          s.controlAeExposureCompensation!.toInt();
    }
    if (s.flashMode != null) {
      nativeParams['FLASH_MODE'] = _flashModeToNative(s.flashMode!);
    }
    // 필요에 따라 여기에 더 많은 키를 추가하세요 (COLOR_CORRECTION_GAINS, LENS_FOCUS_DISTANCE 등)

    try {
      await _platform.invokeMethod('applyCameraSettings', nativeParams);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('네이티브 카메라 설정 적용 완료'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('네이티브 설정 실패: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  // 매핑 함수
  int _flashModeToNative(String mode) {
    switch (mode.toLowerCase()) {
      case 'off':
        return _FLASH_MODE_OFF;
      case 'single':
      case 'auto':
        return _FLASH_MODE_SINGLE;
      case 'torch':
      case 'always':
        return _FLASH_MODE_TORCH;
      default:
        return _FLASH_MODE_OFF;
    }
  }


  Future<void> _takePic() async {
    if (_ctrl != null && _ctrl!.value.isInitialized) {
      final file = await _ctrl!.takePicture();
      setState(() => _shots.add(file.path));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사진 촬영 완료')),
        );
      }
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (!_initd) {
      return const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('카메라'),
        actions: [
          if (widget.cameraSettings != null)
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('현재 설정'),
                  content: Text(
                    'ISO: ${widget.cameraSettings!.sensorSensitivity}\n'
                    '노출 보정: ${widget.cameraSettings!.controlAeExposureCompensation}\n'
                    '플래시 모드: ${widget.cameraSettings!.flashMode}',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    )
                  ],
                ),
              ),
            ),
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.photo_library),
                if (_shots.isNotEmpty)
                  Positioned(
                    right: 0,
                    child: CircleAvatar(
                      radius: 6,
                      backgroundColor: Colors.red,
                      child: Text(
                        '${_shots.length}',
                        style: const TextStyle(
                          fontSize: 8,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: _shots.isEmpty
                ? null
                : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GalleryScreen(images: _shots),
                      ),
                    ),
          ),
        ],
      ),
      body: CameraPreview(_ctrl!),
      floatingActionButton: FloatingActionButton(
        onPressed: _takePic,
        child: const Icon(Icons.camera_alt),
      ),
    );
  }
}

class GalleryScreen extends StatelessWidget {
  final List<String> images;
  const GalleryScreen({Key? key, required this.images}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('갤러리 (${images.length})')),
      body: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, crossAxisSpacing: 4, mainAxisSpacing: 4),
        itemCount: images.length,
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FullScreenImage(imagePath: images[i]),
            ),
          ),
          child: Image.file(File(images[i]), fit: BoxFit.cover),
        ),
      ),
    );
  }
}

class FullScreenImage extends StatelessWidget {
  final String imagePath;
  const FullScreenImage({Key? key, required this.imagePath})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: Center(child: Image.file(File(imagePath))),
    );
  }
}
