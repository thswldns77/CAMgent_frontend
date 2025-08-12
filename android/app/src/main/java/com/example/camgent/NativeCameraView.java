package com.example.camgent;

import android.content.Context;
import android.graphics.Rect;
import android.graphics.SurfaceTexture;
import android.hardware.camera2.CameraAccessException;
import android.hardware.camera2.CameraCaptureSession;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CameraDevice;
import android.hardware.camera2.CameraManager;
import android.hardware.camera2.CameraMetadata;                  // ★ 추가
import android.hardware.camera2.CaptureRequest;
import android.hardware.camera2.params.MeteringRectangle;        // ★ 추가
import android.hardware.camera2.params.RggbChannelVector;       // ★ 추가
import android.hardware.camera2.params.StreamConfigurationMap;
import android.media.Image;
import android.media.ImageReader;
import android.os.Build;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.Looper;
import android.util.Range;
import android.util.Size;
import android.view.Surface;
import android.view.TextureView;
import android.view.View;
import android.view.WindowManager;

import androidx.annotation.NonNull;

import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Comparator;
import java.util.List;
import java.util.Map;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.platform.PlatformView;
import android.util.Log; // ★ 추가
public class NativeCameraView implements PlatformView, MethodChannel.MethodCallHandler {
    private static final String TAG = "Cam2Native"; // ★ 추가
    // Flutter / View
    private final Context context;
    private final TextureView textureView;
    private final MethodChannel channel;

    // Camera2
    private final CameraManager cameraManager;
    private CameraDevice cameraDevice;
    private CameraCaptureSession captureSession;
    private ImageReader imageReader;
    private HandlerThread bgThread;
    private Handler bgHandler;

    private String cameraId;
    private Size previewSize;
    private Surface previewSurface;

    // Cached characteristics
    private Rect activeArrayRect;
    private float maxZoom = 1f;
    private Range<Integer> aeCompRange = new Range<>(-2, 2);

    public NativeCameraView(Context context, BinaryMessenger messenger, int viewId) {

        // 전달받은 context를 ApplicationContext로 변환 -> 앱 전체에서 사용 가능 -> 메모리 누수 방지
        this.context = context.getApplicationContext();

        // 카메라 미리보기를 뿌릴 화면을 생성 -> 카메라2는 surfaceTexture에 그림 -> TextureView 사용
        this.textureView = new TextureView(context);

        // 카메라2의 설정 들을 저장하는 객체
        this.cameraManager = (CameraManager) context.getSystemService(Context.CAMERA_SERVICE);

        // flutter와 android 통신을 위한 MethodChannel 생성
        this.channel = new MethodChannel(messenger, "native_camera_channel_" + viewId);
        this.channel.setMethodCallHandler(this);

        // 카메라 작업/파일 저장 등을 돌릴 백그라운드 스레드 시작
        startBackgroundThread();

        // 프리뷰 화면이 준비됐는지를 알려주는 리스너 연결 -> 화면 준비되면 카메라 오픈
        textureView.setSurfaceTextureListener(surfaceListener);
    }

    // ---------- PlatformView ----------
    @Override public View getView() { return textureView; }

    @Override public void dispose() {
        closeCamera();
        stopBackgroundThread();
        channel.setMethodCallHandler(null);
    }

