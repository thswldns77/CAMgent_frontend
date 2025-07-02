// lib/camera_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'camera_settings.dart';

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
      setState(() { _initd = true; _error = null; });
      _applySettings();
    } catch (e) {
      if (mounted) setState(() => _error = '초기화 실패: $e');
    }
  }

  Future<void> _applySettings() async {
    final s = widget.cameraSettings;
    if (_ctrl != null && _ctrl!.value.isInitialized && s != null) {
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
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('카메라 설정 적용됨'), backgroundColor: Colors.green),
        );
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('설정 실패: $e'), backgroundColor: Colors.orange),
        );
      }
    }
  }

  Future<void> _takePic() async {
    if (_ctrl != null && _ctrl!.value.isInitialized) {
      final file = await _ctrl!.takePicture();
      setState(() => _shots.add(file.path));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진 촬영 완료')),
      );
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
                        '노출: ${widget.cameraSettings!.controlAeExposureCompensation}\n'
                        '플래시: ${widget.cameraSettings!.flashMode}',
                  ),
                  actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
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
                      child: Text('${_shots.length}', style: const TextStyle(fontSize: 8, color: Colors.white)),
                    ),
                  ),
              ],
            ),
            onPressed: _shots.isEmpty ? null : () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => GalleryScreen(images: _shots)),
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
            MaterialPageRoute(builder: (_) => FullScreenImage(imagePath: images[i])),
          ),
          child: Image.file(File(images[i]), fit: BoxFit.cover),
        ),
      ),
    );
  }
}

class FullScreenImage extends StatelessWidget {
  final String imagePath;
  const FullScreenImage({Key? key, required this.imagePath}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: Center(child: Image.file(File(imagePath))),
    );
  }
}
