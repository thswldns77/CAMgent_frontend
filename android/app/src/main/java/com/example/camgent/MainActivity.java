// android/app/src/main/java/com/example/camgent/MainActivity.java
package com.example.camgent;

import android.annotation.SuppressLint;
import android.content.Context;
import android.hardware.camera2.*;
import android.hardware.camera2.params.MeteringRectangle;
import android.hardware.camera2.params.RggbChannelVector;
import android.os.Handler;
import android.os.HandlerThread;
import android.util.Range;
import android.view.Surface;

import androidx.annotation.NonNull;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "camera_settings_channel";

    private CameraManager cameraManager;
    private CameraDevice cameraDevice;
    private CameraCaptureSession captureSession;
    private HandlerThread backgroundThread;
    private Handler backgroundHandler;
    private String cameraId;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        cameraManager = (CameraManager) getSystemService(Context.CAMERA_SERVICE);

        new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                CHANNEL
        ).setMethodCallHandler((call, result) -> {
            if (call.method.equals("getNativeCameraSettings")) {
                String camId = call.argument("cameraId");
                try {
                    CameraCharacteristics c = cameraManager.getCameraCharacteristics(camId);

                    // AE Compensation 범위
                    Range<Integer> evRange = c.get(CameraCharacteristics.CONTROL_AE_COMPENSATION_RANGE);
                    // 최대 디지털 줌
                    float maxZoom = c.get(CameraCharacteristics.SCALER_AVAILABLE_MAX_DIGITAL_ZOOM);

                    Map<String, Object> map = new HashMap<>();
                    map.put("minExposureCompensation", evRange.getLower());
                    map.put("maxExposureCompensation", evRange.getUpper());
                    map.put("minZoom", 1.0f);
                    map.put("maxZoom", maxZoom);

                    result.success(map);
                } catch (CameraAccessException e) {
                    result.error("CAM_ERR", "Camera access failed: " + e.getMessage(), null);
                }

            } else if (call.method.equals("applyCameraSettings")) {
                @SuppressWarnings("unchecked")
                Map<String, Object> settings = (Map<String, Object>) call.arguments;
                applyCameraSettings(settings);
                result.success("Settings applied successfully");

            } else {
                result.notImplemented();
            }
        });
    }

    // 백그라운드 스레드 시작/중지
    private void startBackgroundThread() {
        backgroundThread = new HandlerThread("CameraBackground");
        backgroundThread.start();
        backgroundHandler = new Handler(backgroundThread.getLooper());
    }
    private void stopBackgroundThread() {
        if (backgroundThread != null) {
            backgroundThread.quitSafely();
            try {
                backgroundThread.join();
                backgroundThread = null;
                backgroundHandler = null;
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
        }
    }

    /** 네이티브로 세부 설정 적용 (무거운 작업) */
    @SuppressLint("MissingPermission")
    private void applyCameraSettings(Map<String, Object> settings) {
        try {
            // 후면 카메라 ID 찾기
            for (String id : cameraManager.getCameraIdList()) {
                CameraCharacteristics ch = cameraManager.getCameraCharacteristics(id);
                Integer facing = ch.get(CameraCharacteristics.LENS_FACING);
                if (facing != null && facing == CameraCharacteristics.LENS_FACING_BACK) {
                    cameraId = id;
                    break;
                }
            }
            if (cameraId == null) return;

            startBackgroundThread();
            cameraManager.openCamera(cameraId, new CameraDevice.StateCallback() {
                @Override
                public void onOpened(@NonNull CameraDevice camera) {
                    cameraDevice = camera;
                    createCaptureSession(settings);
                }
                @Override
                public void onDisconnected(@NonNull CameraDevice camera) {
                    camera.close();
                    cameraDevice = null;
                }
                @Override
                public void onError(@NonNull CameraDevice camera, int error) {
                    camera.close();
                    cameraDevice = null;
                }
            }, backgroundHandler);

        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private void createCaptureSession(Map<String, Object> settings) {
        if (cameraDevice == null) return;

        try {
            List<Surface> surfaces = new ArrayList<>();
            // 실제로는 FlutterPlugin 카메라가 제공하는 TextureView Surface 등을 넣어주셔야 합니다.

            cameraDevice.createCaptureSession(
                    surfaces,
                    new CameraCaptureSession.StateCallback() {
                        @Override
                        public void onConfigured(@NonNull CameraCaptureSession session) {
                            captureSession = session;
                            updateCameraSettings(settings);
                        }
                        @Override
                        public void onConfigureFailed(@NonNull CameraCaptureSession session) {
                            // 세션 구성 실패
                        }
                    },
                    backgroundHandler
            );
        } catch (CameraAccessException e) {
            e.printStackTrace();
        }
    }

    private void updateCameraSettings(Map<String, Object> settings) {
        if (cameraDevice == null || captureSession == null) return;

        try {
            CaptureRequest.Builder builder =
                    cameraDevice.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW);

            if (settings.containsKey("SENSOR_SENSITIVITY")) {
                builder.set(CaptureRequest.SENSOR_SENSITIVITY,
                        ((Number) settings.get("SENSOR_SENSITIVITY")).intValue());
            }
            if (settings.containsKey("SENSOR_EXPOSURE_TIME")) {
                builder.set(CaptureRequest.SENSOR_EXPOSURE_TIME,
                        ((Number) settings.get("SENSOR_EXPOSURE_TIME")).longValue());
            }
            if (settings.containsKey("FLASH_MODE")) {
                builder.set(CaptureRequest.FLASH_MODE,
                        ((Number) settings.get("FLASH_MODE")).intValue());
            }
            // 필요한 다른 키들도 동일 패턴으로 추가...
            if (settings.containsKey("COLOR_CORRECTION_GAINS")) {
                @SuppressWarnings("unchecked")
                List<Number> gains = (List<Number>) settings.get("COLOR_CORRECTION_GAINS");
                if (gains.size() == 4) {
                    builder.set(CaptureRequest.COLOR_CORRECTION_GAINS,
                            new RggbChannelVector(
                                    gains.get(0).floatValue(),
                                    gains.get(1).floatValue(),
                                    gains.get(2).floatValue(),
                                    gains.get(3).floatValue()
                            )
                    );
                }
            }

            CaptureRequest req = builder.build();
            captureSession.setRepeatingRequest(req, null, backgroundHandler);

        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        if (captureSession != null) {
            captureSession.close();
        }
        if (cameraDevice != null) {
            cameraDevice.close();
        }
        stopBackgroundThread();
    }
}
