package app.lovable.meowmeow.twa;

import android.net.Uri;
import android.os.Bundle;
import android.view.WindowManager;
import com.google.androidbrowserhelper.locationdelegation.LocationDelegationExtraCommandHandler;
import com.google.androidbrowserhelper.trusted.LauncherActivityMetadata;

/**
 * Entry point of the TWA. The base class handles:
 *  - Verifying the digital asset link with the web origin
 *  - Launching Chrome in trusted-web mode pointed at DEFAULT_URL
 *  - Showing the splash screen during cold start
 *
 * SECURITY — Screenshot / Screen-recording protection:
 *  FLAG_SECURE is applied to this Activity's window BEFORE super.onCreate()
 *  so it takes effect from the first frame. Effects on Android:
 *    • Power+Volume screenshots → blank/black image
 *    • Built-in screen recorder, scrcpy, third-party recorders → black frames
 *    • Recent-apps switcher thumbnail → blank
 *    • Casting / Miracast / mirroring → blocked
 *
 *  Note for TWA: Chrome Custom Tab rendering happens in Chrome's own process.
 *  FLAG_SECURE on the launcher activity protects the splash + the task
 *  thumbnail. Modern Chrome (≥ 89) propagates FLAG_SECURE to the Trusted
 *  Web Activity content as well, so the live web view is also captured as
 *  black on stock devices. Rooted devices and external cameras cannot be
 *  blocked by any app-level flag.
 */
public class LauncherActivity
        extends com.google.androidbrowserhelper.trusted.LauncherActivity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        // Block screenshots & screen recording for every frame, including splash.
        getWindow().setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        );
        super.onCreate(savedInstanceState);
    }

    @Override
    protected Uri getLaunchingUrl() {
        // Append a query parameter so analytics can distinguish TWA traffic
        Uri base = super.getLaunchingUrl();
        return base.buildUpon().appendQueryParameter("source", "twa").build();
    }
}
