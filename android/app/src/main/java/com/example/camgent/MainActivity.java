// android/app/src/main/kotlin/com/example/your_app/MainActivity.java
package com.example.camgent;

import android.annotation.SuppressLint;
import android.content.Context;
import android.hardware.camera2.*;
import android.hardware.camera2.params.MeteringRectangle;
import android.os.Handler;
import android.os.HandlerThread;
import android.util.Range;
import android.util.Size;
import android.view.Surface;
import android.hardware.camera2.params.RggbChannelVector;


import java.util.ArrayList;
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
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        cameraManager = (CameraManager) getSystemService(Context.CAMERA_SERVICE);

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    if (call.method.equals("applyCameraSettings")) {
                        Map<String, Object> settings = call.arguments();
                        if (settings != null) {
                            applyCameraSettings(settings);
                            result.success("Settings applied successfully");
                        } else {
                            result.error("INVALID_ARGUMENT", "Settings map is null", null);
                        }
                    } else {
                        result.notImplemented();
                    }
                });
    }

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

    @SuppressLint("MissingPermission")
    private void applyCameraSettings(Map<String, Object> settings) {
        try {
            for (String id : cameraManager.getCameraIdList()) {
                CameraCharacteristics characteristics = cameraManager.getCameraCharacteristics(id);
                Integer facing = characteristics.get(CameraCharacteristics.LENS_FACING);
                if (facing != null && facing == CameraCharacteristics.LENS_FACING_BACK) {
                    cameraId = id;
                    break;
                }
            }

            if (cameraId == null) {
                return;
            }

            startBackgroundThread();

            cameraManager.openCamera(cameraId, new CameraDevice.StateCallback() {
                @Override
                public void onOpened(CameraDevice camera) {
                    cameraDevice = camera;
                    createCaptureSession(settings);
                }

                @Override
                public void onDisconnected(CameraDevice camera) {
                    camera.close();
                    cameraDevice = null;
                }

                @Override
                public void onError(CameraDevice camera, int error) {
                    camera.close();
                    cameraDevice = null;
                }
            }, backgroundHandler);

        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private void createCaptureSession(Map<String, Object> settings) {
        try {
            if (cameraDevice != null) {
                List<Surface> surfaces = new ArrayList<>(); // 실제로는 TextureView나 SurfaceView의 Surface 필요

                cameraDevice.createCaptureSession(surfaces, new CameraCaptureSession.StateCallback() {
                    @Override
                    public void onConfigured(CameraCaptureSession session) {
                        captureSession = session;
                        updateCameraSettings(settings);
                    }

                    @Override
                    public void onConfigureFailed(CameraCaptureSession session) {
                        // 세션 구성 실패
                    }
                }, backgroundHandler);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private void updateCameraSettings(Map<String, Object> settings) {
        try {
            if (cameraDevice == null || captureSession == null) return;

            CaptureRequest.Builder requestBuilder = cameraDevice.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW);

            if (settings.containsKey("SENSOR_SENSITIVITY")) {
                requestBuilder.set(CaptureRequest.SENSOR_SENSITIVITY, (Integer) settings.get("SENSOR_SENSITIVITY"));
            }

            if (settings.containsKey("SENSOR_EXPOSURE_TIME")) {
                requestBuilder.set(CaptureRequest.SENSOR_EXPOSURE_TIME, ((Number) settings.get("SENSOR_EXPOSURE_TIME")).longValue());
            }

            if (settings.containsKey("COLOR_CORRECTION_MODE")) {
                requestBuilder.set(CaptureRequest.COLOR_CORRECTION_MODE, (Integer) settings.get("COLOR_CORRECTION_MODE"));
            }

            if (settings.containsKey("COLOR_CORRECTION_GAINS")) {
                List<?> gainsList = (List<?>) settings.get("COLOR_CORRECTION_GAINS");
                if (gainsList.size() == 4) {
                    float[] gainsArray = new float[4];
                    for (int i = 0; i < 4; i++) {
                        gainsArray[i] = ((Number) gainsList.get(i)).floatValue();
                    }
                    requestBuilder.set(CaptureRequest.COLOR_CORRECTION_GAINS,
                            new RggbChannelVector(gainsArray[0], gainsArray[1], gainsArray[2], gainsArray[3]));
                }
            }

            if (settings.containsKey("LENS_FOCUS_DISTANCE")) {
                requestBuilder.set(CaptureRequest.LENS_FOCUS_DISTANCE, ((Number) settings.get("LENS_FOCUS_DISTANCE")).floatValue());
            }

            if (settings.containsKey("CONTROL_AE_EXPOSURE_COMPENSATION")) {
                requestBuilder.set(CaptureRequest.CONTROL_AE_EXPOSURE_COMPENSATION,
                        ((Number) settings.get("CONTROL_AE_EXPOSURE_COMPENSATION")).intValue());
            }

            if (settings.containsKey("CONTROL_SCENE_MODE")) {
                requestBuilder.set(CaptureRequest.CONTROL_SCENE_MODE, (Integer) settings.get("CONTROL_SCENE_MODE"));
            }

            if (settings.containsKey("CONTROL_AWB_LOCK")) {
                requestBuilder.set(CaptureRequest.CONTROL_AWB_LOCK, (Boolean) settings.get("CONTROL_AWB_LOCK"));
            }

            if (settings.containsKey("CONTROL_AE_LOCK")) {
                requestBuilder.set(CaptureRequest.CONTROL_AE_LOCK, (Boolean) settings.get("CONTROL_AE_LOCK"));
            }

            if (settings.containsKey("FLASH_MODE")) {
                requestBuilder.set(CaptureRequest.FLASH_MODE, (Integer) settings.get("FLASH_MODE"));
            }

            if (settings.containsKey("CONTROL_AF_REGIONS")) {
                List<?> regionsList = (List<?>) settings.get("CONTROL_AF_REGIONS");
                if (regionsList.size() >= 5) {
                    MeteringRectangle meteringRectangle = new MeteringRectangle(
                            ((Number) regionsList.get(0)).intValue(),
                            ((Number) regionsList.get(1)).intValue(),
                            ((Number) regionsList.get(2)).intValue(),
                            ((Number) regionsList.get(3)).intValue(),
                            ((Number) regionsList.get(4)).intValue()
                    );
                    requestBuilder.set(CaptureRequest.CONTROL_AF_REGIONS, new MeteringRectangle[]{meteringRectangle});
                }
            }

            if (settings.containsKey("CONTROL_AE_REGIONS")) {
                List<?> regionsList = (List<?>) settings.get("CONTROL_AE_REGIONS");
                if (regionsList.size() >= 5) {
                    MeteringRectangle meteringRectangle = new MeteringRectangle(
                            ((Number) regionsList.get(0)).intValue(),
                            ((Number) regionsList.get(1)).intValue(),
                            ((Number) regionsList.get(2)).intValue(),
                            ((Number) regionsList.get(3)).intValue(),
                            ((Number) regionsList.get(4)).intValue()
                    );
                    requestBuilder.set(CaptureRequest.CONTROL_AE_REGIONS, new MeteringRectangle[]{meteringRectangle});
                }
            }

            if (settings.containsKey("CONTROL_EFFECT_MODE")) {
                requestBuilder.set(CaptureRequest.CONTROL_EFFECT_MODE, (Integer) settings.get("CONTROL_EFFECT_MODE"));
            }

            if (settings.containsKey("NOISE_REDUCTION_MODE")) {
                requestBuilder.set(CaptureRequest.NOISE_REDUCTION_MODE, (Integer) settings.get("NOISE_REDUCTION_MODE"));
            }

            if (settings.containsKey("TONEMAP_MODE")) {
                requestBuilder.set(CaptureRequest.TONEMAP_MODE, (Integer) settings.get("TONEMAP_MODE"));
            }

            if (settings.containsKey("JPEG_QUALITY")) {
                requestBuilder.set(CaptureRequest.JPEG_QUALITY, ((Number) settings.get("JPEG_QUALITY")).byteValue());
            }

            if (settings.containsKey("CONTROL_AE_ANTIBANDING_MODE")) {
                requestBuilder.set(CaptureRequest.CONTROL_AE_ANTIBANDING_MODE, (Integer) settings.get("CONTROL_AE_ANTIBANDING_MODE"));
            }

            if (settings.containsKey("CONTROL_AE_TARGET_FPS_RANGE")) {
                List<?> rangeList = (List<?>) settings.get("CONTROL_AE_TARGET_FPS_RANGE");
                if (rangeList.size() == 2) {
                    Range<Integer> range = new Range<>(
                            ((Number) rangeList.get(0)).intValue(),
                            ((Number) rangeList.get(1)).intValue()
                    );
                    requestBuilder.set(CaptureRequest.CONTROL_AE_TARGET_FPS_RANGE, range);
                }
            }

            CaptureRequest captureRequest = requestBuilder.build();
            captureSession.setRepeatingRequest(captureRequest, null, backgroundHandler);

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
