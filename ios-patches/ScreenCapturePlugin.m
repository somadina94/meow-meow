#import <Foundation/Foundation.h>
#import <Capacitor/Capacitor.h>

// Registers the Swift ScreenCapturePlugin with the Capacitor bridge so it
// is reachable as `Capacitor.Plugins.ScreenCapture` from JavaScript.
CAP_PLUGIN(ScreenCapturePlugin, "ScreenCapture",
    CAP_PLUGIN_METHOD(addListener, CAPPluginReturnCallback);
)
