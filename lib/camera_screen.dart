// lib/camera_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'camera_settings.dart';

class CameraScreen extends StatefulWidget {
  final CameraSettings? cameraSettings;
  final VoidCallback? onBackToChat;
  const CameraScreen({
    Key? key,
    this.cameraSettings,
    this.onBackToChat,
  }) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  MethodChannel? _channel;
  bool _isTakingPicture = false;
  double _zoom = 1.0;
  double _exposure = 0.0;
  // 예시 범위, 필요에 따라 cameraManager 에서 실제 범위 가져와 세팅하세요
  final double _minZoom = 1.0, _maxZoom = 4.0;
  final double _minExposure = -2.0, _maxExposure = 2.0;

  @override
  void didUpdateWidget(covariant CameraScreen old) {
    super.didUpdateWidget(old);
    if (_channel != null && widget.cameraSettings != null) {
      final map = widget.cameraSettings!.toJson();
      debugPrint('[Flutter→Native] applySettings (update): $map'); // ★ 로그
      _channel!.invokeMethod('applySettings', map);
    }
  }
  @override
  void dispose() {
    // 네이티브 쪽 카메라/스레드/리스너 정리
    _channel?.invokeMethod('pauseCamera');
    super.dispose();
  }


  void _onPlatformViewCreated(int id) {
    _channel = MethodChannel('native_camera_channel_$id');

    _channel!.setMethodCallHandler((call) async {
      if (call.method == 'previewReady' && widget.cameraSettings != null) {
        final map = widget.cameraSettings!.toJson();
        debugPrint('[Flutter→Native] applySettings: $map');  // ★ 로그
        await _channel!.invokeMethod('applySettings', widget.cameraSettings!.toJson());
      }
    });

    // (선택) 혹시 신호를 못 받는 경우 대비한 백업
    Future.delayed(const Duration(milliseconds: 300), () {
      if (widget.cameraSettings != null) {
        _channel!.invokeMethod('applySettings', widget.cameraSettings!.toJson());
      }
    });
  }

  // 슬라이드 동작
  Future<void> _setZoom(double v) async {
    setState(() => _zoom = v);
    await _channel?.invokeMethod('setZoom', {'zoom': v});
  }

  Future<void> _setExposure(double v) async {
    setState(() => _exposure = v);
    await _channel
        ?.invokeMethod('setExposureCompensation', {'exposure': v});
  }

  // 촬영 버튼
  Future<void> _takePicture() async {
    if (_channel == null || _isTakingPicture) return;
    setState(() => _isTakingPicture = true);

    try {
      final String? uriString =
      await _channel!.invokeMethod<String>('takePicture');
      if (uriString == null) throw '네이티브가 경로를 반환하지 않았습니다.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('갤러리에 저장 완료\n$uriString')),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('촬영 실패: $e')),
      );
    } finally {
      setState(() => _isTakingPicture = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('네이티브 카메라'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBackToChat,
        ),
      ),
      body: Stack(children: [
        AndroidView(
          viewType: 'native_camera_view',
          onPlatformViewCreated: _onPlatformViewCreated,
        ),

        // 설정 오버레이
        if (widget.cameraSettings != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'ISO: ${widget.cameraSettings!.sensorSensitivity}\n'
                    'Shutter: ${widget.cameraSettings!.sensorExposureTime}s\n'
                    'AE Comp: ${widget.cameraSettings!.controlAeExposureCompensation}\n'
                    'Flash: ${widget.cameraSettings!.flashMode}',
                style: const TextStyle(
                    color: Colors.white, fontSize: 12),
              ),
            ),
          ),

        // 줌 슬라이더
        Positioned(
          right: 8,
          top: 100,
          bottom: 100,
          child: RotatedBox(
            quarterTurns: 3,
            child: Slider(
              value: _zoom,
              min: _minZoom,
              max: _maxZoom,
              divisions: 30,
              label: '줌 ${_zoom.toStringAsFixed(1)}x',
              onChanged: _channel == null ? null : _setZoom,
            ),
          ),
        ),

        // 노출 보정 슬라이더
        Positioned(
          left: 8,
          top: 100,
          bottom: 100,
          child: RotatedBox(
            quarterTurns: 3,
            child: Slider(
              value: _exposure,
              min: _minExposure,
              max: _maxExposure,
              divisions:
              ((_maxExposure - _minExposure) * 10).toInt(),
              label: '노출 ${_exposure.toStringAsFixed(1)}',
              onChanged: _channel == null ? null : _setExposure,
            ),
          ),
        ),

        // 촬영 버튼 (하나만 남김)
        Positioned(
          bottom: 24,
          left: 0,
          right: 0,
          child: Center(
            child: GestureDetector(
              onTap: _takePicture,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 4),
                  shape: BoxShape.circle,
                ),
                child: _isTakingPicture
                    ? const CircularProgressIndicator(
                    color: Colors.white)
                    : const Icon(Icons.camera_alt,
                    color: Colors.white, size: 32),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
