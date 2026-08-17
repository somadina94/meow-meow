package app.lovable.meowmeow;

import android.os.Bundle;
import android.view.WindowManager;
import com.getcapacitor.BridgeActivity;

/**
 * MainActivity — Capacitor entry point.
 *
 * SECURITY: FLAG_SECURE is set BEFORE super.onCreate so it covers EVERY
 * screen of the app from the very first frame. The OS will:
 *   • Blank screenshots taken with Power+Volume
 *   • Blank screen recordings (built-in recorder, scrcpy, third-party)
 *   • Show a black thumbnail in the recent-apps switcher
 *
 * This applies app-wide — there is no per-page opt-in needed.
 *
 * Note: cannot stop someone photographing the screen with another camera.
 */
public class MainActivity extends BridgeActivity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        // Apply FLAG_SECURE before the activity window is shown.
        getWindow().setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        );

        super.onCreate(savedInstanceState);
    }
}
