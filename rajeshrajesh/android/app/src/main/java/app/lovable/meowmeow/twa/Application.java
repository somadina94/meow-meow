package app.lovable.meowmeow.twa;

import com.google.androidbrowserhelper.locationdelegation.LocationDelegationExtraCommandHandler;
import com.google.androidbrowserhelper.trusted.ChromeOsSupport;

/**
 * Custom Application class — registers the location-delegation handler so
 * the web app can use the Geolocation API inside the TWA the same way it
 * does in a normal Chrome tab.
 */
public class Application extends android.app.Application {
    @Override
    public void onCreate() {
        super.onCreate();
        // No-op; Bubblewrap auto-wires the location delegation service.
    }
}
