// lib/camera_settings.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

/// 카메라 세팅 모델
class CameraSettings {
  final int? sensorSensitivity;
  final double? sensorExposureTime;
  final String? colorCorrectionMode;
  final List<double>? colorCorrectionGains;
  final double? lensFocusDistance;
  final double? controlAeExposureCompensation;
  final String? controlSceneMode;
  final bool? controlAwbLock;
  final bool? controlAeLock;
  final String? flashMode;
  final String? controlAfRegions;
  final String? controlAeRegions;
  final String? controlEffectMode;
  final String? noiseReductionMode;
  final String? tonemapMode;
  final bool? rawOutput;
  final int? jpegQuality;
  final String? controlAeAntibandingMode;
  final List<int>? controlAeTargetFpsRange;

  CameraSettings({
    this.sensorSensitivity,
    this.sensorExposureTime,
    this.colorCorrectionMode,
    this.colorCorrectionGains,
    this.lensFocusDistance,
    this.controlAeExposureCompensation,
    this.controlSceneMode,
    this.controlAwbLock,
    this.controlAeLock,
    this.flashMode,
    this.controlAfRegions,
    this.controlAeRegions,
    this.controlEffectMode,
    this.noiseReductionMode,
    this.tonemapMode,
    this.rawOutput,
    this.jpegQuality,
    this.controlAeAntibandingMode,
    this.controlAeTargetFpsRange,
  });

  factory CameraSettings.fromJson(Map<String, dynamic> json) {
    return CameraSettings(
      sensorSensitivity: json['SENSOR_SENSITIVITY']?.toInt(),
      sensorExposureTime: json['SENSOR_EXPOSURE_TIME']?.toDouble(),
      colorCorrectionMode: json['COLOR_CORRECTION_MODE'],
      colorCorrectionGains: json['COLOR_CORRECTION_GAINS']?.cast<double>(),
      lensFocusDistance: json['LENS_FOCUS_DISTANCE']?.toDouble(),
      controlAeExposureCompensation:
      json['CONTROL_AE_EXPOSURE_COMPENSATION']?.toDouble(),
      controlSceneMode: json['CONTROL_SCENE_MODE'],
      controlAwbLock: json['CONTROL_AWB_LOCK'],
      controlAeLock: json['CONTROL_AE_LOCK'],
      flashMode: json['FLASH_MODE'],
      controlAfRegions: json['CONTROL_AF_REGIONS'],
      controlAeRegions: json['CONTROL_AE_REGIONS'],
      controlEffectMode: json['CONTROL_EFFECT_MODE'],
      noiseReductionMode: json['NOISE_REDUCTION_MODE'],
      tonemapMode: json['TONEMAP_MODE'],
      rawOutput: json['RAW_OUTPUT'],
      jpegQuality: json['JPEG_QUALITY']?.toInt(),
      controlAeAntibandingMode: json['CONTROL_AE_ANTIBANDING_MODE'],
      controlAeTargetFpsRange:
      json['CONTROL_AE_TARGET_FPS_RANGE']?.cast<int>(),
    );
  }
}

/// API 호출 서비스
class ApiService {
  static const String apiUrl = 'http://10.0.2.2:3000/agent-conversation';

  static Future<CameraSettings?> getCameraSettings(
      String requirement) async {
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'message': requirement}),
    );
    if (response.statusCode == 200) {
      return CameraSettings.fromJson(jsonDecode(response.body));
    }
    throw Exception('API 요청 실패: ${response.body}');
  }

  /// 테스트용 Mock
  static Future<CameraSettings?> getMockCameraSettings(
      String requirement) async {
    await Future.delayed(const Duration(seconds: 2));

    final lowerReq = requirement.toLowerCase();

    if (lowerReq.contains('밝게') || lowerReq.contains('밝은')) {
      return CameraSettings(
        sensorSensitivity: 800,
        sensorExposureTime: 0.033,
        controlAeExposureCompensation: 1.0,
        flashMode: 'AUTO',
        jpegQuality: 95,
        controlSceneMode: 'AUTO',
      );
    } else if (lowerReq.contains('어둡게') || lowerReq.contains('어두운')) {
      return CameraSettings(
        sensorSensitivity: 100,
        sensorExposureTime: 0.008,
        controlAeExposureCompensation: -1.0,
        flashMode: 'OFF',
        jpegQuality: 85,
        controlSceneMode: 'AUTO',
      );
    } else if (lowerReq.contains('인물') || lowerReq.contains('사람')) {
      return CameraSettings(
        sensorSensitivity: 200,
        sensorExposureTime: 0.008,
        controlAeExposureCompensation: 0.0,
        flashMode: 'AUTO',
        jpegQuality: 95,
        controlSceneMode: 'PORTRAIT',
      );
    } else if (lowerReq.contains('야경') || lowerReq.contains('밤')) {
      return CameraSettings(
        sensorSensitivity: 1600,
        sensorExposureTime: 0.066,
        controlAeExposureCompensation: 0.0,
        flashMode: 'OFF',
        jpegQuality: 90,
        controlSceneMode: 'NIGHT',
      );
    }

    return CameraSettings(
      sensorSensitivity: 400,
      sensorExposureTime: 0.008,
      jpegQuality: 90,
      controlSceneMode: 'AUTO',
      flashMode: 'AUTO',
    );
  }
}
