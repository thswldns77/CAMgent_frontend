// lib/camera_screen.dart - 수정된 버전

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'camera_settings.dart';
// ➊ import 추가
import 'dart:convert';
import 'package:flutter/services.dart';

const int _FLASH_MODE_OFF = 0;
const int _FLASH_MODE_SINGLE = 1;
const int _FLASH_MODE_TORCH = 2;

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final CameraSettings? cameraSettings;
  final VoidCallback? onBackToChat;

  const CameraScreen({
    Key? key,
    required this.cameras,
    this.cameraSettings,
    this.onBackToChat,
  }) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  static const _platform = MethodChannel('camera_settings_channel');

  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  bool _isRearCameraSelected = true;
  bool _isFlashOn = false;
  bool _isTakingPicture = false;
  String? _lastPhotoPath;
  bool _showSettingsPanel = false;
  bool _isDisposed = false;
  bool _isInitializing = false;
  bool _settingsApplied = false;

  // 카메라 설정 상태
  double _exposureCompensation = 0.0;
  double _minExposureCompensation = -2.0;
  double _maxExposureCompensation = 2.0;
  double _zoomLevel = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 8.0;

  // 네이티브 설정 대기열
  CameraSettings? _pendingSettings;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pendingSettings = widget.cameraSettings;
    _initializeCamera();
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _disposeController();
    super.dispose();
  }

  Future<void> _disposeController() async {
    if (_controller != null) {
      try {
        await _controller!.dispose();
      } catch (e) {
        print('카메라 컨트롤러 해제 중 오류: $e');
      }
      _controller = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposed) return;

    final CameraController? cameraController = _controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _disposeController();
    } else if (state == AppLifecycleState.resumed) {
      if (_controller == null) {
        _initializeCamera();
      }
    }
  }

  Future<void> _initializeCamera() async {
    if (_isDisposed || _isInitializing) return;

    setState(() {
      _isInitializing = true;
    });

    try {
      // 기존 컨트롤러 완전히 해제
      await _disposeController();

      // 잠시 대기하여 세션 완전히 해제
      await Future.delayed(const Duration(milliseconds: 200));

      if (widget.cameras.isEmpty) {
        if (!_isDisposed) {
          _showErrorDialog('카메라를 찾을 수 없습니다.');
        }
        return;
      }

      final camera = _isRearCameraSelected
          ? widget.cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => widget.cameras.first,
      )
          : widget.cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => widget.cameras.first,
      );

      // 새 컨트롤러 생성
      _controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      _initializeControllerFuture = _controller!.initialize();

      await _initializeControllerFuture;

      if (_isDisposed) return;

      // 카메라 설정 범위 가져오기
      _minExposureCompensation = await _controller!.getMinExposureOffset();
      _maxExposureCompensation = await _controller!.getMaxExposureOffset();
      _maxZoom = await _controller!.getMaxZoomLevel();
      _minZoom = await _controller!.getMinZoomLevel();

      // 카메라 초기화 완료 후 상태 업데이트
      if (!_isDisposed) {
        setState(() {
          _isInitializing = false;
        });
      }

      // 네이티브 설정 적용은 별도로 처리 (미리보기 시작 후)
      if (_pendingSettings != null && !_settingsApplied) {
        // 미리보기가 완전히 시작된 후 설정 적용
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!_isDisposed && _controller != null && _controller!.value.isInitialized) {
            _applyCameraSettingsSequentially(_pendingSettings!);
          }
        });
      }

    } catch (e) {
      if (!_isDisposed) {
        setState(() {
          _isInitializing = false;
        });
        _showErrorDialog('카메라 초기화 실패: $e');
      }
    }
  }


  Future<void> _applyCameraSettingsSequentially(CameraSettings settings) async {
    if (_controller == null || !_controller!.value.isInitialized || _isDisposed) return;

    try {
      // 1. 먼저 Flutter 카메라 설정 적용 (가벼운 설정들)
      await _applyFlutterCameraSettings(settings);

      // 2. 네이티브 설정 적용 전 충분한 대기
      await Future.delayed(const Duration(milliseconds: 300));

      // 3. 네이티브 카메라 설정 적용 (무거운 설정들)
      if (Platform.isAndroid) {
        await _applyNativeCameraSettings(settings);
      }

      _settingsApplied = true;

      if (!_isDisposed) {
        _showSettingsAppliedSnackBar();
      }
    } catch (e) {
      print('카메라 설정 적용 실패: $e');
      if (!_isDisposed) {
        _showErrorDialog('카메라 설정 적용 실패: $e');
      }
    }
  }

  Future<void> _applyFlutterCameraSettings(CameraSettings settings) async {
    if (_controller == null || !_controller!.value.isInitialized || _isDisposed) return;

    try {
      // 노출 보정 적용
      if (settings.controlAeExposureCompensation != null) {
        _exposureCompensation = settings.controlAeExposureCompensation!
            .clamp(_minExposureCompensation, _maxExposureCompensation);
        await _controller!.setExposureOffset(_exposureCompensation);
        await Future.delayed(const Duration(milliseconds: 50));
      }

      // 플래시 모드 설정
      if (settings.flashMode != null) {
        FlashMode flashMode;
        switch (settings.flashMode!.toUpperCase()) {
          case 'OFF':
            flashMode = FlashMode.off;
            _isFlashOn = false;
            break;
          case 'AUTO':
            flashMode = FlashMode.auto;
            _isFlashOn = false;
            break;
          case 'ALWAYS':
            flashMode = FlashMode.always;
            _isFlashOn = true;
            break;
          case 'TORCH':
            flashMode = FlashMode.torch;
            _isFlashOn = true;
            break;
          default:
            flashMode = FlashMode.auto;
            _isFlashOn = false;
        }
        await _controller!.setFlashMode(flashMode);
        await Future.delayed(const Duration(milliseconds: 50));
      }

      // 상태 업데이트
      if (!_isDisposed) {
        setState(() {});
      }

    } catch (e) {
      print('Flutter 카메라 설정 적용 실패: $e');
    }
  }

  Future<void> _applyNativeCameraSettings(CameraSettings settings) async {
    try {
      final Map<String, dynamic> settingsMap = {};

      // 네이티브 설정 매핑
      if (settings.sensorSensitivity != null) {
        settingsMap['SENSOR_SENSITIVITY'] = settings.sensorSensitivity;
      }
      if (settings.sensorExposureTime != null) {
        settingsMap['SENSOR_EXPOSURE_TIME'] = (settings.sensorExposureTime! * 1000000000).toInt();
      }
      if (settings.jpegQuality != null) {
        settingsMap['JPEG_QUALITY'] = settings.jpegQuality;
      }
      if (settings.controlSceneMode != null) {
        settingsMap['CONTROL_SCENE_MODE'] = settings.controlSceneMode;
      }

      // 카메라 ID 추가
      if (_controller != null) {
        settingsMap['CAMERA_ID'] = _isRearCameraSelected ? '0' : '1';
      }

      // 설정이 있을 때만 네이티브 호출
      if (settingsMap.isNotEmpty) {
        await _platform.invokeMethod('applyCameraSettings', settingsMap);
        // 네이티브 설정 적용 후 적절한 대기
        await Future.delayed(const Duration(milliseconds: 200));
      }

    } catch (e) {
      print('네이티브 카메라 설정 적용 실패: $e');
      // 네이티브 설정 실패해도 계속 진행
    }
  }

  void _showSettingsAppliedSnackBar() {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('카메라 설정이 적용되었습니다!'),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('오류'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized || _isDisposed) {
      _showErrorDialog('카메라가 준비되지 않았습니다.');
      return;
    }

    if (_isTakingPicture) return;

    setState(() {
      _isTakingPicture = true;
    });

    try {
      // 카메라 상태 재확인
      if (!_controller!.value.isInitialized || _isDisposed) {
        throw Exception('카메라가 초기화되지 않았습니다.');
      }

      // 촬영 전 잠시 대기
      await Future.delayed(const Duration(milliseconds: 100));

      final image = await _controller!.takePicture();

      // gal을 사용하여 갤러리에 저장
      await Gal.putImage(image.path);

      if (!_isDisposed) {
        setState(() {
          _lastPhotoPath = image.path;
        });

        // 촬영 완료 피드백
        HapticFeedback.lightImpact();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('사진이 저장되었습니다!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!_isDisposed) {
        _showErrorDialog('사진 촬영 실패: $e');
      }
    } finally {
      if (!_isDisposed) {
        setState(() {
          _isTakingPicture = false;
        });
      }
    }
  }

  Future<void> _switchCamera() async {
    if (widget.cameras.length < 2 || _isDisposed || _isInitializing) return;

    setState(() {
      _isRearCameraSelected = !_isRearCameraSelected;
      _settingsApplied = false;
    });

    await _initializeCamera();
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized || _isDisposed) return;

    try {
      setState(() {
        _isFlashOn = !_isFlashOn;
      });

      if (_isFlashOn) {
        await _controller!.setFlashMode(FlashMode.torch);
      } else {
        await _controller!.setFlashMode(FlashMode.off);
      }
    } catch (e) {
      if (!_isDisposed) {
        _showErrorDialog('플래시 설정 실패: $e');
      }
    }
  }

  Future<void> _setExposureCompensation(double value) async {
    if (_controller == null || !_controller!.value.isInitialized || _isDisposed) return;

    try {
      await _controller!.setExposureOffset(value);
      if (!_isDisposed) {
        setState(() {
          _exposureCompensation = value;
        });
      }
    } catch (e) {
      print('노출 보정 설정 실패: $e');
    }
  }

  Future<void> _setZoomLevel(double value) async {
    if (_controller == null || !_controller!.value.isInitialized || _isDisposed) return;

    try {
      await _controller!.setZoomLevel(value);
      if (!_isDisposed) {
        setState(() {
          _zoomLevel = value;
        });
      }
    } catch (e) {
      print('줌 설정 실패: $e');
    }
  }

  Widget _buildCameraPreview() {
    if (_isDisposed) {
      return const Center(child: Text('카메라가 해제되었습니다.'));
    }

    if (_isInitializing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('카메라 초기화 중...', style: TextStyle(color: Colors.white)),
          ],
        ),
      );
    }

    return FutureBuilder<void>(
      future: _initializeControllerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (_controller != null && _controller!.value.isInitialized) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CameraPreview(_controller!),
            );
          } else {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 48),
                  SizedBox(height: 16),
                  Text('카메라 초기화 실패', style: TextStyle(color: Colors.white)),
                ],
              ),
            );
          }
        } else {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('카메라 로딩 중...', style: TextStyle(color: Colors.white)),
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildControlsOverlay() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withOpacity(0.7),
              Colors.transparent,
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 설정 슬라이더들
            if (_showSettingsPanel) _buildSettingsPanel(),

            const SizedBox(height: 20),

            // 메인 컨트롤
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 플래시 토글
                _buildControlButton(
                  icon: _isFlashOn ? Icons.flash_on : Icons.flash_off,
                  onTap: _toggleFlash,
                ),

                // 촬영 버튼
                GestureDetector(
                  onTap: _takePicture,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.grey,
                        width: 4,
                      ),
                    ),
                    child: _isTakingPicture
                        ? const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                        : const Icon(
                      Icons.camera_alt,
                      color: Colors.black,
                      size: 40,
                    ),
                  ),
                ),

                // 카메라 전환
                _buildControlButton(
                  icon: Icons.flip_camera_ios,
                  onTap: (widget.cameras.length > 1 && !_isInitializing) ? _switchCamera : null,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 하단 액션 버튼들
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 설정 패널 토글
                _buildActionButton(
                  icon: Icons.tune,
                  label: '설정',
                  onTap: () {
                    setState(() {
                      _showSettingsPanel = !_showSettingsPanel;
                    });
                  },
                ),

                // 어시스턴트로 돌아가기
                _buildActionButton(
                  icon: Icons.chat,
                  label: '어시스턴트',
                  onTap: widget.onBackToChat,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // 노출 보정
          Row(
            children: [
              const Icon(Icons.exposure, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Text('노출', style: TextStyle(color: Colors.white)),
              Expanded(
                child: Slider(
                  value: _exposureCompensation,
                  min: _minExposureCompensation,
                  max: _maxExposureCompensation,
                  divisions: 20,
                  activeColor: Colors.white,
                  inactiveColor: Colors.grey,
                  onChanged: _setExposureCompensation,
                ),
              ),
            ],
          ),

          // 줌
          Row(
            children: [
              const Icon(Icons.zoom_in, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Text('줌', style: TextStyle(color: Colors.white)),
              Expanded(
                child: Slider(
                  value: _zoomLevel,
                  min: _minZoom,
                  max: _maxZoom,
                  divisions: 20,
                  activeColor: Colors.white,
                  inactiveColor: Colors.grey,
                  onChanged: _setZoomLevel,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: widget.cameras.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.camera_alt_outlined,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              '카메라를 사용할 수 없습니다',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 18,
              ),
            ),
          ],
        ),
      )
          : Stack(
        children: [
          // 카메라 프리뷰
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(16),
              child: _buildCameraPreview(),
            ),
          ),

          // 컨트롤 오버레이
          _buildControlsOverlay(),

          // 상단 정보
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isInitializing
                        ? '⏳ 카메라 초기화 중...'
                        : widget.cameraSettings != null
                        ? '📸 AI 설정 적용됨'
                        : '📷 카메라',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (widget.cameraSettings != null && !_isInitializing && _settingsApplied)
                    const Icon(
                      Icons.smart_toy,
                      color: Colors.green,
                      size: 20,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}