    // ---------- MethodChannel ----------
    @Override
    public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        switch (call.method) {
            case "applySettings": {
                @SuppressWarnings("unchecked")
                Map<String, Object> s = (Map<String, Object>) call.arguments;
                Log.d(TAG, "[MC] applySettings raw=" + s);
                applySettings(s);

                result.success(null);
                break;
            }
            case "setZoom": {
                float zoom = ((Number) ((Map<?, ?>) call.arguments).get("zoom")).floatValue();
                applyZoom(zoom);
                result.success(null);
                break;
            }
            case "setExposureCompensation": {
                float exp = ((Number) ((Map<?, ?>) call.arguments).get("exposure")).floatValue();
                applyExposureCompensation(exp);
                result.success(null);
                break;
            }
            case "takePicture": {
                captureStillAndSave(result);
                break;
            }
            case "pauseCamera":
                android.util.Log.d(TAG, "pauseCamera()");
                pauseCamera();    // 아래 함수 구현
                result.success(null);
                break;
            default: result.notImplemented();
        }
    }
    private void pauseCamera() {
        // 미리 리스너 해제해서 추가 콜백 방지
        if (imageReader != null) {
            imageReader.setOnImageAvailableListener(null, null);
        }
        // 세션 정지
        try {
            if (captureSession != null) {
                captureSession.stopRepeating();
                captureSession.abortCaptures();
            }
        } catch (Exception ignore) {}

        closeCamera();        // 기존 closeCamera 호출
        stopBackgroundThread(); // 백그라운드 스레드도 같이 종료 (재진입시 다시 start)
    }


    // ---------- Surface / Camera lifecycle ----------
    private final TextureView.SurfaceTextureListener surfaceListener =
            new TextureView.SurfaceTextureListener() {
                @Override public void onSurfaceTextureAvailable(@NonNull SurfaceTexture surface, int w, int h) {
                    setUpCamera(w, h);
                    openCamera();
                }
                @Override public void onSurfaceTextureSizeChanged(@NonNull SurfaceTexture s, int w, int h) {}
                @Override public boolean onSurfaceTextureDestroyed(@NonNull SurfaceTexture s) {
                    android.util.Log.d(TAG, "SurfaceTexture destroyed");
                    pauseCamera(); // or at least closeCamera();
                    //closeCamera();
                    return true;
                }
                @Override public void onSurfaceTextureUpdated(@NonNull SurfaceTexture s) {}
            };

    private void setUpCamera(int viewWidth, int viewHeight) {
        try {
            // Back camera
            for (String id : cameraManager.getCameraIdList()) {
                CameraCharacteristics c = cameraManager.getCameraCharacteristics(id);
                Integer facing = c.get(CameraCharacteristics.LENS_FACING);
                if (facing != null && facing == CameraCharacteristics.LENS_FACING_BACK) {
                    cameraId = id;

                    activeArrayRect = c.get(CameraCharacteristics.SENSOR_INFO_ACTIVE_ARRAY_SIZE);
                    if (activeArrayRect == null) activeArrayRect = new Rect(0,0,0,0);

                    Float mz = c.get(CameraCharacteristics.SCALER_AVAILABLE_MAX_DIGITAL_ZOOM);
                    maxZoom = (mz != null && mz > 1f) ? mz : 1f;

                    Range<Integer> r = c.get(CameraCharacteristics.CONTROL_AE_COMPENSATION_RANGE);
                    if (r != null) aeCompRange = r;

                    StreamConfigurationMap map = c.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP);
                    if (map != null) {
                        Size[] sizes = map.getOutputSizes(SurfaceTexture.class);
                        previewSize = choosePreviewSize(sizes, viewWidth, viewHeight);
                    } else previewSize = new Size(1280, 720);
                    break;
                }
            }
            if (cameraId == null) {
                String[] ids = cameraManager.getCameraIdList();
                if (ids.length > 0) {
                    cameraId = ids[0];
                    CameraCharacteristics c = cameraManager.getCameraCharacteristics(cameraId);
                    StreamConfigurationMap map = c.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP);
                    previewSize = (map != null && map.getOutputSizes(SurfaceTexture.class) != null)
                            ? map.getOutputSizes(SurfaceTexture.class)[0]
                            : new Size(1280, 720);
                }
            }
        } catch (Exception e) { e.printStackTrace(); }
        Log.d(TAG, "Selected cameraId=" + cameraId
                + " previewSize=" + previewSize
                + " maxZoom=" + maxZoom
                + " aeCompRange=" + aeCompRange
                + " activeArray=" + activeArrayRect);

    }

    private Size choosePreviewSize(Size[] choices, int viewW, int viewH) {
        if (choices == null || choices.length == 0) return new Size(1280, 720);
        Size wanted = new Size(viewW > 0 ? viewW : 1280, viewH > 0 ? viewH : 720);
        return Arrays.stream(choices)
                .min(Comparator.comparingInt(s ->
                        Math.abs(s.getWidth()*s.getHeight() - wanted.getWidth()*wanted.getHeight())))
                .orElse(choices[0]);
    }

    private final CameraDevice.StateCallback stateCallback = new CameraDevice.StateCallback() {
        @Override public void onOpened(@NonNull CameraDevice camera) {
            cameraDevice = camera; createPreviewSession();
        }
        @Override public void onDisconnected(@NonNull CameraDevice camera) {
            camera.close(); cameraDevice = null;
        }
        @Override public void onError(@NonNull CameraDevice camera, int error) {
            camera.close(); cameraDevice = null;
        }
    };

    private void openCamera() {
        if (cameraId == null) return;
        try {
            // ❗️핵심: bgHandler 대신 null → 메인 스레드 콜백
            cameraManager.openCamera(cameraId, stateCallback, /*handler*/ null);
        } catch (SecurityException se) {
            se.printStackTrace(); // 권한 이슈
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
    private void createPreviewSession() {
        if (cameraDevice == null || !textureView.isAvailable()) return;

        try {
            SurfaceTexture st = textureView.getSurfaceTexture();
            if (st == null) return;

            st.setDefaultBufferSize(previewSize.getWidth(), previewSize.getHeight());
            previewSurface = new Surface(st);

            // JPEG 캡처용 ImageReader
            if (imageReader != null) imageReader.close();
            imageReader = ImageReader.newInstance(
                    previewSize.getWidth(),
                    previewSize.getHeight(),
                    android.graphics.ImageFormat.JPEG,
                    /*maxImages*/ 1
            );

            final CaptureRequest.Builder previewBuilder =
                    cameraDevice.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW);
            previewBuilder.addTarget(previewSurface);

            List<Surface> targets = new ArrayList<>();
            targets.add(previewSurface);
            targets.add(imageReader.getSurface());

            cameraDevice.createCaptureSession(
                    targets,
                    new CameraCaptureSession.StateCallback() {
                        @Override
                        public void onConfigured(@NonNull CameraCaptureSession session) {
                            captureSession = session;
                            try {
                                previewBuilder.set(CaptureRequest.CONTROL_AF_MODE,
                                        CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE);
                                previewBuilder.set(CaptureRequest.CONTROL_AE_MODE,
                                        CaptureRequest.CONTROL_AE_MODE_ON);

                                captureSession.setRepeatingRequest(
                                        previewBuilder.build(), null, /*callback handler*/ null);
                                Log.d(TAG, "Preview configured: preview=" + previewSize + ", imageReader="
                                        + imageReader.getWidth() + "x" + imageReader.getHeight());

                            } catch (CameraAccessException e) {
                                e.printStackTrace();
                            }
                        }

                        @Override
                        public void onConfigureFailed(@NonNull CameraCaptureSession session) {
                            // no-op
                        }
                    },
                    /*handler*/ null // ❗️핵심: bgHandler 대신 null → 메인 스레드 콜백
            );

        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private void closeCamera() {
        try {
            if (captureSession != null) {
                try {
                    captureSession.stopRepeating();
                    captureSession.abortCaptures();
                } catch (Exception ignore) {}
                captureSession.close();
                captureSession = null;
            }
            if (imageReader != null) {
                // 리스너 먼저 끊고
                imageReader.setOnImageAvailableListener(null, null);
                imageReader.close();
                imageReader = null;
            }
            if (cameraDevice != null) {
                cameraDevice.close();
                cameraDevice = null;
            }
        } catch (Exception ignored) {}
    }

    // ---------- Background thread ----------
    private void startBackgroundThread() {
        bgThread = new HandlerThread("native-cam2-bg");
        bgThread.start();
        bgHandler = new Handler(bgThread.getLooper());
    }
    private void stopBackgroundThread() {
        if (bgThread != null) {
            bgThread.quitSafely();
            try { bgThread.join(); } catch (InterruptedException ignored) {}
            bgThread = null; bgHandler = null;
        }
    }

    // ---------- Capture still & save ----------
    // 파일: android/app/src/main/java/com/example/camgent/NativeCameraView.java


    private volatile boolean captureInProgress = false;

// ...

    private void captureStillAndSave(MethodChannel.Result result) {
        if (cameraDevice == null || captureSession == null || imageReader == null) {
            result.error("NO_CAMERA", "Camera not ready", null);
            return;
        }

        // 1) 중복 촬영 가드
        if (captureInProgress) {
            result.error("BUSY", "Capture already in progress", null);
            return;
        }
        captureInProgress = true;
        android.util.Log.d(TAG, "captureStillAndSave() start");

        // 2) 혹시 남아있을 수 있는 이전 이미지 모두 비우기 (드레인)
        try {
            Image drain;
            int drained = 0;
            while ((drain = imageReader.acquireLatestImage()) != null) {
                drain.close();
                drained++;
            }
            if (drained > 0) {
                android.util.Log.d(TAG, "Drained stale images: " + drained);
            }
        } catch (Throwable t) {
            // ignore
        }

        // 3) 먼저 혹시 붙어있던 리스너 제거 (중복 방지)
        imageReader.setOnImageAvailableListener(null, null);

        final boolean[] replied = { false };

        // 4) 이번 촬영용 리스너 1회만 붙이기
        imageReader.setOnImageAvailableListener(reader -> {
            Image image = null;
            try {
                android.util.Log.d(TAG, "onImageAvailable()");
                // 한 번만 최신 이미지 획득
                image = reader.acquireLatestImage(); // 핵심: acquireNextImage() 말고 Latest
                if (image == null) {
                    android.util.Log.w(TAG, "No image returned by acquireLatestImage()");
                    // 메인스레드로 에러 전달
                    new Handler(Looper.getMainLooper()).post(() -> {
                        if (!replied[0]) {
                            replied[0] = true;
                            captureInProgress = false;
                            result.error("NO_IMAGE", "No image to acquire", null);
                        }
                    });
                    return;
                }

                ByteBuffer buffer = image.getPlanes()[0].getBuffer();
                byte[] jpeg = new byte[buffer.remaining()];
                buffer.get(jpeg);
                android.util.Log.d(TAG, "JPEG bytes: " + jpeg.length);

                final String uriString = NativeCameraCapture.saveJpegToMediaStore(context, jpeg);
                android.util.Log.d(TAG, "Saved to MediaStore: " + uriString);

                new Handler(Looper.getMainLooper()).post(() -> {
                    if (!replied[0]) {
                        replied[0] = true;
                        captureInProgress = false;
                        result.success(uriString);
                    }
                });
            } catch (Exception e) {
                android.util.Log.e(TAG, "Capture save error", e);
                new Handler(Looper.getMainLooper()).post(() -> {
                    if (!replied[0]) {
                        replied[0] = true;
                        captureInProgress = false;
                        result.error("CAPTURE_ERR", e.getMessage(), null);
                    }
                });
            } finally {
                // 5) 반드시 닫기 (이거 안 하면 maxImages 경고 납니다)
                if (image != null) {
                    image.close();
                    android.util.Log.d(TAG, "Image closed");
                }
                // 6) 1회 처리 후 리스너 해제
                imageReader.setOnImageAvailableListener(null, null);
            }
        }, bgHandler);

        // 7) 캡처 요청 발사 (스틸만 ImageReader 타겟)
        try {
            final CaptureRequest.Builder still =
                    cameraDevice.createCaptureRequest(CameraDevice.TEMPLATE_STILL_CAPTURE);
            still.addTarget(imageReader.getSurface());
            still.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE);
            still.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON);
            still.set(CaptureRequest.JPEG_ORIENTATION, getJpegOrientation());

            android.util.Log.d(TAG, "captureSession.capture()");
            captureSession.capture(still.build(), new CameraCaptureSession.CaptureCallback(){}, bgHandler);
        } catch (Exception e) {
            android.util.Log.e(TAG, "capture() error", e);
            if (!replied[0]) {
                replied[0] = true;
                captureInProgress = false;
                result.error("CAPTURE_ERR", e.getMessage(), null);
            }
            // 리스너도 안전하게 해제
            imageReader.setOnImageAvailableListener(null, null);
        }
    }


    private int getJpegOrientation() {
        try {
            CameraCharacteristics c = cameraManager.getCameraCharacteristics(cameraId);
            Integer sensorOrientation = c.get(CameraCharacteristics.SENSOR_ORIENTATION);
            if (sensorOrientation == null) sensorOrientation = 0;

            int deviceRotation = 0;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                deviceRotation = context.getDisplay() != null ? context.getDisplay().getRotation() : 0;
            } else {
                WindowManager wm = (WindowManager) context.getSystemService(Context.WINDOW_SERVICE);
                if (wm != null && wm.getDefaultDisplay() != null)
                    deviceRotation = wm.getDefaultDisplay().getRotation();
            }

            int degrees;
            switch (deviceRotation) {
                case Surface.ROTATION_90:  degrees = 90;  break;
                case Surface.ROTATION_180: degrees = 180; break;
                case Surface.ROTATION_270: degrees = 270; break;
                default:                    degrees = 0;
            }
            return (sensorOrientation + degrees) % 360;
        } catch (Exception e) { return 0; }
    }

    // ---------- Settings / Zoom / Exposure ----------
    private void applySettings(Map<String, Object> s) {
        if (cameraDevice == null || captureSession == null || previewSurface == null) return;

        Log.d(TAG, "applySettings() called with: " + s); // ★ 전체 맵

        try {
            final CaptureRequest.Builder b =
                    cameraDevice.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW);
            b.addTarget(previewSurface);

            // ISO
            if (s.containsKey("SENSOR_SENSITIVITY")) {
                int iso = ((Number) s.get("SENSOR_SENSITIVITY")).intValue();
                b.set(CaptureRequest.SENSOR_SENSITIVITY, iso);
                Log.d(TAG, "→ ISO=" + iso);
            }

            // 노출시간(ns) - 네이티브 키 기준
            if (s.containsKey("SENSOR_EXPOSURE_TIME_NS")) {
                long ns = ((Number) s.get("SENSOR_EXPOSURE_TIME_NS")).longValue();
                b.set(CaptureRequest.SENSOR_EXPOSURE_TIME, ns);
                Log.d(TAG, "→ Exposure(ns)=" + ns);
            }

            // AE 보정
            if (s.containsKey("CONTROL_AE_EXPOSURE_COMPENSATION")) {
                int ev = ((Number) s.get("CONTROL_AE_EXPOSURE_COMPENSATION")).intValue();
                b.set(CaptureRequest.CONTROL_AE_EXPOSURE_COMPENSATION, ev);
                Log.d(TAG, "→ AE Comp=" + ev + " (range " + aeCompRange + ")");
            }

            // AE/AWB Lock
            if (s.containsKey("CONTROL_AE_LOCK")) {
                boolean lock = (Boolean) s.get("CONTROL_AE_LOCK");
                b.set(CaptureRequest.CONTROL_AE_LOCK, lock);
                Log.d(TAG, "→ AE Lock=" + lock);
            }
            if (s.containsKey("CONTROL_AWB_LOCK")) {
                boolean lock = (Boolean) s.get("CONTROL_AWB_LOCK");
                b.set(CaptureRequest.CONTROL_AWB_LOCK, lock);
                Log.d(TAG, "→ AWB Lock=" + lock);
            }

            // 플래시/AE 모드
            if (s.containsKey("FLASH_MODE")) {
                String fm = String.valueOf(s.get("FLASH_MODE")).toUpperCase();
                if ("AUTO".equals(fm)) {
                    b.set(CaptureRequest.CONTROL_AE_MODE, CameraMetadata.CONTROL_AE_MODE_ON_AUTO_FLASH);
                    Log.d(TAG, "→ AE Mode=AUTO_FLASH");
                } else {
                    Integer flash = flashModeFromString(fm);
                    if (flash != null) {
                        b.set(CaptureRequest.FLASH_MODE, flash);
                        Log.d(TAG, "→ FlashMode=" + fm);
                    }
                    b.set(CaptureRequest.CONTROL_AE_MODE, CameraMetadata.CONTROL_AE_MODE_ON);
                }
            } else {
                b.set(CaptureRequest.CONTROL_AE_MODE, CameraMetadata.CONTROL_AE_MODE_ON);
                Log.d(TAG, "→ AE Mode=ON");
            }

            // Scene
            if (s.containsKey("CONTROL_SCENE_MODE")) {
                String smS = String.valueOf(s.get("CONTROL_SCENE_MODE"));
                Integer sm = sceneModeFromString(smS);
                if (sm != null) {
                    b.set(CaptureRequest.CONTROL_MODE, CameraMetadata.CONTROL_MODE_USE_SCENE_MODE);
                    b.set(CaptureRequest.CONTROL_SCENE_MODE, sm);
                    Log.d(TAG, "→ SceneMode=" + smS);
                }
            }

            // Focus distance
            if (s.containsKey("LENS_FOCUS_DISTANCE")) {
                float fd = ((Number) s.get("LENS_FOCUS_DISTANCE")).floatValue();
                b.set(CaptureRequest.LENS_FOCUS_DISTANCE, fd);
                Log.d(TAG, "→ FocusDistance=" + fd);
            }

            // FPS Range
            if (s.containsKey("CONTROL_AE_TARGET_FPS_RANGE")) {
                @SuppressWarnings("unchecked")
                List<Number> r = (List<Number>) s.get("CONTROL_AE_TARGET_FPS_RANGE");
                if (r != null && r.size() == 2) {
                    Range<Integer> fps = new Range<>(r.get(0).intValue(), r.get(1).intValue());
                    b.set(CaptureRequest.CONTROL_AE_TARGET_FPS_RANGE, fps);
                    Log.d(TAG, "→ FPS Range=" + fps);
                }
            }

            // JPEG Quality (미리보기엔 영향 X, 캡처용 정보)
            if (s.containsKey("JPEG_QUALITY")) {
                int q = ((Number) s.get("JPEG_QUALITY")).intValue();
                b.set(CaptureRequest.JPEG_QUALITY, (byte) q);
                Log.d(TAG, "→ JPEG Quality=" + q);
            }

            // 마무리
            b.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE);
            if (b.get(CaptureRequest.CONTROL_AE_MODE) == null)
                b.set(CaptureRequest.CONTROL_AE_MODE, CameraMetadata.CONTROL_AE_MODE_ON);

            captureSession.setRepeatingRequest(b.build(), null, null);
            Log.d(TAG, "★ Preview request updated with new settings.");

        } catch (Exception e) {
            Log.e(TAG, "applySettings error", e);
        }
    }

    /* ── 문자열 → Camera2 상수 매핑 ── */
    private Integer flashModeFromString(String s) {
        switch (s.toUpperCase()) {
            case "OFF":    return CameraMetadata.FLASH_MODE_OFF;
            case "SINGLE": return CameraMetadata.FLASH_MODE_SINGLE;
            case "TORCH":  return CameraMetadata.FLASH_MODE_TORCH;
            default:       return null;
        }
    }
    // sceneModeFromString
    private Integer sceneModeFromString(String s) {
        switch (s.toUpperCase()) {
            case "AUTO":
            case "OFF":
            case "DISABLED":
                return CameraMetadata.CONTROL_SCENE_MODE_DISABLED;
            case "PORTRAIT": return CameraMetadata.CONTROL_SCENE_MODE_PORTRAIT;
            case "NIGHT":    return CameraMetadata.CONTROL_SCENE_MODE_NIGHT;
            case "SPORTS":   return CameraMetadata.CONTROL_SCENE_MODE_SPORTS;
            default: return null;
        }
    }
    private Integer colorModeFromString(String s) {
        switch (s.toUpperCase()) {
            case "OFF":              return CameraMetadata.COLOR_CORRECTION_MODE_TRANSFORM_MATRIX;
            case "FAST":             return CameraMetadata.COLOR_CORRECTION_MODE_FAST;
            case "HIGH_QUALITY":     return CameraMetadata.COLOR_CORRECTION_MODE_HIGH_QUALITY;
            case "TRANSFORM_MATRIX": return CameraMetadata.COLOR_CORRECTION_MODE_TRANSFORM_MATRIX;
            default: return null;
        }
    }
    // effectModeFromString
    private Integer effectModeFromString(String s) {
        switch (s.toUpperCase()) {
            case "NONE":
            case "OFF":  return CameraMetadata.CONTROL_EFFECT_MODE_OFF;
            case "MONO": return CameraMetadata.CONTROL_EFFECT_MODE_MONO;
            case "NEGATIVE": return CameraMetadata.CONTROL_EFFECT_MODE_NEGATIVE;
            case "SEPIA": return CameraMetadata.CONTROL_EFFECT_MODE_SEPIA;
            default: return null;
        }
    }
    private Integer noiseReductionFromString(String s) {
        switch (s.toUpperCase()) {
            case "OFF":          return CameraMetadata.NOISE_REDUCTION_MODE_OFF;
            case "FAST":         return CameraMetadata.NOISE_REDUCTION_MODE_FAST;
            case "HIGH_QUALITY": return CameraMetadata.NOISE_REDUCTION_MODE_HIGH_QUALITY;
            case "MINIMAL":      return CameraMetadata.NOISE_REDUCTION_MODE_MINIMAL;
            default:             return null;
        }
    }
    // tonemapFromString
    private Integer tonemapFromString(String s) {
        switch (s.toUpperCase()) {
            case "CONTRAST_CURVE": return CameraMetadata.TONEMAP_MODE_CONTRAST_CURVE;
            case "FAST":           return CameraMetadata.TONEMAP_MODE_FAST;
            case "HIGH_QUALITY":   return CameraMetadata.TONEMAP_MODE_HIGH_QUALITY;
            case "GAMMA_VALUE":    return CameraMetadata.TONEMAP_MODE_GAMMA_VALUE; // ← 추가
            default: return null;
        }
    }
    private Integer antibandingFromString(String s) {
        switch (s.toUpperCase()) {
            case "OFF":  return CameraMetadata.CONTROL_AE_ANTIBANDING_MODE_OFF;
            case "50HZ": return CameraMetadata.CONTROL_AE_ANTIBANDING_MODE_50HZ;
            case "60HZ": return CameraMetadata.CONTROL_AE_ANTIBANDING_MODE_60HZ;
            case "AUTO": return CameraMetadata.CONTROL_AE_ANTIBANDING_MODE_AUTO;
            default:     return null;
        }
    }
    private MeteringRectangle[] parseRegions(String text) {
        if (text == null || text.trim().isEmpty()) return null;
        if (activeArrayRect == null) return null;

        String t = text.trim().toLowerCase();
        if ("full".equals(t)) {
            return new MeteringRectangle[]{
                    new MeteringRectangle(activeArrayRect, MeteringRectangle.METERING_WEIGHT_MAX)
            };
        }
        if ("center".equals(t)) {
            int w = activeArrayRect.width()/3;
            int h = activeArrayRect.height()/3;
            int l = activeArrayRect.left + (activeArrayRect.width()-w)/2;
            int tp = activeArrayRect.top + (activeArrayRect.height()-h)/2;
            return new MeteringRectangle[]{
                    new MeteringRectangle(new Rect(l, tp, l+w, tp+h), MeteringRectangle.METERING_WEIGHT_MAX)
            };
        }

        // 숫자 포맷 "x,y,w,h; x,y,w,h"
        try {
            String[] parts = text.split(";");
            MeteringRectangle[] out = new MeteringRectangle[parts.length];
            for (int i=0;i<parts.length;i++){
                String[] nums = parts[i].trim().split(",");
                if (nums.length != 4) return null;
                int x = Integer.parseInt(nums[0].trim());
                int y = Integer.parseInt(nums[1].trim());
                int w = Integer.parseInt(nums[2].trim());
                int h = Integer.parseInt(nums[3].trim());
                out[i] = new MeteringRectangle(new Rect(x,y,x+w,y+h),
                        MeteringRectangle.METERING_WEIGHT_MAX);
            }
            return out;
        } catch (Exception e) { return null; }
    }


    private void applyZoom(float zoom) {
        if (cameraDevice == null || captureSession == null || previewSurface == null || activeArrayRect == null) return;
        try {
            float z = Math.max(1f, Math.min(zoom, maxZoom));
            int w = activeArrayRect.width(), h = activeArrayRect.height();
            int cropW = (int)(w / z), cropH = (int)(h / z);
            int left = (w - cropW) / 2, top = (h - cropH) / 2;
            Rect zoomRect = new Rect(left, top, left + cropW, top + cropH);

            CaptureRequest.Builder builder =
                    cameraDevice.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW);
            builder.addTarget(previewSurface);
            builder.set(CaptureRequest.SCALER_CROP_REGION, zoomRect);
            builder.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE);
            builder.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON);

            captureSession.setRepeatingRequest(builder.build(), null, bgHandler);
        } catch (Exception e) { e.printStackTrace(); }
    }

    private void applyExposureCompensation(float exposure) {
        if (cameraDevice == null || captureSession == null || previewSurface == null) return;
        try {
            int ev = (int)Math.round(exposure);
            ev = Math.max(aeCompRange.getLower(), Math.min(aeCompRange.getUpper(), ev));

            CaptureRequest.Builder builder =
                    cameraDevice.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW);
            builder.addTarget(previewSurface);
            builder.set(CaptureRequest.CONTROL_AE_EXPOSURE_COMPENSATION, ev);
            builder.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE);
            builder.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON);

            captureSession.setRepeatingRequest(builder.build(), null, bgHandler);
        } catch (Exception e) { e.printStackTrace(); }
    }
}
