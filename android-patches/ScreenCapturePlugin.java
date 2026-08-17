package app.lovable.meowmeow;

import android.content.ContentResolver;
import android.database.ContentObserver;
import android.net.Uri;
import android.os.Handler;
import android.os.Looper;
import android.provider.MediaStore;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

/**
 * ScreenCapturePlugin — Android side.
 *
 * Detects:
 *   • Screenshots → ContentObserver on MediaStore.Images. Even though
 *     FLAG_SECURE blanks the image, Android still writes the row, so we
 *     know an attempt was made and emit "screenshotTaken" to JS.
 *   • Screen recording start/stop → emitted via "recordingChanged" with
 *     isRecording boolean. Implemented through DisplayManager registration
 *     in a follow-up; for now the screenshot observer is the primary
 *     attempt-detector and FLAG_SECURE in MainActivity already blocks
 *     both screenshots AND recording at the OS level.
 *
 * INSTALLATION (one-time, after `npx cap add android`):
 *   1. Copy this file to:
 *      android/app/src/main/java/app/lovable/meowmeow/ScreenCapturePlugin.kt
 *      (rename to .java OR use the Kotlin extension if the project supports it —
 *       this file is written in Java for maximum compatibility)
 *   2. Register the plugin in MainActivity.onCreate():
 *        registerPlugin(ScreenCapturePlugin.class);
 *   3. `npx cap sync android` and run.
 */
@CapacitorPlugin(name = "ScreenCapture")
public class ScreenCapturePlugin extends Plugin {

    private ContentObserver screenshotObserver;
    private long lastScreenshotAt = 0L;

    @Override
    public void load() {
        ContentResolver resolver = getContext().getContentResolver();
        Handler handler = new Handler(Looper.getMainLooper());

        screenshotObserver = new ContentObserver(handler) {
            @Override
            public void onChange(boolean selfChange, Uri uri) {
                if (uri == null) return;
                String path = uri.toString().toLowerCase();
                // MediaStore inserts under .../images/media/<id> — filter
                // by name pattern lookup to avoid logging every gallery write.
                queryForScreenshot(uri);
            }
        };
        resolver.registerContentObserver(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            true,
            screenshotObserver
        );
    }

    private void queryForScreenshot(Uri uri) {
        // Throttle — Android can fire onChange multiple times for one capture.
        long now = System.currentTimeMillis();
        if (now - lastScreenshotAt < 2000) return;
        try {
            android.database.Cursor c = getContext().getContentResolver().query(
                uri,
                new String[]{ MediaStore.Images.Media.DISPLAY_NAME, MediaStore.Images.Media.DATE_ADDED },
                null, null, null
            );
            if (c != null && c.moveToFirst()) {
                String name = c.getString(0).toLowerCase();
                if (name.contains("screenshot") || name.contains("screen_") || name.contains("scrnsht")) {
                    lastScreenshotAt = now;
                    JSObject ret = new JSObject();
                    notifyListeners("screenshotTaken", ret);
                }
                c.close();
            }
        } catch (Exception ignored) {}
    }

    @PluginMethod
    public void noop(PluginCall call) {
        call.resolve();
    }

    @Override
    protected void handleOnDestroy() {
        if (screenshotObserver != null) {
            getContext().getContentResolver().unregisterContentObserver(screenshotObserver);
            screenshotObserver = null;
        }
    }
}
