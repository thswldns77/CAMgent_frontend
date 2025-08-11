//package com.example.camgent;
//
//import android.content.Context;
//import android.os.Build;
//import android.os.Environment;
//import android.provider.MediaStore;
//import android.content.ContentValues;
//import java.io.OutputStream;
//import java.io.File;
//import java.io.FileOutputStream;
//
///** Camera2 API 로부터 받은 JPEG 바이트를 실제 파일/MediaStore에 저장하고 경로를 리턴 */
//public class NativeCameraCapture {
//    public static String takePictureAndSave(Context context, byte[] jpegData) throws Exception {
//        // 앱 전용 Pictures 디렉토리
//        File picturesDir = context.getExternalFilesDir(Environment.DIRECTORY_PICTURES);
//        if (picturesDir == null) throw new Exception("외부 저장소 접근 불가");
//
//        String filename = "IMG_" + System.currentTimeMillis() + ".jpg";
//        File outFile = new File(picturesDir, filename);
//        // 바이트 쓰기
//        FileOutputStream fos = new FileOutputStream(outFile);
//        fos.write(jpegData);
//        fos.close();
//        return outFile.getAbsolutePath();
//    }
//}
// NativeCameraCapture.java
package com.example.camgent;

import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.Context;
import android.net.Uri;
import android.os.Build;
import android.provider.MediaStore;
import java.io.OutputStream;

public class NativeCameraCapture {

    public static String saveJpegToMediaStore(Context ctx, byte[] jpeg) throws Exception {
        String fileName = "IMG_" + System.currentTimeMillis() + ".jpg";
        ContentResolver resolver = ctx.getContentResolver();

        ContentValues values = new ContentValues();
        values.put(MediaStore.Images.Media.DISPLAY_NAME, fileName);
        values.put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg");
        if (Build.VERSION.SDK_INT >= 29) {
            values.put(MediaStore.Images.Media.RELATIVE_PATH, "DCIM/Camgent");
            values.put(MediaStore.Images.Media.IS_PENDING, 1);
        }

        Uri uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values);
        if (uri == null) throw new Exception("Insert failed");

        try (OutputStream out = resolver.openOutputStream(uri)) {
            if (out == null) throw new Exception("openOutputStream null");
            out.write(jpeg);
            out.flush();
        }

        if (Build.VERSION.SDK_INT >= 29) {
            ContentValues cv = new ContentValues();
            cv.put(MediaStore.Images.Media.IS_PENDING, 0);
            resolver.update(uri, cv, null, null);
        }

        // Flutter 쪽엔 경로 대신 URI 문자열을 반환해도 됨
        return uri.toString();
    }
}
