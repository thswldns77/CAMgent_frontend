// lib/camera_settings.dart

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
    // 초로 오면 그대로, ns로 오면 초로 환산
    double? exposureSeconds;
    if (json['SENSOR_EXPOSURE_TIME_NS'] != null) {
      exposureSeconds = (json['SENSOR_EXPOSURE_TIME_NS'] as num).toDouble() / 1e9;
    } else if (json['SENSOR_EXPOSURE_TIME'] != null) {
      final v = (json['SENSOR_EXPOSURE_TIME'] as num).toDouble();
      exposureSeconds = v > 1e6 ? v / 1e9 : v; // 1e6 넘으면 ns라고 간주
    }

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

  /// 네이티브로 보낼 Map

// camera_settings.dart
  Map<String, dynamic> toJson() {
    int? exposureNs;
    if (sensorExposureTime != null) {
      final v = sensorExposureTime!;
      // 초(double)로 오면 ns로 변환, 이미 ns 같은 큰 값이면 그대로
      exposureNs = (v > 1e6 ? v.round() : (v * 1e9).round());
    }

    return {
      if (sensorSensitivity != null) 'SENSOR_SENSITIVITY': sensorSensitivity,
      if (exposureNs != null) 'SENSOR_EXPOSURE_TIME_NS': exposureNs,
      if (jpegQuality != null)      'JPEG_QUALITY': jpegQuality,
      if (flashMode != null)        'FLASH_MODE': flashMode?.toUpperCase(),
      if (controlAeExposureCompensation != null)
        'CONTROL_AE_EXPOSURE_COMPENSATION':
        controlAeExposureCompensation!.round(), // EV는 int
      if (controlSceneMode != null) 'CONTROL_SCENE_MODE': controlSceneMode?.toUpperCase(),
      if (controlAwbLock != null)   'CONTROL_AWB_LOCK': controlAwbLock,
      if (controlAeLock != null)    'CONTROL_AE_LOCK': controlAeLock,
      if (colorCorrectionMode != null) 'COLOR_CORRECTION_MODE': colorCorrectionMode?.toUpperCase(),
      if (colorCorrectionGains != null) 'COLOR_CORRECTION_GAINS': colorCorrectionGains,
      if (lensFocusDistance != null) 'LENS_FOCUS_DISTANCE': lensFocusDistance,
      if (controlEffectMode != null) 'CONTROL_EFFECT_MODE': controlEffectMode?.toUpperCase(),
      if (noiseReductionMode != null) 'NOISE_REDUCTION_MODE': noiseReductionMode?.toUpperCase(),
      if (tonemapMode != null) 'TONEMAP_MODE': tonemapMode?.toUpperCase(),
      if (controlAeAntibandingMode != null) 'CONTROL_AE_ANTIBANDING_MODE': controlAeAntibandingMode?.toUpperCase(),
      if (controlAeTargetFpsRange != null) 'CONTROL_AE_TARGET_FPS_RANGE': controlAeTargetFpsRange,
    };
  }


}
