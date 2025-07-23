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
